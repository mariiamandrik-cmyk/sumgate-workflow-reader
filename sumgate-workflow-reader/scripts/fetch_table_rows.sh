#!/usr/bin/env bash
# Dump the rows of a SumGate project database table ("storage"). Read-only GET.
#
# Usage:
#   fetch_table_rows.sh <table_name> [max_rows] [env_name]
#
# <table_name> includes the leading "$" (e.g. '$art_test' — quote it).
# The endpoint has no pagination: it always returns EVERY row, so large tables
# can be big. [max_rows] only trims the printed output (needs jq); the whole
# table is still downloaded. Use 0 or omit for all rows.
# Each row carries an `iterator` (1-based row number) next to the columns.
# Needs SUMGATE_SCOPE (see save_config.sh).
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck disable=SC1091
source "${SCRIPT_DIR}/_resolve_env.sh"

if [ "$#" -lt 1 ] || [ "$#" -gt 3 ]; then
  echo "Usage: $0 '<\$table_name>' [max_rows] [env_name]" >&2
  exit 1
fi

TABLE="$1"
MAX_ROWS="${2:-0}"
resolve_env "${3:-}"
require_scope

sumgate_fetch "/api/project/storages/gridlist" -G \
  --data-urlencode "scope=${SUMGATE_SCOPE}" \
  --data-urlencode "name=${TABLE}" || { echo "$RESPONSE" | jq . 2>/dev/null || echo "$RESPONSE"; exit 1; }

if command -v jq >/dev/null 2>&1; then
  echo "$RESPONSE" | jq --argjson n "$MAX_ROWS" \
    'if $n > 0 then .response.total_rows = (.response.storages|length) | .response.storages |= .[:$n] else . end'
else
  echo "$RESPONSE"
fi
