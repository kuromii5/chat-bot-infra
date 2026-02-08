RELEASE_NAME=chat-bot-app
PROMETHEUS_RELEASE_NAME=monitoring
CHART_PATH=./
VALUES=values.yaml
SECRETS=secrets-local.yaml

all: clean monitor-install up

up:
	helm upgrade --install $(RELEASE_NAME) $(CHART_PATH) -f $(VALUES) -f $(SECRETS)

down:
	helm uninstall $(RELEASE_NAME) || true
	helm uninstall $(PROMETHEUS_RELEASE_NAME) || true

clean: down
	kubectl delete pvc --all

# --- Мониторинг ---

monitor-install:
	helm repo add prometheus-community https://prometheus-community.github.io/helm-charts
	helm repo update
	helm upgrade --install $(PROMETHEUS_RELEASE_NAME) prometheus-community/kube-prometheus-stack \
		--namespace default \
		-f values.yaml \
		--create-namespace

password-grafana:
	@kubectl get secret $(PROMETHEUS_RELEASE_NAME)-grafana -o jsonpath="{.data.admin-password}" | base64 -d ; echo

targets:
	curl -s http://localhost:9090/api/v1/targets | jq '.data.activeTargets[] | {job: .labels.job, status: .health}'

.PHONY: all up down clean monitor-install port-grafana port-prom password-grafana targets