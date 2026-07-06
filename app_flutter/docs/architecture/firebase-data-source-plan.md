# Firebase DataSource — Implementation Plan

## 1. Current Architecture (SQLite-only)

```
main.dart
  └─ RepositoryResolver.resolve()
       ├─ Loads assets/persistence-config.json → reads repository_type
       ├─ Copies pre-built `assets/properties_db.db` to app support dir
       ├─ Opens DB via sqflite_common_ffi
       ├─ Checks existence of type_definitions table
       │    ├─ If rows exist → SqliteDataSource(db) + SqliteRepositoryAdapter(db)
       │    └─ If no rows   → FallbackDataSource() + SqliteRepositoryAdapter(db)
       └─ Returns (AbstractRepository, DataSource)
```

The returned pair is injected into the widget tree via `Provider`:

- `Provider<DataSource>` → consumed by `TreeViewModel` (side bar type tree)
- `Provider<AbstractRepository>` → consumed by `PropertyGrid`, element/alarm/event tables

All data — schema, properties, elements, alarms, events — lives in the same local SQLite file.

---

## 2. Separation of Concerns

`RepositoryResolver` today bundles two responsibilities that must be unlinked for a Firebase backend:

| Concern | Interface | SQLite impl | Firebase impl |
|---|---|---|---|
| Schema / ontology | `DataSource` | `SqliteDataSource` (reads `type_definitions`, `type_attributes`, `type_relations` tables) | `FirebaseDataSource` (reads Firestore collections `schema/types`, `schema/attributes`, `schema/relations`) |
| Data operations | `AbstractRepository` | `SqliteRepositoryAdapter` (reads `properties`, `elements`, `alarms`, `events` tables) | `FirebaseRepositoryAdapter` (reads/writes Firestore documents `data/{nodeId}/properties`, collections `data/{nodeId}/elements`, etc.) |

For Firebase, **both** schema and data must come from Firestore, not from the local SQLite file. The resolver must be refactored so it no longer hard-codes SQLite initialisation; instead it should dispatch to the appropriate factory based on a configuration value.

---

## 3. Config Mechanism

Three options are available to select the data source at startup:

### Option A — Environment variable (`DATA_SOURCE=sqlite|firebase`)

```dart
const dataSourceType = String.fromEnvironment('DATA_SOURCE', defaultValue: 'sqlite');
```

- **Pros**: Simple, no extra files; works in CI/emulator tests via `--dart-define=DATA_SOURCE=firebase`.
- **Cons**: Not discoverable by non-developers; only settable at build time.

### Option B — Config file (`.pipeline/active_data_source.json`)

```json
{ "active_data_source": "firebase" }
```

- **Pros**: Runtime-switchable; same pattern as the existing `persistence-config.json`; can be version-controlled per environment.
- **Cons**: Requires file-system I/O at startup; extra failure path.

### Option C — Build flag (`--dart-define=DATA_SOURCE=firebase`)

Identical to Option A in mechanism; only differs in developer ergonomics (`--dart-define` vs shell env).

### Recommendation

Use **Option A (`DATA_SOURCE` environment variable via `String.fromEnvironment`)** because:

1. It is the simplest possible mechanism — zero additional file I/O.
2. It works with both `flutter run --dart-define=DATA_SOURCE=firebase` and CI scripts.
3. It does not require wiring a new config-file parser.
4. The existing `persistence-config.json` check can be retained as a fallback for backward compatibility, but `DATA_SOURCE` env var takes precedence (env var overrides file).

---

## 4. FirebaseDataSource Implementation

```dart
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:app_flutter/domain/data_source.dart';
import 'package:app_flutter/domain/type_descriptor.dart';

class FirebaseDataSource implements DataSource {
  FirebaseDataSource({FirebaseFirestore? firestore})
      : _firestore = firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore _firestore;

  @override
  String get name => 'firebase';

  @override
  Future<List<TypeDescriptor>> discoverTypes() async {
    final typeSnap = await _firestore.collection('schema/types').get();
    final attrSnap = await _firestore.collection('schema/attributes').get();
    final relSnap = await _firestore.collection('schema/relations').get();

    // Index by type_name
    final attrsByType = <String, List<FieldDescriptor>>{};
    for (final doc in attrSnap.docs) {
      final data = doc.data();
      final tn = data['type_name'] as String;
      attrsByType.putIfAbsent(tn, () => []).add(_parseField(data));
    }

    final relsByParent = <String, List<TypeRelationDescriptor>>{};
    for (final doc in relSnap.docs) {
      final data = doc.data();
      final ptn = data['parent_type_name'] as String;
      relsByParent.putIfAbsent(ptn, () => []).add(TypeRelationDescriptor(
        relationName: data['relation_name'] as String,
        childTypeName: data['child_type_name'] as String,
        childLabel: data['child_label'] as String,
      ));
    }

    return typeSnap.docs.map((doc) {
      final data = doc.data();
      final tn = data['type_name'] as String;
      return TypeDescriptor(
        typeName: tn,
        displayName: data['display_name'] as String? ?? tn,
        iconName: data['icon_name'] as String? ?? '',
        fields: attrsByType[tn] ?? [],
        childTypes: relsByParent[tn] ?? [],
        parentTypes: [],
      );
    }).toList();
  }

  @override
  Future<TypeDescriptor?> typeFor(String typeName) async {
    final typeDocs = await _firestore
        .collection('schema/types')
        .where('type_name', isEqualTo: typeName)
        .get();
    if (typeDocs.docs.isEmpty) return null;

    final data = typeDocs.docs.first.data();
    final attrDocs = await _firestore
        .collection('schema/attributes')
        .where('type_name', isEqualTo: typeName)
        .get();
    final relDocs = await _firestore
        .collection('schema/relations')
        .where('parent_type_name', isEqualTo: typeName)
        .get();

    return TypeDescriptor(
      typeName: typeName,
      displayName: data['display_name'] as String? ?? typeName,
      iconName: data['icon_name'] as String? ?? '',
      fields: attrDocs.docs.map((d) => _parseField(d.data())).toList(),
      childTypes: relDocs.docs.map((d) => TypeRelationDescriptor(
        relationName: d.data()['relation_name'] as String,
        childTypeName: d.data()['child_type_name'] as String,
        childLabel: d.data()['child_label'] as String,
      )).toList(),
      parentTypes: [],
    );
  }

  @override
  Future<List<(String, String)>> discoverHierarchy() async {
    final snap = await _firestore.collection('schema/relations').get();
    return snap.docs.map((doc) => (
      doc.data()['parent_type_name'] as String,
      doc.data()['child_type_name'] as String,
    )).toList();
  }

  FieldDescriptor _parseField(Map<String, dynamic> data) { ... }
}
```

- Place in `lib/domain/data_sources/firebase_data_source.dart`.
- Uses Firestore collections with a `schema/` prefix to keep them logically separated from operational data.
- No local database involvement.

---

## 5. FirebaseRepositoryAdapter Implementation

```dart
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:app_flutter/domain/repository.dart';

class FirebaseRepositoryAdapter implements AbstractRepository {
  FirebaseRepositoryAdapter({FirebaseFirestore? firestore})
      : _firestore = firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore _firestore;

  @override
  Future<Map<String, dynamic>> fetchProperties(String nodeId) async {
    final doc = await _firestore.doc('data/$nodeId/properties/current').get();
    if (!doc.exists) return {};
    return doc.data() as Map<String, dynamic>? ?? {};
  }

  @override
  Future<void> saveProperties(String nodeId, Map<String, dynamic> data) async {
    await _firestore.doc('data/$nodeId/properties/current').set(data);
  }

  @override
  Stream<Map<String, dynamic>> watchProperties(String nodeId) {
    return _firestore
        .doc('data/$nodeId/properties/current')
        .snapshots()
        .map((snap) => snap.data() as Map<String, dynamic>? ?? {});
  }

  @override
  Future<List<Map<String, dynamic>>> fetchElements(String parentNodeId) async {
    final snap = await _firestore.collection('data/$parentNodeId/elements').get();
    return snap.docs.map((d) => d.data()).toList();
  }

  @override
  Future<List<Map<String, dynamic>>> fetchAlarms(String parentNodeId) async {
    final snap = await _firestore.collection('data/$parentNodeId/alarms').get();
    return snap.docs.map((d) => d.data()).toList();
  }

  @override
  Future<List<Map<String, dynamic>>> fetchEvents(String parentNodeId) async {
    final snap = await _firestore.collection('data/$parentNodeId/events').get();
    return snap.docs.map((d) => d.data()).toList();
  }
}
```

- Place in `lib/domain/repositories/firebase_repository_adapter.dart`.
- Data structure mirrors SQLite tables but stored as Firestore documents:

```
data/{nodeId}/
  properties/current      → document (key-value map)
  elements/{docId}        → document per element
  alarms/{docId}          → document per alarm
  events/{docId}          → document per event
```

- Real-time watching is built-in via `.snapshots()` (replaces the manual `StreamController` in `SqliteRepositoryAdapter`).

---

## 6. main.dart Changes

```dart
Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  const dataSourceType =
      String.fromEnvironment('DATA_SOURCE', defaultValue: 'sqlite');

  late final AbstractRepository repository;
  late final DataSource dataSource;

  if (dataSourceType == 'firebase') {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
    dataSource = FirebaseDataSource();
    repository = FirebaseRepositoryAdapter();
  } else {
    // Existing path — unchanged
    (repository, dataSource) = await RepositoryResolver.resolve();
  }

  // Theme setup (unchanged) ...
  final themeService = SharedPreferencesThemeService();
  final themeController = ThemeController(themeService);
  await themeController.loadSettings();

  final textScalerController = TextScalerController(themeService);
  await textScalerController.load();

  globalThemeController = themeController;
  globalTextScalerController = textScalerController;

  runApp(
    MultiProvider(
      providers: [
        Provider<AbstractRepository>.value(value: repository),
        Provider<DataSource>.value(value: dataSource),
        ChangeNotifierProvider<ThemeController>.value(value: themeController),
        ChangeNotifierProvider<TextScalerController>.value(value: textScalerController),
      ],
      child: const MyApp(),
    ),
  );
}
```

Key points:

- `DATA_SOURCE` env var gates which path is taken; existing SQLite path is completely unchanged.
- Firebase initialisation (`Firebase.initializeApp`) is only called in the Firebase path — no impact on existing users.
- Both `repository` and `dataSource` are typed as their abstract interfaces, so the widget tree requires zero changes.

---

## 7. RepositoryResolver Refactoring

The resolver currently does three things that should be split:

1. **Config reading** — read `persistence-config.json` (or env var) to decide backend type.
2. **SQLite initialisation** — copy DB, open connection, verify type_definitions table.
3. **Fallback logic** — choose `FallbackDataSource` when metadata tables are absent.

### Proposed refactoring

Replace the monolithic `resolve()` with two static methods that return individual concerns:

```dart
class BackendConfig {
  final String type; // 'sqlite' | 'firebase' | ...
  final String? configPath;
  final String? dbAssetPath;
  final bool sqliteInMemory;
}

class RepositoryResolver {
  /// Reads configuration from env var or config file.
  static Future<BackendConfig> readConfig({...}) async { ... }

  /// Initialises SQLite and returns the pair.
  static Future<(AbstractRepository, DataSource)> resolveSqlite({...}) async {
    // current _createSqliteAdapter body
  }

  /// Top-level resolver (backward-compatible).
  static Future<(AbstractRepository, DataSource)> resolve({...}) async {
    final cfg = await readConfig(...);
    switch (cfg.type) {
      case 'firebase':
        throw UnsupportedError('Firebase must be initialised in main.dart');
      default:
        return resolveSqlite(...);
    }
  }
}
```

The Firebase path skips `RepositoryResolver` entirely — `main.dart` creates the Firebase instances directly. This avoids pulling Firebase dependencies into the resolver and keeps the SQLite code path untouched.

### Layering after refactoring

```
main.dart
  ├─ [DATA_SOURCE=sqlite]  → RepositoryResolver.resolve()  (unchanged)
  │                           └─ BackendConfig.readConfig()
  │                           └─ RepositoryResolver.resolveSqlite()
  │                                  ├─ SqliteDataSource
  │                                  └─ SqliteRepositoryAdapter
  │
  └─ [DATA_SOURCE=firebase] → Firebase.initializeApp()
                               ├─ FirebaseDataSource
                               └─ FirebaseRepositoryAdapter
```

---

## 8. Migration Path

| Step | Description | Dependencies |
|---|---|---|
| **1** | Refactor `RepositoryResolver`: extract `readConfig()` as a separate static method; keep `resolve()` backward-compatible. | None |
| **2** | Add `DATA_SOURCE` env var support in `main.dart` with `const dataSourceType = String.fromEnvironment(...)`. | Step 1 |
| **3** | Add `cloud_firestore` dependency to `pubspec.yaml`. | None |
| **4** | Implement `FirebaseDataSource` in `lib/domain/data_sources/`. | Step 2 |
| **5** | Implement `FirebaseRepositoryAdapter` in `lib/domain/repositories/`. | Step 2 |
| **6** | Add Firebase project config files (`google-services.json`, `GoogleService-Info.plist`) per platform. | Step 3 |
| **7** | Test with Firebase Emulator Suite (`firebase emulators:start`). | Steps 4–6 |
| **8** | Update `domain-deployment.md` with Firebase setup instructions. | Step 7 |

---

## 9. Risks

| Risk | Severity | Mitigation |
|---|---|---|
| **Firestore latency for schema discovery** — `discoverTypes()` runs multiple queries at startup; high latency blocks the UI tree. | Medium | Cache `List<TypeDescriptor>` in memory after the first `discoverTypes()` call. Invalidate cache only when schema changes (use a `last_updated` timestamp doc or Firebase Remote Config trigger). |
| **Offline support** — if the app starts without connectivity, Firestore queries fail. | High | Enable `FirebaseFirestore.instance.settings = Settings(persistenceEnabled: true)`. Firestore caches recently-read documents on disk. The schema cache (above) also mitigates this for the ontology. |
| **Firestore cost** — every property read/write incurs a document read/write cost. | Low | Property data is already document-sized (one doc per node). Element/alarm/event lists are sub-collections; paginate if needed. Monitor usage in Firebase Console. |
| **Security Rules** — Firestore must be open enough for the app but not globally open. | Medium | Use Firebase App Check + Security Rules that validate request origin. Document the required rules in `domain-deployment.md`. |
| **No existing Firebase project** — infra setup is a precondition. | Low | Create one Firebase project per environment (dev, staging, prod). Document the setup steps. |

---

## 10. Effort Estimate

| Step | Estimated Time | Notes |
|---|---|---|
| 1. Refactor `RepositoryResolver` | 0.5 day | Pure Dart refactor, no new deps |
| 2. Env var in `main.dart` | 0.25 day | Three-line conditional |
| 3. Add `cloud_firestore` dep | 0.1 day | `flutter pub add cloud_firestore` |
| 4. Implement `FirebaseDataSource` | 1 day | Data mapping mirrors `SqliteDataSource._buildType` |
| 5. Implement `FirebaseRepositoryAdapter` | 1 day | Six methods; watch uses `.snapshots()` |
| 6. Firebase project + config files | 1 day | Per-platform setup, rule deployment |
| 7. Firebase Emulator testing | 1 day | Seed schema + data via admin SDK |
| 8. Documentation | 0.5 day | Update `domain-deployment.md` |
| **Total** | **~5 days** | One developer, serial execution |

Estimates assume familiarity with Firebase Firestore and Flutter. Parallelisable steps (e.g. steps 4 & 5 can proceed in tandem after step 2).
