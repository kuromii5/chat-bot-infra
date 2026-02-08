RELEASE_NAME=chat-bot-app
PROMETHEUS_RELEASE_NAME=monitoring
CHART_PATH=./
VALUES=values.yaml
SECRETS=secrets-local.yaml

all: monitor-install up

up:
	helm upgrade --install $(RELEASE_NAME) $(CHART_PATH) -f $(VALUES) -f $(SECRETS)

down:
	helm uninstall $(RELEASE_NAME) || true

clean: down
	kubectl delete pvc --all

# --- Мониторинг ---

monitor-install:
	helm repo add prometheus-community https://prometheus-community.github.io/helm-charts
	helm repo update
	helm upgrade --install $(PROMETHEUS_RELEASE_NAME) prometheus-community/kube-prometheus-stack \
		--set alertmanager.enabled=false \
		--set prometheus-node-exporter.enabled=true \
		--set kube-state-metrics.enabled=true \
		--set grafana."grafana.ini".server.root_url="http://monitoring.local/grafana/" \
		--set grafana."grafana.ini".server.serve_from_sub_path=true \
		--set prometheus.prometheusSpec.externalUrl="http://monitoring.local/prometheus" \
		--set prometheus.prometheusSpec.routePrefix="/" \
		--create-namespace

port-grafana:
	kubectl port-forward svc/$(PROMETHEUS_RELEASE_NAME)-grafana 3000:80

port-prom:
	kubectl port-forward svc/$(PROMETHEUS_RELEASE_NAME)-kube-prometheus-prometheus 9090

password-grafana:
	@kubectl get secret $(PROMETHEUS_RELEASE_NAME)-grafana -o jsonpath="{.data.admin-password}" | base64 -d ; echo

targets:
	curl -s http://localhost:9090/api/v1/targets | jq '.data.activeTargets[] | {job: .labels.job, status: .health}'

.PHONY: all up down clean monitor-install port-grafana port-prom password-grafana targets