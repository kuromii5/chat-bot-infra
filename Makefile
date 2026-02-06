RELEASE_NAME=chat-bot-app
CHART_PATH=./
VALUES=values.yaml
SECRETS=secrets-local.yaml

all: clean up

up:
	helm upgrade --install $(RELEASE_NAME) $(CHART_PATH) -f $(VALUES) -f $(SECRETS)

down:
	helm uninstall $(RELEASE_NAME) || true

clean: down
	kubectl delete pvc --all

.PHONY: all up down clean