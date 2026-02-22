RELEASE_NAME=chat-bot-app
PROMETHEUS_RELEASE_NAME=monitoring
LOKI_RELEASE_NAME=loki
CHART_PATH=./
VALUES=values.yaml
LOKI_VALUES=loki-values.yaml
SECRETS=secrets-local.yaml

prepare:
	@minikube status > /dev/null 2>&1 || minikube start

all: prepare clean monitor-install up

up:
	helm upgrade --install $(RELEASE_NAME) $(CHART_PATH) -f $(VALUES) -f $(SECRETS)

down:
	helm uninstall $(RELEASE_NAME) || true
	helm uninstall $(PROMETHEUS_RELEASE_NAME) || true
	helm uninstall $(LOKI_RELEASE_NAME) || true

clean: down
	-kubectl delete pvc --all

# --- Мониторинг ---

monitor-install:
	helm repo add prometheus-community https://prometheus-community.github.io/helm-charts
	helm repo add grafana https://grafana.github.io/helm-charts
	helm repo update

	helm upgrade --install $(PROMETHEUS_RELEASE_NAME) prometheus-community/kube-prometheus-stack \
		-n default -f $(VALUES)
	
	helm upgrade --install $(LOKI_RELEASE_NAME) grafana/loki \
		-n default -f $(LOKI_VALUES)

	helm upgrade --install promtail grafana/promtail \
		-n default \
		--set "config.clients[0].url=http://loki-gateway.default.svc.cluster.local/loki/api/v1/push"
		--set "config.clients[0].tenant_id=1"

.PHONY: all up down clean monitor-install