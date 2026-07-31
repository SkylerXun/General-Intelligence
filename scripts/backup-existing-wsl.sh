#!/usr/bin/env bash
set -euo pipefail

# One-time backup helper for the six pre-existing containers. It is intentionally
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

containers=(new-api postgres redis sub2api sub2api-postgres sub2api-redis)
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

# Logical database dumps are easier to restore and review than raw volume data.
for container in postgres sub2api-postgres; do
  docker exec "$container" sh -c \
    'PGPASSWORD="$POSTGRES_PASSWORD" pg_dumpall -U "$POSTGRES_USER"' \
    > "$backup_dir/${container}-all.sql"
done

# Copy every named volume from the existing stack without stopping containers.
declare -A seen_volumes=()
for container in "${containers[@]}"; do
  while IFS= read -r volume; do
    [[ -z "$volume" || -n "${seen_volumes[$volume]:-}" ]] && continue
    seen_volumes[$volume]=1
    safe_name="${volume//[^A-Za-z0-9_.-]/_}"
    docker run --rm \
      -v "${volume}:/source:ro" \
      -v "${backup_dir}/volumes:/backup" \
      alpine:3.21 \
      tar -C /source -czf "/backup/${safe_name}.tar.gz" .
  done < <(docker inspect --format '{{range .Mounts}}{{if eq .Type "volume"}}{{println .Name}}{{end}}{{end}}' "$container")
done

printf 'BACKUP_FORMAT=1\nCREATED_AT_UTC=%s\n' "$timestamp" > "$backup_dir/metadata.env"
(cd "$backup_dir" && sha256sum *.sql volumes/*.tar.gz > SHA256SUMS)

echo "Existing runtime backup completed: $backup_dir"
echo "It contains sensitive data. Move it to encrypted off-host storage before any migration."
