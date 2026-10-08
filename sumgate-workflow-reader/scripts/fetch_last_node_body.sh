#!/usr/bin/env bash
# Fetch a specific node's input/output from the LATEST run only — a shortcut
# that skips looking up a history_id/step_token (use fetch_node_body.sh for
# any other, older run).
#
# Usage:
#   fetch_last_node_body.sh <workflow_id> <node_id> [env_name]
#
# <node_id> is a step id, same as used by fetch_step_config.sh.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck disable=SC1091
source "${SCRIPT_DIR}/_resolve_env.sh"

if [ "$#" -lt 2 ] || [ "$#" -gt 3 ]; then
  echo "Usage: $0 <workflow_id> <node_id> [env_name]" >&2
  exit 1
fi

WORKFLOW_ID="$1"
NODE_ID="$2"
resolve_env "${3:-}"
require_scope

RESPONSE=$(curl -s "${SUMGATE_BASE_URL}/api/workflows/step_histories?scope=${SUMGATE_SCOPE}&id=${WORKFLOW_ID}&mode=get_last_node_body&node_id=${NODE_ID}" \
  -H 'Accept: */*' \
  -H "Cookie: ${SUMGATE_COOKIE}")

if check_response "$RESPONSE"; then HAD_ERROR=0; else HAD_ERROR=1; fi

if command -v jq >/dev/null 2>&1; then
  echo "$RESPONSE" | jq .
else
  echo "$RESPONSE"
fi

exit $HAD_ERROR
