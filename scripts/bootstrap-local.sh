#!/usr/bin/env bash
# Brings up the whole chat-bot stack on a local minikube cluster.
#
#   ./scripts/bootstrap-local.sh
#
# Tunables (environment variables):
#   MINIKUBE_PROFILE=minikube
#   MINIKUBE_CPUS=4
#   MINIKUBE_MEMORY=8192      # MB
#   MINIKUBE_DISK=30g
#   SKIP_OBS=1                # skip the observability stack
#
# Optional GHCR credentials (images are public today, so this is normally
# unnecessary). If set, an image pull secret named ghcr-pull-secret is created:
#   GHCR_USERNAME=... GHCR_TOKEN=... ./scripts/bootstrap-local.sh
set -euo pipefail

cd "$(dirname "${BASH_SOURCE[0]}")/.."

PROFILE="${MINIKUBE_PROFILE:-minikube}"
CPUS="${MINIKUBE_CPUS:-4}"
MEMORY="${MINIKUBE_MEMORY:-8192}"
DISK="${MINIKUBE_DISK:-30g}"

log() { printf '\n==> %s\n' "$*"; }

need() {
  command -v "$1" >/dev/null 2>&1 || {
    echo "Required command '$1' is not installed." >&2
    echo "Run ./scripts/install-tools.sh first." >&2
    exit 1
  }
}

need docker
need minikube
need kubectl
need helm

log "Checking Docker"
if ! docker info >/dev/null 2>&1; then
  echo "Cannot talk to the Docker daemon as $(id -un)." >&2
  echo "Install Docker with: sudo ./scripts/install-docker.sh" >&2
  echo "Then log out/in (or run 'newgrp docker') and retry." >&2
  exit 1
fi

log "Checking secrets"
if [[ ! -f secrets-local.yaml ]]; then
  ./scripts/generate-secrets.sh
fi

log "Starting minikube (profile: $PROFILE, ${CPUS} CPUs, ${MEMORY} MB RAM, ${DISK} disk)"
if ! minikube status -p "$PROFILE" >/dev/null 2>&1; then
  minikube start -p "$PROFILE" \
    --driver=docker \
    --cpus="$CPUS" \
    --memory="$MEMORY" \
    --disk-size="$DISK"
fi

log "Ensuring the ingress addon is enabled"
if ! minikube addons list -p "$PROFILE" | grep -E '^ingress\s*\|.*enabled' >/dev/null 2>&1; then
  minikube addons enable ingress -p "$PROFILE"
fi

log "Waiting for the ingress controller"
for _ in $(seq 1 60); do
  kubectl get namespace ingress-nginx >/dev/null 2>&1 && break
  sleep 2
done
kubectl wait --namespace ingress-nginx \
  --for=condition=ready pod \
  --selector=app.kubernetes.io/component=controller \
  --timeout=300s

if [[ -n "${GHCR_USERNAME:-}" && -n "${GHCR_TOKEN:-}" ]]; then
  log "Creating ghcr-pull-secret"
  kubectl create secret docker-registry ghcr-pull-secret \
    --docker-server=ghcr.io \
    --docker-username="$GHCR_USERNAME" \
    --docker-password="$GHCR_TOKEN" \
    --dry-run=client -o yaml | kubectl apply -f -
fi

if [[ "${SKIP_OBS:-0}" != "1" ]]; then
  log "Installing observability stack (Prometheus, Loki, Jaeger, OTel)"
  # Must run before the app chart: the chart contains a ServiceMonitor CRD object.
  make obs-install
fi

log "Installing the application chart"
make up

log "Cluster state"
kubectl get pods,jobs,svc,ingress

MINIKUBE_IP="$(minikube ip -p "$PROFILE")"
cat <<EOF

Stack deployed.

Option A - hosts file (all ingress hosts):
  echo "${MINIKUBE_IP} chat-bot.local monitoring.local jaeger.local rabbitmq.local" | sudo tee -a /etc/hosts

Option B - no root, use port forwarding:
  ./scripts/port-forward.sh

Migrator logs:
  kubectl logs job/migrator
EOF
