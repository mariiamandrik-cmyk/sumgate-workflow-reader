#!/usr/bin/env bash
# Save a named SumGate environment (base URL + session cookie + optional
# run-history scope) for this user. Config lives outside the skill folder,
# so packaging/sharing this skill never bundles anyone's real secrets.
#
# Usage:
#   save_config.sh <env_name> <base_url> "<cookie header value>" ["<scope>"]
#
# Example:
#   save_config.sh prod https://app.sumgate.io "SUMGATE_SID=...; SUMGATE_TOKEN=...; SUMGATE_LOGIN=...; SUMGATE_VIEW=..."
#
# <scope> is only needed for run-history / debugging features (fetch_run_*,
# fetch_node_body.sh) — it's the "scope=..." query param value seen in any
# app.sumgate.io/api/workflows/histories or step_histories request in
# DevTools. It's session-scoped like the cookie, not per-workflow, so one
# captured value covers every workflow this environment can see. Omit it if
# you only need the structure/config-reading features (fetch_steps.sh etc).
#
# Run again with the same <env_name> to overwrite (e.g. once a cookie expires).
set -euo pipefail

if [ "$#" -lt 3 ] || [ "$#" -gt 4 ]; then
  echo "Usage: $0 <env_name> <base_url> \"<cookie header value>\" [\"<scope>\"]" >&2
  exit 1
fi

ENV_NAME="$1"
BASE_URL="$2"
COOKIE="$3"
SCOPE="${4:-}"

CONFIG_ROOT="${HOME}/.config/sumgate"
CONFIG_DIR="${CONFIG_ROOT}/environments"
CONFIG_FILE="${CONFIG_DIR}/${ENV_NAME}.env"

mkdir -p "$CONFIG_DIR"
chmod 700 "$CONFIG_ROOT" "$CONFIG_DIR"

{
  printf 'SUMGATE_BASE_URL=%q\n' "$BASE_URL"
  printf 'SUMGATE_COOKIE=%q\n' "$COOKIE"
  if [ -n "$SCOPE" ]; then
    printf 'SUMGATE_SCOPE=%q\n' "$SCOPE"
  fi
} > "$CONFIG_FILE"

chmod 600 "$CONFIG_FILE"

echo "Saved environment '${ENV_NAME}' -> ${BASE_URL} at ${CONFIG_FILE} (permissions 600)."
