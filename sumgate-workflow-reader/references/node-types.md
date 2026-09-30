# SumGate node type reference

Catalog of every `workflow_task_type` seen so far, built from real `steps/config` responses. `schema` is identical for every node of the same type (it's the SumGate UI's form definition), so this only needs discovering once per type — read this file instead of re-deriving it from scratch each time a node of a known type shows up. When a genuinely new `workflow_task_type` appears, add a new section here following the same pattern (schema title, purpose, key `data` fields, quirks) rather than leaving it undocumented for the next person.

SumGate's own editor sidebar groups node types into categories (Data, Flow, Transaction, Deprecated, Trigger). This file is being filled in one category at a time as they're reviewed, so the categories below may be incomplete or a type's category may not be confirmed yet — that's noted per type where relevant.

## Table of contents
- [manual_trigger](#manual_trigger)
- [condition](#condition)
- [delay](#delay)
- [sql_request](#sql_request)
- [http_request](#http_request)
- [send_email](#send_email)
- **Flow category:**
  - [break](#break)
  - [debug](#debug)
  - [loop](#loop)
  - [next](#next)
  - [terminate](#terminate)
- **Transaction category:**
  - [call-workflow](#call-workflow)
  - [csv](#csv)
  - [mysql](#mysql)
  - [slack](#slack)
  - [webhook_reply](#webhook_reply)
  - [workflow-response](#workflow-response)
- **Trigger category:**
  - [hubspot_crm](#hubspot_crm)
  - [scheduled](#scheduled)
  - [webhook](#webhook)
  - [workflow-trigger](#workflow-trigger)
- **Deprecated category:**
  - [OAuth token stubs: bigquery, bitrix24, google_sheets, hubspot, zoom](#oauth-token-stubs-bigquery-bitrix24-google_sheets-hubspot-zoom)
  - [File storage: gdrive, gstorage](#file-storage-gdrive-gstorage)
  - [openai](#openai)
  - [Legacy mail nodes: send_mail, mail_report, mail_notify, get_mail_basic_table](#legacy-mail-nodes-send_mail-mail_report-mail_notify-get_mail_basic_table)
- **Data category:**
  - [array](#array)
  - [container](#container)
  - [data_mapper](#data_mapper)
  - [date_time](#date_time)
  - [hash](#hash)
  - [html_xml_parser](#html_xml_parser)
  - [json_object](#json_object)
  - [math](#math)
  - [string](#string)
- [Resolving `authentication` ids](#resolving-authentication-ids)
- [Resolving other dropdown references (the `definitions?field=...` pattern)](#resolving-other-dropdown-references-the-definitionsfield-pattern)

---

## manual_trigger

**Schema:** empty (`{}`) — nothing to configure. `mapping`/`data` are always `null`.

The entry point of a workflow: whatever starts it (a person clicking "Run" in the SumGate UI, or an external caller). If a workflow has more than one of these, each is a separate possible starting point rather than a step in the middle of the flow.

## condition

**Schema title:** "Condition". Branches the flow in two: *"True – flow goes on the right side"*, *"False – flow exits on the left"* — matches the `BottomRight`/`BottomLeft` edge endpoints seen in `steps/list` (see main `SKILL.md`).

**`data` shape once configured** (inferred from the schema; see `references/schemas.md`-style structure below rather than a confirmed live example):
```json
{
  "or_conditions": [
    {
      "and_conditions": [
        { "value": "...", "operator": "text_eq", "compare_value": "..." }
      ]
    }
  ]
}
```
- Top level is OR'd groups; within each group, rules are AND'd — i.e. `(A and B) or (C and D)`.
- `operator` covers text/numeric/datetime/boolean/array comparisons plus existence checks (`Basic - Exists` / `Basic - Does not exist`). Full enum is in the schema if exact operator behavior ever needs double-checking.
- `value` / `compare_value` can reference other steps' output via `{{$.steps.<var_name>.<field>}}`.
- An unconfigured condition returns `"mapping": null, "data": null` — same as any untouched node, not an error.

## delay

**Schema title:** "Delay" — *"Specify the number of seconds you would like workflow execution to delay"*.

**`data`:** `{ "delay": <integer> }`, seconds, **capped at 60** (`minimum: 0, maximum: 60`). Worth flagging to the user if they expect a longer pause — this node type can't do more than a minute; longer waits need a different mechanism (e.g. a scheduled re-trigger).

## sql_request

**Schema title:** "SQLRequest".

**Key `data` fields:**
- `query` — the literal SQL text. Supports named (`:param`) or unnamed (`?`) placeholders per the schema description. Tables prefixed `$` (e.g. `$bp_inquiries_logs`) are the same `$table_name` convention used elsewhere in this codebase's SQL — not SumGate-specific templating.
- `var_wrapper.variables` — a name/value table supplying the actual bound values for the query's placeholders.
- `pagination.page_size` / `pagination.page_offset` — 0 means unpaginated (return everything the query yields).

**Output (`mapping.output.table`):** an array — the query's result rows. Later steps reference a column of the *first* row like `{{$.steps.<var_name>.table[0].<column>}}` (seen in practice: `{{$.steps.sql-request-6.table[0].date_ts}}`).

## http_request

**Schema title:** "HTTPRequest".

**Key `data` fields:**
- `method` — one of `GET`, `POST`, `PUT`, `DELETE`, `HEAD`, `PATCH`.
- `url` — supports `{{$.steps.<var_name>.<field>}}` templating, same as everywhere else.
- `headers` / `query_params` — arrays of `{name, value}` pairs; values can also use `{{...}}` templating.
- `body` — a string, usually JSON, with `{{...}}` placeholders substituted before sending.
- `authentication` — an **id** referencing a stored connection (e.g. `"49872896"`); see [Resolving `authentication` ids](#resolving-authentication-ids) below. Never the credential itself.
- `auth_type` — how the resolved credential gets attached to the request: `null` (no auth), `api_key` (added to a header or query param), `bearer` (a `token`, e.g. default `$.auth.access_token`), `basic` (`username`/`password`), or `hawk` (`hawk_id`/`hawk_key`/`hawk_algorithm`). The `$.auth.*` defaults are placeholders SumGate fills in server-side from whatever `authentication` connection was picked — they are **not** literal secret values even when they appear in `data` verbatim.
- `timeout`, `ssl_verification` (`"No"`/`"Yes"`), `proxy`, `follow_redirect` (`"No"`/`"Yes"`), `ignore_response_code` (`"No"`/`"Yes"`), `parse_response_body` (`none`/`json`/`xml`/`s_file`).

## send_email

**Schema title:** "Mail Report".

**Key `data` fields:** `authentication` (a mail-connection id, same resolution mechanism as `http_request`), `from_email`, `to_email`, `cc_email`, `bcc_email`, `subject`, `body_text`, `body_html`, `attachments` (comma-separated names of binary properties from earlier steps to attach), `ignore_ssl_issue` (boolean).

**Output (`mapping.output`):** `oneOf` `{ "status": "..." }` or `{ "error": "..." }` — later steps (e.g. a `condition`) can branch on whether the send succeeded.

---

# Flow category

`condition` and `delay` (documented above, before categories were being tracked) are also Flow-category nodes.

## break

**Schema:** just one field, `loop_target` — which `loop` step to exit. Resolved via `scripts/fetch_definitions.sh <this_step_id> "field=refs_choose_all_steps&task_type=loop"` (the `task_type=loop` filter restricts the dropdown to loop steps only — see [below](#resolving-other-dropdown-references-the-definitionsfield-pattern)). Classic loop **`break`**: stops the targeted loop entirely and continues after it.

## debug

**Schema title:** "Debug". One field, `source` — a path/value to inspect. Presumably surfaces that value in SumGate's own execution log/debug panel for troubleshooting a run; doesn't appear to alter the workflow's data itself.

## loop

**Schema title:** "Loop". Like `condition`, this is a branch point, but with **inverted** left/right semantics — per its own description: *"The loop body runs on the left side; data is placed into the `*.value` field. When exiting the loop, the flow exits to the right."* So here **left = keep looping (body), right = done** — the opposite of `condition`'s right=True/left=False. Always check which node type you're looking at before assuming what a side means.

`dataset` (`oneOf`, one style per node):
- `array_iterator` — loop over each element of an array (`source`).
- `object_key` — loop over each key of an object (`source`).
- `repeat` — loop a fixed or dynamic (`$.path`) number of times (`repeat`).
- `do_while` — keep looping until `target` (a `$.path`) equals `true`/`false` (`equal`).

## next

**Schema:** identical to `break` — a `loop_target` picking which loop to act on. This is the **`continue`** counterpart to `break`'s **`break`**: skips the rest of the current iteration's body and moves to the next one, without exiting the loop.

## terminate

**Schema:** empty (`{}`) — nothing to configure. Unconditionally **stops the entire workflow run** at this point (not just the current loop) — the hard-exit counterpart to `break`/`next`, which only affect a single loop.

---

# Transaction category

`http_request`, `sql_request`, and `send_email` (documented above, before categories were being tracked) are also Transaction-category nodes.

## call-workflow

**Schema title:** "SETTINGS". Triggers **another SumGate workflow** from within this one:
- `choose_workflow` — which workflow to call, resolved via `scripts/fetch_definitions.sh <this_step_id> "field=choose_workflow_name"` (a new `field` value — see [below](#resolving-other-dropdown-references-the-definitionsfield-pattern)).
- `wait_until_done` — **"Fire and wait for response"**: if `true`, this node blocks until the called workflow finishes and replies (see `workflow-response` below, which is how the *called* workflow sends that reply back).
- `without_repeat` — an idempotency guard: skip launching if a call with the same key already ran. Either `use_sha` (auto-derive the key from the passed parameters) or a manually specified `check_key`. Only meaningful when *not* waiting for a response (`wait_until_done: false`) — the schema itself marks these two as mutually exclusive via `options.dependencies`.
- `variables` — a name/value table of data to pass into the called workflow.

## csv

**Schema title:** "CSV". One operation per node (same pattern as `array`/`string`):
- **Decode** — `source_target_str` (path to a CSV string) → parsed array, using `configuration` (see below).
- **Encode** — `source_target_arr` (path to an array) → CSV string, with `header_template` choosing how column headers are derived (from the first object's own fields, from a separate array of header names, or manually specified), plus the same `configuration`.

Shared `configuration`: `end_line` (Windows `\r\n` / Unix `\n` / old MacOS `\r`), `delimiter`, `quote_character`, `escape_character` — all standard CSV dialect settings.

## mysql

**Schema title:** "SQLRequest" — **same title as the plain `sql_request` type**, but this one connects **directly** to a MySQL server rather than only through a pre-saved `authentication` connection: it has both an `authentication` picker (same `field=authentications` mechanism) *and* a full `auth_config` block (`host`, `port`, `user`, `password`, `database`, optional `ssl_cert`/`ssl_key`/`ssl_ca`, all defaulting to `$.auth.*` placeholders). `query`/`var_wrapper.variables` work the same as `sql_request`. Treat this as "SQL request with an ad-hoc/overridable connection" versus `sql_request`'s "SQL request against a pre-configured connection" — worth double-checking with the user if it's ever unclear which one a given workflow relies on, since the schemas look almost identical at a glance.

## slack

**Schema title:** "SETTINGS". A lightweight, connection-free way to post to Slack via an **incoming webhook** (not the stored-`authentication` mechanism `http_request`/`send_email` use): `webhook_url` (the token portion of a Slack incoming webhook URL), `channel` (e.g. `#my-channel`, overriding the webhook's default), `message`.

## webhook_reply

**Schema title:** "SETTINGS". Sends an HTTP response back to whatever externally called this workflow — which implies SumGate workflows can be **triggered by an inbound webhook call**, not only `manual_trigger` (a webhook-trigger node type hasn't been seen on a canvas yet; if one shows up, document it and cross-link it here). Fields: `reply_http_code` (status code, default 200), `reply_body` (either a literal `string_template` with `{{...}}` interpolation, or a `payload_path` pointing at a `$.steps...` value), `reply_headers`.

## workflow-response

**Schema title:** "SETTINGS". The simpler counterpart to `webhook_reply`, used when *this* workflow was itself invoked via another workflow's `call-workflow` node with `wait_until_done: true` — `reply_payload.source` (a `$.path`) is what gets sent back as that call's result.

---

# Deprecated category

Everything here still works if an old workflow uses it, but these are legacy, narrow, single-purpose nodes that newer generic nodes (`http_request` + a stored `authentication`, `send_email`) have superseded. When analyzing a workflow that uses one of these, it's worth a one-line note to the user that it's a deprecated node type, in case they want to modernize it — but don't assume that on their behalf.

## OAuth token stubs: bigquery, bitrix24, google_sheets, hubspot, zoom

**Schema title:** "Settings" for all five. Each has an `authentication` picker plus exactly one possible action, **`get_access_token`** — that's the entire node. These exist purely to pull an OAuth access token for that specific service out of a stored connection; superseded by `http_request`'s `auth_type: bearer` (default `$.auth.access_token`), which resolves the same token automatically without a dedicated node.

Cosmetic difference between them: bigquery/google_sheets call the field `operation`, bitrix24/hubspot/zoom call it `trigger_event` — same single enum (`""`/`get_access_token`) either way.

**Quirk worth knowing:** these five resolve their `authentication` dropdown via **`field=choose_authentication`** (singular) — a genuinely different `field` value from the `field=authentications` (plural) used everywhere else (see [below](#resolving-other-dropdown-references-the-definitionsfield-pattern)). Not a typo on our part; the live API is just inconsistent between old and new node types.

## File storage: gdrive, gstorage

**Schema title:** "Check selectize" for both (an internal/placeholder title, not user-facing naming). Google Drive and Google Cloud Storage, with **identical schemas**: `resource` (always `"File"`), `file_ops` (`file_get_metadata` / `file_upload` / `file_download`), and one options block per operation:
- `file_get_metadata_options` — `file_id`, `resolve_data` (fetch full metadata vs just the ID).
- `file_upload_options` — upload from `binary_data` (a prior step's binary output) or `file_content` (literal text), plus `file_name`, `mime_type`, `parents` (destination folder IDs), and free-form `appPropertyValues`/`propertyValues` key-value tables.
- `file_download_options` — just `file_id`.

Uses the standard `field=authentications`.

## openai

**Schema title:** "Check selectize" (same placeholder title as gdrive/gstorage — likely built from the same template). Very narrow: the only `file_ops` option is **`speech_txt`** (Speech to text), taking `binary_data` as input. A legacy Whisper-style transcription node — anything else OpenAI-related on a modern workflow almost certainly goes through generic `http_request` instead.

## Legacy mail nodes: send_mail, mail_report, mail_notify, get_mail_basic_table

Four different eras of "send an email from SumGate," all predating `send_email` (Transaction category):

- **`send_mail`** ("Send Mail") — the simplest: `subject`, `send_to` (plain array of email addresses), `body` (HTML), `from`. No stored-connection/`authentication` field at all.
- **`mail_report`** ("Mail Report" — same schema title as the modern `send_email`, but a different, older shape) — adds `mail_components`: named report fragments (`c1`, `c2`, ...) each with a `type` (`basic_table` / `trend_table` / `artox_activity_table`), a SQL `query`, and JSON `settings`, referenced in the `body` HTML via `%c1%`-style placeholders. `send_to` can be a manual email list *or* a named **mailing group** (resolved via a new field value, `field=choose_mailing_group` — see below).
- **`mail_notify`** ("Mail Notification") — the most elaborate: built around a `dataset` variable with required `title`/`send_to`/`email` fields, configurable display (`List` / `Subgroup` / `In Table`), a `body_template` chosen from a fixed list of named templates (`notification_letter*`) or custom HTML, and separate toggles for notifying "Executors" vs sending a "Full Report" (to a mailing group or manual list, as one combined email or split into separates). The default sender name, `"SLA Control"`, strongly suggests this was purpose-built for SLA-breach notifications specifically, not general-purpose email.
- **`get_mail_basic_table`** ("BasicTable") — despite the name, not itself an email sender: a table-rendering helper (`Auto` or `Manual Configuration` of fields/alignment/CSS) that most likely produces the HTML behind a `mail_report` component — same field-configuration shape (`field_name`/`type`/`align`/`valueFormat`/`styleTH`/`styleTD`) as `mail_report`'s `basic_table` component type.

New dropdown reference found here: **`field=choose_mailing_group`** — lists configured mailing groups (used by `mail_report`/`mail_notify`'s "Mailing Group" recipient option).

---

# Data category

## array

**Schema title:** "Array Management". A single `operations` field (`oneOf`) picks one array operation per node instance; every operation writes its result to `assign_target` (a `$.path...` in the workflow's payload):

| Operation | Does |
|---|---|
| `array_push` / `array_unshift` | Append / prepend `value` |
| `length` | Count items |
| `shift` / `pop` | Remove & return first / last element |
| `pluck` | Extract one field (`xarg1`) from every element (like SQL `SELECT column`) |
| `join` | Join into a string with a delimiter (`xarg1`, default `,`) |
| `reverse` | Reverse order |
| `indexOf` | Find position of `xarg1` |
| `chunk` | Split into sub-arrays of size `xarg1` |
| `getKeys` | Return keys, optionally filtered to ones whose value matches `xarg1` |
| `lookupAt` | Look up by index/key |
| `array_combine` | Zip a "keys" array (`xarg1`) and a "values" array (`xarg2`) into one object |
| `insertAt` / `removeAt` | Insert/remove at a position (`xarg1`), `removeAt` also takes a `count` (`xarg2`) |

One node = one operation; a workflow doing several array manipulations in sequence will have several `array` nodes chained together, not one node with a list of operations.

## container

**Schema:** empty (`{}`) — same as `manual_trigger`, nothing to configure. Purely a **visual grouping box** on the canvas (a folder for other nodes), not something that runs logic itself. Don't expect a `data`/`mapping` for it beyond `null`.

## data_mapper

**Schema title:** "Assign Value". Writes (or deletes) fields directly on **another step's** data:
- `assign_target` — which step to write into; resolved via the dropdown-reference pattern, see [below](#resolving-other-dropdown-references-the-definitionsfield-pattern) (`field=refs_choose_all_steps`).
- `assign_list` — an array of `{key, value, set_if_empty, remove_field}`:
  - `key` — the field path on the target, e.g. `data.list`.
  - `value` — e.g. `$.steps.sql-request-1.table` or a literal like `123`.
  - `set_if_empty` — ignore the target's expected type and create the field if it's missing.
  - `remove_field` — delete that field instead of setting it.

This is a meaningful one to flag when analyzing a workflow: it's how one step can reach in and directly mutate another step's payload, which is easy to miss if only following the visual edges.

## date_time

**Schema title:** "Date and Time". One `operations` field (`oneOf`) picks a single action per node, same one-operation-per-node pattern as `array`:

`add_time`, `sub_time` — add/subtract `xarg2` of a given `xarg1` time unit.
`diff` — difference between the input date and `cmp_target` (defaults to now if empty), in `in_units` (default millisecond).
`format` — reformat the input date.
`get_date_part` / `set_date_part` — read/write a specific unit (year, month, day, ...).
`get_start_date` — start of the given unit (e.g. start of month).
`get_object` — return as a date object rather than a formatted string.
`timestamp` / `timestamp_ms` — Unix timestamp in seconds / milliseconds.
`days_in_months` — number of days in the input date's month.

Shared plumbing across all operations:
- **Input** (`input.assign_target`/`from_tz`/`from_format`) — path to the source date, its timezone, and (if not a standard ISO format) a moment.js-style format string.
- **Output** (`output_format.output_tz`/`output_time_format`) — target timezone and, if given, a format string (otherwise the result is a date object, not a string).
- `unit_list` enum: `year, quarter, month, week, day, hour, minute, second, millisecond`.
- `timezone` enum: the full IANA tz database (hundreds of entries) — not reproduced here, just know it exists and is a standard tz name like `Europe/Kyiv`.

## hash

**Schema title:** "Hash" — *"creating cryptographic hashes in workflows"*.

**`data`:** `configuration.payload_data` (the text to hash), `configuration.secret_key` (optional — turns it into an HMAC-style signed hash rather than a plain digest), `configuration.algorithm_type` (`md5`/`sha256`/`sha512`), `result.result_format` (`hex`/`base64`), `result.result_path`.

## html_xml_parser

**Schema title:** "HTML/XML Parser" — *"analyze an HTML or XML document and optionally apply selectors to it"*.

**`data`:** `configuration.payload_path` (path to the HTML/XML string), `configuration.selector` (a CSS-style selector; absent = whole document), `result.result_format` (`text`/`xml`/`json`), `result.result_path`. Output is always an array of matching elements — one element (the whole doc) if no selector, empty array if the selector matches nothing.

## json_object

**Schema title:** "JSON Object". Small utility node: `source` (a JSON string, or a `{{$.steps...}}` reference), `operation` (`decode` parses a JSON string into an object, `encode` serializes an object back to a JSON string).

## math

**Schema title:** "MATH" — *"evaluate expressions based on payload data and store the results in the payload"*.

**`data.statements`** — an array of `{expression, save_path}`, evaluated **top to bottom**, so a later statement can reference an earlier one's `save_path`. Supports trig/log/rounding functions (`sin`, `cos`, `sqrt`, `log`, `round`, `ceil`, `floor`, ...) and a ternary `if(condition, then, else)`.

## string

**Schema title:** "Text Manipulations". Same one-operation-per-node pattern as `array`:

| Operation | Does |
|---|---|
| `concat` | Build/join a string (`text`) into `save_path` — the one operation using `save_path` instead of `assign_target` |
| `split` | Split by a delimiter/regex (`xarg1`) |
| `to_lowercase` / `to_uppercase` | Case conversion |
| `to_number` | Parse as a number |
| `trim` / `trim_start` / `trim_end` | Whitespace trimming |
| `replace_all` / `replace` | Regex search (`xarg1`) & replace (`xarg2`), all-occurrences vs first-occurrence |
| `match_all` | Regex pattern search |
| `urlencode` | URL-encode or -decode (`mode`) |

---

# Trigger category

`manual_trigger` (documented above, before categories were being tracked) is also a Trigger-category node.

## hubspot_crm

**Schema title:** "Settings". Fires when a specific HubSpot CRM event happens: `authentication` (a HubSpot connection) + `trigger_event`, one of `contact.creation`/`contact.deletion`/`company.creation`/`company.deletion`/`deal.creation`/`deal.deletion`. Uses the legacy singular `field=choose_authentication` (same quirk as the Deprecated-category OAuth stubs), even though this node itself isn't deprecated — the inconsistency runs across categories, not just within one.

## scheduled

**Schema title:** "SETTINGS" — *"kicks off a workflow at an interval you can specify"*: the classic cron/timer trigger. `interval_section` is `oneOf`:
- **Standard** — `day_of_week` (multi-select Sun–Sat), `start_at` (time of day), optional `start`/`end` (date range to bound when the schedule is active at all).
- **Advanced (Cron)** — a raw `cron_interval` string, same optional `start`/`end`.

Plus a top-level `timezone` (full IANA list) that the schedule is interpreted in.

## webhook

**Schema title:** "SETTINGS". Fires when a specific **pre-created webhook** receives a call: `choose_hook.name` picks which one, resolved via a new dropdown field, `field=choose_hook_name` (see [below](#resolving-other-dropdown-references-the-definitionsfield-pattern)) — webhooks themselves are created/managed in a separate part of the app (`.../webhooks/edit/`), not inline in this node. This confirms what `webhook_reply` (Transaction category) implied: a workflow can be triggered by an inbound HTTP call, and `webhook_reply` is how it responds to that same call.

## workflow-trigger

**Schema:** just `{"type": "string", "title": "Description"}` — the entire "configuration" is a free-text description field. This is the **receiving end of `call-workflow`**: the entry point a workflow exposes so another workflow's `call-workflow` node can invoke it (with `variables` passed in). Together with `workflow-response` (Transaction category, the reply half), this is the full pattern for one workflow calling another as a reusable sub-routine: caller's `call-workflow` → callee's `workflow-trigger` → ... → callee's `workflow-response` → back to the caller (if `wait_until_done` was set).

---

## Resolving `authentication` ids

Both `http_request` and `send_email` (and likely other types with a stored-credential field) reference a connection by opaque numeric id rather than a name. The schema's `refs_choose_auth` definition points at a **third API endpoint** that resolves these into human-readable labels:

```bash
scripts/fetch_definitions.sh <any_step_id> "field=authentications"
```

Calls `GET <SUMGATE_BASE_URL>/api/workflows/steps/definitions?field=authentications&id=<step_id>` and returns:
```json
{
  "enum": ["", "49807360", "49545216", ...],
  "options": { "enum_titles": ["", "[absence] 5a...aa", "[hubspot] HubSpot Sync", ...] }
}
```
`enum[i]` pairs positionally with `enum_titles[i]` — look up an `authentication` id from a node's `data` in `enum` and read off the matching label, e.g. `49610752` → `[Mail][someone@example.com]`. This turns an opaque id into something worth telling the user (which external service/account a step actually talks to) without ever exposing the credential itself.

The exact set of connections returned may be scoped to what that particular `id` node is allowed to use rather than being a fixed global list — treat differences between calls as expected, not a bug.

## Resolving other dropdown references (the `definitions?field=...` pattern)

`authentications` (above) turns out to be one instance of a **general pattern**: any schema field that needs to offer a dropdown of "things elsewhere in this workspace" points at:

```
GET <SUMGATE_BASE_URL>/api/workflows/steps/definitions?<query_string>&id=<step_id>
```

`<query_string>` always includes `field=<field_name>`, and **sometimes an extra filter param** — copy whatever the schema's `$ref` shows after the `?` verbatim rather than assuming it's always just `field=...`. Known so far:

- **`field=authentications`** — stored external-service connections (see above).
- **`field=refs_choose_all_steps`** — used by `data_mapper`'s `assign_target`; lists the other steps in the same workflow that can be written into.
- **`field=refs_choose_all_steps&task_type=loop`** — same field, but filtered down to only `loop`-type steps; used by `break`/`next` (Flow category) to pick *which* loop they act on. This confirms the filter param genuinely restricts the list, not just cosmetic.
- **`field=choose_workflow_name`** — used by `call-workflow` (Transaction category); lists the other workflows in the workspace that can be triggered.
- **`field=choose_authentication`** (singular — *not* the same as `field=authentications`, see the Deprecated-category OAuth stubs below) — same idea, an older/parallel naming used by a handful of legacy integration nodes.
- **`field=choose_mailing_group`** — used by the legacy mail nodes (Deprecated category); lists configured mailing groups.
- **`field=choose_hook_name`** — used by `webhook` (Trigger category); lists pre-created webhooks that can trigger a workflow.

All return the same shape (`{"enum": [...], "options": {"enum_titles": [...]}}`, positionally paired). Fetch any of them with:
```bash
scripts/fetch_definitions.sh <step_id> "<query_string>"
```
If a new schema shows a `"$ref": "/api/workflows/steps/definitions?..."` whose query string isn't listed above, pass it through exactly as written and add the new pattern to this list once its purpose is confirmed.
