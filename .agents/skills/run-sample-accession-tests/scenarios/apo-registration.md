# Scenario: APO Registration

Replaces `spec/features/registration/01_apo_registration_spec.rb`.

**Depends on**: nothing (first scenario in a run).

**Produces**:
- `apo_creation.druid`, `apo_creation.title`

**Settings used**: `{{argo_url}}`

---

1. Navigate to `{{argo_url}}/apo/new`.
   - **Wait (up to 1 min): the page shows "The following defaults will
     apply to all newly registered objects."**
     - If a login form or Duo prompt appears first, pause and ask the
       human copilot to complete authentication, then continue once the
       expected text appears.
2. Generate a unique APO title, e.g. `Integration Testing APO <random
   short phrase>`. Record it as `apo_creation.title`.
3. Fill in the registration form:
   - Title → the generated APO title
   - View access → `World`
   - Download access → `World`
   - Default use license → `CC Attribution Non-Commercial 3.0 Unported`
   - Default Use and Reproduction statement → `Use statement from APO`
   - Default Copyright statement → `None`
4. Click **Register APO**.
5. **Verify: the page now shows the APO title you entered**, and shows a
   table row for "DRUID" — read that druid value and record it as
   `apo_creation.druid`.
6. **Verify: the page shows "APO `<druid>` created."** (substituting the
   druid just recorded).
7. **Wait (up to 5 min) for: the page shows "v1 Accessioned"** (this is
   the accessioning workflow finishing for the new APO). Use the poll
   convention in `SKILL.md` — refresh and recheck, stop immediately if a
   `.alert-danger` error banner appears instead.

## Done

Record in the run log per `SKILL.md`'s run-state convention:

```
apo_creation: { druid: <...>, title: <...> }
```

This feeds `collection-registration.md` and `register-objects.md`, which
select this APO by title/druid.
