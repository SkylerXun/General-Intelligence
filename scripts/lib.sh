#!/usr/bin/env bash
set -euo pipefail

GATEWAY_SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
GATEWAY_ROOT="$(cd -- "$GATEWAY_SCRIPT_DIR/.." && pwd)"

gateway_load_context() {
  local environment="${1:-local}"

  case "$environment" in
    local)
      GATEWAY_ENV_FILE="$GATEWAY_ROOT/env/local.env"
      GATEWAY_PROJECT="gateway-local"
      GATEWAY_COMPOSE_FILES=(
        -f "$GATEWAY_ROOT/docker/compose.yaml"
        -f "$GATEWAY_ROOT/docker/compose.local.yaml"
      )
      ;;
    prod)
      GATEWAY_ENV_FILE="$GATEWAY_ROOT/env/production.env"
      GATEWAY_PROJECT="gateway"
      GATEWAY_COMPOSE_FILES=(
        -f "$GATEWAY_ROOT/docker/compose.yaml"
        -f "$GATEWAY_ROOT/docker/compose.prod.yaml"
      )
      ;;
    *)
      echo "Usage: environment must be local or prod." >&2
      return 2
      ;;
  esac

  if [[ ! -f "$GATEWAY_ENV_FILE" ]]; then
    echo "Missing environment file: $GATEWAY_ENV_FILE" >&2
    return 2
  fi

  set -a
  # shellcheck disable=SC1090
  source "$GATEWAY_ENV_FILE"
  set +a
}

gateway_compose() {
  docker compose --project-name "$GATEWAY_PROJECT" --env-file "$GATEWAY_ENV_FILE" "${GATEWAY_COMPOSE_FILES[@]}" "$@"
}

gateway_require_docker() {
  docker version >/dev/null 2>&1 || {
    echo "Docker Engine is unavailable. Run this command inside WSL Ubuntu." >&2
    return 1
  }
}
