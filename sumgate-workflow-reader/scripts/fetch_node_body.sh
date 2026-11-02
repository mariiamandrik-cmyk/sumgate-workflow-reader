#!/usr/bin/env bash
# Fetch the actual input/output data a specific node produced during one
# specific historical run (not necessarily the latest one).
#
# Usage:
#   fetch_node_body.sh <workflow_id> <history_id> <step_token> [env_name]
#
# Get <history_id> from list_runs.sh and <step_token> from that run's entry
# in fetch_run_steps.sh's output (each step has its own token — tokens are
# signed/opaque, pass them through exactly as returned, never construct one
# yourself).
#
# For the LATEST run only, fetch_last_node_body.sh is simpler (just needs a
# node_id, no history_id/step_token lookup required).
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck disable=SC1091
source "${SCRIPT_DIR}/_resolve_env.sh"

if [ "$#" -lt 3 ] || [ "$#" -gt 4 ]; then
  echo "Usage: $0 <workflow_id> <history_id> <step_token> [env_name]" >&2
  exit 1
fi

WORKFLOW_ID="$1"
HISTORY_ID="$2"
STEP_TOKEN="$3"
resolve_env "${4:-}"
require_scope

sumgate_get "/api/workflows/step_histories" -G \
  --data-urlencode "scope=${SUMGATE_SCOPE}" \
  --data-urlencode "id=${WORKFLOW_ID}" \
  --data-urlencode "mode=get_node_body" \
  --data-urlencode "history_id=${HISTORY_ID}" \
  --data-urlencode "step_token=${STEP_TOKEN}"
