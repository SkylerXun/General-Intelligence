#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(cd -- "$SCRIPT_DIR/.." && pwd)"
TARGET="$ROOT_DIR/env/local.env"
TEMPLATE="$ROOT_DIR/env/local.env.example"

if [[ -e "$TARGET" ]]; then
  echo "Refusing to overwrite existing local configuration: $TARGET" >&2
  exit 1
fi

generate_secret() {
  if command -v openssl >/dev/null 2>&1; then
    openssl rand -hex 32
  else
    dd if=/dev/urandom bs=32 count=1 2>/dev/null | od -An -tx1 | tr -d ' \n'
  fi
}

install -m 600 "$TEMPLATE" "$TARGET"
for key in \
  POSTGRES_SUPERUSER_PASSWORD \
  NEWAPI_PG_PASSWORD \
  SUB2API_PG_PASSWORD \
  REDIS_PASSWORD \
  NEWAPI_SESSION_SECRET \
  SUB2API_ADMIN_PASSWORD \
  SUB2API_JWT_SECRET \
  SUB2API_TOTP_ENCRYPTION_KEY; do
  value="$(generate_secret)"
  sed -i "s|^${key}=__GENERATE__$|${key}=${value}|" "$TARGET"
done

echo "Created $TARGET with generated local secrets."
echo "The Sub2API administrator password is stored only in that file."
