#!/usr/bin/env bash
set -euo pipefail

# One-time backup helper for the pre-existing New API runtime. It is intentionally
# read-only toward those containers and requires an explicit confirmation.
confirmation="${1:-}"
target_root="${2:-/mnt/d/gateway/backups}"

if [[ "$confirmation" != "--confirm-existing-runtime-backup" ]]; then
  echo "Usage: $0 --confirm-existing-runtime-backup [target-directory]" >&2
  exit 2
fi

docker version >/dev/null 2>&1 || {
  echo "Docker Engine is unavailable." >&2
  exit 1
}

timestamp="$(date -u +%Y%m%dT%H%M%SZ)"
backup_dir="$target_root/existing-runtime-${timestamp}"
mkdir -p "$backup_dir/volumes"
chmod 700 "$backup_dir"

containers=(new-api postgres redis)
for container in "${containers[@]}"; do
  docker inspect "$container" >/dev/null 2>&1 || {
    echo "Required existing container is missing: $container" >&2
    exit 1
  }
done

# Record only names, images, state, and mount identities. Never export env vars.
for container in "${containers[@]}"; do
  docker inspect --format \
    '{{.Name}} image={{.Config.Image}} state={{.State.Status}}{{range .Mounts}} {{.Type}}:{{.Name}}->{{.Destination}}{{end}}' \
    "$container"
done > "$backup_dir/runtime-inventory.txt"

# Export only the New API database. This deliberately excludes any other database
# that may still exist in the old PostgreSQL instance.
docker exec postgres sh -c \
  'PGPASSWORD="$POSTGRES_PASSWORD" pg_dump -Fc -U "$POSTGRES_USER" -d newapi' \
  > "$backup_dir/newapi.dump"

# Capture the Redis snapshot used by New API. The old instance may contain other
# logical databases; the new single-service stack restores this snapshot as-is.
redis_snapshot=/tmp/newapi-migration.rdb
docker exec redis sh -c \
  'redis-cli --no-auth-warning -a "$REDIS_PASSWORD" --rdb "$1" >/dev/null' \
  sh "$redis_snapshot"
docker cp "redis:$redis_snapshot" "$backup_dir/redis.rdb"
docker exec redis rm -f "$redis_snapshot" >/dev/null 2>&1 || true

# Copy the New API data volume without stopping containers. The output name and
# checksum format match scripts/restore.sh, so this backup can be moved directly.
newapi_volume="$(docker inspect --format '{{range .Mounts}}{{if eq .Destination "/data"}}{{.Name}}{{end}}{{end}}' new-api)"
[[ -n "$newapi_volume" ]] || { echo "Could not locate the New API data volume." >&2; exit 1; }
docker run --rm \
  -v "$newapi_volume:/source:ro" \
  -v "$backup_dir:/backup" \
  alpine:3.21 \
  tar -C /source -czf /backup/newapi_data.tar.gz .

printf 'BACKUP_FORMAT=1\nCREATED_AT_UTC=%s\n' "$timestamp" > "$backup_dir/metadata.env"
(cd "$backup_dir" && sha256sum newapi.dump redis.rdb newapi_data.tar.gz > SHA256SUMS)

echo "Existing runtime backup completed: $backup_dir"
echo "It contains sensitive data. Move it to encrypted off-host storage before any migration."
