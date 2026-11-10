# SumGate workflow reader

A Claude Code skill that reads and debugs [SumGate](https://app.sumgate.io) workflow-automation processes by calling SumGate's internal API directly — no public docs exist for it, so this was reverse-engineered from real browser traffic (see `sumgate-workflow-reader/SKILL.md` for the full story and all endpoints found so far).

## What it can do

- Read a workflow's structure (nodes, how they connect) from just a URL or numeric id.
- Look inside any single node — the literal SQL a `sql_request` runs, the URL/body an `http_request` sends, the rules a `condition` checks.
- List every workflow in the workspace, to find one by name when you don't have the id.
- Debug past runs: list recent executions, see which branch a condition took, pull the actual input/output a node produced on a specific (or the latest) run.
- Get the *real values* a step ran with: step history is fetched at detail level `ls=2` (override with `SUMGATE_LS`), so `fetch_node_body.sh` returns a node's resolved `output` — a trigger's `payload`, an HTTP response, a SQL node's bound `params` and result `table` — instead of the unsubstituted config template. Handy for bulk reviews across many runs (page `list_runs.sh`, then steps → node → body, 8 parallel threads is fine).
- Read project database tables: a table's structure and rows (`$table_name`), plus a catalog of every table SQL can see (~280) with their columns.
- Peek at the newest rows of the `$career_change_logs` storage with `latest_career_changes.sh [limit]` (a read-only shortcut over `run_sql.sh`).
- Run ad-hoc **read-only SQL** (`SELECT` only) against project storages and plain DB tables such as `raw_hs_contacts` — `INSERT`/`UPDATE`/`DELETE` and other writes are refused before anything is sent.
- Review a workflow for issues: unreachable/leftover nodes, unconfigured nodes, deprecated node types, recent run failures, hardcoded values that should be parameters, loops with no guaranteed exit, and missing or misleading node names.
- Write up a shareable Google Doc for other developers: sub-flows in plain language, how they relate to each other, which DB tables get used and why, what each SQL script actually does, and uncertain spots clearly flagged for a human to confirm.

**Strictly read-only:** the skill never modifies a workflow — changes are made by a human in the SumGate UI. Every call is a `GET`, except `run_sql.sh`, which `POST`s a query only after checking locally that it is a plain `SELECT`/`SHOW`/`DESCRIBE`/`EXPLAIN`.

## Using it

1. Grab this skill into your own Claude Code setup — the single folder [`sumgate-workflow-reader/`](sumgate-workflow-reader/) is the whole thing, no build step. Drop it wherever your Claude Code picks up skills from (ask in #ai-tools if unsure), or just point Claude at `sumgate-workflow-reader/SKILL.md` and ask it to follow it.
2. First time, Claude will walk you through saving your own SumGate session (cookies from your browser's DevTools) to `~/.config/sumgate/environments/` — this is per-person and never stored in this repo. SumGate sessions expire after a while; when that happens, every script detects it on its own and tells you exactly how to grab a fresh cookie, so you don't need to "check" beforehand.
3. Then just ask, in plain language — "read this SumGate workflow: `<url>`", "what does step X actually do", "why did workflow 1302's last run fail", "find the workflow about contract management", "which tables have `hs_` in the name", "show 10 rows from `raw_hs_contacts`". Claude runs the scripts in `sumgate-workflow-reader/scripts/` itself. Condition branches are read as a fixed rule: the right-hand output is *true*, the left-hand one *false*.

## Maintaining this

SumGate's API isn't documented anywhere else, so `sumgate-workflow-reader/SKILL.md` and `sumgate-workflow-reader/references/` (`node-types.md`, `review-checklist.md`, `documentation-template.md`) *are* the documentation — every endpoint, node type, and review check found/added so far is written up there, including the ones still only partially understood. If you (or Claude, working with you) find a new endpoint, node type, or review check worth adding, write it up there the same way the existing ones are written, so the next person doesn't have to rediscover it from scratch. The scripts share their request/auth-error handling through `scripts/_resolve_env.sh` (`sumgate_get` / `sumgate_fetch`) — new scripts should reuse it rather than calling `curl` directly. Keep this README's "What it can do" list in sync too when a capability is added.

Run URLs look like `https://app.sumgate.io/p/<workspace>/workflows/view/?id=<workflow_id>&history_id=<run_id>#debug` — handy when pointing someone at a specific run (the `history_id` comes from `list_runs.sh`).

Never commit real cookies, tokens, or the `scope` value into this repo — they're per-person secrets and belong only in `~/.config/sumgate/environments/` on your own machine (see the Security notes section in `SKILL.md`).
