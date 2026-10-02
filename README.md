# SumGate workflow reader

A Claude Code skill that reads and debugs [SumGate](https://app.sumgate.io) workflow-automation processes by calling SumGate's internal API directly — no public docs exist for it, so this was reverse-engineered from real browser traffic (see `sumgate-workflow-reader/SKILL.md` for the full story and all endpoints found so far).

## What it can do

- Read a workflow's structure (nodes, how they connect) from just a URL or numeric id.
- Look inside any single node — the literal SQL a `sql_request` runs, the URL/body an `http_request` sends, the rules a `condition` checks.
- List every workflow in the workspace, to find one by name when you don't have the id.
- Debug past runs: list recent executions, see which branch a condition took, pull the actual input/output a node produced on a specific (or the latest) run.

## Using it

1. Grab this skill into your own Claude Code setup — the single folder [`sumgate-workflow-reader/`](sumgate-workflow-reader/) is the whole thing, no build step. Drop it wherever your Claude Code picks up skills from (ask in #ai-tools if unsure), or just point Claude at `sumgate-workflow-reader/SKILL.md` and ask it to follow it.
2. First time, Claude will walk you through saving your own SumGate session (cookies from your browser's DevTools) to `~/.config/sumgate/environments/` — this is per-person and never stored in this repo.
3. Then just ask, in plain language — "read this SumGate workflow: `<url>`", "what does step X actually do", "why did workflow 1302's last run fail", "find the workflow about contract management". Claude runs the scripts in `sumgate-workflow-reader/scripts/` itself.

## Maintaining this

SumGate's API isn't documented anywhere else, so `sumgate-workflow-reader/SKILL.md` and `sumgate-workflow-reader/references/node-types.md` *are* the documentation — every endpoint and node type found so far is written up there, including the ones still only partially understood. If you (or Claude, working with you) find a new endpoint or node type, add it there the same way the existing ones are written, so the next person doesn't have to rediscover it from scratch.

Never commit real cookies, tokens, or the `scope` value into this repo — they're per-person secrets and belong only in `~/.config/sumgate/environments/` on your own machine (see the Security notes section in `SKILL.md`).
