#!/usr/bin/env bash
# List recent runs (executions) of a workflow — summary per run: status,
# duration, which step it last reached, what triggered it.
#
# Usage:
#   list_runs.sh <workflow_id> [before] [env_name]
#
# <before> paginates backwards by history_id (exclusive) — pass the oldest
# history_id you've already seen to fetch the next older page. Omit it, or
# pass "latest" (needed as a placeholder when also passing env_name), to get
# the most recent runs.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck disable=SC1091
source "${SCRIPT_DIR}/_resolve_env.sh"

if [ "$#" -lt 1 ] || [ "$#" -gt 3 ]; then
  echo "Usage: $0 <workflow_id> [before] [env_name]" >&2
  exit 1
fi

WORKFLOW_ID="$1"
BEFORE="${2:-latest}"
if [ "$BEFORE" = "latest" ]; then
  BEFORE="999999999999"
fi
resolve_env "${3:-}"
require_scope

sumgate_get "/api/workflows/histories?scope=${SUMGATE_SCOPE}&id=${WORKFLOW_ID}&before=${BEFORE}"
