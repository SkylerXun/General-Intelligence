#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=lib.sh
source "$SCRIPT_DIR/lib.sh"

gateway_require_docker

if [[ ! -f "$GATEWAY_ROOT/env/local.env" ]]; then
  "$SCRIPT_DIR/init-local.sh"
fi

gateway_load_context local
# Build serially: the local WSL allocation is small and an existing stack may
# still be running. This does not touch that existing Compose project.
if [[ "${GATEWAY_SKIP_NEWAPI_BUILD:-false}" == "true" ]]; then
  docker image inspect "$NEWAPI_IMAGE" >/dev/null 2>&1 || {
    echo "GATEWAY_SKIP_NEWAPI_BUILD=true requires an existing $NEWAPI_IMAGE image." >&2
    exit 1
  }
  echo "Reusing existing New API image: $NEWAPI_IMAGE"
else
  gateway_compose build new-api
fi
gateway_compose build sub2api
gateway_compose up -d --no-build

echo "New API:  http://localhost:${NEWAPI_LOCAL_PORT}"
echo "Sub2API:  http://localhost:${SUB2API_LOCAL_PORT}"
echo "Run scripts/smoke-test.sh local after both services are healthy."
