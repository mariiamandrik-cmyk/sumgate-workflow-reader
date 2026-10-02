# Sourced (not executed) by the other scripts to resolve which saved
# environment to use and load SUMGATE_BASE_URL / SUMGATE_COOKIE from it.
#
# Usage inside a script:
#   source "$(dirname "$0")/_resolve_env.sh"
#   resolve_env "${2:-}"     # pass whatever env_name argument the caller got, or ""
#   # SUMGATE_BASE_URL and SUMGATE_COOKIE are now set

resolve_env() {
  local env_name="${1:-}"
  local config_dir="${HOME}/.config/sumgate/environments"

  if [ -z "$env_name" ]; then
    local envs=()
    if [ -d "$config_dir" ]; then
      for f in "$config_dir"/*.env; do
        [ -e "$f" ] || continue
        envs+=("$(basename "$f" .env)")
      done
    fi
    if [ "${#envs[@]}" -eq 0 ]; then
      echo "No environments configured yet. Run scripts/save_config.sh <env_name> <base_url> \"<cookie>\" first." >&2
      return 1
    elif [ "${#envs[@]}" -eq 1 ]; then
      env_name="${envs[0]}"
    else
      echo "Multiple environments configured: ${envs[*]}" >&2
      echo "Specify which one to use as an extra argument." >&2
      return 1
    fi
  fi

  local config_file="${config_dir}/${env_name}.env"
  if [ ! -f "$config_file" ]; then
    echo "No such environment '${env_name}' (looked for ${config_file})." >&2
    return 1
  fi

  # shellcheck disable=SC1090
  source "$config_file"

  if [ -z "${SUMGATE_BASE_URL:-}" ] || [ -z "${SUMGATE_COOKIE:-}" ]; then
    echo "Config at ${config_file} is missing SUMGATE_BASE_URL or SUMGATE_COOKIE." >&2
    return 1
  fi
}

# Call after resolve_env for scripts that need SUMGATE_SCOPE (the run-history
# / debugging endpoints). Separate from resolve_env's own check since most
# scripts (structure/config reading) don't need it at all.
require_scope() {
  if [ -z "${SUMGATE_SCOPE:-}" ]; then
    echo "This environment has no SUMGATE_SCOPE saved. Re-run save_config.sh with a 4th argument — capture the 'scope=' value from any app.sumgate.io/api/workflows/histories or step_histories request in DevTools." >&2
    return 1
  fi
}
