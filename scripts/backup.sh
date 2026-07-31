#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=lib.sh
source "$SCRIPT_DIR/lib.sh"

environment="${1:-local}"
gateway_require_docker
gateway_load_context "$environment"

timestamp="$(date -u +%Y%m%dT%H%M%SZ)"
backup_dir="$GATEWAY_ROOT/backups/${environment}-${timestamp}"
mkdir -p "$backup_dir"
chmod 700 "$backup_dir"

if [[ -z "$(gateway_compose ps -q postgres)" || -z "$(gateway_compose ps -q redis)" ]]; then
  echo "The $environment stack is not running; cannot create a consistent backup." >&2
  exit 1
fi

gateway_compose exec -T postgres sh -c \
  'PGPASSWORD="$POSTGRES_PASSWORD" pg_dump -U postgres -Fc -d newapi' \
  > "$backup_dir/newapi.dump"
gateway_compose exec -T postgres sh -c \
  'PGPASSWORD="$POSTGRES_PASSWORD" pg_dump -U postgres -Fc -d sub2api' \
  > "$backup_dir/sub2api.dump"

redis_container="$(gateway_compose ps -q redis)"
temporary_rdb="/tmp/gateway-${timestamp}.rdb"
cleanup_redis_snapshot() {
  docker exec "$redis_container" rm -f "$temporary_rdb" >/dev/null 2>&1 || true
}
trap cleanup_redis_snapshot EXIT

docker exec "$redis_container" redis-cli --no-auth-warning -a "$REDIS_PASSWORD" --rdb "$temporary_rdb" >/dev/null
docker cp "$redis_container:$temporary_rdb" "$backup_dir/redis.rdb"

printf 'BACKUP_FORMAT=1\nENVIRONMENT=%s\nCREATED_AT_UTC=%s\n' "$environment" "$timestamp" > "$backup_dir/metadata.env"
(cd "$backup_dir" && sha256sum newapi.dump sub2api.dump redis.rdb > SHA256SUMS)

echo "Backup completed: $backup_dir"
echo "Store this directory in encrypted off-host storage. It contains service state."
