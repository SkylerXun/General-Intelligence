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
gateway_compose build new-api
gateway_compose build sub2api
gateway_compose up -d --no-build

echo "New API:  http://localhost:${NEWAPI_LOCAL_PORT}"
echo "Sub2API:  http://localhost:${SUB2API_LOCAL_PORT}"
echo "Run scripts/smoke-test.sh local after both services are healthy."
