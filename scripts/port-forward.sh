#!/usr/bin/env bash
# Port-forwards the stack to localhost. Useful when you cannot edit /etc/hosts.
#
#   ./scripts/port-forward.sh
#
# Endpoints:
#   API             http://localhost:8080
#   Auth (direct)   http://localhost:8082   (needed for /api/v1/users/preferences)
#   Grafana         http://localhost:3000
#   Prometheus      http://localhost:9090
#   Jaeger          http://localhost:16686
#   RabbitMQ UI     http://localhost:15672
set -euo pipefail

pids=()

cleanup() {
  if ((${#pids[@]})); then
    kill "${pids[@]}" 2>/dev/null || true
  fi
}
trap cleanup EXIT INT TERM

forward() {
  local svc="$1" ports="$2"
  if kubectl get "svc/$svc" >/dev/null 2>&1; then
    kubectl port-forward "svc/$svc" "$ports" >/dev/null 2>&1 &
    pids+=("$!")
    echo "port-forward svc/$svc $ports"
  else
    echo "skip svc/$svc (not found)"
  fi
}

forward gateway-service 8080:80
forward auth-service 8082:8080
forward monitoring-grafana 3000:80
forward monitoring-kube-prometheus-prometheus 9090:9090
forward rabbitmq-service 15672:15672

if kubectl get svc/jaeger-query >/dev/null 2>&1; then
  forward jaeger-query 16686:16686
else
  forward jaeger 16686:16686
fi

echo "Press Ctrl+C to stop."
wait
