RELEASE_NAME=chat-bot-app
CHART_PATH=./
VALUES=values.yaml
SECRETS=secrets-local.yaml

MIGRATOR_IMAGE=migrator:latest

all: clean migrator-build up

migrator-build:
	docker build -t $(MIGRATOR_IMAGE) -f ../migrations/Dockerfile.migrate ../migrations
	minikube image load $(MIGRATOR_IMAGE)

up:
	helm upgrade --install $(RELEASE_NAME) $(CHART_PATH) -f $(VALUES) -f $(SECRETS)

down:
	helm uninstall $(RELEASE_NAME) || true

clean: down
	kubectl delete pvc --all
	kubectl delete jobs --all || true
	kubectl delete secrets --all || true

restart:
	kubectl rollout restart deployment
	kubectl delete jobs --all || true

.PHONY: all up down clean restart