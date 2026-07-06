import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

Future<void> main() async {
  sqfliteFfiInit();
  databaseFactory = databaseFactoryFfi;
  final dbPath = 'assets/properties_db.db';
  final file = File(dbPath);
  if (await file.exists()) {
    await file.delete();
  }
  await DatabaseInitializer.create(dbPath: dbPath, seed: true);
  print('Generic database properties_db.db regenerated successfully.');

  final gzFile = File('assets/properties_db.db.gz');
  if (await gzFile.exists()) {
    await gzFile.delete();
  }
  final bytes = await file.readAsBytes();
  final gzipped = gzip.encode(bytes);
  await gzFile.writeAsBytes(gzipped);
  print('Database gzipped to properties_db.db.gz successfully.');
}

/// Creates and optionally seeds a local SQLite database for development
/// and testing.
///
/// Generates the full schema (`properties`, `instances`, `type_definitions`,
/// `type_attributes`, `type_relations`) and populates sample data when [seed] is true.
/// Used at app startup when no pre-built database asset exists, or when running in CI/testing environments.
///
/// Call [create] once before any repository operation. The returned
/// [Database] is shared across [SqliteDataSource]. Do not call [create] multiple times for the
/// same path — it reopens the same file and re-runs `CREATE TABLE IF NOT
/// EXISTS`, which is safe but wasteful.
class DatabaseInitializer {
  /// Opens (or creates) the database and ensures all tables exist.
  ///
  /// If [dbPath] is null, the database is placed in the app support
  /// directory as `properties_db.db`. When [seed] is true and the
  /// `properties` table is empty, sample data is inserted. Idempotent for the tables (uses `CREATE TABLE IF NOT
  /// EXISTS`) but NOT for seeding (checks row count first).
  ///
  /// Throws on I/O errors (path resolution, file creation) or SQL
  /// execution failures.
  static Future<Database> create({String? dbPath, bool seed = true}) async {
    final isTest = !kIsWeb && Platform.environment.containsKey('FLUTTER_TEST');
    if (!kIsWeb && (isTest || Platform.isWindows || Platform.isLinux || Platform.isMacOS)) {
      sqfliteFfiInit();
      databaseFactory = databaseFactoryFfi;
    }

    final String path;
    if (kIsWeb) {
      path = dbPath ?? inMemoryDatabasePath;
    } else {
      path = dbPath != null
          ? (dbPath == inMemoryDatabasePath ? dbPath : p.absolute(dbPath))
          : p.join(
              (await getApplicationSupportDirectory()).path,
              'properties_db.db',
            );
    }

    final db = await databaseFactory.openDatabase(path);
    await db.execute('PRAGMA journal_mode = WAL;');
    await db.execute('PRAGMA busy_timeout = 5000;');
    await db.execute('PRAGMA foreign_keys = ON;');

    await db.execute('''
      CREATE TABLE IF NOT EXISTS properties (
        node_id TEXT PRIMARY KEY,
        parent_node_id TEXT REFERENCES properties(node_id),
        data_json TEXT NOT NULL
      )
    ''');

    await db.execute('''
      CREATE INDEX IF NOT EXISTS idx_properties_parent_node_id
      ON properties(parent_node_id);
    ''');

    await db.execute('''
      CREATE TABLE IF NOT EXISTS instances (
        id TEXT PRIMARY KEY,
        parent_node_id TEXT NOT NULL,
        type_name TEXT NOT NULL,
        data_json TEXT NOT NULL
      )
    ''');

    await db.execute('''
      CREATE INDEX IF NOT EXISTS idx_instances_parent_type
      ON instances(parent_node_id, type_name);
    ''');

    await db.execute('''
      CREATE INDEX IF NOT EXISTS idx_instances_type_name
      ON instances(type_name);
    ''');

    await db.execute('''
      CREATE TABLE IF NOT EXISTS type_definitions (
        type_name TEXT PRIMARY KEY,
        display_name TEXT NOT NULL,
        icon_name TEXT NOT NULL DEFAULT 'insert_drive_file'
      )
    ''');

    await db.execute('''
      CREATE TABLE IF NOT EXISTS type_attributes (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        type_name TEXT NOT NULL REFERENCES type_definitions(type_name),
        attr_key TEXT NOT NULL,
        label TEXT NOT NULL,
        attr_type TEXT NOT NULL,
        section_label TEXT,
        section_order INTEGER NOT NULL DEFAULT 0,
        is_required INTEGER NOT NULL DEFAULT 0,
        min_value REAL,
        max_value REAL,
        pattern TEXT,
        enum_options TEXT,
        enum_display_names TEXT,
        default_value TEXT,
        input_formatters TEXT,
        UNIQUE(type_name, attr_key)
      )
    ''');

    await db.execute('''
      CREATE TABLE IF NOT EXISTS type_relations (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        parent_type_name TEXT NOT NULL REFERENCES type_definitions(type_name),
        relation_name TEXT NOT NULL,
        child_type_name TEXT NOT NULL REFERENCES type_definitions(type_name),
        child_label TEXT NOT NULL,
        UNIQUE(parent_type_name, child_type_name)
      )
    ''');

    if (seed) {
      final countResult =
          await db.rawQuery('SELECT COUNT(*) as count FROM type_definitions');
      final count = countResult.first['count'] as int? ?? 0;
      if (count == 0) {
        await _seed(db);
      }
    }

    return db;
  }

  /// Inserts sample data.
  static Future<void> _seed(Database db) async {
    final details = ['Detail_A', 'Detail_B', 'Detail_C'];
    for (final d in details) {
      await db.insert('type_definitions', {
        'type_name': d,
        'display_name': d.replaceAll('_', ' '),
        'icon_name': 'widgets',
      });

      final attrBatch = db.batch();
      for (int i = 1; i <= 50; i++) {
        attrBatch.insert('type_attributes', {
          'type_name': d,
          'attr_key': 'field_$i',
          'label': 'Field $i',
          'attr_type': 'string',
          'section_label': 'General',
          'section_order': 0,
          'is_required': 0,
        });
      }
      await attrBatch.commit(noResult: true);
    }

    final isTest = !kIsWeb && Platform.environment.containsKey('FLUTTER_TEST');
    final int maxMasters = isTest ? 20 : 1000;
    for (int chunkStart = 0; chunkStart < maxMasters; chunkStart += 50) {
      final chunkEnd = (chunkStart + 50) > maxMasters ? maxMasters : (chunkStart + 50);
      final batch = db.batch();

      for (int i = chunkStart; i < chunkEnd; i++) {
        final m = 'Master_${i + 1}';
        _addNodeToBatch(batch, m, null, details, isRoot: true);

        for (int c = 1; c <= 5; c++) {
          final child = '${m}_Child_$c';
          _addNodeToBatch(batch, child, m, details, isRoot: false);

          for (int g = 1; g <= 2; g++) {
            final gc = '${child}_Grandchild_$g';
            _addNodeToBatch(batch, gc, child, details, isRoot: false);
          }
        }
      }

      await batch.commit(noResult: true);
    }
  }

  static void _addNodeToBatch(Batch batch, String node, String? parent, List<String> details, {required bool isRoot}) {
    batch.insert('type_definitions', {
      'type_name': node,
      'display_name': node.replaceAll('_', ' '),
      'icon_name': 'insert_drive_file',
    });

    for (final d in details) {
      batch.insert('type_relations', {
        'parent_type_name': node,
        'relation_name': 'contains',
        'child_type_name': d,
        'child_label': d.replaceAll('_', ' '),
      });
    }

    for (int i = 1; i <= 50; i++) {
      batch.insert('type_attributes', {
        'type_name': node,
        'attr_key': 'field_$i',
        'label': 'Field $i',
        'attr_type': 'string',
        'section_label': 'General',
        'section_order': 0,
        'is_required': 0,
      });
    }

    final propertiesMap = {
      for (int j = 1; j <= 50; j++) 'field_$j': 'val_${node}_field_$j'
    };
    batch.insert('properties', {
      'node_id': node,
      'parent_node_id': parent,
      'data_json': jsonEncode(propertiesMap),
    });

    for (final d in details) {
      for (int k = 1; k <= 5; k++) {
        final instId = 'inst_${node}_${d}_$k';
        final instanceMap = {
          for (int j = 1; j <= 50; j++) 'field_$j': 'val_inst_${node}_${d}_${k}_field_$j'
        };
        batch.insert('instances', {
          'id': instId,
          'parent_node_id': node,
          'type_name': d,
          'data_json': jsonEncode(instanceMap),
        });
      }
    }
  }
}
