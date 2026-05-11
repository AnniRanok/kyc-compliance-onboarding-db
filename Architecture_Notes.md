# Architecture Notes – KYC Compliance Database

Design decisions, trade-offs and reasoning behind the schema structure.

---

## Domain Decomposition

The schema is intentionally split into four bounded domains to reflect real-world compliance system concerns:

**Master Data** handles static reference data — countries, legal forms, and company registration. This separation allows the compliance logic to remain independent of jurisdictional changes.

**Ownership** models the beneficial ownership graph. The decision to use a dedicated `Ownership` bridge table (rather than embedding ownership on `Company`) enables:
- Many-to-many ownership across entities
- Historical tracking via `ValidFrom`/`ValidTo`
- Clean separation of identity (`UBO`) from relationship (`Ownership`)

**Documents** implements a configuration-driven compliance layer. `RequiredDocuments` acts as a rules table — linking legal forms to document types — so that adding a new jurisdiction requires only data changes, not schema changes.

**Onboarding** captures the workflow state. Isolating case management from master data means the same company can be re-onboarded without corrupting historical records.

---

## Key Trade-offs

### Trigger vs. Application-level automation
Trigger-based automation (`trg_OnboardingCase_StatusChange`) was chosen for document status propagation and audit trail creation because:
- These are transactional side effects that must always fire, regardless of which application or user initiates the status change
- Centralizing this logic at the database layer eliminates the risk of inconsistency across multiple client applications

Trade-off: triggers add implicit behavior that can be surprising to developers unfamiliar with the schema. Mitigated by clear naming conventions and inline comments.

### Stored procedures for workflow enforcement
Status transitions are validated inside `usp_UpdateCaseStatus` rather than relying on CHECK constraints alone. This allows:
- Multi-step validation (not expressible in a single CHECK)
- Meaningful error messages via OUTPUT parameters
- Reuse of scalar functions within the validation chain

### Configuration-driven document requirements
`RequiredDocuments` stores which document types are mandatory per legal form. This avoids hard-coding compliance rules in application logic and supports:
- Adding new countries or legal forms without schema changes
- Different requirement levels (Standard vs. Enhanced Due Diligence)
- UBO-specific document requirements via `AppliesToUBO` flag

### Temporal ownership modeling
`Ownership.ValidFrom` / `ValidTo` supports historical queries such as:
- "Who owned this company on a given date?"
- "Which UBOs were reportable at the time of onboarding?"

This is critical for regulatory audit purposes where point-in-time accuracy matters.

---

## Scalability Considerations

- New jurisdictions: add rows to `Country`, `LegalForm`, `RequiredDocuments` — no schema changes required
- New document types: add to `DocumentType` catalog — immediately available for requirement configuration
- Additional external sources: add to `ExternalSource` — referenced by `ExternalVerificationCheck`
- Extended UBO attributes (e.g. PEP status, sanctions flags): add columns to `UBO` without breaking existing foreign key relationships

---

## What This Schema Does Not Cover

- **Risk scoring** — a natural extension would be a `RiskAssessment` table linked to `OnboardingCase`
- **Sanctions screening** — `ExternalVerificationCheck` provides the hook but a dedicated sanctions integration layer would be needed
- **Multi-currency revenue** — `AnnualRevenue` is stored as a single decimal; a production system would require currency codes
- **Audit logging** — a separate audit log table (tracking all INSERT/UPDATE/DELETE with timestamps and user context) would be standard in a production compliance system
