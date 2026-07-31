#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(cd -- "$SCRIPT_DIR/.." && pwd)"
submodule="${1:-}"
revision="${2:-}"

if [[ "$submodule" != "new-api" && "$submodule" != "sub2api" ]] || [[ -z "$revision" ]]; then
  echo "Usage: $0 <new-api|sub2api> <explicit-commit-or-tag>" >&2
  exit 2
fi

if [[ -n "$(git -C "$ROOT_DIR/$submodule" status --porcelain)" ]]; then
  echo "Refusing to update a dirty submodule: $submodule" >&2
  exit 1
fi

git -C "$ROOT_DIR/$submodule" fetch --tags origin
target="$(git -C "$ROOT_DIR/$submodule" rev-parse --verify "${revision}^{commit}")"
git -C "$ROOT_DIR/$submodule" checkout --detach "$target"

echo "$submodule now points to $target"
echo "Review 'git -C $ROOT_DIR diff --submodule=log' and commit the root pointer when approved."
