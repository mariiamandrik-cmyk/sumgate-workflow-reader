# Generating workflow documentation

Trigger this when the user asks to "document this workflow", "write up docs for X", "create documentation for this flow", or similar — producing a shareable technical write-up for other developers, as a Google Doc. Distinct from Steps 3–7: those answer a specific question in chat, this produces a standing reference document.

## Step 0: Ask which language

**Before writing anything, ask which language the document itself should be written in.** Suggest English as the default — this is usually meant for a wider dev team, not just whoever's asking — but go with whatever they actually choose (e.g. Ukrainian). Write the *entire* document in that language, independent of whatever language the conversation itself is happening in.

## Gathering the data

1. `scripts/fetch_steps.sh` — structure (nodes + edges).
2. `scripts/find_unreachable_nodes.sh` — anything not wired to a trigger.
3. `scripts/fetch_step_config.sh` on every meaningful node — **both** the reachable sub-flows **and** any unreachable element you're not confident is obvious scratch work. Don't classify something as "clearly a test" from its title alone without looking — in practice, two nodes that looked like throwaway drafts by name turned out to be a real in-progress improvement and a real diagnostic query once their actual SQL was read.
4. `scripts/list_workflows.sh` — owner, last-modified-by, dates, active/disabled, for the header.
5. `scripts/list_runs.sh` — a quick recent-health check (all `Success`? anything failing?) worth a one-line mention if relevant.

## Document structure

1. **Header** — title, id, link, who created/last modified it and when, active/disabled, trigger(s) with specifics (cron expression, webhook name, etc).
2. **Short description** — 2–3 plain-language sentences on what it does and why. Cross-check against the workflow's own `description` field from `list_workflows.sh` if it has one — it sometimes already states the purpose accurately.
3. **Sub-flows** — one subsection per trigger/entry point, narrated as logical stages (not a literal node-by-node transcript), covering branches/conditions in prose. If a canvas has several independent triggers, each gets its own subsection.
4. **Flow relationships** — how sub-flows on the *same* canvas relate to each other (e.g. one is a narrower manual variant of the other, or they're meant to run in a specific order), plus any `call-workflow`/`workflow-trigger` links to *other* SumGate workflows (their id, which direction, and why).
5. **Elements outside the main flow** — from `find_unreachable_nodes.sh`, filtered per the rule below.
6. **Database tables** — every table referenced across the workflow's SQL: name, read or write, which node(s) touch it, what it's for. Explicitly note any inconsistency you notice (e.g. two variants of what looks like the same query reading from differently-named tables) with a review marker — this kind of thing has turned out to be a real, substantive finding in practice, not just a formality to tick off.
7. **SQL scripts: purpose** — for every `sql_request` node (including ones that only showed up in the "outside the main flow" section), a one-or-two-sentence plain-language description of what it actually computes, not a restatement of its title.
8. **Integrations** — external services touched (HubSpot, Slack, BigQuery, ...) and why.

## Filtering test/scratch elements

For each unreachable node or cluster found by `find_unreachable_nodes.sh`:

- **Obviously scratch/test, after actually reading its config** — a single node with a generic non-business title (`"for comments"`, `"cleaning the table"`), a node of type `debug` itself, or a small cluster built around a `debug` node holding an ad-hoc literal (like a hardcoded offset used to poke at something manually) → **leave it out of the document entirely**, don't even mention it exists. Don't clutter real documentation with someone's scratch work.
- **Anything else** — including nodes/clusters whose title or content looks meaningful even if their exact purpose isn't obvious, or where you're simply not sure → **include it**, under "Elements outside the main flow," with a review marker explaining what's uncertain (not wired to any trigger; purpose unclear from the config alone; etc). When genuinely unsure, include and flag rather than silently drop.

## Review marker convention

Mark anything that's *your interpretation* rather than a fact you're directly citing from a config field with:

```
🔶 <local word for "NEEDS REVIEW">: <short reason>
```

highlighted with a yellow background — in the HTML sent to Drive, wrap it as `<span style="background-color:#FFEB3B;">...</span>`. Use this for: inferred business purpose, ambiguous unreachable elements, suspicious inconsistencies (differing table names for what looks like the same logic, duplicate near-identical queries), a sub-flow that produces data but nothing downstream ever consumes it, and anything else where judgment — not direct citation — produced the statement.

## Creating the actual Google Doc

Requires a Google Drive/Docs connector attached to the session — if its tools aren't in your tool list, ask the user to attach one (Claude Code's native connector setup); there's no fallback via SumGate itself, and don't try to approximate one with a different file type without saying so.

Use the connector's `create_file` tool: pass the composed content as `textContent` with `contentMimeType: "text/html"` — Drive auto-converts HTML into a native Google Doc, and headings, bold, tables, and the `<span style="background-color:...">` highlight all come through correctly. Give it a clear `title` (workflow name + id).

**There is no tool to edit an existing Doc's content in place** — the connector's `update_file` only changes metadata (title, parent folder), not body content. To revise a document already created this way: create a fresh file with the updated content (same title is fine), then `trash_file` the old version — that's a reversible move to Drive's trash, not permanent deletion, so it's safe to do without asking each time, but mention it so the user knows where the old version went.
