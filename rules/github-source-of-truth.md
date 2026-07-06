<!-- Copyright Gint Atkinson, gint.atkinson@gmail.com -->

# Rule: Issue Tracker as Canonical Source of Truth

**ALWAYS enforce:** The configured issue tracker is the canonical source of truth for all work items. Local files are derived artifacts and may be stale.

## Hard constraints

- Before starting any task, verify the issue's current status using the configured issue tracker query command.
- Before creating new issues, check for duplicates using the configured issue tracker query command.
- All issue lifecycle operations (create, close, edit, transition) MUST use the tracker's issue management commands — never modify local files as the primary operation.
- Every local specification file MUST include the tracker issue ID in its YAML frontmatter (`issue_id: <int>`).
- When referencing issues in markdown, use the live tracker issue number — never hard-code or assume numbers.
- When constructing links to files in issue descriptions, use absolute remote URLs resolved from repository configuration, never relative paths like `../features/...`.

## What local files are for

- Local markdown files (`docs/epics/`, `docs/features/`, etc.) are human-readable specification sources and working copies.
- Their checklist and status metadata may be stale. Always sync local state with the tracker using the configured reconciliation workflow.
- The authoritative "done" state lives in the issue tracker, not in local frontmatter.

## Relationship to other rules

- See `rules/platform-independence.md` for specification content rules (WHAT vs HOW).
- See `.pipeline/constitution.md` § *Unique Backlog Identifiers* for the issue ID frontmatter mandate.
- See `.pipeline/constitution.md` § *Agent Behavior* for commit and branch naming conventions referencing issue numbers.

## Why

Local files can be contaminated by uncommitted edits, outdated checklists, or broken cross-references. The configured issue tracker is the single source of truth for issue status, assignment, and lifecycle. Querying it directly prevents agents from working on closed issues, creating duplicates, or using stale metadata.
