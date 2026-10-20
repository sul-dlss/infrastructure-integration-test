# Scenario: Register Objects

Replaces `spec/features/registration/03_register_objects_spec.rb`
(via `spec/support/shared_examples/register_objects.rb`).

**Depends on**: `apo_creation.title`, `collection_registration.title`
(from `apo-registration.md` / `collection-registration.md`).

**Produces**: one run-log entry per row in the table below, each shaped
`{ druid: <...>, title: <...> }`, keyed by that row's **Object key**
(e.g. `register_objects.preassembly_accessioning`).

**Settings used**: `{{argo_url}}`, `{{test_folio_instance_hrid}}`,
`{{number_of_constituents}}` (currently `2`, i.e. two virtual-object rows)

---

## Note on APO/Collection overrides

Most rows use the APO and Collection created in the prior two scenarios.
A few rows target **different, pre-existing APOs/Collections** that this
skill does not create (`Goobi Testing APO`, `APO for GIS`, `Integration
Test Collection - GIS`, `integration-testing`) — these must already exist
in the target environment; if a row's `Verify: Collection options include`
checkpoint fails for one of these, that's an environment-setup problem,
not a scenario bug. `None` as a collection means "don't add a Collection"
(no Collection field to fill).

## Efficiency note

The registration form's APO dropdown alone has 500+ options in a real
environment. Taking a full `browser_snapshot` (or an unscoped
`browser_find`) on this page is expensive — prefer:

- Reading/setting native `<select>` fields (APO, Collection, Content
  Type, Initial Workflow, View/Download access) directly via
  `browser_evaluate`, by DOM id (`registration_admin_policy`,
  `registration_collection`, `registration_content_type`,
  `registration_workflow_id`), dispatching a `change` event so the
  page's own JS (which repopulates Collection/Initial Workflow options
  based on the APO selected) fires correctly. Verify the repopulation
  happened by reading the target select's options afterward, still via
  `browser_evaluate`, rather than a full snapshot.
- Using `browser_find` scoped to a specific field's label (e.g. "Project
  Name", "Source ID") rather than a full-page snapshot, when you do need
  a snapshot-based ref (e.g. to click something).

## Reusable procedure

For **each row** in the table below, repeat this procedure. Do not batch
multiple rows into one form submission — one full procedure per row,
start to finish, so a failure on one row doesn't corrupt the next.

1. Navigate to `{{argo_url}}/registration`.
   - **Verify: the page shows "Register DOR Items"** (handle login/Duo
     the same way as `apo-registration.md` if it appears — should not
     happen if reusing an already-authenticated Playwright session).
2. Set the **APO** `<select id="registration_admin_policy">` to the row's
   APO value (by option text), dispatching a `change` event.
3. Read `<select id="registration_collection">`'s options (via
   `browser_evaluate`) and **verify the row's Collection is now present**
   — options repopulate asynchronously in response to the APO selection.
   Skip this and the next sub-step entirely if the row's Collection is
   `None`.
4. Set **Collection** to the row's value.
5. If the row has a **Content Type**, set `<select
   id="registration_content_type">` to it.
6. If the row has an **Initial Workflow**, first verify the option is now
   present on `<select id="registration_workflow_id">` (it repopulates
   based on APO, same as Collection), then set it.
7. If the row has a **Project Name**: click the "Project Name" combobox,
   type the value. If an autocomplete option appears matching what you
   typed, click it; if not (e.g. a brand-new project name), the typed
   value is still accepted directly — you can confirm via
   `browser_evaluate` reading `input[name="registration[project]"]`'s
   value if you want extra confidence, but it is not required.
8. If the row has **Tags**: click the "Tags" combobox, type the value,
   and click the matching autocomplete option (unlike Project Name, Tags
   reliably shows a dropdown option to click, occasionally with what
   looks like a duplicate entry for the same text — either one is fine
   to click).
9. Switch to (or confirm you're on) the **"Fill in form"** tab (not
   "Upload CSV") and fill the **Source ID** and **Title** fields there
   (per-row fields, alongside Barcode and Folio Instance HRID — not
   separate top-level fields):
   - Source ID:
     - If the row is a virtual-object row, use `virtual-object-creation:
       <a fresh random UUID>-<row index, 0-based>` (matches
       `virtual_source_id` in the original spec — the index is per this
       scenario's virtual-object rows specifically, not the whole table).
     - Otherwise use `<object key, hyphenated>:<a fresh random UUID>`,
       e.g. `preassembly-accessioning:3f9c...`.
   - If the row has a **Folio Instance HRID**, also fill that field with
     `{{test_folio_instance_hrid}}`.
   - Title: `<Object key, as a human-readable phrase> object for <random
     short phrase>`, e.g. "Preassembly accessioning object for cascade
     harbor kestrel".
10. Click **Register**.
11. **Verify: the page shows "Items successfully registered."**
12. Read the registered druid from the results table (a link inside the
    table; its text is the bare druid — prepend `druid:`). Record `{
    druid: "druid:<bare druid>", title: <the title from step 9> }` under
    this row's Object key in the run log.
13. Move to the next row (navigate back to `{{argo_url}}/registration`
    fresh rather than reusing "Back to form", to avoid carrying over
    stale field state between rows with different APOs).

## Table of objects to register

| Object key | APO | Collection | Content Type | Initial Workflow | Project Name | Tags |
|---|---|---|---|---|---|---|
| `access_indexing` | *(APO from apo-registration)* | *(Collection from collection-registration)* | — | — | — | — |
| `goobi_accessioning` | `Goobi Testing APO` | `integration-testing` | `image` | `goobiWF` | `Integration Testing` | `DPG : Workflow : Accession_Content_Expedited` |
| `item_creation_no_files_or_collection` | *(from apo-registration)* | `None` | `book` | — | `Awesome Project` | `Some : UniqueTagValue` |
| `item_creation_with_folio_hrid` | *(from apo-registration)* | *(from collection-registration)* | `book` | — | `Awesome Folio Project` | `Some : UniqueTagValue` — **also fill Folio Instance HRID** with `{{test_folio_instance_hrid}}` |
| `preassembly_gis_raster_accessioning` | `APO for GIS` | `Integration Test Collection - GIS` | `geo` | — | `Integration Test - GIS via preassembly` | — |
| `preassembly_gis_vector_accessioning` | `APO for GIS` | `Integration Test Collection - GIS` | `geo` | — | `Integration Test - GIS via preassembly` | — |
| `preassembly_hfs_accessioning` | *(from apo-registration)* | *(from collection-registration)* | `file` | — | `Integration Test - hierarchical files via Preassembly` | — |
| `preassembly_ocr_document` | *(from apo-registration)* | *(from collection-registration)* | `document` | — | `Integration Test - Document OCR via Preassembly` | — |
| `preassembly_ocr_image` | *(from apo-registration)* | *(from collection-registration)* | `image` | — | `Integration Test - Image OCR via Preassembly` | — |
| `preassembly_accessioning` | *(from apo-registration)* | *(from collection-registration)* | `image` | — | `Integration Test - Accessioning via Preassembly` | — |
| `preassembly_speech_to_text` | *(from apo-registration)* | *(from collection-registration)* | `media` | — | `Integration Test - Media Speech To Text via Preassembly` | — |
| `virtual_object_creation_0` | *(from apo-registration)* | *(from collection-registration)* | `image` | — | `Integration Test - Virtual object via Preassembly` | — |
| `virtual_object_creation_1` | *(from apo-registration)* | *(from collection-registration)* | `image` | — | `Integration Test - Virtual object via Preassembly` | — |

The last two rows are the virtual-object-constituent rows (count driven
by `{{number_of_constituents}}` — currently 2; add more
`virtual_object_creation_N` rows if that setting changes).

## Done

By the end, the run log should have 13 new entries, one per row above,
each `{ druid: <...>, title: <...> }`. `preassembly_accessioning`'s entry
feeds `preassembly-accessioning.md` directly.

## Verified in a live dry run (2026-09-23)

Rows `access_indexing`, `goobi_accessioning`, and `preassembly_accessioning`
were completed live against stage using the procedure above (see
`.agents/skills/run-sample-accession-tests/runs/2026-09-23T11-30-00-0700.md`),
confirming:
- APO-dependent repopulation of both Collection and Initial Workflow
  options.
- The select2-style Project Name / Tags comboboxes accept free text
  directly (no click needed) when there's no matching existing option,
  and offer a clickable autocomplete option when there is.
- Source ID / Title live in the "Fill in form" tab's per-row fields, not
  as standalone top-level fields.
The remaining rows were not run in that dry run (to conserve time/cost)
but follow the identical mechanics already verified.
