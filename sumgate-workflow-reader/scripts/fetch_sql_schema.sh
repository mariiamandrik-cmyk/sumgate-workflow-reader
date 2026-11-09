#!/usr/bin/env bash
# List the tables available to SumGate SQL (project storages `$name` and plain
# DB tables) together with their columns. Read-only GET.
#
# Usage:
#   fetch_sql_schema.sh [filter] [env_name]
#
# No filter  -> one line per table: name and column count (the full dump is
#               ~280 tables, too big to print).
# [filter]   -> case-insensitive substring of the table name; prints those
#               tables with every column (name, type, nullable, key, default).
# Endpoint: GET /api/sql/schema?scope=...  ->
#   {"cache_info": {...}, "schema": {"<table>": [{COLUMN_NAME, DATA_TYPE,
#    IS_NULLABLE, COLUMN_DEFAULT, COLUMN_KEY, EXTRA}, ...]}}
# Project storages keep their leading "$" in the name. The result is cached
# server-side (see cache_info), so a just-created table may be missing.
# Needs SUMGATE_SCOPE and jq.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck disable=SC1091
source "${SCRIPT_DIR}/_resolve_env.sh"

if [ "$#" -gt 2 ]; then
  echo "Usage: $0 [filter] [env_name]" >&2
  exit 1
fi

FILTER="${1:-}"
resolve_env "${2:-}"
require_scope
command -v jq >/dev/null 2>&1 || { echo "jq is required for this script." >&2; exit 1; }

sumgate_fetch "/api/sql/schema?scope=${SUMGATE_SCOPE}" \
  || { echo "$RESPONSE" | jq . 2>/dev/null || echo "$RESPONSE"; exit 1; }

if [ -z "$FILTER" ]; then
  echo "$RESPONSE" | jq -r '.cache_info as $c
    | "# \($c.tables_count // (.schema|length)) tables (cached: \($c.cached))",
      (.schema | to_entries | sort_by(.key)[] | "\(.key)\t\(.value|length) cols")'
else
  echo "$RESPONSE" | jq --arg f "$FILTER" '.schema
    | with_entries(select(.key | ascii_downcase | contains($f | ascii_downcase)))
    | map_values(map({name: .COLUMN_NAME, type: .DATA_TYPE, null: (.IS_NULLABLE == "YES"), key: .COLUMN_KEY, default: .COLUMN_DEFAULT}))'
fi
