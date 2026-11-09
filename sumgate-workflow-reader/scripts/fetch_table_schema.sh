#!/usr/bin/env bash
# Show the structure (columns, datatypes, nullability) of a SumGate project
# database table ("storage"). Read-only GET.
#
# Usage:
#   fetch_table_schema.sh <table_name> [env_name]
#
# <table_name> is the name as used in SQL nodes, including the leading "$"
# (e.g. '$art_test' — quote it so the shell doesn't expand it).
# Needs SUMGATE_SCOPE (see save_config.sh).
#
# The raw response also carries an `export_link` with a signed download key;
# it is dropped from the output on purpose (don't paste it anywhere).
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck disable=SC1091
source "${SCRIPT_DIR}/_resolve_env.sh"

if [ "$#" -lt 1 ] || [ "$#" -gt 2 ]; then
  echo "Usage: $0 '<\$table_name>' [env_name]" >&2
  exit 1
fi

TABLE="$1"
resolve_env "${2:-}"
require_scope

sumgate_fetch "/api/project/storages/get" -G \
  --data-urlencode "scope=${SUMGATE_SCOPE}" \
  --data-urlencode "name=${TABLE}" \
  --data-urlencode "mode=grideditor" || { echo "$RESPONSE" | jq . 2>/dev/null || echo "$RESPONSE"; exit 1; }

if command -v jq >/dev/null 2>&1; then
  echo "$RESPONSE" | jq 'del(.response.export_link)'
else
  echo "$RESPONSE"
fi
