# AGENTS.md

Instructions for any AI coding/testing agent working in this repository.

## What this repo is

RSpec/Capybara feature specs that do inter-system integration testing of
SDR (Stanford Digital Repository) against the `stage` or `qa`
environments. Most of the suite drives a real browser through Argo,
Preassembly, and related staging apps, and some specs also use SSH/SCP to
stage files or run remote commands.

## Agent-driven testing skill

If you are being asked to run, extend, or reason about the
`:sample_accession` integration-testing path specifically (register an
APO/Collection, register test objects, accession and re-accession an
object via Preassembly), **read
`.agents/skills/run-sample-accession-tests/SKILL.md` first**, before
doing anything else. It defines:

- how state is tracked across a run (a gitignored run log, never the
  `tmp/*.yml` files the RSpec suite uses),
- strict credential-handling rules (never persist, echo, or read
  `.local.yml` secrets yourself),
- required preflight checks (VPN/network reachability, SSH ControlMaster
  session) before starting any scenario,
- one-time environment setup for the browser-automation tool being used
  (must be headed with a persistent profile, not headless/isolated),
- conventions for waiting on async workflows, verifying checkpoints, and
  handling SCP/SSH steps safely,
- a tooling checklist (browser automation, shell/SSH access, file
  read/write, etc.) to confirm before starting a run at all.

The individual scenario files live in
`.agents/skills/run-sample-accession-tests/scenarios/` — one file per
RSpec spec file being replaced, in dependency order (see `SKILL.md`'s
"Scenario ordering" section). Do not improvise scenario steps or skip
its checkpoint/credential conventions.

## If you're working on the RSpec suite instead

See the main `README.md` for setup, environment configuration, and how to
run the existing Capybara-based tests.

## TODO: remaining work on the agent-driven skill

The skill currently covers only the `:sample_accession` quick-run path
(5 scenario files, listed in `SKILL.md`'s "Scenario ordering" section).
That's a deliberate first slice, not the whole suite. Remaining work, in
roughly the order it makes sense to tackle it:

### 1. Finish validating the `sample_accession` scenarios themselves

- [x] **Dry-run `scenarios/preassembly-accessioning.md` live** against
      stage. Done 2026-09-24 (see
      `.agents/skills/run-sample-accession-tests/runs/20260924T193206Z.md`)
      — passed end-to-end (job #5206, `status: success`). Two mismatches
      found and folded back into the scenario file and `SKILL.md`: the
      "Download link appears" completion signal was wrong (that link is
      present from job creation, not just completion — the real signal
      is the "State" cell reading "Job completed"), and the Cleanup
      step's `rm -rf .../<bare druid>` target doesn't exist in this
      environment's actual shared/pre-staged bundle-directory setup.
- [ ] **Dry-run `scenarios/preassembly-reaccessioning.md` live** —
      partially done 2026-09-24 (same run log as above). **Steps 1–6
      passed in full** (safety guard, original file-set checkpoint, CSV
      edit/re-upload, three-SCP staging, job submission/completion, and
      the post-swap file-list/byte-size verification) against the object
      `preassembly-accessioning.md` produced in that same run. **Step 7
      (replication + fixity) did not reach a conclusion** — the
      replication event hadn't appeared in Argo after ~12 minutes of
      polling, exceeding both configured timeouts (`timeouts.workflow`
      300s, `timeouts.events.poll_for` 240s); 7b/7c and the witness pass
      were not attempted as a result. Three more mismatches found and
      folded back (S3 key format was wrong in the scenario's own
      example, the events page needs a full reload each poll rather than
      re-checking a stale DOM, and the shared `manifest.csv` state
      carries over between this scenario and `preassembly-accessioning.md`
      runs against the same bundle directory). **Remaining work**: a
      follow-up run (fresh object, since the safety guard now blocks
      re-running against the same druid past v1) that carries Step 7
      through to an actual pass/fail, with the extended timeout budget
      now documented in the scenario file.
- [ ] **Finish `scenarios/register-objects.md`'s remaining rows.** Only
      3 of the ~13 rows (`access_indexing`, `goobi_accessioning`,
      `preassembly_accessioning`) were actually run live; the rest
      (`item_creation_no_files_or_collection`,
      `item_creation_with_folio_hrid`,
      `preassembly_gis_raster_accessioning`,
      `preassembly_gis_vector_accessioning`,
      `preassembly_hfs_accessioning`, `preassembly_ocr_document`,
      `preassembly_ocr_image`, `preassembly_speech_to_text`, and the
      `virtual_object_creation_N` rows) were deferred to conserve
      time/cost. Lower risk than the two items above (same verified
      form mechanics), but still unverified.
- [ ] Once all of the above pass cleanly end-to-end in one sitting,
      that's parity with `bin/rspec --tag sample_accession` — worth
      explicitly declaring that milestone reached.

### 2. Extend coverage to the rest of the test suite

The full RSpec suite has substantially more specs than the
`sample_accession` slice touches. None of the following currently have
scenario files; each would need the same treatment (read the RSpec spec
+ any shared examples/helpers it uses, draft a scenario file, dry-run it
live, fold back lessons learned):

- [ ] `spec/features/accessioning/access_indexing_spec.rb`
- [ ] `spec/features/accessioning/argo_spreadsheet_update_spec.rb`
- [ ] `spec/features/accessioning/goobi_accessioning_spec.rb` (stage
      only)
- [ ] `spec/features/accessioning/item_creation_no_files_or_collection_spec.rb`
- [ ] `spec/features/accessioning/item_creation_with_folio_hrid_spec.rb`
- [ ] `spec/features/accessioning/sdr_client_deposit_spec.rb`
- [ ] `spec/features/accessioning/virtual_object_creation_spec.rb`
- [ ] `spec/features/preassembly/preassembly_gis_raster_accessioning_spec.rb`
      (stage only)
- [ ] `spec/features/preassembly/preassembly_gis_vector_accessioning_spec.rb`
      (stage only)
- [ ] `spec/features/preassembly/preassembly_hfs_accessioning_spec.rb`
- [ ] `spec/features/preassembly/preassembly_ocr_document_spec.rb`
- [ ] `spec/features/preassembly/preassembly_ocr_image_spec.rb`
- [ ] `spec/features/preassembly/preassembly_speech_to_text_media_spec.rb`
- [ ] `spec/features/sdr/bulk_tags_edit_spec.rb`
- [ ] `spec/features/sdr/etd_creation_spec.rb` (needs ETD
      backdoor credentials — see README's "Set ETD Credentials")
- [ ] `spec/features/sdr/h3_globus_creation_spec.rb` (needs a Globus
      login/account — see README's "Globus" section)
- [ ] `spec/features/sdr/h3_object_creation_spec.rb`
- [ ] `spec/features/sdr/web_archive_accessioning_spec.rb`
- [ ] `spec/features/verify/argo_spreadsheet_update_review_spec.rb`
- [ ] `spec/features/verify/collection_registration_review_spec.rb`
- [ ] `spec/features/verify/goobi_accessioning_review_spec.rb` (stage
      only)
- [ ] `spec/features/verify/sdr_client_deposit_review_spec.rb`

Some of these likely share enough structure with an existing scenario
(e.g. the `verify` specs are read-only checks against objects other
scenarios already created) that a "reusable procedure + table" approach,
like `register-objects.md` uses, may fit better than one file per spec —
worth deciding case-by-case rather than assuming a strict 1:1 mapping.

### 3. Open design questions to revisit once more scenarios exist

- [ ] Decide whether scenario files outside `sample_accession` should
      live under `.agents/skills/run-sample-accession-tests/scenarios/`
      or whether a broader skill (e.g. a new, differently-named skill
      directory) makes more sense once the skill covers more than the
      quick-run path — the current name and structure were chosen
      specifically for the `sample_accession` scope.
- [ ] Revisit `SKILL.md`'s conventions (checkpoint precision, poll
      backoff, witness pass) against whatever new failure modes turn up
      once scenarios exist for specs this skill hasn't touched yet
      (e.g. Globus, ETD, WAS/pywb integrations look meaningfully
      different from the Argo/Preassembly flows validated so far).

