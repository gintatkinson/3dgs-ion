# Solution Walkthrough: Downstream Baseline Seeding and Compliance Framework

This document outlines the solution design, script descriptions, Project Constitution amendments, Code Realization Table, and baseline verification results for Feature 44.

---

## 1. Overview of Issue #44

Issue #44 introduces the **Downstream Baseline Seeding and Compliance Framework** to enforce architectural consistency, structural conformance, and quality gates across downstream platforms (Flutter). Specifically, it aims to:
- **Seed Baseline Templates**: Allow downstream projects to be cleanly bootstrapped with baseline structures while preserving active working states (such as `.git`, `.dart_tool`, and lockfiles).
- **Enforce Conformance Gates**: Validate type compatibility against mandated domain classes and interfaces, check structural integrity, and verify that compilation and testing suites execute cleanly.
- **Enforce Zero-Mocking**: Require that client-side applications connect to live, persistent databases or emulators in active builds, prohibiting mock/stub repository adapters at the dependency injection level.

---

## 2. Description of the Bootstrap and Verify Scripts

Two key utility scripts were added to realize Feature 44:

### 2.1. [bootstrap_downstream.py](file:///Users/perkunas/digital-pipeline-repo/scripts/bootstrap_downstream.py)
This script initializes or updates a downstream application (`flutter`) by copying baseline template files from the repository's root template folder (`app_flutter`) to a specified destination directory.
- **Preservation Logic**: It surgically avoids overwriting critical working state files and folders at the destination, including `.git`, `.dart_tool`, `pubspec.lock`, and other package-manager lockfiles.
- **Usage**:
  ```bash
  python3 scripts/bootstrap_downstream.py <platform> <destination_path>
  ```

### 2.2. [verify_downstream_baseline.py](file:///Users/perkunas/digital-pipeline-repo/scripts/verify_downstream_baseline.py)
This compliance validator asserts that a downstream project matches all baseline and structural requirements:
- **Baseline Check**: Asserts that all essential files exist (e.g., `pubspec.yaml`, `analysis_options.yaml`, `lib/domain/types.dart`, `lib/domain/validation.dart` for Flutter).
- **Type Compatibility**: Programmatically parses the types file (`types.dart`) to ensure the presence of all 9 mandated domain classes/interfaces.
- **Build and Test Verification**: Triggers the package manager to fetch dependencies and executes build/compilation and test suites (`flutter pub get && flutter analyze && flutter test` for Flutter).
- **Usage**:
  ```bash
  python3 scripts/verify_downstream_baseline.py <platform> <destination_path>
  ```

---

## 3. Amendments to the Project Constitution

To make baseline verification a mandatory quality gate for downstream applications, the [Project Constitution](file:///Users/perkunas/digital-pipeline-repo/.pipeline/constitution.md) was amended.

### Section 4.5: Downstream Conformance Gates
The following rules were formally integrated under Section 4:
- Prior to integrating any downstream application implementation, the project **MUST** be bootstrapped and verified.
- The downstream project must be initialized using the [bootstrap_downstream.py](file:///Users/perkunas/digital-pipeline-repo/scripts/bootstrap_downstream.py) script.
- The baseline conformance must be verified using the [verify_downstream_baseline.py](file:///Users/perkunas/digital-pipeline-repo/scripts/verify_downstream_baseline.py) script, which asserts that all baseline files are present, validates type compatibility with the mandated domain classes, and compiles/tests the project with a clean exit code.

Additionally, **Section 5 (Forbidden Practices)** was updated to forbid deleting, disabling, or modifying baseline files, layout splitters, playback timelines, or focus-loss validation forms in downstream projects, as they form the core compliance and verification framework.

---

## 4. Code Realization Table

The following table maps the feature components to their corresponding files, classes, interfaces, and methods in the Flutter baseline.

| UML Element | Realization Tag | File Path | Properties & Realized Behavior |
| :--- | :--- | :--- | :--- |
| `PersistenceBootstrap` | `@realizes UML::PersistenceBootstrap` | [bootstrap_downstream.py](file:///Users/perkunas/digital-pipeline-repo/scripts/bootstrap_downstream.py) | Copies core template components and structures into the target project workspace. |
| `ComplianceValidator` | `@realizes UML::ComplianceValidator` | [verify_downstream_baseline.py](file:///Users/perkunas/digital-pipeline-repo/scripts/verify_downstream_baseline.py) | Validates baseline file existence, checks for mandated class declarations, and verifies build/test cycles. |
| `Velocity` | `@realizes UML::Velocity` | [types.dart](file:///Users/perkunas/digital-pipeline-repo/app_flutter/lib/domain/types.dart) | Class representing 3D velocity vectors with `fromJson` and `toJson` serialization. |
| `TemporalContext` | `@realizes UML::TemporalContext` | [types.dart](file:///Users/perkunas/digital-pipeline-repo/app_flutter/lib/domain/types.dart) | Class representing temporal context and velocity projection. |
| `PhysicalAddress` | `@realizes UML::PhysicalAddress` | [types.dart](file:///Users/perkunas/digital-pipeline-repo/app_flutter/lib/domain/types.dart) | Class containing address parameters with serialization support. |
| `LocationType` | `@realizes UML::LocationType` | [types.dart](file:///Users/perkunas/digital-pipeline-repo/app_flutter/lib/domain/types.dart) | Class wrapping structural node identity strings. |
| `LocationHierarchy` | `@realizes UML::LocationHierarchy` | [types.dart](file:///Users/perkunas/digital-pipeline-repo/app_flutter/lib/domain/types.dart) | Class managing nested parent hierarchies and relationships. |
| `RackLocation` | `@realizes UML::RackLocation` | [types.dart](file:///Users/perkunas/digital-pipeline-repo/app_flutter/lib/domain/types.dart) | Class defining coordinates within server rooms. |
| `Rack` | `@realizes UML::Rack` | [types.dart](file:///Users/perkunas/digital-pipeline-repo/app_flutter/lib/domain/types.dart) | Class enforcing physical dimension limits and power parameters. |
| `ContainedChassis` | `@realizes UML::ContainedChassis` | [types.dart](file:///Users/perkunas/digital-pipeline-repo/app_flutter/lib/domain/types.dart) | Class implementing physical slot overlap detection logic. |
| `ChassisContainmentSubsystem` | `@realizes UML::ChassisContainmentSubsystem` | [types.dart](file:///Users/perkunas/digital-pipeline-repo/app_flutter/lib/domain/types.dart) | Class executing comprehensive containment overlap validation checks. |

---

## 5. Verification Results

The downstream platform was verified successfully using the [verify_downstream_baseline.py](file:///Users/perkunas/digital-pipeline-repo/scripts/verify_downstream_baseline.py) gate.

### Flutter Baseline Verification
```bash
python3 scripts/verify_downstream_baseline.py flutter app_flutter
```
**Output Trace:**
```text
Verifying conformance for platform 'flutter' at '/Users/perkunas/digital-pipeline-repo/app_flutter'...
Success: All baseline files exist.
Success: Type compatibility validation passed (all mandated domain classes exist).
Running 'flutter pub get' to resolve dependencies...
Got dependencies!
Running 'flutter analyze'...
Analyzing app_flutter...
No issues found! (ran in 2.1s)
Running 'flutter test'...
00:00 +0: loading /Users/perkunas/digital-pipeline-repo/app_flutter/test/property_grid_test.dart
00:00 +1: /Users/perkunas/digital-pipeline-repo/app_flutter/test/breadcrumbs_test.dart: Renders all items when total count <= maxItems
00:01 +4: /Users/perkunas/digital-pipeline-repo/app_flutter/test/widget_test.dart: Dashboard console boots and renders main widgets successfully
00:01 +7: /Users/perkunas/digital-pipeline-repo/app_flutter/test/layout_test.dart: Layout switches tabs in TabbedContainer
00:02 +10: /Users/perkunas/digital-pipeline-repo/app_flutter/test/topology_map_test.dart: TopologyMap widget renders viewport, grid, and scrubber
00:02 +13: /Users/perkunas/digital-pipeline-repo/app_flutter/test/property_grid_test.dart: Validates locationType immediately upon selection change and on blur
00:02 +15: /Users/perkunas/digital-pipeline-repo/app_flutter/test/layout_test.dart: Layout keyboard navigation and node selection
00:02 +16: /Users/perkunas/digital-pipeline-repo/app_flutter/test/topology_map_test.dart: Timeline scrubber adjusts playhead time
00:02 +17: /Users/perkunas/digital-pipeline-repo/app_flutter/test/topology_map_test.dart: Play/Pause button starts/stops ticking
00:02 +18: /Users/perkunas/digital-pipeline-repo/app_flutter/test/topology_map_test.dart: Speed dropdown selection updates multiplier
00:02 +19: All tests passed!
Success: Build and test suite execution passed. Conformance gate verified.
```

