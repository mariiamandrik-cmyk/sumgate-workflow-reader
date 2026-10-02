# Reviewing a SumGate workflow

A checklist-driven review, in the same spirit as a code review: six checks, each either a plain graph/data check or something that needs the reviewer's judgment (called out explicitly below). Run them in order — each one builds on data the previous one already fetched, so nothing is fetched twice.

Trigger this when the user asks to "review", "audit", "check over", "go through", or "clean up" a SumGate workflow — not just "read" or "describe" it (that's Steps 3–6).

**Cost note:** checks 2, 4, and 6 need every non-trivial node's full config (`fetch_step_config.sh`), which is one API call per node. For a small workflow this is trivial; for a large one (dozens of nodes) mention the call count to the user before diving in, same as you would for any other large-but-routine task — it's not a reason to skip the review, just worth a heads-up.

## 1. Graph cleanliness — isolated nodes and unreachable sub-flows

```bash
scripts/find_unreachable_nodes.sh <workflow_id>
```

Walks the graph from every trigger-type node (`manual_trigger`, `scheduled`, `webhook`, `hubspot_crm`, `workflow-trigger`) across `steps/list`'s edges and reports any node that edge-walking never reaches — a single isolated node, or a whole cluster of nodes only connected to each other, not to any trigger.

This is a **pure graph check** — it only knows edges exist, not what any node's logic actually does (a `condition` that structurally always takes one branch still counts both branches as "reachable"). Report findings as "not wired into any trigger" rather than "dead code", since the distinction between leftover scratch work and an intentionally-parked branch for later needs a human's context.

## 2. Incomplete configuration — unconfigured nodes, deprecated types

- **Deprecated types**: cross-reference each node's `workflow_task_type` (already in hand from `fetch_steps.sh`) against the Deprecated category in `references/node-types.md` (`bigquery`, `bitrix24`, `google_sheets`, `hubspot`, `zoom`, `gdrive`, `gstorage`, `openai`, `send_mail`, `mail_report`, `mail_notify`, `get_mail_basic_table`) — no extra API calls needed, flag any match and suggest the modern equivalent where one exists (e.g. `send_mail`/`mail_report` → `send_email`, the OAuth-token-stub types → `http_request`'s own `auth_type: bearer`).
- **Unconfigured nodes**: for every node whose type is *not* `manual_trigger`, `container`, or `terminate` (those three always have an empty schema and `data: null` by design — see `references/node-types.md`), fetch its config (`fetch_step_config.sh`) and flag any with `"data": null` — the node sits on the canvas but nobody has ever filled it in. This is exactly the kind of thing that silently breaks a workflow (an unconfigured `condition` always evaluates false, for instance — see the "hardcoded constants" and "infinite loops" checks below, which reuse this same fetch).

## 3. Run history — recent failures

```bash
scripts/list_runs.sh <workflow_id>
```
Check the last handful of runs for any `status` other than `"Success"`. For each failing run, use `fetch_run_steps.sh <workflow_id> <history_id>` to see which node it stopped at, then `fetch_node_body.sh` on that node's token to see the actual input/output that caused it — same debugging flow as Step 6, just run proactively as part of the review rather than because the user already suspected a specific run. Even if every recent run shows `"Success"`, check whether a `condition` is suspiciously always taking the same branch every time (visible in `fetch_run_steps.sh`'s per-step `title`, e.g. always `"[false] Condition"`) — formally successful but functionally stuck, exactly like the real bug found in workflow 1302 during this skill's own testing.

## 4. Hardcoded constants

**This is a judgment check, not a mechanical one.** While reading each node's `data` (from check 2's `fetch_step_config.sh` calls — don't re-fetch), look for literal values that probably should have been a `{{$.steps.<var_name>.<field>}}` reference, a `:named` SQL parameter, or a stored `authentication`/connection instead of being typed in directly: a raw email address, a specific record/deal/contact id baked into a URL or SQL `WHERE` clause, a literal API key or password instead of an `authentication` reference, a hardcoded date instead of a computed one. Use judgment about what's a legitimate constant (a fixed Google Sheet id a workflow is permanently tied to is normal) versus brittle coupling (a specific HubSpot deal id hardcoded into a node meant to run on every deal). Flag with the specific field and why it looks wrong, not just "contains a literal".

## 5. Infinite loops

For every `loop` node whose `data.dataset` is `do_while` (`fetch_step_config.sh` on it, or already fetched in check 2): note the `target` path it checks for `equal`. Then trace the loop's **body** (the branch leaving its `BottomLeft` endpoint per the Flow-category convention in `references/node-types.md`) forward through the edges until it loops back or hits a `break`/`next`. Somewhere in that body, a node needs to actually write to `target` — most often a `data_mapper` whose `assign_target`/`key` matches it, but check any node type that could plausibly update that path. If nothing in the body writes to `target`, and there's no `break` node anywhere in the loop's reachable body as an alternate exit, flag it: the loop has no way to ever stop on its own.

For `repeat`-style loops, check whether the count (`repeat`'s value) is a fixed literal (fine) or a dynamic `$.path` — if dynamic, note it as worth double-checking that the upstream value is actually bounded, rather than treating it as automatically safe.

## 6. Node naming

**Also a judgment check.** Two things:
- A node with `title: null` where the logic is non-trivial (a `condition`, `sql_request`, `http_request`, `loop`, ... — not a `manual_trigger` or `container`, which often don't need one) makes a workflow harder for the next person to read. Flag these as "should be named" rather than a hard error.
- A node that **does** have a title — compare it against what the node's `data` actually does (same data already fetched in check 2/4). A mismatch (e.g. a step titled "Marketing events" that doesn't query marketing events at all, or a leftover name copy-pasted from a different node) is worth flagging explicitly, since a wrong label is often more misleading than no label at all.

## Reporting

Summarize findings grouped by these six checks, most-concrete-and-actionable first (a node that will literally break > a loop that could hang > a naming nit). Skip checks with nothing to report rather than writing "no issues found" six times. Always state this is the result of reading the workflow's current saved configuration, not a guarantee about runtime behavior the reviewer hasn't directly observed (pair with check 3's actual run history where it's available, since that's ground truth rather than inference).
