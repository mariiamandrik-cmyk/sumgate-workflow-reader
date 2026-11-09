#!/usr/bin/env bash
# Run a READ-ONLY SQL query against SumGate's SQL endpoint (project storages
# `$table` and plain DB tables such as raw_hs_contacts). 
#
# Usage:
#   run_sql.sh "<sql>" [max_rows] [env_name]
#
# Endpoint: POST /api/sql/execute?scope=...  body {"sql": "...", "params": {}}
# This is the ONLY non-GET call in the skill, and it is guarded: the query is
# validated locally BEFORE anything is sent. Allowed: a single SELECT / WITH ...
# SELECT / SHOW / DESCRIBE / EXPLAIN. Refused: INSERT, UPDATE, DELETE, DROP,
# ALTER, TRUNCATE, CREATE, REPLACE INTO, MERGE, GRANT, CALL, SET, LOCK, LOAD,
# SELECT ... INTO, FOR UPDATE, multiple statements. Always include a LIMIT.
# [max_rows] only trims the printed output (needs jq). Needs SUMGATE_SCOPE.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck disable=SC1091
source "${SCRIPT_DIR}/_resolve_env.sh"

if [ "$#" -lt 1 ] || [ "$#" -gt 3 ]; then
  echo "Usage: $0 \"<sql>\" [max_rows] [env_name]" >&2
  exit 1
fi

SQL="$1"
MAX_ROWS="${2:-0}"
resolve_env "${3:-}"
require_scope

# Read-only guard. Fails closed: anything not clearly a plain read is refused.
SQL="$SQL" python3 -I - <<'PY' || exit 1
import os, re, sys
sql = os.environ["SQL"]
# Drop comments and the contents of string literals / backticked names, so
# keywords inside them (e.g. a column called `set`) are not misread.
s = re.sub(r"/\*.*?\*/", " ", sql, flags=re.S)
s = re.sub(r"(--|#)[^\n]*", " ", s)
s = re.sub(r"'(?:[^'\\]|\\.|'')*'|\"(?:[^\"\\]|\\.)*\"|`[^`]*`", " ", s)
s = s.strip().rstrip(";").strip()
def refuse(why):
    print(f"Refused (read-only guard): {why}. This skill only runs SELECT/SHOW/DESCRIBE/EXPLAIN.", file=sys.stderr)
    sys.exit(1)
if not s:
    refuse("empty query")
if ";" in s:
    refuse("multiple statements")
first = s.split(None, 1)[0].upper()
if first not in {"SELECT", "WITH", "SHOW", "DESCRIBE", "DESC", "EXPLAIN"}:
    refuse(f"statement starts with {first}")
bad = re.compile(
    r"\b(INSERT|UPDATE|DELETE|DROP|ALTER|TRUNCATE|CREATE|MERGE|GRANT|REVOKE|CALL|EXEC|EXECUTE|SET|LOCK|UNLOCK|RENAME|LOAD|HANDLER|INTO|OUTFILE|DUMPFILE|REPLACE(?!\s*\())\b",
    re.I)
m = bad.search(s)
if m:
    refuse(f"forbidden keyword {m.group(1).upper()}")
if re.search(r"\bFOR\s+UPDATE\b|\bLOCK\s+IN\s+SHARE\b", s, re.I):
    refuse("locking read")
PY

BODY=$(SQL="$SQL" python3 -I -c 'import json,os; print(json.dumps({"sql": os.environ["SQL"], "params": {}}))')

sumgate_fetch "/api/sql/execute?scope=${SUMGATE_SCOPE}" -X POST \
  -H 'Content-Type: application/json' --data-binary "$BODY" \
  || { echo "$RESPONSE" | jq . 2>/dev/null || echo "$RESPONSE"; exit 1; }

if command -v jq >/dev/null 2>&1 && [ "$MAX_ROWS" -gt 0 ]; then
  echo "$RESPONSE" | jq --argjson n "$MAX_ROWS" \
    'walk(if type == "array" and length > $n then .[:$n] else . end)'
elif command -v jq >/dev/null 2>&1; then
  echo "$RESPONSE" | jq .
else
  echo "$RESPONSE"
fi
