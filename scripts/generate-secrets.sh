#!/usr/bin/env bash
# Generates chat-bot-infra/secrets-local.yaml with random development secrets.
# The file is gitignored and created with mode 600. Existing file is kept.
set -euo pipefail

cd "$(dirname "${BASH_SOURCE[0]}")/.."

OUT="secrets-local.yaml"

if [[ -f "$OUT" ]]; then
  echo "$OUT already exists, leaving it untouched."
  exit 0
fi

umask 077

pg_super="$(openssl rand -hex 16)"
pg_admin="$(openssl rand -hex 16)"
pg_app="$(openssl rand -hex 16)"
pg_ro="$(openssl rand -hex 16)"
rmq_pass="$(openssl rand -hex 16)"
jwt_secret="$(openssl rand -hex 32)"
smtp_pass="$(openssl rand -hex 16)"

cat > "$OUT" <<EOF
# Local development secrets. Generated $(date -u +%Y-%m-%dT%H:%M:%SZ).
# This file is gitignored. Do not use these values in production.

db:
  superuser:
    password: "${pg_super}"
  admin:
    password: "${pg_admin}"
  app:
    password: "${pg_app}"
  readonly:
    password: "${pg_ro}"

rabbitmq:
  user: "admin"
  password: "${rmq_pass}"

authService:
  jwt:
    secret: "${jwt_secret}"

notificationService:
  smtp:
    # Replace with a real SMTP server if you need email delivery.
    # Keep host/from non-empty: the Helm template renders them as plain strings.
    host: "smtp.example.com"
    port: 587
    from: "noreply@chat-bot.local"
    password: "${smtp_pass}"
EOF

chmod 600 "$OUT"
echo "created $(pwd)/$OUT (mode 600)"
