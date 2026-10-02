#!/usr/bin/env bash
# List every workflow in the workspace — id, title, who created/last
# modified it, when, and whether it's disabled. Useful for finding a
# workflow by name/topic when you only have a vague description, or for
# searching across several workflows.
#
# Usage:
#   list_workflows.sh [env_name]
#
# Needs SUMGATE_SCOPE (see save_config.sh) — same requirement as the Step 6
# run-history scripts.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck disable=SC1091
source "${SCRIPT_DIR}/_resolve_env.sh"

if [ "$#" -gt 1 ]; then
  echo "Usage: $0 [env_name]" >&2
  exit 1
fi

resolve_env "${1:-}"
require_scope

RESPONSE=$(curl -s "${SUMGATE_BASE_URL}/api/workflows/list?scope=${SUMGATE_SCOPE}" \
  -H 'Accept: */*' \
  -H "Cookie: ${SUMGATE_COOKIE}")

if command -v jq >/dev/null 2>&1; then
  echo "$RESPONSE" | jq .
else
  echo "$RESPONSE"
fi
