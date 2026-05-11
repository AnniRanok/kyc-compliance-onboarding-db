# KYC & AML Compliance Onboarding System

## System Design Document

**Architecture Style:** Database-centric OLTP compliance system
**Primary Domain:** AML / KYC / Regulatory Onboarding
**Database:** Microsoft SQL Server 2022
**Design Focus:** Regulatory correctness, auditability, workflow enforcement
**Implementation:** T-SQL, SQL Server 2022
**Schema:** 12 tables, 14 FK constraints, 3NF normalized

---

## 1. Problem Statement

Financial institutions operating in regulated jurisdictions must perform KYC (Know Your Customer) and AML (Anti-Money Laundering) checks before onboarding corporate clients.

This includes:

- Verifying legal entity identity across jurisdictions (DACH, BENELUX)
- Identifying Ultimate Beneficial Owners (UBOs) with ≥ 25% ownership threshold per EU AML Directive (AMLD)
- Ensuring document completeness based on jurisdiction-specific compliance rules
- Maintaining full auditability of onboarding decisions

### Core Challenge

Design a data-first compliance system that enforces regulatory rules at the database layer, ensuring correctness, auditability, and workflow consistency without relying on application logic.

---

## 2. System Goals

### Functional Requirements

- Register companies across multiple EU jurisdictions
- Model ownership structures including indirect and temporal ownership
- Identify and report UBOs (≥ 25% ownership threshold)
- Enforce document requirements based on jurisdiction + legal form
- Manage onboarding lifecycle:

```text
Open → InReview → Approved / Rejected → Closed
```

- Track external verification checks (registry, credit bureau, etc.)

### Non-Functional Requirements

- Strong data consistency (ACID compliance required)
- Full auditability of onboarding actions
- Extensible schema for new jurisdictions and legal forms
- Role-based access control (RBAC)
- Support analytical reporting workloads

---

## 3. System Architecture Overview

This is an OLTP-first compliance system with embedded workflow enforcement and analytical reporting layers.
The architecture prioritizes consistency and auditability over horizontal scalability, reflecting the requirements of regulated financial onboarding systems.

### High-Level Components

```text
[ Onboarding System / Analysts ]
             ↓
     [ SQL Server DB Layer ]
             ↓
 ┌─────────────────────────────┐
 │  Master Data Layer          │
 │  - Company / Country        │
 │  - Legal Forms              │
 ├─────────────────────────────┤
 │  Ownership Layer            │
 │  - UBO Graph                │
 │  - Temporal Ownership       │
 ├─────────────────────────────┤
 │  Compliance Layer           │
 │  - Documents                │
 │  - Requirements Engine      │
 ├─────────────────────────────┤
 │  Workflow Layer             │
 │  - Onboarding Cases         │
 │  - External Verification    │
 └─────────────────────────────┘
```

---

## 4. Technology Choice Rationale

SQL Server was selected due to:

- Strong ACID transactional guarantees
- Mature procedural SQL support (T-SQL)
- Native RBAC and security capabilities
- Reliable backup and recovery tooling
- Strong support for regulated enterprise workloads

---

## 5. Data Model Design

### 5.1 Master Data Layer

**Tables**

| Table          | Description                              |
|----------------|------------------------------------------|
| Country        | Jurisdiction reference data              |
| LegalForm      | Legal entity types per jurisdiction      |
| Company        | Core legal entity records                |
| CompanyAddress | Physical and registered address data     |

Represents jurisdictional and legal entity structure.

---

### 5.2 Ownership Layer (Core Complexity)

**Tables**

| Table     | Description                              |
|-----------|------------------------------------------|
| UBO       | Ultimate Beneficial Owner identity data  |
| Ownership | Company ↔ UBO relationship mapping       |

**Key Design Decisions**

- Many-to-many ownership relationship modeling
- Temporal validity (ValidFrom, ValidTo)
- Historical compliance reconstruction support
- Explicit support for direct and indirect ownership chains

---

### 5.3 Compliance Document Layer

**Tables**

| Table               | Description                                  |
|---------------------|----------------------------------------------|
| DocumentType        | Catalogue of accepted document types         |
| RequiredDocuments   | Jurisdiction + legal form requirement rules  |
| SubmittedDocuments  | Client-submitted document records            |

**Key Design Decisions**

- Configuration-driven compliance rules
- No schema changes required for jurisdiction updates
- Dynamic support for evolving regulatory requirements

---

### 5.4 Onboarding Workflow Layer

**Tables**

| Table                    | Description                               |
|--------------------------|-------------------------------------------|
| OnboardingCase           | Lifecycle state machine per company       |
| ExternalVerificationCheck| External check records per case           |
| ExternalSource           | Registry and bureau source reference data |

**Key Design Decisions**

- Encapsulated onboarding lifecycle state machine
- Workflow auditability
- External verification traceability

---

## 6. Business Logic Enforcement

### 6.1 Stored Procedure Layer

#### `usp_SubmitDocument`

Handles:

- Validation of onboarding case state
- Duplicate document prevention
- UBO eligibility validation (≥ 25%)
- Auto-transition to InReview when requirements are satisfied

#### `usp_UpdateCaseStatus`

Enforces:

- Valid state transitions only
- Business rule validation
- Consistent lifecycle progression

---

### 6.2 Trigger-Based Automation

#### `trg_OnboardingCase_StatusChange`

Triggered on onboarding case status updates.

**Responsibilities**

- Propagates document status changes
- Creates audit entries in verification tables
- Preserves transactional consistency for downstream compliance actions

> ⚠️ **Design Choice**
> Triggers are used only for transactional side effects, not for core business logic enforcement. This minimizes hidden logic while preserving consistency guarantees.

---

### 6.3 Cursor-Based Batch Processing

#### `cursor_cases`

Used for:

- Batch evaluation of Open / InReview cases
- Document gap analysis
- Automated onboarding progression recommendations

> ⚠️ **Trade-off**
> Cursor-based processing was selected for procedural clarity in iterative compliance evaluation workflows, despite lower scalability compared to set-based processing.

---

## 7. Analytical Layer

### Views

| View                       | Purpose                              |
|----------------------------|--------------------------------------|
| vw_OnboardingOverview      | Operational onboarding dashboard     |
| vw_DocumentCompletionStats | Compliance KPI monitoring            |
| vw_CompanyWithUBO          | Ownership transparency analysis      |

### Design Principle

Operational OLTP workflows are separated from analytical consumption layers to reduce coupling between transactional and reporting workloads.

---

## 8. Access Control Model

Role-based access control (RBAC) is enforced directly at the database layer.

| Role                 | Permissions                              |
|----------------------|------------------------------------------|
| OnboardingReaderRole | SELECT only                              |
| OnboardingWriterRole | SELECT, INSERT, UPDATE, EXECUTE          |

> **Security Principle:** Least-privilege access enforcement for regulated data environments.

---

## 9. Key Design Decisions & Trade-offs

### 9.1 Database-First Enforcement vs Application-Layer Logic

| | |
|---|---|
| **Advantages** | Centralized rule enforcement, client-independent data integrity, strong consistency guarantees |
| **Trade-offs** | Reduced flexibility in distributed architectures, higher coupling to relational database platform |

---

### 9.2 Temporal Ownership Modeling

| | |
|---|---|
| **Advantages** | Historical compliance reconstruction, regulatory audit support, point-in-time ownership analysis |
| **Trade-offs** | Increased query complexity, more complex indexing strategies |

---

### 9.3 Configuration-Driven Document Rules

| | |
|---|---|
| **Advantages** | Flexible jurisdiction support, reduced schema migration frequency, easier regulatory adaptation |
| **Trade-offs** | More complex validation layer, increased configuration management requirements |

---

### 9.4 Trigger-Based Side Effects

| | |
|---|---|
| **Advantages** | Guaranteed transactional consistency, automatic downstream synchronization |
| **Trade-offs** | Hidden execution paths, reduced observability without documentation |

---

### 9.5 Cursor-Based Batch Processing

| | |
|---|---|
| **Advantages** | Procedural clarity, easier iterative evaluation workflows |
| **Trade-offs** | Poor scalability on large datasets, lower performance compared to set-based approaches |

---

## 10. System Constraints

- Single-region SQL Server deployment
- OLTP-first workload prioritization
- Moderate onboarding throughput assumptions
- Strong consistency preferred over eventual consistency
- Database-centric validation model

---

## 11. Scalability Considerations

The current architecture is optimized for correctness and operational clarity rather than internet-scale throughput.

### Potential Scaling Strategies

- Partition `OnboardingCase` by jurisdiction
- Optimize indexing on:
  - `CompanyName`
  - `CaseStatus`
  - Ownership percentage columns
- Archive completed onboarding cases to cold storage
- Refactor cursor workflows into set-based or distributed processing pipelines

---

## 12. Reliability & Consistency

- Fully ACID-compliant transactional model
- Referential integrity enforced via foreign keys
- Workflow transitions validated at the database layer
- Audit trail generation via triggers and verification tables

### Failure Handling

- Transaction rollback on procedure failure
- Idempotent document submission logic
- Audit preservation during partial workflow failures

---

## 13. Security Model

- RBAC enforced at the database layer
- Separation of read and write responsibilities
- Controlled access to sensitive UBO identity information

---

## 14. Future Extensions

- AML risk scoring engine
- Sanctions and PEP screening integration
- Event-driven onboarding workflows
- API integration for onboarding platforms
- Immutable append-only audit logging architecture

---

## 15. Summary

This system demonstrates a database-centric compliance architecture designed for regulated financial environments.

### Key Strengths

- Strong relational modeling (3NF + temporal data)
- Embedded workflow enforcement at the database layer
- AML/KYC domain correctness aligned with EU AMLD
- Separation of operational and analytical workloads

### Core Architectural Principle

> *"Data integrity and regulatory correctness are enforced at the database layer rather than delegated to external application services."*
