# Walkthrough: Epic Template Mandate & UML Validation Gate

## Overview
This document records the systemic fix applied to the zero-defect digital engineering pipeline to enforce UML diagram completeness at the Epic level. By updating the prompt rules and adding explicit validation checks, we prevent the generation of diagram-less Epics.

## Changes Implemented

### 1. Mandated Epic Templates in Specification Engineering
* **Target File**: [SKILL.md](../../skills/schema-specification-engineering/SKILL.md)
* **Modifications**:
  * Updated **Step 1 (Forensic Audit & Module Decomposition)**: Explicitly instructed that Epics must contain an overarching UML Class Diagram and a UML State Machine Diagram representing the macro-level domain.
  * Added **Epic File Structure / Template** under **Step 4 (Output Formatting & Strict GitHub Instrumentation)**: Defined a rigid template structure for Epics requiring:
    * `## System-Level UML Class Diagram` with a `classDiagram` block.
    * `## System State Machine Diagram` with a `stateDiagram-v2` block.
    * `## Child Features` list with issue links.

### 2. Plugged the Epic Linter Gap
* **Target File**: [verify_model_coverage.py](../../skills/spec-orchestrator/scripts/verify_model_coverage.py)
* **Modifications**:
  * Defined `epics_dir` mapping to `docs/epics/` in the `verify_uml_diagrams` function.
  * Added a dedicated `# 4. Verify Epics` section auditing all Epic markdown files.
  * Enforced validation rules:
    * Asserts the presence of a `## System-Level UML Class Diagram` header.
    * Asserts the presence of a ````mermaid classDiagram```` block.
    * Asserts the presence of a `## System State Machine Diagram` header.
    * Asserts the presence of a ````mermaid stateDiagram-v2```` block.
    * Detects and warns about invalid Mermaid dotted link syntax.
