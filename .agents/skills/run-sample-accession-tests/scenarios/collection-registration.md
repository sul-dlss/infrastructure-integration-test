# Scenario: Collection Registration

Replaces `spec/features/registration/02_collection_registration_spec.rb`.

**Depends on**: `apo_creation.druid`, `apo_creation.title` (from
`apo-registration.md`).

**Produces**:
- `collection_registration.druid`, `collection_registration.title`

**Settings used**: `{{argo_url}}`

---

1. Navigate to `{{argo_url}}/view/<apo_creation.druid>`.
   - **Verify: the page shows the APO title recorded by
     `apo-registration.md`** (confirms you're on the right APO, and
     confirms auth carried over).
2. Click **Create Collection**.
   - This opens a **modal dialog** (not a full page navigation) offering
     a choice between "Create a Collection from Title/Abstract" and
     "Create a Collection from Folio." "From Title/Abstract" is the
     default selection — leave it selected for this scenario.
3. Generate a unique collection title (a short random phrase). Record it
   as `collection_registration.title`.
4. Fill in the form:
   - Collection Title → the generated title
   - Collection Abstract → `Created by
     https://github.com/sul-dlss/infrastructure-integration-test`
5. Click **Register Collection**.
6. **Verify: the page shows "Created collection `<druid>`"** in an
   info-style alert box (confirmed format: `Created collection
   druid:xxxxxxxxxx`). Record the druid as `collection_registration.druid`.

## Done

Record in the run log per `SKILL.md`'s run-state convention:

```
collection_registration: { druid: <...>, title: <...> }
```

This feeds `register-objects.md`, which selects this Collection by title
when registering test objects.
