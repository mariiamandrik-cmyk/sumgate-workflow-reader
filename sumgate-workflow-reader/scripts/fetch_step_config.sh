#!/usr/bin/env bash
# Fetch a single node's internal configuration: its form schema, and — the
# important part — the actual saved `data` (e.g. the SQL a sql_request runs,
# or the URL/method/body a http_request sends).
#
# Usage:
#   fetch_step_config.sh <step_id>              # uses the only configured environment
#   fetch_step_config.sh <step_id> <env_name>   # uses a specific one (when several exist)
#
# <step_id> is a STEP id (the "id" field from a step in fetch_steps.sh's
# output), not the workflow id.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck disable=SC1091
source "${SCRIPT_DIR}/_resolve_env.sh"

if [ "$#" -lt 1 ] || [ "$#" -gt 2 ]; then
  echo "Usage: $0 <step_id> [env_name]" >&2
  exit 1
fi

STEP_ID="$1"
resolve_env "${2:-}"

RESPONSE=$(curl -s "${SUMGATE_BASE_URL}/api/workflows/steps/config?id=${STEP_ID}" \
  -H 'Accept: */*' \
  -H "Cookie: ${SUMGATE_COOKIE}")

if check_response "$RESPONSE"; then HAD_ERROR=0; else HAD_ERROR=1; fi

if command -v jq >/dev/null 2>&1; then
  echo "$RESPONSE" | jq .
else
  echo "$RESPONSE"
fi

exit $HAD_ERROR
