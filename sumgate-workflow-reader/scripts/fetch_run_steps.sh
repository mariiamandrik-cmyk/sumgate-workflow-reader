#!/usr/bin/env bash
# List every node that executed during one specific run (history), with its
# status, duration, and a step_token usable to pull that node's actual
# input/output via fetch_node_body.sh.
#
# Usage:
#   fetch_run_steps.sh <workflow_id> <history_id> [env_name]
#
# Get <history_id> from list_runs.sh.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck disable=SC1091
source "${SCRIPT_DIR}/_resolve_env.sh"

if [ "$#" -lt 2 ] || [ "$#" -gt 3 ]; then
  echo "Usage: $0 <workflow_id> <history_id> [env_name]" >&2
  exit 1
fi

WORKFLOW_ID="$1"
HISTORY_ID="$2"
resolve_env "${3:-}"
require_scope

RESPONSE=$(curl -s "${SUMGATE_BASE_URL}/api/workflows/step_histories?scope=${SUMGATE_SCOPE}&mode=get_all&id=${WORKFLOW_ID}&history_id=${HISTORY_ID}&ls=4" \
  -H 'Accept: */*' \
  -H "Cookie: ${SUMGATE_COOKIE}")

if check_response "$RESPONSE"; then HAD_ERROR=0; else HAD_ERROR=1; fi

if command -v jq >/dev/null 2>&1; then
  echo "$RESPONSE" | jq .
else
  echo "$RESPONSE"
fi

exit $HAD_ERROR
