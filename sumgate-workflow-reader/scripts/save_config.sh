#!/usr/bin/env bash
# Save a named SumGate environment (base URL + session cookie) for this user.
# Config lives outside the skill folder, so packaging/sharing this skill
# never bundles anyone's real secrets.
#
# Usage:
#   save_config.sh <env_name> <base_url> "<cookie header value>"
#
# Example:
#   save_config.sh prod https://app.sumgate.io "SUMGATE_SID=...; SUMGATE_TOKEN=...; SUMGATE_LOGIN=...; SUMGATE_VIEW=..."
#
# Run again with the same <env_name> to overwrite (e.g. once a cookie expires).
set -euo pipefail

if [ "$#" -ne 3 ]; then
  echo "Usage: $0 <env_name> <base_url> \"<cookie header value>\"" >&2
  exit 1
fi

ENV_NAME="$1"
BASE_URL="$2"
COOKIE="$3"

CONFIG_ROOT="${HOME}/.config/sumgate"
CONFIG_DIR="${CONFIG_ROOT}/environments"
CONFIG_FILE="${CONFIG_DIR}/${ENV_NAME}.env"

mkdir -p "$CONFIG_DIR"
chmod 700 "$CONFIG_ROOT" "$CONFIG_DIR"

cat > "$CONFIG_FILE" <<EOF
SUMGATE_BASE_URL=${BASE_URL}
SUMGATE_COOKIE=${COOKIE}
EOF

chmod 600 "$CONFIG_FILE"

echo "Saved environment '${ENV_NAME}' -> ${BASE_URL} at ${CONFIG_FILE} (permissions 600)."
