# Solution Walkthrough - Issue #65 Baseline Verification Customizations

This document summarizes the changes, verification proof, and Code Realization Table for Issue #65: Baseline Verification Customizations.

## Changes Overview

1. **`scripts/bootstrap_downstream.py`**:
   - Added the `--no-domain` command-line argument.
   - For Flutter, skips walking/copying the `lib/domain` directory.
   - For React, skips copying the `src/types.ts` file.

2. **`scripts/verify_downstream_baseline.py`**:
   - Implemented dynamic loading of mandated domain classes from configuration files inside the downstream directory (checking in order: `.pipeline/logical-ui/codebase_rules.json`, `codebase_rules.json`, `baseline_manifest.json`).
   - Parses `"mandated_classes"` under the `"validation_rules"` key or at the root level.
   - Falls back to the hardcoded default `MANDATED_CLASSES` list if configuration is missing or invalid.

3. **`README.md`**:
   - Updated baseline seeding documentation to include the `--no-domain` flag.
   - Updated compliance checks documentation to describe the dynamic loading of mandated classes from configuration files.

4. **`.pipeline/constitution.md`**:
   - Updated Section 4.5 (Downstream Conformance Gates) to document that domain baseline verification is dynamically parameterized via target configuration rules.

5. **`.agents/skills/feature-driven-implementation/SKILL.md`**:
   - Added a note instructing agents to use the `--no-domain` flag with the bootstrap script if implementing a different project domain.

## Code Realization Table

| Component/Feature | Source File | Class / Function / Section | Description |
| :--- | :--- | :--- | :--- |
| `--no-domain` Flag | [scripts/bootstrap_downstream.py](file:///Users/perkunas/digital-pipeline-repo/scripts/bootstrap_downstream.py) | `main` | Added `--no-domain` argument and directory/file skip logic. |
| Dynamic Verification | [scripts/verify_downstream_baseline.py](file:///Users/perkunas/digital-pipeline-repo/scripts/verify_downstream_baseline.py) | `load_mandated_classes`, `main` | Added configuration lookup logic and replaced hardcoded class loop. |
| User Instructions | [README.md](file:///Users/perkunas/digital-pipeline-repo/README.md) | Downstream Baseline Seeding and Compliance | Documented the `--no-domain` option and dynamic validation rules. |
| Constitution Rules | [.pipeline/constitution.md](file:///Users/perkunas/digital-pipeline-repo/.pipeline/constitution.md) | Section 4.5 Downstream Conformance Gates | Noted that domain validation is dynamically parameterized. |
| Agent Workflows | [.agents/skills/feature-driven-implementation/SKILL.md](file:///Users/perkunas/digital-pipeline-repo/.agents/skills/feature-driven-implementation/SKILL.md) | Step 1: Backlog & Dependency Mapping | Instructed agents to use `--no-domain` for different project domains. |

## Verification and Execution Proof

### 1. Bootstrapping with `--no-domain`
Successfully ran bootstrapping tests into temporary paths:
- **React**: Verified that `src/types.ts` is omitted.
  ```
  Skipping domain file per --no-domain: types.ts
  Bootstrap complete for react.
  Copied: 20 files.
  Skipped/Preserved: 1 files.
  ```
- **Flutter**: Verified that `lib/domain` is omitted.
  ```
  Omitted:
  ```

### 2. Dynamic Class Validation
Verified that the verification script successfully loads from the target configuration:
```
Loaded mandated classes dynamically from tmp/test-verify-react/.pipeline/logical-ui/codebase_rules.json: ['RackLocation']
['RackLocation']
```
If configuration is missing or malformed, it gracefully falls back to the default list of 9 classes.
