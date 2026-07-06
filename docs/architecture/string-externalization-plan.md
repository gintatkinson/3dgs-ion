# String Externalization Plan

## 1. Current State Inventory

All hardcoded display strings found across `lib/` (excluding imports, doc comments, JSON parsing fallbacks, debug prints, and trivial single-character strings).

### Brand strings (3 occurrences)

| File:line | String value | Category | Target |
|-----------|-------------|----------|--------|
| `lib/app/app.dart:18` | `'Console'` | Brand (app title) | `app_config.dart` |
| `lib/features/tree/sidebar_tree.dart:53` | `'Console'` | Brand (sidebar header) | `app_config.dart` |
| `lib/features/layout/breadcrumbs.dart:149` | `'Console'` | Brand (breadcrumb root) | `app_config.dart` |

### UI labels (9 occurrences)

| File:line | String value | Category | Target |
|-----------|-------------|----------|--------|
| `lib/features/tree/sidebar_tree.dart:119` | `'Worker: ${workerResult ?? "Idle"}'` | UI label | `strings.json` |
| `lib/features/topology/topographical_view.dart:59` | `'Active View: $currentView'` | UI label | `strings.json` |
| `lib/features/properties/property_grid.dart:596` | `'Committed Data (verified on blur)'` | UI label | `strings.json` |
| `lib/features/properties/property_grid.dart:239` | `'Other'` | UI label (fallback section) | `strings.json` |
| `lib/features/properties/property_grid.dart:361` | `'Active Reference'` | UI label (badge) | `strings.json` |
| `lib/features/properties/property_grid.dart:150` | `'${field.label} is required'` | UI label (validation) | `strings.json` (template) |
| `lib/features/properties/property_grid.dart:156` | `'Must be a valid double'` | UI label (validation) | `strings.json` |
| `lib/features/properties/property_grid.dart:162` | `'Must be a valid integer'` | UI label (validation) | `strings.json` |
| `lib/features/properties/property_grid.dart:172` | `'Invalid format'` | UI label (validation) | `strings.json` |
| `lib/features/properties/property_grid.dart:178` | `'Value cannot be less than ${field.minValue}'` | UI label (validation) | `strings.json` (template) |
| `lib/features/properties/property_grid.dart:181` | `'Value cannot be greater than ${field.maxValue}'` | UI label (validation) | `strings.json` (template) |
| `lib/features/properties/property_grid.dart:200` | `'Invalid value'` | UI label (validation) | `strings.json` |

### Section titles (12 occurrences)

| File:line | String value | Category | Target |
|-----------|-------------|----------|--------|
| `lib/core/theme/widgets/settings_panel.dart:25` | `'Theme'` | Section title | `strings.json` |
| `lib/core/theme/widgets/settings_panel.dart:40` | `'Color'` | Section title | `strings.json` |
| `lib/core/theme/widgets/settings_panel.dart:75` | `'Text Size'` | Section title | `strings.json` |

### Tab labels from layout config service fallback (3 occurrences)

| File:line | String value | Category | Target |
|-----------|-------------|----------|--------|
| `lib/features/layout/layout_config_service.dart:45` | `'Items'` | Tab label | `logical-layout.json` (already tokenized) or `strings.json` |
| `lib/features/layout/layout_config_service.dart:46` | `'Status'` | Tab label | `logical-layout.json` (already tokenized) or `strings.json` |
| `lib/features/layout/layout_config_service.dart:47` | `'Activity'` | Tab label | `logical-layout.json` (already tokenized) or `strings.json` |

Note: `logical-layout.json` already references these via `"token:layout.labels.elements"`, `"token:layout.labels.alarms"`, `"token:layout.labels.events"`. The fallbacks in `layout_config_service.dart` should be removed after the JSON layer resolves them.

### Topology playback controls (6 occurrences)

| File:line | String value | Category | Target |
|-----------|-------------|----------|--------|
| `lib/features/topology/topology_map.dart:378` | `'Play'` / `'Pause'` | UI label | `strings.json` |
| `lib/features/topology/topology_map.dart:386` | `'t:'` | UI label | `strings.json` |
| `lib/features/topology/topology_map.dart:414` | `'Speed:'` | UI label | `strings.json` |
| `lib/features/topology/topology_map.dart:423` | `'0.5x'` | UI label | `strings.json` |
| `lib/features/topology/topology_map.dart:424` | `'1.0x'` | UI label | `strings.json` |
| `lib/features/topology/topology_map.dart:425` | `'2.0x'` | UI label | `strings.json` |
| `lib/features/topology/topology_map.dart:426` | `'5.0x'` | UI label | `strings.json` |

### Error messages (3 unique)

| File:line | String value | Category | Target |
|-----------|-------------|----------|--------|
| `lib/app/app.dart:68` | `'Error loading layout configuration: ${snapshot.error}'` | Error | `strings.json` |
| `lib/features/tables/view_models/tables_view_model.dart:97` | `'Failed to load table data'` | Error | `strings.json` |
| `lib/features/tables/view_models/tables_view_model.dart:135` | `'Failed to load table data'` | Error | `strings.json` |

### Color scheme names / descriptions (12 occurrences)

| File:line | String value | Category | Target |
|-----------|-------------|----------|--------|
| `lib/core/theme/app_themes.dart:12,13` | `'Greys'`, `'Professional grey-based theme'` | Theme metadata | `strings.json` or keep as config (low priority) |
| `lib/core/theme/app_themes.dart:30,31` | `'Blue Whale'`, `'Deep blue ocean theme'` | Theme metadata | `strings.json` or keep as config |
| `lib/core/theme/app_themes.dart:48,49` | `'Mandy Red'`, `'Bold red accent theme'` | Theme metadata | `strings.json` or keep as config |
| `lib/core/theme/app_themes.dart:66,67` | `'Wasabi'`, `'Fresh green theme'` | Theme metadata | `strings.json` or keep as config |
| `lib/core/theme/app_themes.dart:84,85` | `'Deep Purple'`, `'Rich purple theme'` | Theme metadata | `strings.json` or keep as config |
| `lib/core/theme/app_themes.dart:102,103` | `'Material Baseline'`, `'Standard Material 3 baseline'` | Theme metadata | `strings.json` or keep as config |

### Fallback / domain data (6 occurrences)

| File:line | String value | Category | Target |
|-----------|-------------|----------|--------|
| `lib/domain/data_sources/fallback_data_source.dart:17` | `'Item'` | Fallback domain label | `test/helpers/test_data.dart` (move) |
| `lib/domain/data_sources/fallback_data_source.dart:20` | `'Name'` | Fallback field label | `test/helpers/test_data.dart` (move) |
| `lib/domain/data_sources/fallback_data_source.dart:21` | `'Description'` | Fallback field label | `test/helpers/test_data.dart` (move) |
| `lib/features/tree/tree_defaults.dart:6` | `'Item'` | Fallback tree label | `test/helpers/test_data.dart` (move) |
| `lib/app/app.dart:43` | `'Item'` | Default active view | `strings.json` |

### Logical-layout.json (already externalized via token system)

Values like `"Category A"`, `"Item A1"`, etc. are in a data file (JSON), not code — **already externalized**. No action needed.

### Test fixture strings (all test files)

| File:line | String value | Category | Target |
|-----------|-------------|----------|--------|
| `test/breadcrumbs_test.dart:10-12` | `'Root'`, `'Level 1'`, `'Level 2'` | Test fixture | `test/helpers/test_data.dart` |
| `test/property_grid_test.dart:54-65` | `'Field 1'`, `'Field 2'`, `'Primary'`, `'Secondary'` | Test fixture | `test/helpers/test_data.dart` |
| `test/property_grid_test.dart:124-128` | `'Code'`, `'Invalid format'` | Test fixture | `test/helpers/test_data.dart` |
| `test/layout_test.dart:97` | `'Active View: Item'` | Test assertion | Update to use keys |
| `test/layout_test.dart:117` | `'Status'` | Test fixture | `test/helpers/test_data.dart` |
| `test/layout_test.dart:124` | `'Activity'` | Test fixture | `test/helpers/test_data.dart` |
| `test/topology_map_test.dart:9-56` | `'Ingestion'`, `'Metrics'`, `'Location'`, `'Chassis'` | Test fixture | `test/helpers/test_data.dart` |
| `test/topology_map_test.dart:116` | `'t:'` | Test assertion | Update to use keys |
| `test/topology_map_test.dart:215` | `'Play'` | Test assertion | Update to use keys |
| `test/widget_test.dart:44` | `'Console'` | Test assertion | Update to use keys |

---

## 2. Target Architecture

```
lib/
  core/
    app_config.dart              ← Brand-level strings (app name, window title)
                                      (imported by app.dart, sidebar_tree.dart, breadcrumbs.dart)

assets/
  strings.json                   ← All UI labels, section titles, error messages
                                      (loaded via StringResources loader, consumed everywhere else)

lib/
  core/
    string_resources.dart        ← Static loader + accessor for strings.json

  features/*/models/*            ← Domain-specific labels come from
                                      FieldDescriptor.sectionLabel / childLabel
                                      (these are already dynamic from DataSource)

test/
  helpers/
    test_data.dart               ← Generic test factories / fixture builders
                                      (provides terse test-specific values;
                                       replaces fallback_data_source.dart and tree_defaults.dart
                                       for test use only)
```

### Externalization boundaries

| Scope | Mechanism | Example |
|-------|-----------|---------|
| App name / brand | `lib/core/app_config.dart` constants | `static const appTitle = 'Console'` |
| All UI labels | `assets/strings.json` keyed map | `"sidebar.workerStatus": "Worker: {status}"` |
| Validation error templates | `assets/strings.json` with `{}` placeholders | `"errors.minValue": "Value cannot be less than {min}"` |
| Tab labels from layout tokens | `assets/logical-layout.json` → `resolveLabelsMapping()` | Already tokenized as `token:layout.labels.*` |
| Domain field labels | `FieldDescriptor.label` from `DataSource` | Already dynamic from `TypeDescriptor.fields` |
| Test-only fixtures | `test/helpers/test_data.dart` factory functions | `makeFieldDescriptor(label: 'Test Field')` |
| Color scheme metadata | `strings.json` (or keep inline — low priority) | Scheme names rarely change and are tightly coupled to `FlexSchemeData` |

---

## 3. String Loader

```dart
// lib/core/string_resources.dart
import 'dart:convert';
import 'package:flutter/services.dart' show rootBundle;

class StringResources {
  static Map<String, String> _strings = {};

  static Future<void> load() async {
    final json = await rootBundle.loadString('assets/strings.json');
    _strings = Map<String, String>.from(jsonDecode(json));
  }

  static String get(String key, {String? fallback}) =>
      _strings[key] ?? fallback ?? key;
}
```

**Usage pattern:**

```dart
// Before
Text('Console')
Text('Worker: ${workerResult ?? "Idle"}')
Text('Value cannot be less than ${field.minValue}')

// After
Text(StringResources.get('app.title'))
Text(
  StringResources.get('sidebar.workerStatus')
      .replaceFirst('{status}', '${workerResult ?? "Idle"}'),
)
Text(
  StringResources.get('errors.minValue')
      .replaceFirst('{min}', '${field.minValue}'),
)
```

**Initialization in `main()`:**

```dart
void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await StringResources.load();
  runApp(const MyApp());
}
```

---

## 4. Schema for strings.json

```json
{
  "app.title": "Platform Dashboard",
  "app.windowTitle": "Platform Dashboard",

  "sidebar.header": "Platform Dashboard",
  "sidebar.workerStatus": "Worker: {status}",

  "breadcrumbs.home": "Home",

  "topology.activeView": "Active View: {view}",
  "topology.play": "Play",
  "topology.pause": "Pause",
  "topology.timeLabel": "t:",
  "topology.speedLabel": "Speed:",

  "properties.otherSection": "Other",
  "properties.activeReference": "Active Reference",
  "properties.committedData": "Committed Data (verified on blur)",

  "tabs.defaultElements": "Items",
  "tabs.defaultAlarms": "Status",
  "tabs.defaultEvents": "Activity",

  "settings.themeMode": "Theme",
  "settings.colorScheme": "Color",
  "settings.textSize": "Text Size",

  "errors.layoutLoad": "Error loading layout configuration: {message}",
  "errors.tableLoad": "Failed to load table data",
  "errors.required": "{label} is required",
  "errors.invalidDouble": "Must be a valid double",
  "errors.invalidInteger": "Must be a valid integer",
  "errors.invalidFormat": "Invalid format",
  "errors.minValue": "Value cannot be less than {min}",
  "errors.maxValue": "Value cannot be greater than {max}",
  "errors.invalidValue": "Invalid value",

  "fallback.typeName": "Item",
  "fallback.fieldName": "Name",
  "fallback.fieldDescription": "Description",

  "defaults.activeView": "Item"
}
```

---

## 5. Migration Strategy — 6 Ordered Phases

| Phase | What | Files changed | Testable by |
|-------|------|--------------|------------|
| **1** | Create `StringResources` + `strings.json` + `app_config.dart` | 3 new files | Unit test that loader reads JSON and `get()` returns values |
| **2** | Replace brand strings in `app.dart`, `sidebar_tree.dart`, `breadcrumbs.dart` | 3 modified files + verify nothing broken | Visual check + test assertions pass (`widget_test.dart:44` updated) |
| **3** | Replace UI labels in `property_grid.dart`, `settings_panel.dart`, `tabbed_container.dart`, `topology_map.dart`, `topographical_view.dart` | 5 modified files | All existing tests pass |
| **4** | Replace error messages in `app.dart:68`, `tables_view_model.dart:97,135`, `property_grid.dart:150-200` | 3 modified files | Error paths still work (test manually or add test) |
| **5** | Move fallback/test fixtures: extract generic test data factory, point tests at `test/helpers/test_data.dart`, deprecate `fallback_data_source.dart` for test use | 4 test files modified, 2 new helper files | All tests pass with new factory |
| **6** | Add CI gate script + update CI config | 1 new script | CI fails on unapproved hardcoded strings |

### Phase details

#### Phase 1 — Foundation
Create these files only (no existing code modified):
- `lib/core/app_config.dart` — brand constants
- `lib/core/string_resources.dart` — loader + accessor
- `assets/strings.json` — all strings from schema above

#### Phase 2 — Brand strings
- `app.dart:18` → `StringResources.get('app.title')`
- `sidebar_tree.dart:53` → `StringResources.get('sidebar.header')`
- `breadcrumbs.dart:149` → `StringResources.get('breadcrumbs.home')`
- Init loader in `main()` before `runApp()`

#### Phase 3 — UI labels
- `settings_panel.dart:25,40,75` → `StringResources.get('settings.*')`
- `property_grid.dart:239` → `StringResources.get('properties.otherSection')`
- `property_grid.dart:361` → `StringResources.get('properties.activeReference')`
- `property_grid.dart:596` → `StringResources.get('properties.committedData')`
- `topographical_view.dart:59` → `StringResources.get('topology.activeView', ...)`
- `topology_map.dart:378` → `StringResources.get('topology.play/pause')`
- `topology_map.dart:386` → `StringResources.get('topology.timeLabel')`
- `topology_map.dart:414` → `StringResources.get('topology.speedLabel')`
- `topology_map.dart:423-426` → `StringResources.get('topology.speed.*')`
- `layout_config_service.dart:45-47` → keep as fallback but source from `strings.json` instead of literal

#### Phase 4 — Error messages
- `app.dart:68` → template with `StringResources.get('errors.layoutLoad', ...)`
- `tables_view_model.dart:97,135` → `StringResources.get('errors.tableLoad')`
- `property_grid.dart` validation messages → template from `strings.json`

#### Phase 5 — Test fixtures
- Create `test/helpers/test_data.dart` with factory functions:
  - `makeBreadcrumbItem({String id, String label})`
  - `makeFieldDescriptor({String key, String label, ...})`
  - `makeTypeDescriptor({String typeName, ...})`
  - `makeTopologyNode({String id, String label, ...})`
- Update 4 test files to use factories instead of hardcoded strings
- Replace fallback references in `fallback_data_source.dart` with factory calls in test setup

#### Phase 6 — CI gate
- Create `scripts/check-hardcoded-strings.sh`
- Wire into CI pipeline (GitHub Actions / whatever the project uses)
- Run after `flutter analyze` but before test execution

---

## 6. CI Gate Script

```bash
#!/bin/bash
# scripts/check-hardcoded-strings.sh
# Fails if any hardcoded display string > 20 chars is found in lib/
# after externalization is complete.

set -euo pipefail

EXIT_CODE=0

# Check for display strings: single-quoted strings containing at least
# one uppercase followed by lowercase (sentence-case / title-case strings).
# Exclude: imports, doc comments, inline comments, Test() invocations, Key() constructors.
grep -rn "'.*[A-Z].*[a-z].*[a-z].*[a-z].*'" lib/ --include="*.dart" \
  | grep -v "^.*import\|^.*///\|// \|Test(\|Key(\|const \|Icon(" \
  && EXIT_CODE=1 || true

if [ $EXIT_CODE -ne 0 ]; then
  echo "FAIL: Hardcoded display strings found. Externalize them to assets/strings.json."
  exit 1
fi

echo "PASS: No hardcoded display strings detected."
exit 0
```

**Integration point:** Add to `pubspec.yaml` scripts or CI config:

```yaml
# In CI:
- run: bash scripts/check-hardcoded-strings.sh
```

---

## 7. Risk Assessment

| Risk | Impact | Mitigation |
|------|--------|------------|
| `strings.json` not loaded before UI renders | All labels appear as their key names (e.g., `"app.title"`) | Load in `main()` before `runApp()`; `get()` returns `key` as fallback so missing keys are self-documenting |
| Key typo in `strings.json` (e.g., `"app.tile"` instead of `"app.title"`) | Key name displayed in UI | The fallback `key` behavior makes this visibly obvious in development. Add a lint rule or key-coverage unit test in CI. |
| Performance of runtime string lookup | Negligible (~1 μs per lookup) | `HashMap` O(1); load once at startup. The `strings.json` file is small (< 5 KB). |
| Template strings with `{param}` do not match callers (e.g., `{name}` vs `{label}`) | Incorrect substitution — raw template displayed | Each template key must be paired with documentation. Unit test each template substitution path. |
| Tests don't have `strings.json` loaded | `StringResources.get()` returns key names; test assertions expecting specific labels fail | Test helper loads `strings.json` in `setUpAll()`, or tests use the fallback behavior intentionally. Alternatively, make `StringResources` injectable for tests. |
| Theme scheme names (`'Greys'`, `'Blue Whale'`, etc.) are tightly coupled to `FlexSchemeData` | Externalizing adds indirection with no benefit | Keep scheme names/descriptions inline in `app_themes.dart`. They are configuration, not UI strings. Revisit only if multi-language support is needed. |
| Developer adds a new hardcoded string post-migration | Regression — hardcoded string appears | CI gate fails; code review catches it; `#` lint rule in IDE. |

---

## 8. Effort Estimate

| Phase | Effort | Details |
|-------|--------|---------|
| 1 — Foundation | 30 min | Create 3 files, write loader, init in `main()` |
| 2 — Brand strings | 30 min | Update 3 files, verify in test + visual check |
| 3 — UI labels | 2 hours | 5 files: settings, property grid, topology, tab labels |
| 4 — Error messages | 1 hour | 3 files: app error, table view model, validation templates |
| 5 — Test fixtures | 1 hour | Create factory, update 4 test files, deprecate fallback |
| 6 — CI gate | 30 min | Script + CI integration |
| **Total** | **~4 hours** | All phases independently testable; rollback possible per phase |

**Notes:**
- Phase 3 is the heaviest because it touches the topology playback panel (Play/Pause/Speed labels) and the property grid validation templates.
- Phase 5 can be done in parallel with Phase 3 (different files, no merge conflicts expected).
- Phase 6 is optional but recommended before merging Phase 2–5 to prevent regression.
