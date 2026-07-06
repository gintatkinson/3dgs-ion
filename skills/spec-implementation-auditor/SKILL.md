<!-- Copyright Gint Atkinson, gint.atkinson@gmail.com -->

---
name: spec-implementation-auditor
description: "Audits the codebase against generated specifications (Epics, Features, UML diagrams) to detect missing, partial, or incorrectly implemented features. Use when a feature was specified but never built, built partially, or built incorrectly — bridging the gap between spec-orchestrator output and feature-driven-implementation backlog."
compatibility: "Requires git, configured issue tracker, and an existing spec directory under docs/ (epics/, features/, user-stories/, use-cases/)."
metadata:
  risk: low
  source: custom
  version: "1.0"
---

# Specification-to-Code Implementation Auditor

Use this skill when a feature, user story, or use case exists in the specification documents (`docs/`) but is missing, partially implemented, or incorrectly implemented in the codebase. This is NOT for runtime bugs (use `debug-protocol`) and NOT for new un-spec'd features (add to backlog and use `feature-driven-implementation`).

This skill reconciles what was specified against what exists in source code, files targeted gap issues, and optionally dispatches implementation for confirmed gaps.

## Step 0 — Gate Check: Is this audit necessary?

Before starting, confirm:
- Is there a specification document (Feature, User Story, Use Case) that describes behavior that should exist?
- Does the behavior not exist, exist only partially, or work incorrectly compared to the spec?
- Is this a runtime defect (bug) — if yes, stop and use `debug-protocol` instead.
- Is this entirely new functionality with no spec — if yes, route to backlog + `feature-driven-implementation`.

If this is a spec'd feature with missing/incorrect implementation, proceed to Step 1.

## Step 1 — Specification Inventory Subagent

Dispatch a subagent to: Discover all specification documents in the `docs/` directory tree. Read each document and extract:
- Issue ID and title (from YAML frontmatter or content)
- Acceptance criteria / scenarios / alternate flows
- UML class/sequence/state/use-case diagrams
- Source references (schema spec sections)
- Interface requirements (UI / API / M2M payload shapes)

Return a structured inventory: one entry per spec document with its requirements listed as verifiable claims.

## Step 2 — Codebase Coverage Subagent

Dispatch a subagent to: For each verifiable claim from Step 1, search the codebase for corresponding implementation:
- Check Flutter (`lib/`) and Python (`scripts/`) as applicable.
- Search by semantic keywords, class names, widget names, route paths, API endpoints.
- Check test files for corresponding test coverage.
- Do NOT assume — verify each claim against actual file content.

Return a coverage matrix mapping each spec claim to:
- ✅ Fully implemented (code + tests found)
- ⚠️ Partially implemented (some aspects present, others missing)
- ❌ Missing (no corresponding code found)
- ❓ Ambiguous (code exists but doesn't clearly match the spec)

## Step 3 — Gap Analysis Subagent

Dispatch a subagent to: Analyze the coverage matrix from Step 2 and classify each gap:
- **Missing feature**: Entire spec document has no corresponding implementation.
- **Partial implementation**: Core behavior exists but edge cases, alternate flows, or specified constraints are absent.
- **Implementation drift**: Code exists but behaves differently from the spec (wrong types, missing validation, incorrect UI layout).
- **Test gap**: Feature is implemented but has no automated tests covering the spec's acceptance criteria.

For each gap, estimate: (1) which source files would need to change, (2) whether this is a new feature issue or a fix to an existing one.

Return a prioritized gap report.

## Step 4 — Issue Filing Subagent

Dispatch a subagent to: For each gap identified in Step 3, file a GitHub issue:

- **Missing features**: File as a `feature` issue with label `feature`. Include the full spec document reference (URL to the doc file), acceptance criteria copied from the spec, and links to related specs.
- **Partial implementations / implementation drift**: File as a `bug` issue with label `bug`. Include the expected behavior from the spec, observed behavior from the codebase, and file:line references.
- **Test gaps**: File as a `chore` issue with label `chore`. Include which spec scenarios lack test coverage and which test files need creation/update.

Every issue must:
- Include an absolute URL to the source spec document (via `meta.upstream_repository`)
- Include `audited_by: spec-implementation-auditor` in the body
- Link to related issues if the gap spans multiple specs

Return the list of created issue URLs.

## Step 5 — Implementation Dispatch (Optional)

If configured to do so, the coordinator may dispatch the `feature-driven-implementation` skill for each new `feature` issue, or the `debug-protocol` skill for each new `bug` issue.

This step is OPTIONAL and must be explicitly authorized by the human per-issue or globally.

## Step 6 — Report Subagent

Dispatch a subagent to: Generate a summary report containing:
- Total spec documents audited
- Coverage percentages (fully / partially / missing / ambiguous)
- Issues filed (count and URLs)
- Recommended next actions

Save the report to `docs/audits/spec-coverage-<YYYY-MM-DD>.md`.

## Audit Checklist

- [ ] Step 0: Confirmed this is a spec-to-code gap (not a bug, not a new feature)
- [ ] Step 1 subagent: spec inventory complete
- [ ] Step 2 subagent: codebase coverage complete
- [ ] Step 3 subagent: gap analysis complete
- [ ] Step 4 subagent: issues filed
- [ ] Step 5: Implementation dispatch authorized? (Yes/No)
- [ ] Step 6 subagent: report saved to `docs/audits/`
