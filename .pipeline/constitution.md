---
title: "Project Constitution — Functional Layer"
project: "Digital Systems Engineering Pipeline"
tier: functional
created: "2026-06-29"
last_updated: "2026-06-29"
---

# Project Constitution: Digital Systems Engineering Pipeline

> This document governs specification generation and is platform-independent and protocol-agnostic.
> All agents MUST read this file before beginning any pipeline execution.
> For platform-specific rules, see `.pipeline/profiles/<platform>.md`.

## Domain Rules

### Specification Sources
- Primary sources are normative technical specifications and standards documents.
- Structural schemas and interface definitions are the authoritative machine-readable models.
- When the normative text and the schema conflict, the schema is authoritative for structural completeness; the normative text is authoritative for behavioral semantics.

### Schema Compliance
- Every data model constraint in the schema MUST be captured in at least one Feature's acceptance criteria. Zero loss tolerance.
- Constraints include: data type, validation ranges, regex patterns, default values, mandatory fields, conditional expressions, minimum/maximum elements, and structural relationship references.
- If a schema node has no explicit constraint, document its type and note "no additional constraints specified in schema."

### Data Model Integrity
- Every schema definition, model node, data object, property, variant, custom type, and extension defined in the input schemas MUST map to at least one Feature.
- Cross-module or external schema references must be explicitly documented with source and target module names.
- Circular dependencies must be flagged and escalated — do not silently drop them.

### Model Metamodel & Profile Mapping Standard
- Namespace & Boundary Constructs: Top-level schema modules, packages, namespaces, or tag groups map to a logical Component or Package.
- Structural Entity & Type Definitions: Message schemas, container types, lists, structural groupings, and objects map to a logical Class.
- Data Properties & Leaf Nodes: Individual fields, properties, elements, attributes, or variables map to a logical Property (or owned attribute of a class) with appropriate visibility, type, and multiplicity.
- Interfaces & Operations: Services, RPC methods, actions, or operational paths map to a logical Operation defined on the target classifier.
- Rules & Validation Logic: Any syntax constraints, range checks, pattern validations, conditional dependencies, or length constraints map to a logical Constraint.

### Universal Model Consistency Rules
- Dynamic-to-Static Alignment: No class, component, interface, attribute, operation, signal, or message may be used in dynamic behavior specifications unless it is explicitly defined in the structural models.
- Every lifeline in a sequence diagram MUST represent an instance of a defined logical Class or Component.
- Every message (synchronous, asynchronous, or return) in a sequence diagram must map to an active Operation or Signal defined on the target classifier's interface/class definition.
- Every trigger, event, or action on a state machine transition must be defined as an Operation or Signal in the class metamodel.
- Auto-verification Failure: Any diagram or spec that references undefined operations, classes, or signals will violate the quality gates and halt the pipeline.

### Traceability
- Every Epic MUST reference the specification section(s) it covers.
- Every Feature MUST include a "Source References" section with verbatim specification clause numbers and schema paths.
- Every User Story MUST link to the Features it validates.
- Every Use Case MUST link to the User Stories and Features it realizes.

### Standard & Platform Parameter Isolation
1. **Tier 1: Functional Layer (Abstract Specification)**: Epics, Features, User Stories, Use Cases, and Logical UI specifications. Must be platform-independent and standard-agnostic. No framework keywords, specific standards designations, or hardcoded visual values allowed.
2. **Tier 2: Runtime Configuration Parameters (Dynamic Context)**: Design tokens, dynamic mapping configurations, translation files. Single source of truth for standard-specific definitions and visual attributes.
3. **Tier 3: Platform Implementation Profiles (Technical Execution)**: `.pipeline/profiles/<platform>.md` and codebase implementations. Govern build mechanics, performance patterns, and dependencies.

### Unique Backlog Identifiers
- All local specification files MUST include a permanent unique identifier (`issue_id: <int>`) in their YAML frontmatter, mapped directly to their remote issue number.
- Matching by title normalization is prohibited as a primary selector.

## Specification Standards

### Epic Granularity
- One Epic per major functional domain or protocol module.
- An Epic should contain 3-15 Features. Fewer than 3 means the Epic is too narrow; more than 15 means it should be split.
- Epic titles use the format: `[Module/Domain]: [Functional Area]`.

### Feature Granularity
- A Feature represents a single, independently testable functional capability.
- A Feature should have 3-10 acceptance criteria. Fewer means it lacks specificity; more than 10 means it should be split.
- Features MUST be platform-independent and standard-agnostic.
- Feature titles use the format: `[Verb] [Object] [Qualifier]`.

### BDD Scenario Format
- All acceptance criteria MUST use Given-When-Then format.
- Negative scenarios (error cases, boundary violations) are MANDATORY for every constraint.

### User Story Format
- User Stories follow: `As a [Actor], I want to [Action], so that [Outcome]`.
- Each User Story MUST have at least one BDD scenario (Given-When-Then).

### Use Case Formality
- Use Cases follow formal structure: Actor, Preconditions, Main Success Scenario (numbered steps), Alternate Flows, Postconditions.
- The Realization Matrix maps each Use Case to its constituent User Stories and Features.

### Labeling Taxonomy
- Exactly four label types: `epic`, `feature`, `user-story`, `use-case`, or as defined by the issue tracker configuration.
- Labels are bootstrapped via the configured label bootstrap command to ensure idempotency.

## Agent Behavior

### Commit Format
- Specification commits: `docs: [action] [artifact type] -- [brief description]`
- Implementation commits: `feat:`, `fix:`, `test:`, `refactor:`, `chore:` per Conventional Commits.

### Branch Strategy
- Specification work: directly on the default branch or a single `spec/<module>` branch if the change is large.
- Implementation work: `feat/<issue-number>-<short-description>` branches.

### Documentation Standards
- All generated markdown files include YAML frontmatter.
- All generated markdown files include a "Source References" section at the bottom.
- No orphan documents — every file must be linked from at least one tracker issue.

### Idempotency
- Re-running any pipeline skill MUST NOT create duplicate issues or documents.

### Error Handling
- If a validation gate fails, HALT immediately. Do not proceed to the next phase.
- If you suspect the failure is due to a pipeline tooling bug or schema limitation, report it as an issue to the upstream repository.

### Strict Planning Mode Gate (Insurmountable Approval Gate)
- Under NO circumstances may the agent invoke any file-writing, file-modifying, or command-running tools that alter the codebase/repository files unless the user has explicitly typed "Proceed", "Approved", or "Approve plan" in the conversation history of the current turn sequence.
- If a plan is written, the agent MUST immediately terminate its turn and stop calling tools to wait for approval.

## Universal Quality Gates

### Specification Validation Gates
- Post schema extraction: Every schema node maps to at least one Feature. Coverage = 100%.
- Post User Stories: Every User Story links to at least one Feature.
- Post Use Cases: Every Use Case links to at least one User Story and one Feature.
- Post Reconciliation: All local markdown checklist states match tracker issue states.

### Model Coverage Verification
- Verify model coverage scripts MUST pass with exit code 0 before declaring specification complete.
- Coverage is binary: 100% or fail.

### Cross-Reference Integrity
- No broken issue links (all `#N` references must resolve to existing tracker issues).
- No orphan Features (every Feature belongs to exactly one Epic).
- No orphan User Stories (every Story links to at least one Feature).

### Human Approval (The Grill)
- Required before implementation begins.
- NOT required for specification generation.

### Downstream Conformance Gates
- Prior to integrating any downstream application implementation, the project MUST be bootstrapped and verified.
- The downstream project must be initialized using the configured bootstrap script.
- Baseline conformance must be verified using the configured verification script, which asserts that all baseline files are present, validates type compatibility, and compiles/tests the project with a clean exit code.
