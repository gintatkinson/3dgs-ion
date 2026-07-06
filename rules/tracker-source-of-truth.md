<!-- Copyright Gint Atkinson, gint.atkinson@gmail.com -->

# Rule: Tracker as Source of Truth

**ALWAYS enforce:** Use the issue tracker's CLI commands resolved from configuration to query the tracker for authoritative issue state. Never trust local files or checklist documentation alone.

## Hard constraints

- Before working on a feature, verify its status using the tracker's configured issue view command.
- Before creating issues, check for duplicates using the tracker's configured issue query command.
- Use the tracker's configured issue lifecycle commands (create, close, edit) for all issue operations.
- When referencing Issue IDs in markdown, use the live tracker Issue number — never hard-code or assume numbers.
- When constructing links to files in issue descriptions, dynamically determine the remote URL from the repository settings (e.g., `meta.upstream_repository`). Never use relative paths like `../features/...` in issue bodies.

## What local files are for

- Local markdown files (`docs/epics/`, `docs/features/`, etc.) are the specification source, but their checklist states may be stale.
- Always sync local state with the tracker state using the backlog reconciliation script (e.g., `reconcile_backlog.py`).

## Why

Local files can be contaminated, outdated, or contain broken links. The configured issue tracker is the canonical state store. Querying it directly prevents agents from working on closed issues, creating duplicates, or referencing stale data.
