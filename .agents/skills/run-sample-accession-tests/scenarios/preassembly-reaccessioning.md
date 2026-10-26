# Scenario: Preassembly Re-accessioning

Replaces `spec/features/preassembly/preassembly_reaccessioning_spec.rb`.

This is the most involved scenario in the set: it edits a downloaded CSV,
performs multiple SCP round-trips to two different remote concerns
(staging files for Preassembly, and later verifying preservation
replication), and ends with a fixity check run over SSH. Treat every
checkpoint here as load-bearing — this scenario is the closest thing to
a true regression check for the whole accessioning pipeline.

**Depends on**:
- `register_objects.preassembly_accessioning.druid`,
  `register_objects.preassembly_accessioning.title` (from
  `register-objects.md`) — this scenario assumes
  `preassembly-accessioning.md` has already completed successfully for
  this same druid (i.e. the object is at `v1 Accessioned`).

**Produces**: nothing persisted for further scenarios (this is the last
scenario in the `sample_accession` set) — but see the "Safety guard"
step below, which reads back prior state to protect against unsafe
re-runs.

**Settings used**: `{{argo_url}}`, `{{preassembly_url}}`,
`{{preassembly_username}}`, `{{preassembly_host}}`,
`{{preassembly_bundle_directory}}`, `{{preservation_catalog_username}}`,
`{{preservation_catalog_host}}`, `{{dor_services_url}}`,
`{{dor_services_token}}`, `{{ocr_enabled}}`

---

## Before you start: preflight

Confirm both `SKILL.md` preflight checks (network + SSH ControlMaster)
have passed for this run, same as `preassembly-accessioning.md`. This
scenario additionally needs the ControlMaster session to cover
`{{preservation_catalog_host}}` by the time you reach the fixity-check
step — re-check that specifically before that step if it wasn't
confirmed at the top of the run.

## Step 1 — Navigate and safety guard

1. Navigate to
   `{{argo_url}}/view/<register_objects.preassembly_accessioning.druid>`.
   - **Verify: the page shows the title
     `register_objects.preassembly_accessioning.title`**.
2. **Wait (up to `{{timeouts.workflow}}` seconds) for: the page shows a
   pattern matching `v<N> Accessioned`** (confirms the earlier
   preassembly-accessioning job has finished).
3. Read the version number `N` from that text.
4. **Safety guard — critical, do not skip:** if `N > 1`, **stop this
   scenario entirely and do not proceed.** This means the object has
   already been re-accessioned by a prior run of this same scenario, and
   this scenario is not safe to replay against an already-reaccessioned
   druid (the file-count/byte-size checkpoints below assume a
   freshly-accessioned v1 object). Report this clearly, and note that a
   fresh object requires re-running `register-objects.md`'s
   `preassembly_accessioning` row and `preassembly-accessioning.md`
   before this scenario can run again.
5. If `N == 1`, proceed. Record `N` locally as `original_version` (used
   throughout this scenario; not written to the run log since this
   scenario is a terminal step).

## Step 2 — Verify original file set

1. On the same Argo page, find all table rows with class `file`.
2. **Verify: there are exactly 6 such rows**, matching (in this exact
   order):
   1. `argo-logo.png image/png <N>.<N> KB`
   2. `argo-logo.jp2 image/jp2 <N>[.<N>] KB`
   3. `image.jpg image/jpeg <N>.<N> KB`
   4. `image.jp2 image/jp2 <N>[.<N>] KB`
   5. `sul-logo.png image/png <N>.<N>+ KB`
   6. `sul-logo.jp2 image/jp2 <N>.<N>+ KB`
3. **Verify: the "Content type" field reads `image`.**
4. Expand the "Technical metadata" section (click it), scroll to the
   bottom of the page (triggers lazy-loading of that section), and
   **wait (short — a couple seconds is enough) for: the page still shows
   `v<original_version> Accessioned`** (confirms the page didn't
   navigate away underneath you while metadata loaded).
5. **Verify: the word "filetype" appears (at least) 3 times**, **the
   phrase "file_modification" appears (at least) 3 times**, and **the
   text "bytes 29634" appears somewhere** (this is the byte size of the
   file we're about to remove from the manifest for a targeted
   re-accession — recording it now lets us confirm later that only the
   intended file changed).

## Step 3 — Download and edit the CSV

1. Click **Download CSV**.
2. **Verify: a CSV file downloads.** Parse it as CSV.
3. Edit the parsed rows:
   - Remove the row where column 2 (index 1) equals `Image 3`.
   - Remove the row where column 5 (index 4) equals `argo-logo.jp2`.
   - Append a new row:
     ```
     <bare druid>,Image 4,image,3,vision_for_stanford.jpg,vision_for_stanford.jpg,no,no,yes,world,world,,image/jpeg,
     ```
4. Write the edited rows to a local file `tmp/file_manifest.csv`.
5. Delete the originally-downloaded CSV file locally (avoid picking it
   up by mistake later).

## Step 4 — Stage the file manifest and files via SCP

1. **Propose and run** (per `SKILL.md` conventions), each as its own
   command, verifying exit 0 before proceeding to the next:
   ```
   scp tmp/file_manifest.csv {{preassembly_username}}@{{preassembly_host}}:{{preassembly_bundle_directory}}
   ```
2. Write a local file `tmp/manifest.csv` with:
   ```
   druid,object
   <bare druid>,<bare druid>
   ```
   (Note: this is a **different** manifest.csv content than
   `preassembly-accessioning.md` used — the `object` column now points
   at the bare druid itself, not `content`, because this is a targeted
   re-accession using a file manifest.)
3. **Propose and run:**
   ```
   scp tmp/manifest.csv {{preassembly_username}}@{{preassembly_host}}:{{preassembly_bundle_directory}}
   ```
4. Create a local directory named after the bare druid. Copy
   `spec/fixtures/argo-home.png` into it as `argo-logo.png` (replacing
   the original file with a different one), and copy
   `spec/fixtures/vision_for_stanford.jpg` into it unchanged (a new
   file).
5. **Propose and run:**
   ```
   scp -r <bare druid> {{preassembly_username}}@{{preassembly_host}}:{{preassembly_bundle_directory}}
   ```
6. After all three SCPs succeed, **wait about 20 seconds** before
   proceeding — this mirrors the original spec's deliberate pause to
   avoid a race condition between the file staging completing remotely
   and Preassembly starting to read it. (This is one of the few places
   where a fixed sleep is appropriate rather than a poll, because there
   is no observable "staging is done" signal to poll for — the wait is
   bounded and small, not a substitute for a real completion check.)

## Step 5 — Submit the re-accession job

1. Navigate to `{{preassembly_url}}`.
2. **Verify: the page shows "Start new job".**
3. Fill in the job form:
   - Project name → `IntegrationTest-preassembly-reaccessioning-<a fresh
     random UUID>`
   - Job type → `Preassembly Run`
   - Content type → `Image`
   - Staging location → `{{preassembly_bundle_directory}}`
   - Processing configuration → `Group by filename`, **unless**
     `{{ocr_enabled}}` is true, in which case leave this field alone (it
     may not be present/relevant when OCR is enabled — matches the
     original spec's `unless Settings.ocr.enabled` condition).
   - Choose the "use file manifest" option (the radio/checkbox for
     supplying a file manifest, as opposed to the default grouping
     behavior).
4. Click **Submit**.
5. **Verify: the page shows "Success! Your job is queued. A link to job
   output will be emailed to you upon completion."**
6. Read the job number from a table cell matching `Job #<N>`.
7. Navigate to `{{preassembly_url}}/job_runs/<job number>`.
8. **Wait (up to `{{timeouts.workflow}}` seconds) for: a "Download" link
   to appear.**
9. Click **Download**.
10. **Verify: the downloaded file, parsed as YAML, has `status:
    success`.** Read its `pid` field — this is the prefixed druid the
    job operated on (should match the original druid; if it doesn't,
    stop and report the mismatch rather than proceeding against the
    wrong object).
11. Delete the downloaded file locally afterward.
12. Compute `latest_version = original_version + 1` (i.e. `2`, given the
    safety guard in Step 1 already confirmed `original_version == 1`).

## Step 6 — Verify the re-accessioned object

1. Navigate to `{{argo_url}}/view/<pid from Step 5>`.
2. **Wait (up to `{{timeouts.workflow}}` seconds) for: the page shows
   `v<latest_version> Accessioned`** (the accessioning workflow
   finishing for the new version).
3. Find all table rows with class `file`.
4. **Verify: there are exactly 6 such rows**, matching (in this exact
   order):
   1. `argo-logo.png image/png <N>.<N> KB`
   2. `argo-logo.jp2 image/jp2 <N>[.<N>] KB`
   3. `image.jpg image/jpeg <N>.<N> KB`
   4. `image.jp2 image/jp2 <N>[.<N>] KB`
   5. `vision_for_stanford.jpg image/jpeg <N>.<N>+ KB`
   6. `vision_for_stanford.jp2 image/jp2 <N>.<N>+ KB`
   (Compare against Step 2's list: `sul-logo.*` is gone, replaced by
   `vision_for_stanford.*` — confirms the targeted file swap worked as
   intended, not just that *some* re-accessioning happened.)
5. Expand "Technical metadata" again, scroll to bottom, **wait (short)
   for: the page still shows `v<latest_version> Accessioned`**.
6. **Verify: "filetype" appears (at least) 3 times**, **"file_modification"
   appears (at least) 3 times**, **the text "bytes 9071" appears
   somewhere** (vision_for_stanford.jpg's byte size — the new file), and
   **the text "bytes 29634" appears somewhere** (confirms the original,
   unchanged file from Step 2 — `image.jpg`, per the manifest — is
   genuinely untouched, not just present by coincidence).

## Step 7 — Confirm preservation replication and fixity

This step has three parts, all load-bearing; do not skip any of them or
substitute a weaker check.

### 7a — Replication event visible in Argo

1. On the same Argo page, click **Events** to expand that section, then
   scroll to the bottom (triggers lazy loading).
2. **Wait (up to ~5 seconds) for: an events panel to finish loading**,
   then click any "Expand all" controls within it.
3. Compute the expected S3 key: the druid's tree path (e.g.
   `druid:ab123cd4567` → `ab/123/cd/4567`) plus
   `.v<latest_version padded to 4 digits>.zip` (e.g.
   `ab/123/cd/4567.v0002.zip`).
4. **Verify: that exact key string appears somewhere in the expanded
   events section.**

### 7b — Full replication event history via the events API

This step calls the dor-services-app events API directly (not through
the browser) — an HTTP GET, not an SCP/SSH command, but still uses a
credential (`{{dor_services_token}}`), so treat it under `SKILL.md`'s
credential-handling rules: the human copilot supplies the token
out-of-band to whatever script/tool makes this call; the agent does not
need to see or type the token itself if a pre-configured client/script
already has it.

1. For every version from `1` to `latest_version` inclusive, and for
   every endpoint in `aws_s3_west_2_stage`, `gcp_s3_south_1`,
   `aws_s3_east_1_stage` (stage-environment endpoint names — adjust
   suffixes if running against QA, per `EventHelpers::TARGET_ENDPOINT_NAMES`):
   - **Verify: the events list (from `GET
     {{dor_services_url}}/v1/objects/<prefixed druid>/events` or
     equivalent client call) contains an event with `event_type ==
     "druid_version_replicated"`, whose data's `parts_info` has exactly
     one entry, whose `s3_key` matches that version's zip key (as
     computed in 7a), and whose `endpoint_name` matches.**
2. This may need polling (events are recorded asynchronously after
   replication) — poll up to `{{timeouts.events.poll_for}}` seconds
   (default 240), checking every `{{timeouts.events.poll_interval}}`
   seconds (default 2), per the same poll convention as elsewhere (though
   here there's no error-state page to bail out on early — rely on the
   timeout).
3. If any expected (version, endpoint) combination never appears, stop
   and report exactly which one(s) are missing.

### 7c — Remote fixity check via SSH

1. **Propose the command** (per `SKILL.md`'s "Non-browser steps"
   convention), substituting the bare druid and `latest_version`:
   ```
   ssh {{preservation_catalog_username}}@{{preservation_catalog_host}} \
     'cd preservation_catalog/current && RAILS_ENV=production bin/fixity_check_replicated_moabs --druid_list <bare druid> --endpoints_to_audit gcp_s3_south_1'
   ```
2. Get human-copilot approval (or run directly if pre-authorized), using
   the SSH ControlMaster session — confirm it covers
   `{{preservation_catalog_host}}` specifically before running this if
   that wasn't already checked at the top of the scenario.
3. **Verify: the command exits 0**, **and its stdout matches the pattern
   `fixity check passed - validate_checksums - <bare druid>...actual
   version: <latest_version>`.** Report the full stdout/stderr as
   evidence regardless of outcome.

## Witness pass (strongly recommended for this scenario specifically)

Per `SKILL.md`'s "Witness pass" section: given this scenario is the
closest thing to an end-to-end preservation-correctness check in the
whole set, have a second, independent review — either the human copilot
or a separate agent session — confirm that each checkpoint's *recorded
evidence* (not just the claimed pass/fail) actually supports the claim,
especially Step 6 (file swap correctness) and Step 7 (replication +
fixity). This scenario is exactly the kind of run where declaring success
without solid evidence would be the most costly mistake to make quietly.

## Cleanup (matches original spec's `after` block)

Regardless of outcome:
1. Delete any locally downloaded files (CSV, YAML) still present.
2. Delete the local directory created in Step 4.
3. **Propose and run** (best-effort — a failure here is not a scenario
   failure, just note it):
   ```
   ssh {{preassembly_username}}@{{preassembly_host}} rm -rf {{preassembly_bundle_directory}}/<bare druid>
   ```

## Done

This is the last scenario in the `sample_accession` set. A clean run
through all five scenario files (`apo-registration.md`,
`collection-registration.md`, `register-objects.md`,
`preassembly-accessioning.md`, `preassembly-reaccessioning.md`) is the
agent-driven equivalent of `bin/rspec --tag sample_accession`.
