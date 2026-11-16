#!/usr/bin/env bash
# Removes the chat-bot Helm releases.
#
#   ./scripts/teardown-local.sh           # releases only, PVCs and cluster stay
#   ./scripts/teardown-local.sh --purge   # also delete PVCs and the minikube profile
set -euo pipefail

cd "$(dirname "${BASH_SOURCE[0]}")/.."

PROFILE="${MINIKUBE_PROFILE:-minikube}"
PURGE=0
[[ "${1:-}" == "--purge" ]] && PURGE=1

echo "==> Uninstalling Helm releases"
make down

if [[ "$PURGE" == "1" ]]; then
  echo "==> Deleting all PVCs in the current namespace"
  kubectl delete pvc --all --ignore-not-found
  echo "==> Deleting minikube profile '$PROFILE'"
  minikube delete -p "$PROFILE"
else
  echo "PVCs and the minikube profile were kept. Use --purge for a full reset."
fi
