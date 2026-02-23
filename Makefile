RELEASE_NAME            = chat-bot-app
PROMETHEUS_RELEASE_NAME = monitoring
LOKI_RELEASE_NAME       = loki
JAEGER_RELEASE_NAME     = jaeger
OTEL_RELEASE_NAME       = otel-collector

CHART_PATH    = ./
VALUES        = values.yaml
LOKI_VALUES   = loki-values.yaml
JAEGER_VALUES = jaeger-values.yaml
OTEL_VALUES   = otel-values.yaml
SECRETS       = secrets-local.yaml

prepare:
	@minikube status > /dev/null 2>&1 || minikube start

all: prepare clean obs-install up

up:
	helm upgrade --install $(RELEASE_NAME) $(CHART_PATH) -f $(VALUES) -f $(SECRETS)

down:
	helm uninstall $(RELEASE_NAME) || true
	helm uninstall $(PROMETHEUS_RELEASE_NAME) || true
	helm uninstall $(LOKI_RELEASE_NAME) || true
	helm uninstall promtail || true
	helm uninstall $(JAEGER_RELEASE_NAME) || true
	helm uninstall $(OTEL_RELEASE_NAME) || true

clean: down
	-kubectl delete pvc --all

# --- Observability Stack ---

obs-install: repo-add prometheus-stack-install loki-install jaeger-install otel-install
	@echo "--- [Observability Stack Installed Successfully] ---"

repo-add:
	helm repo add prometheus-community https://prometheus-community.github.io/helm-charts
	helm repo add grafana https://grafana.github.io/helm-charts
	helm repo add jaegertracing https://jaegertracing.github.io/helm-charts
	helm repo add open-telemetry https://open-telemetry.github.io/opentelemetry-helm-charts
	helm repo update

prometheus-stack-install:
	helm upgrade --install $(PROMETHEUS_RELEASE_NAME) prometheus-community/kube-prometheus-stack \
		-n default -f $(VALUES)

loki-install:
	helm upgrade --install $(LOKI_RELEASE_NAME) grafana/loki \
		-n default -f $(LOKI_VALUES)
	helm upgrade --install promtail grafana/promtail \
		-n default \
		--set "config.clients[0].url=http://loki-gateway.default.svc.cluster.local/loki/api/v1/push" \
		--set "config.clients[0].tenant_id=1"

jaeger-install:
	helm upgrade --install $(JAEGER_RELEASE_NAME) jaegertracing/jaeger \
		-n default -f $(JAEGER_VALUES)

otel-install:
	helm upgrade --install $(OTEL_RELEASE_NAME) open-telemetry/opentelemetry-collector \
		-n default -f $(OTEL_VALUES)

.PHONY: prepare all up down clean obs-install otel-install jaeger-install loki-install prometheus-stack-install repo-add