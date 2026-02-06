RELEASE_NAME=chat-bot-app
PROMETHEUS_RELEASE_NAME=monitoring
CHART_PATH=./
VALUES=values.yaml
SECRETS=secrets-local.yaml

up:
	helm upgrade --install $(RELEASE_NAME) $(CHART_PATH) -f $(VALUES) -f $(SECRETS) --wait

down:
	helm uninstall $(RELEASE_NAME) || true

clean: down
	kubectl delete pvc --all

# --- Мониторинг ---

monitor-install:
	helm upgrade --install $(PROMETHEUS_RELEASE_NAME) prometheus-community/kube-prometheus-stack \
		--set alertmanager.enabled=false \
		--set prometheus-node-exporter.enabled=true \
		--set kube-state-metrics.enabled=true \
		--create-namespace

port-grafana:
	kubectl port-forward svc/$(PROMETHEUS_RELEASE_NAME)-grafana 3000:80

port-prom:
	kubectl port-forward svc/$(PROMETHEUS_RELEASE_NAME)-kube-prometheus-prometheus 9090

password-grafana:
	@kubectl get secret $(PROMETHEUS_RELEASE_NAME)-grafana -o jsonpath="{.data.admin-password}" | base64 -d ; echo

targets:
	curl -s http://localhost:9090/api/v1/targets | jq '.data.activeTargets[] | {job: .labels.job, status: .health}'

.PHONY: all up down clean monitor-install port-grafana port-prom pass-grafana targets