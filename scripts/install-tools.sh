#!/usr/bin/env bash
# Installs minikube, kubectl and helm into ~/.local/bin (no root required).
set -euo pipefail

BIN_DIR="${BIN_DIR:-$HOME/.local/bin}"
TMP_DIR="${TMP_DIR:-/tmp/opencode/install}"
MINIKUBE_VERSION="${MINIKUBE_VERSION:-v1.39.0}"
KUBECTL_VERSION="${KUBECTL_VERSION:-v1.37.2}"
HELM_VERSION="${HELM_VERSION:-v3.22.1}"

mkdir -p "$BIN_DIR" "$TMP_DIR"

download() {
  local url="$1" out="$2"
  if [[ -s "$out" ]]; then
    echo "using cached $out"
    return
  fi
  echo "downloading $url"
  curl -fL --retry 10 --retry-delay 2 --retry-all-errors -o "$out" "$url"
}

if ! command -v minikube >/dev/null 2>&1; then
  download "https://storage.googleapis.com/minikube/releases/${MINIKUBE_VERSION}/minikube-linux-amd64" "$TMP_DIR/minikube"
  install -m 0755 "$TMP_DIR/minikube" "$BIN_DIR/minikube"
fi

if ! command -v kubectl >/dev/null 2>&1; then
  download "https://dl.k8s.io/release/${KUBECTL_VERSION}/bin/linux/amd64/kubectl" "$TMP_DIR/kubectl"
  install -m 0755 "$TMP_DIR/kubectl" "$BIN_DIR/kubectl"
fi

if ! command -v helm >/dev/null 2>&1; then
  download "https://get.helm.sh/helm-${HELM_VERSION}-linux-amd64.tar.gz" "$TMP_DIR/helm.tar.gz"
  tar -xzf "$TMP_DIR/helm.tar.gz" -C "$TMP_DIR"
  install -m 0755 "$TMP_DIR/linux-amd64/helm" "$BIN_DIR/helm"
fi

echo
echo "Installed:"
minikube version | head -1
kubectl version --client | head -1
helm version --short
