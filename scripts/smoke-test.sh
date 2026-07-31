#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=lib.sh
source "$SCRIPT_DIR/lib.sh"

environment="${1:-local}"
gateway_require_docker
gateway_load_context "$environment"

for service in postgres redis new-api sub2api; do
  if [[ -z "$(gateway_compose ps -q "$service")" ]]; then
    echo "Missing running service: $service" >&2
    exit 1
  fi
done

gateway_compose exec -T new-api sh -c \
  'wget -q -O - http://localhost:3000/api/status | grep -q "\"success\""'
gateway_compose exec -T sub2api wget -q -T 5 -O /dev/null http://localhost:8080/health

evicted_keys="$(gateway_compose exec -T redis sh -c \
  'redis-cli --no-auth-warning -a "$REDIS_PASSWORD" INFO stats | sed -n "s/^evicted_keys://p"' | tr -d '\r')"
if [[ "$evicted_keys" != "0" ]]; then
  echo "Redis evicted_keys is $evicted_keys; expected 0 under noeviction." >&2
  exit 1
fi

echo "Infrastructure smoke test passed for $environment."
echo "Complete the application acceptance checklist in docs/operations.md before public use."
