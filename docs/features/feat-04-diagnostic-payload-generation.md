---
title: "Feature 04: Tooling-Side Automatic Diagnostic Payload Generation"
type: "feature"
interface_type: "api"
generation_mode: "subagent"
spec_source: "Project Constitution"
---

# Feature: Tooling-Side Automatic Diagnostic Payload Generation

## Parent Epic
- [ ] #[EpicID] - [Epic Title]([Repository Base URL]/<blob_path>/[Branch Name]/docs/epics/epic-XX-name.md) (semantic linkage justification)

## Description
When linter or reconciler tooling commands fail during pipeline runs, downstream execution agents need a structured, machine-readable reproduction case to file bugs upstream. This feature automates the collection and serialization of diagnostic data and snippets when a tool fails.

## UML Class Diagram
```mermaid
classDiagram
    class ToolingSubsystem {
        +DiagnosticLogger logger [1]
    }
    class DiagnosticLogger {
        +String timestamp [1]
        +String toolName [1]
        +String version [1]
        +String command [1]
        +Integer exitCode [1]
        +String traceback [1]
        +String targetFile [1]
        +String snippetContent [1]
        +logFailure(error : String, context : String) : void
        +serializePayload() : String [1]
    }
    ToolingSubsystem *-- DiagnosticLogger
```

## Interface Requirements
### 1. Payload Schema
The tool must serialize a JSON payload at `.pipeline/diagnostics/repro_payload_[timestamp].json` containing:
- `timestamp`: ISO-8601 string.
- `tooling`: Object with `name` and `version`.
- `context`: Object with `command`, `exit_code`, `downstream_repo` URL, and `commit_hash`.
- `failure`: Object with `traceback` and `error_summary`.
- `reproduction_case`: Object with `target_file`, `snippet_type`, and `snippet_content`.

### 3. Logical Operations & Interface Messages
1. The tool (linter/reconciler) runs standard validations.
2. If an exception or validation error is encountered, the tool intercepts the failure before exiting.
3. The tool gathers git state and logs, extracts the offending text block (e.g. alternate flows block), and writes the JSON payload file.

### 4. Logical Exception States & Validation Failures
1. If the tool is unable to write the payload JSON to disk (e.g. due to folder permissions), it logs a warning message to stderr and exits with exit code 1.
