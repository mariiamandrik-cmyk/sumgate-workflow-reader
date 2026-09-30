#!/usr/bin/env bash
# Fetch a SumGate workflow's node/edge graph, using a saved named environment.
#
# Usage:
#   fetch_steps.sh <workflow_id>              # uses the only configured environment
#   fetch_steps.sh <workflow_id> <env_name>   # uses a specific one (when several exist)
#
# Environments are created with save_config.sh and stored per-name under
# ~/.config/sumgate/environments/<env_name>.env
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck disable=SC1091
source "${SCRIPT_DIR}/_resolve_env.sh"

if [ "$#" -lt 1 ] || [ "$#" -gt 2 ]; then
  echo "Usage: $0 <workflow_id> [env_name]" >&2
  exit 1
fi

WORKFLOW_ID="$1"
resolve_env "${2:-}"

RESPONSE=$(curl -s "${SUMGATE_BASE_URL}/api/workflows/steps/list?id=${WORKFLOW_ID}" \
  -H 'Accept: */*' \
  -H "Cookie: ${SUMGATE_COOKIE}")

if command -v jq >/dev/null 2>&1; then
  echo "$RESPONSE" | jq .
else
  echo "$RESPONSE"
fi
