#!/usr/bin/env bash
# Print the newest records of the `$career_change_logs` storage (read-only).
#
# Usage:
#   latest_career_changes.sh [limit] [env_name]
#
# [limit] defaults to 10. Newest = latest `date`, ties broken by highest `id`.
# Columns: id, object_id, type, old_value, new_value, date, task, record_id.
# Goes through run_sql.sh, so it is guarded to plain SELECTs. Needs SUMGATE_SCOPE.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
LIMIT="${1:-10}"

case "$LIMIT" in
  ''|*[!0-9]*) echo "limit must be a positive integer" >&2; exit 1 ;;
esac

exec "${SCRIPT_DIR}/run_sql.sh" \
  "SELECT * FROM \`\$career_change_logs\` ORDER BY \`date\` DESC, \`id\` DESC LIMIT ${LIMIT};" \
  0 "${2:-}"
