# Debugging Protocol Dossier: Issues #53-59

This document logs the step-by-step progress, hypotheses, evidence, and root-cause analysis for each defect under investigation.

---

## Active Issue: Issues #53, #54, #55 (Profiler Integration Test Failures)
* **Status**: Step 1 Reproduction Complete.

---

## 1. Step 1: Reproduction Findings
- **Integration Test File**: `app_flutter/integration_test/node_iteration_test.dart`
- **Reproduction Command**: `flutter test integration_test/node_iteration_test.dart -d macos`
- **Findings**:
  1. **Tapping Offscreen Nodes**: `Integration: 10 cycles x 20 nodes...` test succeeds but generates numerous offscreen hit-test warnings (e.g. `Offset(124.5, -426.0) is outside the bounds of the root of the render tree`) because it fails to ensure nodes are scrolled into view via `tester.ensureVisible` before tapping.
  2. **Icon Finder Ambiguity**: `find.byIcon(Icons.settings)` matches both the interactive settings icon on the sidebar and the decorative viewport stats icon, causing settings pane failure.
  3. **Slider Ambiguity**: `find.byType(Slider)` matches both the opacity and text scale sliders in `SettingsPanel`, triggering a `StateError (Too many elements)`.
  4. **Offscreen Tapping on Bottom Sheet Dismissal**: Relying on `tester.tapAt(Offset.zero)` fails or calculates incorrect offsets, leading to uncompleted tests.
- **Scope**: Isolated to `node_iteration_test.dart`. No systemic defects in Layout settings logic.

## 2. Step 2: Hypothesis Log
- **Hypothesis 1 (Offscreen Nodes)**: The integration test does not call `tester.ensureVisible` before tapping. Over multiple cycles, scrolled nodes Y coordinate shifts outside the `(1000, 800)` test window bounds, throwing hit-test warnings/errors.
- **Hypothesis 2 (Settings Icon Finder)**: `find.byIcon(Icons.settings).first` matches the decorative icon in `scene_3d_viewport.dart` instead of the button in `sidebar_tree.dart`. Hence, the settings bottom sheet never opens, causing downstream finders to throw "No element" exceptions.
- **Hypothesis 3 (Slider Finder)**: `find.byType(Slider)` matches two sliders (Overlay Opacity and Text Size) inside `SettingsPanel`, triggering a too-many-elements `StateError`.
- **Hypothesis 4 (Dismissal tap offset)**: `tester.tapAt(Offset.zero)` fails to close the bottom sheet because (0,0) is outside the modal barrier area or intercepted by window headers. Using `find.byType(ModalBarrier).last` will dismiss it cleanly.
- **Hypothesis 5 (Sandbox File Write)**: The macOS sandbox restricts direct filesystem writes to `../benchmark_results.jsonl`, triggering a `FileSystemException`. We should wrap this block in a `try-catch` to avoid test crashes (or use path providers).

## 3. Step 3: Investigation Evidence
- **Icons.settings Location Conflict**: Confirmed that `Icons.settings` is used in three places:
  1. `sidebar_tree.dart:145` (tappable sidebar settings button)
  2. `scene_3d_viewport.dart:708` (decorative viewport icon)
  3. `scene_3d_viewport.dart:963` (viewport config overlay button)
  - This ambiguity causes `find.byIcon(Icons.settings).first` to match the wrong icon, preventing settings bottom sheet from opening.
- **SettingsPanel Sliders**: Verified that two `Slider` widgets exist under `SettingsPanel`:
  1. `settings_panel.dart:79` (Overlay Opacity Slider)
  2. `settings_panel.dart:134` (Text Size Slider)
  - This duplicate matches causes `tester.getRect(slider)` to throw a too-many-elements `StateError`.
- **Sandbox File Path Access**: verified that `node_iteration_test.dart:16-19` points to `${Directory.current.parent.path}/benchmark_results.jsonl`. Inside a macOS sandboxed app run, writing outside the sandbox container throws a `PathAccessException`.
- **Tapping Loop Visibility**: In the first loop (`node_iteration_test.dart:157-163`), there is no call to `ensureVisible` before tapping. In the second loop, it is correctly included.

## 4. Step 4: Evidence Dossier
- **Evidence Log File**: [evidence_dossier.md](file:///Users/perkunas/.gemini/antigravity/brain/837aa23e-a019-4d60-bb76-e42bd71de64c/evidence_dossier.md)
- **Ruled Out Hypotheses**:
  1. *Systemic Layout State Corruption*: Ruled out. The settings controls, panel widgets, and breadcrumb layout state render and propagate accurately when targeted by explicit, non-ambiguous finders.
  2. *Isolate Thread Deadlock*: Ruled out. Database initializes and background workers execute continuously without thread lock or blocking Dart ports.
  3. *Uncaught Sandboxed Write Failures*: Ruled out. The benchmark log file write operations fail silently or output caught warnings due to macOS sandbox limits but do not terminate the runner process directly.
- **Confirmed Symptoms**:
  - Offscreen Node Warning stack traces in first loop: `Offset(124.5, -426.0) is outside the bounds...`
  - Settings Icon finder matches: `scene_3d_viewport.dart:708` instead of `sidebar_tree.dart:145`
  - Slider finder matches: 2 duplicate instances under `SettingsPanel` (`settings_panel.dart:79`, `settings_panel.dart:134`)
  - Bad State "No element" at `node_iteration_test.dart:114` due to closed settings panel sheet.

## 5. Step 5: Root Cause ("5 Whys")
*Awaiting subagent dispatch...*

## 6. Step 6: Applied Fixes
*Awaiting subagent dispatch...*

## 7. Step 7: Verification Results
*Awaiting subagent dispatch...*
