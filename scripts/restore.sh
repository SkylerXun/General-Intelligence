#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=lib.sh
source "$SCRIPT_DIR/lib.sh"

environment="${1:-}"
backup_dir="${2:-}"
confirmation="${3:-}"

if [[ "$environment" != "local" && "$environment" != "prod" ]] || [[ -z "$backup_dir" ]]; then
  echo "Usage: $0 <local|prod> <backup-directory> --yes-i-understand-this-overwrites-gateway-data" >&2
  exit 2
fi
if [[ "$confirmation" != "--yes-i-understand-this-overwrites-gateway-data" ]]; then
  echo "Refusing restore without the exact destructive-operation confirmation." >&2
  exit 2
fi

for file in newapi.dump sub2api.dump redis.rdb SHA256SUMS; do
  [[ -f "$backup_dir/$file" ]] || { echo "Backup is missing $file" >&2; exit 2; }
done
(cd "$backup_dir" && sha256sum -c SHA256SUMS)

gateway_require_docker
gateway_load_context "$environment"

echo "Stopping application services for restore."
gateway_compose stop new-api sub2api redis
gateway_compose up -d postgres

for attempt in {1..30}; do
  if gateway_compose exec -T postgres pg_isready -U postgres -d postgres >/dev/null 2>&1; then
    break
  fi
  if [[ "$attempt" == "30" ]]; then
    echo "PostgreSQL did not become ready." >&2
    exit 1
  fi
  sleep 2
done

for database in newapi sub2api; do
  gateway_compose exec -T postgres sh -c \
    "PGPASSWORD=\"\$POSTGRES_PASSWORD\" psql -v ON_ERROR_STOP=1 -U postgres -d postgres -c \"DROP DATABASE IF EXISTS ${database} WITH (FORCE);\" -c \"CREATE DATABASE ${database} OWNER ${database};\""
  gateway_compose exec -T postgres sh -c \
    "PGPASSWORD=\"\$POSTGRES_PASSWORD\" pg_restore --no-owner --no-privileges -U postgres -d ${database}" \
    < "$backup_dir/${database}.dump"
done

# The Redis AOF is removed so Redis restores from this validated RDB snapshot.
gateway_compose run --rm --no-deps --entrypoint sh redis -c \
  'rm -rf /data/appendonlydir /data/dump.rdb && cat > /data/dump.rdb' \
  < "$backup_dir/redis.rdb"

gateway_compose up -d
echo "Restore completed. Run scripts/smoke-test.sh $environment before accepting traffic."
