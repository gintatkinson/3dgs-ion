# Code Review: Local Database, Schema Validators & Firebase Adapters

This review evaluates the code quality, correctness, security, performance, architecture, testing, and documentation of the 11 domain files under `app_flutter/lib/domain/`.

---

## 🔴 Critical Severity

### 1. Missing Tree and Topology Implementations in Firebase Adapter
- **Tracking Issue**: [GitHub Issue #63](https://github.com/gintatkinson/3dgs-002/issues/63)
- **Severity**: 🔴 Critical
- **Location**: [firebase_data_source.dart](file:///Users/perkunas/jail/3dgs-002/app_flutter/lib/domain/data_sources/firebase_data_source.dart#L255-L267)
- **Issue**: `fetchRootNodes()`, `fetchChildrenForNode()`, and `fetchTopologyData()` are empty stubs returning empty lists or static empty models. If the application is configured to run with the `'firebase'` datasource, the sidebar tree navigation and the interactive topology map will be completely empty and broken.
- **Suggestion**: Implement the actual Firestore query logic to retrieve these structures from the backend database, mirroring the SQLite functionality.
- **Example**:
  ```dart
  @override
  Future<List<TreeNode>> fetchRootNodes() async {
    final snapshot = await _firestore
        .collection('data')
        .where('parent_node_id', isNull: true)
        .get();
    return snapshot.docs.map((doc) {
      final data = doc.data();
      return TreeNode(
        id: doc.id,
        label: data['name']?.toString() ?? doc.id.replaceAll('_', ' '),
        children: const [], // Load children lazily
      );
    }).toList();
  }
  ```

### 2. Platform Class Crashes on Flutter Web
- **Tracking Issue**: [GitHub Issue #60](https://github.com/gintatkinson/3dgs-002/issues/60)
- **Severity**: 🔴 Critical
- **Location**: [repository_resolver.dart:114](file:///Users/perkunas/jail/3dgs-002/app_flutter/lib/domain/repository_resolver.dart#L114), [database_initializer.dart:51](file:///Users/perkunas/jail/3dgs-002/app_flutter/lib/domain/database_initializer.dart#L51)
- **Issue**: Direct calls to `Platform.environment` and `Platform.isWindows`/`isLinux`/`isMacOS` from `dart:io` throw an `Unsupported operation: Platform._environment` exception on Flutter Web at startup. Since `RepositoryResolver.resolve` is called globally on app launch, this crash blocks the app from initializing on web even if SQLite is not selected.
- **Suggestion**: Use `kIsWeb` from `package:flutter/foundation.dart` to guard all `Platform` property reads.
- **Example**:
  ```dart
  import 'package:flutter/foundation.dart' show kIsWeb;
  // ...
  final isTest = !kIsWeb && Platform.environment.containsKey('FLUTTER_TEST');
  if (!kIsWeb && (isTest || Platform.isWindows || Platform.isLinux || Platform.isMacOS)) {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  }
  ```

---

## 🟠 Important Severity

### 3. Local-Only Stream Broadcasts in Firebase Adapter
- **Tracking Issue**: [GitHub Issue #72](https://github.com/gintatkinson/3dgs-002/issues/72)
- **Severity**: 🟠 Important
- **Location**: [firebase_data_source.dart:168-175](file:///Users/perkunas/jail/3dgs-002/app_flutter/lib/domain/data_sources/firebase_data_source.dart#L168-L175)
- **Issue**: `watchProperties` listens to an in-memory `StreamController` populated only when local writes happen via `saveProperties`. It does not listen to Firestore database snapshots. Consequently, real-time sync across different clients/devices is broken.
- **Suggestion**: Leverage Firestore's native real-time updates via document snapshots.
- **Example**:
  ```dart
  @override
  Stream<Map<String, dynamic>> watchProperties(String nodeId) {
    return _firestore
        .collection('data')
        .doc(nodeId)
        .snapshots()
        .map((snapshot) => snapshot.data() ?? {});
  }
  ```

### 4. High Firestore Read Latency & Billing Overhead
- **Tracking Issue**: [GitHub Issue #73](https://github.com/gintatkinson/3dgs-002/issues/73)
- **Severity**: 🟠 Important
- **Location**: [firebase_data_source.dart:82-93](file:///Users/perkunas/jail/3dgs-002/app_flutter/lib/domain/data_sources/firebase_data_source.dart#L82-L93)
- **Issue**: `typeFor` performs a full network fetch of the schema types document via `discoverTypes()` on every call, running a linear scan `O(N)`. This causes excessive billing costs and network latency.
- **Suggestion**: Cache the schema in-memory after the initial load.
- **Example**:
  ```dart
  List<TypeDescriptor>? _cachedTypes;

  @override
  Future<List<TypeDescriptor>> discoverTypes() async {
    if (_cachedTypes != null) return _cachedTypes!;
    // ... perform fetch ...
    _cachedTypes = types;
    return types;
  }
  ```

### 5. Hardcoded Mock Data Patterns Leaked into SQLite Queries
- **Tracking Issue**: [GitHub Issue #113](docs/reviews/review_database_domain.md)
- **Severity**: 🟠 Important
- **Location**: [sqlite_data_source.dart:266-270](file:///Users/perkunas/jail/3dgs-002/app_flutter/lib/domain/data_sources/sqlite_data_source.dart#L266-L270)
- **Issue**: Database queries in `fetchChildrenForNode` hardcode specific demo node type names (`'Detail_A'`, `'Detail_B'`, `'Detail_C'`) and naming conventions (`LIKE '%_Child_%'`). This breaks the domain-agnostic capability of the database adapter.
- **Suggestion**: Generalize the queries to use the schema metadata structure (e.g., filtering children based on the `type_relations` table) rather than hardcoded string filters.

### 6. Architectural Purity Violations (Circular/Leaked Dependencies)
- **Tracking Issue**: [GitHub Issue #114](docs/reviews/review_database_domain.md)
- **Severity**: 🟠 Important
- **Location**: [data_source.dart:1-8](file:///Users/perkunas/jail/3dgs-002/app_flutter/lib/domain/data_source.dart#L1-L8), [icon_mapper.dart:1](file:///Users/perkunas/jail/3dgs-002/app_flutter/lib/domain/icon_mapper.dart#L1), [column_model.dart:3](file:///Users/perkunas/jail/3dgs-002/app_flutter/lib/domain/column_model.dart#L3)
- **Issue**: The `domain` layer contains direct dependencies on presentation concepts (`TreeNode`, `TopologyData`, `IconData` and `package:flutter/material.dart`). This couples the domain layers tightly to the UI layer and makes it harder to run headless tests or swap styling frameworks.
- **Suggestion**: 
  - Store layout and presentation configurations as generic domain models (e.g. `ColumnDefinition`, icon name strings).
  - Perform mapping from domain entities to UI models (like `TreeNode` or `IconData`) in the presentation or feature layer.

### 7. Overly Restrictive Unique Constraint on Type Relations
- **Tracking Issue**: [GitHub Issue #115](docs/reviews/review_database_domain.md)
- **Severity**: 🟠 Important
- **Location**: [database_initializer.dart:127](file:///Users/perkunas/jail/3dgs-002/app_flutter/lib/domain/database_initializer.dart#L127)
- **Issue**: `type_relations` defines a `UNIQUE(parent_type_name, child_type_name)` constraint. This prevents a parent type from having multiple relations to the same child type (e.g., a `substation` node containing both a `primary_transformer` and a `secondary_transformer` relation of the same type `transformer`).
- **Suggestion**: Incorporate `relation_name` into the uniqueness constraint.
- **Example**:
  ```sql
  UNIQUE(parent_type_name, relation_name, child_type_name)
  ```

---

## 🟡 Suggestion Severity

### 8. Regular Expression Re-compilation Performance Hotspot
- **Tracking Issue**: [GitHub Issue #116](docs/reviews/review_database_domain.md)
- **Severity**: 🟡 Suggestion
- **Location**: [instance_record.dart:128](file:///Users/perkunas/jail/3dgs-002/app_flutter/lib/domain/instance_record.dart#L128)
- **Issue**: During batch schema validation, compiling a new `RegExp` object inside a hot loop (`for (final fd in fields)`) triggers high CPU usage and garbage collection overhead.
- **Suggestion**: Cache compiled patterns or pre-compile schemas.
- **Example**:
  ```dart
  static final Map<String, RegExp> _compiledRegexes = {};

  RegExp _getOrCreateRegExp(String pattern) {
    return _compiledRegexes[pattern] ??= RegExp(pattern);
  }
  ```

### 9. Redundant String Conversions in Validator
- **Tracking Issue**: [GitHub Issue #117](docs/reviews/review_database_domain.md)
- **Severity**: 🟡 Suggestion
- **Location**: [instance_record.dart:92-115](file:///Users/perkunas/jail/3dgs-002/app_flutter/lib/domain/instance_record.dart#L92-L115)
- **Issue**: If a field's value is already parsed as `int` or `double` within the attributes map, the validator converts it to a string (`value.toString()`) and parses it again.
- **Suggestion**: Perform direct type checking first.
- **Example**:
  ```dart
  if (fd.type == 'int') {
    final parsed = value is int ? value : int.tryParse(strVal);
    // ...
  }
  ```

### 10. Failed Map Type Casting on jsonDecode
- **Tracking Issue**: [GitHub Issue #118](docs/reviews/review_database_domain.md)
- **Severity**: 🟡 Suggestion
- **Location**: [instance_record.dart:44](file:///Users/perkunas/jail/3dgs-002/app_flutter/lib/domain/instance_record.dart#L44)
- **Issue**: `decoded is Map<String, dynamic>` check fails if `jsonDecode` returns a `Map<dynamic, dynamic>`.
- **Suggestion**: Use `Map.from()` to cast dynamic maps safely.
- **Example**:
  ```dart
  if (decoded is Map) {
    attrs = Map<String, dynamic>.from(decoded);
  }
  ```

### 11. Dead Code: Obsolete AttributeDefinition Class
- **Tracking Issue**: [GitHub Issue #119](docs/reviews/review_database_domain.md)
- **Severity**: 🟡 Suggestion
- **Location**: [schema.dart:1-56](file:///Users/perkunas/jail/3dgs-002/app_flutter/lib/domain/schema.dart#L1-L56)
- **Issue**: The `AttributeDefinition` class in `schema.dart` is not imported or used anywhere in the Flutter app source files; it is fully superseded by `FieldDescriptor`.
- **Suggestion**: Remove `schema.dart` to prevent code rot.

---

## 💡 Nitpick Severity

### 12. Top-Level main() Entrypoint in Library File
- **Tracking Issue**: [GitHub Issue #124](docs/reviews/review_database_domain.md)
- **Severity**: 💡 Nitpick
- **Location**: [database_initializer.dart:8-27](file:///Users/perkunas/jail/3dgs-002/app_flutter/lib/domain/database_initializer.dart#L8-27)
- **Issue**: Placing a runnable `main()` script inside `lib/domain/` violates Dart package structure conventions.
- **Suggestion**: Move the script to a `tool/` directory (e.g. `tool/regenerate_db.dart`).

### 13. Swallowed Database Initializer Exceptions
- **Tracking Issue**: [GitHub Issue #125](docs/reviews/review_database_domain.md)
- **Severity**: 💡 Nitpick
- **Location**: [repository_resolver.dart:154-164](file:///Users/perkunas/jail/3dgs-002/app_flutter/lib/domain/repository_resolver.dart#L154-L164)
- **Issue**: Empty catch blocks (`catch (_) {}`) swallow asset load and unzip issues during database initialization, hindering error diagnostics.
- **Suggestion**: Print or log errors using a logger or `debugPrint`.
- **Example**:
  ```dart
  } catch (e, stack) {
    debugPrint('Database asset decompression failed: $e\n$stack');
  }
  ```

### 14. Unsafe Type Cast on Nested Map Lists
- **Severity**: 💡 Nitpick
- **Location**: [validation.dart:67](file:///Users/perkunas/jail/3dgs-002/app_flutter/lib/domain/validation.dart#L67)
- **Issue**: Accessing `unitList[i] as Map<String, dynamic>` throws an error if JSON parsing yield `_Map<dynamic, dynamic>`.
- **Suggestion**: Use `Map<String, dynamic>.from(...)` instead of direct casting.
