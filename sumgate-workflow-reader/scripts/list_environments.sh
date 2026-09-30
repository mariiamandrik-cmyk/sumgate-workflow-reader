#!/usr/bin/env bash
# List this user's configured SumGate environments (names + base URLs only,
# never cookies).
#
# Usage:
#   list_environments.sh
set -euo pipefail

CONFIG_DIR="${HOME}/.config/sumgate/environments"

envs=()
if [ -d "$CONFIG_DIR" ]; then
  for f in "$CONFIG_DIR"/*.env; do
    [ -e "$f" ] || continue
    envs+=("$f")
  done
fi

if [ "${#envs[@]}" -eq 0 ]; then
  echo "No environments configured yet. Run scripts/save_config.sh <env_name> <base_url> \"<cookie>\" first." >&2
  exit 1
fi

for f in "${envs[@]}"; do
  name=$(basename "$f" .env)
  base_url=$(grep '^SUMGATE_BASE_URL=' "$f" | cut -d= -f2-)
  echo "${name} -> ${base_url}"
done
