# SDR Sample Accession — Agent Skill

## Purpose

This skill replaces the `:sample_accession`-tagged Capybara/RSpec feature
specs with an LLM agent driving a real browser via the Playwright MCP,
supervised by a human copilot. It exists to fix two problems with the
RSpec version:

- **Reliability**: brute-force `location.reload()` polling loops and fixed
  `sleep N` calls produce false negatives that don't reflect real
  regressions.
- **Speed / maintenance cost**: brittle CSS selectors break on incidental
  markup changes, and every environment quirk (2FA, SSH, Duo) has to be
  encoded in Ruby.

Scenarios are expressed as **git-versioned, human-readable instruction
files** (`scenarios/*.md`) rather than code. This file defines the shared
conventions every scenario file relies on, so scenario files can stay short
and focused on *what to do and check*, not *how to wait or recover*.

## Tooling checklist

Before running any scenario, confirm the agent has access to tools
covering each of these capabilities. The specific tool names below are
what this skill has been validated against; any tool offering the same
capability should work, but hasn't necessarily been tried here.

- **Browser automation**, with at minimum: navigate, click, fill
  form fields, take an accessibility-tree snapshot, and evaluate
  arbitrary JavaScript in the page (needed for the "Large-page
  efficiency convention" below). Must be launchable **headed** with a
  **persistent profile/storage state** — see "One-time environment
  setup." *(Validated with: Playwright MCP.)*
- **Shell/command execution**, capable of running `scp`/`ssh`
  non-interactively against a pre-established connection (see
  "Preflight checks" and "Non-browser steps (SCP/SSH)"), and of running
  small local scripts (e.g. to generate a random title/UUID, or parse a
  downloaded CSV/YAML file). Ideally sandboxed/isolated from
  long-term memory, per "Credential handling" below.
- **Local file read/write**, for the run log, generated manifest
  files, and downloaded artifacts (CSV/YAML) that get parsed as
  checkpoint evidence.
- **Task/checklist tracking** across a long-running scenario, so
  progress and outstanding steps survive context compaction in a long
  session — not strictly required, but recommended once a scenario has
  many steps (e.g. `register-objects.md`'s per-row loop).
- **A second, independent agent session or reviewer**, for the
  "Witness pass" described below — only needed for the higher-stakes
  scenarios, not every run.

If any of these is missing, treat it the same as a failed preflight
check: stop and resolve it before starting, rather than discovering the
gap partway through a scenario.

## Roles

- **Agent**: drives the browser (Playwright MCP tools), makes judgment
  calls about "still loading" vs. "actually broken," records state,
  reports pass/fail per checkpoint.
- **Human copilot**: present for the run. Handles anything the agent
  cannot or should not do unattended:
  - Duo / 2FA approval prompts.
  - Entering any credential (SUNet password, API token, etc.) the agent
    should never see, type, or persist — see "Credential handling"
    below. A pre-authenticated persistent browser profile (see
    "Authentication") means this rarely comes up mid-run.
  - Approving any SSH/SCP command the agent proposes running against
    `preassembly` or `preservation_catalog` hosts (file staging, fixity
    checks). The agent should draft the exact command and ask before
    running it via a shell tool.
  - Starting a VPN connection or an SSH ControlMaster session when a
    preflight check (see "Preflight checks" below) finds either missing.
  - Spot-checking / overriding a checkpoint verdict the agent isn't
    confident about.

The agent should escalate to the human rather than guess, whenever a step
requires a credential, a host-key/SSH prompt, or a Duo push, and whenever
it is not confident a checkpoint has actually passed.

## Matching model capability to the task at hand

This skill involves two distinct kinds of agent work, with different
capability requirements. Don't default to the same model tier for both —
it's easy to overspend on one and underspend on the other.

**Authoring/editing a scenario file** (writing or revising the numbered
steps and checkpoints, deciding how precise a checkpoint needs to be,
anticipating failure modes not spelled out in whatever source material
the scenario was derived from) is high-judgment work. Mistakes made here
are silent and repeated: a subtly-wrong or under-specified checkpoint
gets baked into a file that every future run then executes against,
possibly for a long time before anyone notices it was never checking the
right thing. Favor a model that is strong specifically on:
- **long-horizon reasoning and planning** — holding a whole multi-step
  flow in mind and reasoning about ordering/dependencies, not just
  answering the immediate question;
- **careful instruction-following and precision in writing** — the
  output here *is* the instructions another (possibly less capable)
  model or a human will follow later, so ambiguity or hand-waving in the
  prose directly becomes a defect;
- **adversarial/edge-case thinking** — anticipating what could go wrong,
  what a checkpoint might falsely pass on, what a credential-handling
  gap could look like — rather than only describing the happy path.

Budget the time to have such a model think carefully and iterate,
rather than accept a fast first draft.

**Executing an already-written scenario against a real environment** is
comparatively mechanical, *provided the scenario is actually
well-specified*: each step already states the exact value to enter, the
exact text to look for, the exact condition to wait on. Here, prioritize
different traits over raw reasoning power:
- **reliable, literal instruction-following** — doing exactly what a
  well-specified step says, not "improving" on it or skipping ahead;
- **disciplined tool use** — calling the available tools (browser
  actions, shell commands) correctly and checking their results, rather
  than assuming an action succeeded;
- **honest, calibrated reporting** — saying "I'm not sure this passed"
  rather than defaulting to an optimistic reading of ambiguous evidence.

A smaller/cheaper model with these traits will typically outperform a
larger, more expensive model that has them less reliably. Raw benchmark
capability matters far less for this phase than for authoring.

A practical consequence: when a lower-capability model is executing a
scenario and hits something the scenario didn't anticipate (unexpected
UI structure, an ambiguous checkpoint, a judgment call the steps don't
clearly resolve), it should **stop and flag the gap rather than improvise
past it** — either escalating to the human copilot, or flagging it for a
follow-up authoring pass with a stronger model. Treat "the scenario file
didn't cover this" as a signal to go fix the scenario file (with a
capable model), not as license for the executing model to guess. Over
time this pushes more edge cases into the written instructions, which is
exactly what makes cheaper execution viable on repeat runs — a mature,
well-refined scenario needs progressively less real-time judgment to
execute correctly.

## Run state

State that today lives in `tmp/{date}_data.yml` (druids, titles, job ids)
is instead tracked as an explicit **run log**: a scratch file at
`.agents/skills/run-sample-accession-tests/runs/{timestamp}.md`. This
directory is gitignored
(`.agents/skills/run-sample-accession-tests/runs/`) — run logs are
ephemeral working state for a single dry-run/session, never committed.
Each scenario file says what it expects to receive from prior scenarios
and what it must record for later ones. Treat this run log as the source
of truth for druids/titles/job-ids within a run — never invent or guess
an id.

**Credentials never go in the run log**, or anywhere else persisted to
disk or git. See "Credential handling" below — this is a hard rule, not a
preference.

## Credential handling

No credential — SUNet password, Duo response, SSH passphrase, API token,
or any other secret — is ever:

- written to the run log or any other file the agent creates,
- included in a checkpoint's recorded "evidence,"
- echoed back in the agent's own output/transcript, even to confirm it
  was received,
- retained by the agent beyond the moment it's needed (the agent should
  not "remember" a credential across scenarios or runs — each time it's
  needed, either a persisted authenticated session/profile handles it
  transparently, or the human enters it live).

In practice this means:

- The agent never reads `config/**/*.local.yml` (or any `.local.yml`)
  itself. Those files are for the human copilot's own tooling, not
  agent consumption.
- If a login form appears, the agent does not type a username or password
  into it — it pauses and asks the human copilot to do so directly in the
  browser window the agent is driving.
- If a command needs a token or password (e.g. an API call using
  `dor_services.token`), the human copilot supplies it out-of-band (typed
  directly into a terminal/prompt they control), not by telling the agent
  the value.
- Non-interactive SSH/SCP should rely on key-based auth via an existing
  ControlMaster session (see "Preflight checks" below) precisely so the
  agent never needs to handle an SSH password either.

## Preflight checks

Before starting **any** scenario, run these two checks. Both exist because
their failure modes look like mysterious hangs/timeouts deep into a
scenario otherwise — better to fail fast with a clear message.

1. **Network reachability**: confirm HTTPS access to the target
   environment's Argo host (e.g. `https://argo-stage.stanford.edu` for
   stage) — a simple reachability check (e.g. an HTTP HEAD/GET that
   returns any response rather than a connection error/timeout) is
   sufficient; a login redirect still counts as reachable.
   - **If unreachable**: stop and ask the human copilot to start/check
     their VPN connection, then retry the check before proceeding.
2. **SSH ControlMaster session**: confirm there is an active SSH
   ControlMaster session available for the hosts this run will need
   (`preassembly` and/or `preservation_catalog`, per the scenario's
   needs) — e.g. `ssh -O check <host>` against the configured
   `preassembly.host` / `preservation_catalog.host`.
   - **If absent**: stop and ask the human copilot to establish the
     ControlMaster session (so subsequent `scp`/`ssh` calls in the run
     are non-interactive and don't need a password/passphrase from the
     agent), then retry the check before proceeding.

Record the outcome of both checks (pass/fail, environment checked) at the
top of the run log, before any scenario's own steps begin.

**Re-run both checks after any unexplained mid-run failure, not just at
the start.** A live run hit three separate VPN drops mid-scenario, each
surfacing as a confusing downstream symptom rather than an obvious
network error: a browser navigation hanging then failing with
`net::ERR_TIMED_OUT`, or an `scp`/`ssh` command failing with
`mux_client_request_stdio_fwd: read from master failed: Broken pipe` /
`scp: Connection closed`. In every case the SSH ControlMaster session had
also silently died (`ssh -O check <host>` afterward reported "No such
file or directory", even though a check run immediately after the VPN
reconnected had briefly reported "Master running" before it died again)
— **the two checks can fail independently and at different times**, so
re-check both, not just the one that seemed to fail. Treat any of these
symptoms as a signal to stop, re-run both preflight checks, and ask the
human copilot to reconnect VPN and/or re-establish the ControlMaster
session (`ssh sdr-infra`) before retrying the action that failed — do
not retry blindly against a connection that's actually gone.

## One-time environment setup

Before the first run in any environment (per human copilot / machine),
confirm the Playwright MCP server itself is configured correctly — this
is a prerequisite distinct from the per-run preflight checks above, and
its failure mode is confusing rather than a clean error: a headless
and/or `--isolated` browser will happily hit a login wall with no visible
window for a human to complete it, and no session will ever persist.

Check the Playwright MCP server's launch args (e.g. in
`~/.config/eca/config.json`'s `mcpServers.playwright`, or the equivalent
for whatever client is running the agent):

- **Headed, not headless** — no `--headless` flag. The human copilot
  needs an actual visible window to complete login/Duo in.
- **Persistent profile, not isolated** — a fixed `--user-data-dir` (e.g.
  `--browser firefox --user-data-dir
  ~/.cache/playwright-sdr-integration-profile`), not `--isolated`. This
  is what lets a "trust this browser" Duo cookie survive across runs, so
  most runs after the first don't need a human login step at all.
- Watch for stray/duplicate config entries silently overriding the
  intended settings (JSON objects silently keep only the last key of a
  duplicate) — if the browser that opens doesn't match what's configured,
  check for exactly this.

This is a one-time (per machine) setup step, not something to rediscover
by having a run fail partway through.

## Locator convention

When filling or clicking, use the **`ref=` identifier from the most
recent snapshot**, not a hand-written locator string (e.g. `textbox
"Title"`) — the latter is not guaranteed to resolve and can fail outright
depending on the tool. Take a fresh snapshot after any navigation or
significant DOM change before acting on it, since refs are tied to a
specific snapshot.

## Large-page efficiency convention

Some pages in this suite have very large forms (e.g. Argo's registration
page has an APO dropdown with 500+ options in a real environment). A full
`browser_snapshot`, or an unscoped `browser_find`, on such a page dumps
all of that into context on every call — expensive and mostly irrelevant.
Prefer, in this order:

1. **`browser_evaluate` for native `<select>`/`<input>` fields**: read or
   set values directly by DOM id/name rather than snapshotting to find a
   ref. When setting a value that should trigger dependent UI behavior
   (e.g. an APO selection repopulating a Collection dropdown), dispatch a
   `change` event so the page's own JS listeners fire. Verify the
   resulting state (e.g. that the dependent dropdown's options updated)
   by reading it back via `browser_evaluate`, not via another full
   snapshot.
2. **`browser_find` scoped to a specific field's label** (e.g. "Project
   Name") instead of a full-page snapshot, when you need a snapshot-based
   ref to click something (autocomplete comboboxes, buttons) that
   `browser_evaluate` can't drive directly.
3. Fall back to a full `browser_snapshot` only when you genuinely need to
   see the whole page state (e.g. right after a page load, to get your
   bearings once).

## Checkpoint convention

Every scenario is a sequence of **actions** and **checkpoints**.
Checkpoints are the load-bearing part — they replace RSpec's `expect(...)`
calls and must stay precise, not vibes-based:

- State the *exact* expected text, count, or value, e.g. "exactly 6 rows
  with class `file`" or "row 1 matches `argo-logo.png image/png <N>.<N>
  KB`" — not "the files look right."
- When a checkpoint requires waiting on an async workflow, use the
  **poll convention** below instead of ad hoc sleeps.
- Report each checkpoint's outcome explicitly (pass/fail + brief evidence:
  matched text, a snapshot reference, or a downloaded file's parsed
  contents) rather than silently moving on. This guards against declaring
  success without real evidence — see "Witness pass" below.
- If a checkpoint fails, stop the scenario and report exactly which
  checkpoint failed and what was observed instead of expected. Do not
  continue to later steps that depend on it.

## Poll convention (replaces `reload_page_until_timeout!`)

When an instruction says **"Wait (up to N minutes) for: `<condition>`"**:

1. Take a snapshot / check for the condition.
2. If present, proceed.
3. If an error state is visible (e.g. a `.alert-danger` banner, an HTTP
   error page), **stop immediately** and report it — do not keep waiting.
4. Otherwise wait with backoff (e.g. 10s, 10s, 20s, 30s, capped at ~60s
   between checks) and recheck, up to the stated timeout.
5. On timeout, report failure with the last observed page state.

**Some pages do not update in place** (confirmed via a live run: Argo's
Events panel and Preassembly's job-detail page both only reflect state as
of their last full load — no auto-refresh, no "load more"/pagination
surfacing newer data). For these, "recheck" in step 4 means a fresh
`browser_navigate` to the same URL, not re-inspecting the already-loaded
DOM or re-clicking an already-expanded section — the latter will silently
poll a stale snapshot forever regardless of real backend progress. When
authoring a scenario's wait condition, state explicitly whether a reload
is required, rather than leaving it implicit.

**A scenario's own suggested timeout may understate real-world latency**
— a live run saw one async condition (preservation replication) take up
to ~6.5 minutes for one case and still not resolve after ~12 minutes for
another, well past that scenario's configured `timeouts.workflow` (300s)
and `timeouts.events.poll_for` (240s). Treat hitting a stated timeout as
a signal to check with the human copilot whether to extend the wait
(especially for a condition confirmed to sometimes legitimately take
longer) rather than an automatic hard failure — but still surface it
clearly rather than silently waiting past what was agreed.

This is deliberately less aggressive than the old 1-second reload loop —
real workflows take minutes, and cheap frequent polling was mostly wasted
cost, not faster detection.

## Authentication

- Prefer a **persistent authenticated browser profile** (Playwright
  storage state / persistent context) that already has a "trust this
  browser" cookie for Duo, reused across runs, so 2FA is rarely needed.
  See "One-time environment setup" above for how the Playwright MCP
  server must be launched for this to work at all.
- If a login form or Duo prompt appears anyway, the agent pauses and asks
  the human copilot to complete it **directly in the browser window** —
  the agent never types a username, password, or Duo response itself, and
  never asks the human to send a credential through the chat. See
  "Credential handling" above.
- Continue once the expected post-login text appears.
- Note: a separately-authenticated regular browser (e.g. the human's own
  Brave/Chrome session) does **not** help here — Playwright drives its
  own browser instance/profile, so authentication must happen in the
  window Playwright is actually driving.

## Non-browser steps (SCP/SSH)

Some scenarios require moving files to/from `preassembly` or
`preservation_catalog` hosts, or running a remote fixity-check command.
These rely on the SSH ControlMaster session confirmed during preflight
checks, so no password/passphrase prompt should occur. For these steps:

1. The agent states the exact command it intends to run (source, target,
   flags) as part of its output.
2. The human copilot approves (or the agent runs it directly via a shell
   tool if the human has pre-authorized this for the session) — using the
   existing ControlMaster session, not a fresh interactive login.
3. The agent parses command output/exit status as the checkpoint evidence,
   the same as it would parse a downloaded file's contents.
4. If a command unexpectedly prompts for a password/passphrase (meaning
   the ControlMaster session isn't actually in effect), the agent stops
   and asks the human to re-check/re-establish it — it does not attempt
   to supply credentials itself.

## Witness pass (optional but recommended)

For higher-stakes scenarios (full reaccessioning + fixity check), consider
a second, independent pass — either the human copilot reviewing the
checkpoint evidence log, or a separate agent session given only the
recorded evidence (not the acting agent's narrative) and asked to confirm
each checkpoint's claim is actually supported by the evidence. This
mirrors the `allium:witness` pattern: don't trust a self-report of
convergence without an independent check.

## Scenario ordering

This skill currently covers the full `:sample_accession`-tagged RSpec set
(the "Accessioning Quick Run" described in this repo's README) as 5
scenario files, run in this order:

1. `scenarios/apo-registration.md` — registers an APO. No dependencies.
2. `scenarios/collection-registration.md` — registers a Collection under
   that APO. Depends on (1).
3. `scenarios/register-objects.md` — registers ~13 test objects (most
   under the APO/Collection from (1)/(2); a few target other,
   pre-existing APOs/Collections that must already exist in the target
   environment). Depends on (1) and (2).
4. `scenarios/preassembly-accessioning.md` — accessions one of the
   objects from (3) (`preassembly_accessioning`) via a real Preassembly
   job, including SCP to the preassembly host. Depends on (3).
5. `scenarios/preassembly-reaccessioning.md` — re-accessions that same
   object with a targeted file swap, verifies preservation replication,
   and runs a remote fixity check via SSH. Depends on (4) having
   completed (specifically, checks the object is still at `v1
   Accessioned` before proceeding, and refuses to run against an
   already-reaccessioned object).

A scenario file states which prior scenarios' run-log entries it depends
on at the top, so scenarios can be run individually as long as those
entries exist in the current run log. Scenarios (1)–(3) are read-mostly
and low-risk to rerun; (4) and (5) create real Preassembly jobs and
mutate real preservation state — don't rerun (5) against the same object
(see its built-in safety guard).

## Settings

Scenario files reference environment values in `{{double-brace}}`
placeholders rather than hardcoding staging hosts, so the same
instructions work against `stage` or `qa`. These map to the existing
`config/settings.yml` (and environment-specific `config/settings/{env}.yml`,
plus local override files) keys — the human copilot supplies the active
environment at the start of a run and resolves these from that
environment's actual config, e.g.:

- `{{argo_url}}`, `{{purl_url}}`
- `{{preassembly_url}}`, `{{preassembly_username}}`, `{{preassembly_host}}`,
  `{{preassembly_bundle_directory}}`
- `{{preservation_catalog_username}}`, `{{preservation_catalog_host}}`
- `{{dor_services_url}}`, `{{dor_services_token}}`
- `{{test_folio_instance_hrid}}`, `{{number_of_constituents}}`,
  `{{ocr_enabled}}`
- `{{timeouts.workflow}}`, `{{timeouts.events.poll_for}}`,
  `{{timeouts.events.poll_interval}}`

Never resolve `{{dor_services_token}}` (or any other credential-shaped
placeholder) by reading it yourself from a `.local.yml` file — see
"Credential handling" above.

## Scenario file format

See `scenarios/apo-registration.md` for the simplest reference example.
Each of the 5 files under `scenarios/` (see "Scenario ordering" above)
has:

- **Depends on**: prior run-log entries required, if any.
- **Produces**: run-log entries this scenario must record.
- **Steps**: numbered actions in plain language.
- **Checkpoints**: interleaved with steps, marked `Verify:` or `Wait:`.

Before the first scenario in a run, complete the **preflight checks**
above and record their outcome in the run log.
