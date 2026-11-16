# Локальный запуск инфраструктуры chat-bot

Инфраструктура поднимается в **minikube** (driver `docker`) через **Helm**.
Docker Compose в проекте отсутствует.

Все команды ниже выполняются из каталога `chat-bot-infra`.

## 1. Быстрый старт

```bash
cd chat-bot-infra

./scripts/install-tools.sh        # minikube, kubectl, helm -> ~/.local/bin
sudo ./scripts/install-docker.sh  # Docker из репозитория Ubuntu
newgrp docker                     # или перелогиниться

./scripts/bootstrap-local.sh      # секреты, minikube, ingress, observability, приложение
```

`bootstrap-local.sh` делает всё по порядку:

1. проверяет Docker, minikube, kubectl, helm;
2. создаёт `secrets-local.yaml`, если его нет (случайные пароли, mode 600);
3. стартует minikube и включает ingress-addon;
4. ставит observability-стек (`make obs-install`);
5. ставит приложение (`make up`);
6. печатает состояние кластера и подсказку по `/etc/hosts`.

## 2. Состав стека

| Компонент | Порт | Доступ |
|---|---:|---|
| API (nginx gateway) | 80 | `http://chat-bot.local` |
| Auth Service | 8080, gRPC 50051, metrics 9000 | внутри кластера |
| Chat Service | 8081, metrics 9000 | внутри кластера |
| Notification Service | metrics 9000 | без HTTP API |
| PostgreSQL 18 | 5432 | внутри кластера |
| RabbitMQ | 5672, UI 15672 | `http://rabbitmq.local` |
| Kafka | 9092, 9093 | внутри кластера |
| Elasticsearch | 9200 | развёрнут, но кодом не используется |
| Prometheus / Grafana | 9090 / 3000 | `http://monitoring.local/prometheus`, `/grafana/` |
| Jaeger | 16686 | `http://jaeger.local` |
| OTel Collector | 4317, 4318 | внутри кластера |

Grafana: `admin` / `admin`.

## 3. Доступ к ingress-хостам

Вариант A — `/etc/hosts` (нужен root):

```bash
echo "$(minikube ip) chat-bot.local monitoring.local jaeger.local rabbitmq.local" | sudo tee -a /etc/hosts
```

Вариант B — без root, port-forward:

```bash
./scripts/port-forward.sh
```

Тогда API — `http://localhost:8080`, Grafana — `http://localhost:3000`,
Prometheus — `http://localhost:9090`, Jaeger — `http://localhost:16686`,
RabbitMQ UI — `http://localhost:15672`, auth-service напрямую — `http://localhost:8082`.

## 4. Секреты

`secrets-local.yaml` создаётся скриптом `scripts/generate-secrets.sh`
(или автоматически из `bootstrap-local.sh`). Файл в `.gitignore`, права `600`.

Если файл нужно пересоздать:

```bash
rm secrets-local.yaml
./scripts/generate-secrets.sh
```

SMTP-значения — заглушки. Для реальной отправки писем укажите рабочий SMTP-сервер.

## 5. Образы

Образы в `values.yaml` лежат в публичном GHCR:

- `ghcr.io/kuromii5/chat-bot-auth-service:v2.13`
- `ghcr.io/kuromii5/chat-bot-chat-service:v2.16`
- `ghcr.io/kuromii5/chat-bot-notification-service:v1.2`
- `ghcr.io/kuromii5/chat-bot-migrations:v1.4`

Проверено: манифесты отдаются анонимно (HTTP 200), pull-secret не обязателен.
Если пакеты станут приватными, `bootstrap-local.sh` создаст секрет при наличии
переменных:

```bash
GHCR_USERNAME=<user> GHCR_TOKEN=<PAT with read:packages> ./scripts/bootstrap-local.sh
```

## 6. Полезные команды

```bash
# Состояние
kubectl get pods,jobs,svc,ingress
kubectl get pvc
kubectl logs job/migrator

# Логи сервисов
kubectl logs deploy/auth-service
kubectl logs deploy/chat-service
kubectl logs deploy/notification-service

# Переустановить только приложение
make up

# Переустановить observability + приложение
make obs-install && make up

# Удалить релизы (PVC и кластер остаются)
./scripts/teardown-local.sh

# Полный сброс: релизы, PVC, minikube-профиль
./scripts/teardown-local.sh --purge
```

## 7. API: минимальный сценарий

```bash
BASE=http://chat-bot.local

# Human
curl -sS -X POST "$BASE/api/v1/auth/register" -H 'Content-Type: application/json' -d '{
  "email":"human@example.com","password":"password123","username":"human1",
  "role":"Human","email_notifications_enabled":true
}'

# AI
curl -sS -X POST "$BASE/api/v1/auth/register" -H 'Content-Type: application/json' -d '{
  "email":"ai@example.com","password":"password123","username":"ai1",
  "role":"AI","email_notifications_enabled":true
}'

# Логин
curl -sS -X POST "$BASE/api/v1/auth/login" -H 'Content-Type: application/json' \
  -d '{"email":"human@example.com","password":"password123"}'
```

Дальше: `POST /api/v1/chat/send`, `POST /api/v1/chat/rooms/{id}/claim`,
`POST /api/v1/chat/rooms/{id}/close`, `PUT /api/v1/chat/profile/tags`,
WebSocket `/api/v1/chat/ws`.

## 8. Известные ограничения чарта

1. **`/api/v1/users/preferences` не проксируется gateway.** Используйте
   `./scripts/port-forward.sh` и `http://localhost:8082/api/v1/users/preferences`.
2. **`ghcr-pull-secret` упоминается в deployment'ах, но не создаётся Makefile.**
   Для публичных образов это только предупреждение.
3. **SMTP username не прокидывается** в `templates/notification/configmap.yaml`.
4. **Notification tracing**: ConfigMap задаёт `TRACING_*`, код читает `OTEL_*`.
5. **`make all` и `make clean` удаляют все PVC в namespace** — это полный сброс данных.
6. **`make prepare` не включает ingress-addon** — это делает `bootstrap-local.sh`.
7. **Версии observability-чартов не зафиксированы** в Makefile.
8. **Elasticsearch не используется** Go-кодом, но потребляет память. При нехватке
   RAM можно уменьшить `MINIKUBE_MEMORY` или убрать elastic из чарта.
9. **Образ `chat-bot-migrations:v1.4` в GHCR устарел**: в нём миграции только до
   009, а репозиторий содержит 010 и 011 (010 нужна auth-service). Если БД уже
   содержит 010/011, `make up` упадёт с `unknown migration in database`.
   Локальная сборка и загрузка в minikube:
   ```bash
   cd ../chat-bot-migrations
   docker build -f ../chat-bot-infra/scripts/Dockerfile.migrator-local \
     -t ghcr.io/kuromii5/chat-bot-migrations:v1.4 .
   minikube image load ghcr.io/kuromii5/chat-bot-migrations:v1.4 --overwrite
   ```
   После пересоздания minikube образ нужно загрузить снова.
10. **`migrator` — pre-upgrade hook.** Если PVC `pg-data` удалён, helm-хук ждёт
    `db`, а PVC создаётся только после хука — дедлок. Обход:
    `helm upgrade --install ... --no-hooks`, дождаться `db`, затем `make up`.
11. **Kafka однонодовая.** В чарте зафиксированы replication factor = 1 для
    внутренних топиков; без этого consumer group не работает.

## 9. Требования к ресурсам

По умолчанию: 4 CPU, 8 ГБ RAM, 30 ГБ диска. Переопределяется переменными:

```bash
MINIKUBE_CPUS=6 MINIKUBE_MEMORY=10240 MINIKUBE_DISK=40g ./scripts/bootstrap-local.sh
```
