# Scenario: Preassembly Accessioning (Create a Preassembly Job)

Replaces `spec/features/accessioning/preassembly_accessioning_spec.rb`
(via `spec/support/shared_examples/preassembly_job_creation.rb`), using
that shared example's **default** parameters (no OCR/speech-to-text/file
manifest overrides — those apply to other, non-`sample_accession` specs
built on the same shared example).

**Depends on**:
- `register_objects.preassembly_accessioning.druid`,
  `register_objects.preassembly_accessioning.title` (from
  `register-objects.md`)
- `collection_registration.title` (from `collection-registration.md`) —
  used only for context/verification, not filled into any form here.

**Produces**: nothing new in the run log (the original spec doesn't save
job-related state either — `save_job_id` defaults to `false`). The
druid from `register_objects.preassembly_accessioning` is what
`preassembly-reaccessioning.md` depends on.

**Settings used**: `{{argo_url}}`, `{{preassembly_url}}`,
`{{preassembly_username}}`, `{{preassembly_host}}`,
`{{preassembly_bundle_directory}}`

---

## Before you start: preflight

This scenario is the first one in the sequence to touch SSH/SCP. Confirm
both `SKILL.md` preflight checks have passed for this run (network
reachability to Argo, and an active SSH ControlMaster session covering
`{{preassembly_host}}`) before proceeding — see `SKILL.md`'s "Preflight
checks" section. Don't re-derive this logic here; just confirm it's been
done and recorded in the run log.

## Step 1 — Confirm starting state in Argo

1. Navigate to `{{argo_url}}/view/<register_objects.preassembly_accessioning.druid>`.
2. **Verify: the page shows the title
   `register_objects.preassembly_accessioning.title`** (confirms the
   right object, and confirms auth carried over).

## Step 2 — Stage the manifest file via SCP

The object's files must already exist on `{{preassembly_host}}` at
`{{preassembly_bundle_directory}}` (staged there ahead of time, outside
this scenario's scope — same assumption the original spec makes). What
this scenario stages is the **manifest.csv** telling Preassembly which
druid to associate with which staged content.

1. Compute the bare druid (strip the `druid:` prefix) from
   `register_objects.preassembly_accessioning.druid`.
2. Write a local file `tmp/manifest.csv` with exactly this content
   (header row + one data row):
   ```
   druid,object
   <bare druid>,content
   ```
3. **Propose the SCP command** per `SKILL.md`'s "Non-browser steps"
   convention:
   ```
   scp tmp/manifest.csv {{preassembly_username}}@{{preassembly_host}}:{{preassembly_bundle_directory}}
   ```
   State this command, get human-copilot approval (or run directly if
   pre-authorized for the session), and run it using the existing
   ControlMaster session.
4. **Verify: the command exits 0.** If it doesn't, stop and report the
   command's stderr — do not proceed to the Preassembly UI with an
   unstaged manifest.

## Step 3 — Submit the Preassembly job

1. Navigate to `{{preassembly_url}}`.
2. **Verify: the page shows a "Start new job" heading.**
3. Fill in the job form:
   - Project name → `IntegrationTest-preassembly-accessioning-<a fresh
     random UUID>`
   - Job type → `Preassembly Run`
   - Content type → `Image`
   - Staging location → `{{preassembly_bundle_directory}}`
   - Leave all other fields/radio choices at their defaults (no
     processing-configuration override, no file-manifest option, no
     OCR/speech-to-text settings — those belong to other scenarios built
     on the same underlying job-creation flow, not this one).
4. Click **Submit**.
5. **Verify: the page shows "Success! Your job is queued. A link to job
   output will be emailed to you upon completion."**
6. Read the job number from a table cell matching `Job #<N>` — record it
   locally (not in the run log; this scenario doesn't persist a job id,
   matching the original spec's default `save_job_id: false`).

## Step 4 — Wait for the job and download its result

1. Click the first link in the results table (leads to the job's detail
   page).
2. **Verify: the page shows the project name from step 3.**
3. **Wait (up to `{{timeouts.workflow}}` seconds, default 300) for: the
   "State" table cell to read "Job completed"** (equivalently, the
   per-druid Progress Log row's status column reading "Accessioning
   success" or an error string) — this is the background Preassembly job
   finishing. Use the poll convention in `SKILL.md`, **and note that this
   page does not update in place**: each poll iteration needs a fresh
   `browser_navigate` to the same `job_runs/<N>` URL, not just re-checking
   the already-loaded DOM. **Do not wait for a "Download" link to
   appear** — confirmed via a live run that the "Job output log /
   Download" row is present on this page from the moment the job is
   created, whether the job is "Running" or "Job completed"; it is not a
   completion signal at all, so a check for its presence passes
   immediately and never actually waits for the job. Unlike the
   Argo-workflow polls in earlier scenarios, there's no `.alert-danger`
   equivalent visible on this page to bail out on early — if the job
   fails, the State cell should show an error string instead of "Job
   completed"; rely on the overall timeout if it doesn't.
4. Click **Download**.
5. **Verify: the downloaded file, parsed as YAML, has `status: success`.**
   If the download doesn't parse as YAML, or `status` is anything else,
   stop and report the actual downloaded content.
6. Delete the downloaded file locally afterward (matches the original
   spec's `delete_download` — avoids accidentally picking up a stale
   download in a later scenario that also downloads a YAML, e.g.
   `preassembly-reaccessioning.md`).

## Cleanup (matches original spec's `after` block)

After this scenario (whether it passed or failed), clean up the staged
manifest so it doesn't interfere with reruns:

1. **First check what's actually there** — `{{preassembly_bundle_directory}}`
   has been observed (live run) to be a **shared, persistent staging
   area** reused across many unrelated runs (old druid-named directories,
   a reusable `content/` directory holding the real pre-staged files,
   `README.md`, a `structure-*.csv`), not a fresh per-run directory. Run
   `ssh {{preassembly_username}}@{{preassembly_host}} ls -la
   {{preassembly_bundle_directory}}` first and confirm a `<bare druid>`
   directory actually exists before trying to remove it — for this row
   (content mapped to the shared `content/` folder via `manifest.csv`),
   it never does, and the step below would be a no-op.
2. Only if a `<bare druid>` directory is actually present, **propose and
   run** (per `SKILL.md` conventions):
   ```
   ssh {{preassembly_username}}@{{preassembly_host}} rm -rf {{preassembly_bundle_directory}}/<bare druid>
   ```
3. This is best-effort — a failure here shouldn't be treated as a
   scenario failure, just noted in the run log. Note that `manifest.csv`
   itself is **not** cleaned up by this step — it's shared, mutable state
   that the next run of this scenario (or `preassembly-reaccessioning.md`)
   will overwrite with its own content anyway.

## Done

Nothing new recorded in the run log for downstream scenarios beyond what
was already there. `preassembly-reaccessioning.md` re-derives everything
it needs from `register_objects.preassembly_accessioning`, and expects
this scenario to have completed successfully first (specifically, that
the object has reached `vN Accessioned` status in Argo before it starts —
which it checks itself via its own poll step, not something this scenario
needs to verify beyond the YAML `status: success` check above).

## Verified in a live dry run (2026-09-24)

Run live end-to-end against stage (see
`.agents/skills/run-sample-accession-tests/runs/20260924T193206Z.md`),
confirming everything above except the two corrections already folded
in (the completion signal being "State" rather than a Download link,
and the Cleanup section's shared/pre-staged bundle-directory caveat).
The job (Preassembly #5206) completed in well under a minute for this
single-image row.
