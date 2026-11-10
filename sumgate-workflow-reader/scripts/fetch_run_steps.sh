#!/usr/bin/env bash
# List every node that executed during one specific run (history), with its
# status, duration, and a step_token usable to pull that node's actual
# input/output via fetch_node_body.sh.
#
# Usage:
#   fetch_run_steps.sh <workflow_id> <history_id> [env_name]
#
# Get <history_id> from list_runs.sh.
#
# `ls` selects the detail level, and it is baked into each step's token:
#   ls=2 (default) -> fetch_node_body.sh returns the node's real `output`
#                     (e.g. a SQL node's `params`, a webhook/trigger `payload`,
#                     an HTTP response body).
#   ls=1           -> same steps, but fetch_node_body.sh returns only the saved
#                     config template with `output: null`.
#   ls>=3          -> empty step list (observed). The old default, 4, was this.
# Override with SUMGATE_LS=<n> only for experiments.
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

sumgate_get "/api/workflows/step_histories?scope=${SUMGATE_SCOPE}&mode=get_all&id=${WORKFLOW_ID}&history_id=${HISTORY_ID}&ls=${SUMGATE_LS:-2}"
