#!/usr/bin/env bash
# Resolve a schema's dropdown reference (any "$ref": "/api/workflows/steps/
# definitions?..." seen in a node's schema) into its actual list of options
# — e.g. stored authentication connections, other steps available as a
# data_mapper target, or (for break/next) the loops a step can target.
#
# Usage:
#   fetch_definitions.sh <step_id> "<query_string>"              # uses the only configured environment
#   fetch_definitions.sh <step_id> "<query_string>" <env_name>   # uses a specific one
#
# <query_string> is everything the schema's $ref shows after the "?",
# copied as-is (it varies — some fields need extra params). Examples:
#   fetch_definitions.sh 44746 "field=authentications"
#   fetch_definitions.sh 50950 "field=refs_choose_all_steps"
#   fetch_definitions.sh 50962 "field=refs_choose_all_steps&task_type=loop"
#
# See references/node-types.md "Resolving other dropdown references".
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck disable=SC1091
source "${SCRIPT_DIR}/_resolve_env.sh"

if [ "$#" -lt 2 ] || [ "$#" -gt 3 ]; then
  echo "Usage: $0 <step_id> \"<query_string>\" [env_name]" >&2
  exit 1
fi

STEP_ID="$1"
QUERY_STRING="$2"
resolve_env "${3:-}"

RESPONSE=$(curl -s "${SUMGATE_BASE_URL}/api/workflows/steps/definitions?${QUERY_STRING}&id=${STEP_ID}" \
  -H 'Accept: */*' \
  -H "Cookie: ${SUMGATE_COOKIE}")

if command -v jq >/dev/null 2>&1; then
  echo "$RESPONSE" | jq .
else
  echo "$RESPONSE"
fi
