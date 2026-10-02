#!/usr/bin/env bash
# Find nodes that are not reachable from any trigger node — i.e. isolated
# nodes or whole disconnected sub-flows left on the canvas (leftover
# scratch/reference nodes, dead branches). Used by the workflow-review flow.
#
# Usage:
#   find_unreachable_nodes.sh <workflow_id> [env_name]
#
# Reachability is a plain graph walk from every trigger-type node (
# manual_trigger, scheduled, webhook, hubspot_crm, workflow-trigger) across
# steps/list's edges — it does not know about any node's actual logic (e.g.
# a condition that always takes one branch), only whether an edge exists.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck disable=SC1091
source "${SCRIPT_DIR}/_resolve_env.sh"

if [ "$#" -lt 1 ] || [ "$#" -gt 2 ]; then
  echo "Usage: $0 <workflow_id> [env_name]" >&2
  exit 1
fi

WORKFLOW_ID="$1"
resolve_env "${2:-}"

RESPONSE=$(curl -s "${SUMGATE_BASE_URL}/api/workflows/steps/list?id=${WORKFLOW_ID}" \
  -H 'Accept: */*' \
  -H "Cookie: ${SUMGATE_COOKIE}")

echo "$RESPONSE" | jq '
  .response as $r
  | ($r.steps | map(.id)) as $all_ids
  | ($r.steps
      | map(select(.workflow_task_type as $t
          | ["manual_trigger","scheduled","webhook","hubspot_crm","workflow-trigger"] | index($t)))
      | map(.id)) as $trigger_ids
  | ($r.edges | group_by(.source_task_id)
      | map({key: .[0].source_task_id, value: (map(.target_task_id) | unique)})
      | from_entries) as $adj
  | def bfs(reached):
      (reached | map($adj[.] // []) | add // [] | unique) as $frontier
      | (reached + $frontier | unique) as $combined
      | if ($combined | length) == (reached | length)
        then reached
        else bfs($combined)
        end;
  (bfs($trigger_ids)) as $reachable
  | ($all_ids - $reachable) as $unreachable_ids
  | {
      total_nodes: ($all_ids | length),
      trigger_nodes: ($trigger_ids | length),
      reachable_nodes: ($reachable | length),
      unreachable_nodes: (
        $r.steps
        | map(select(.id as $id | $unreachable_ids | index($id)))
        | map({id, var_name, workflow_task_type, title})
      )
    }
'
