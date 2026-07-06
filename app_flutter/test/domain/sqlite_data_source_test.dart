import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:app_flutter/domain/database_initializer.dart';
import 'package:app_flutter/domain/data_sources/sqlite_data_source.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  test('saveProperties preserves parent_node_id for child node on conflict/update', () async {
    // 1. Initialize an in-memory FFI database with schema created
    final db = await DatabaseInitializer.create(dbPath: inMemoryDatabasePath, seed: false);

    // 2. Insert parent and child nodes representing parent-child relation
    await db.insert('properties', {
      'node_id': 'parent_node',
      'parent_node_id': null,
      'data_json': '{}',
    });

    await db.insert('properties', {
      'node_id': 'child_node',
      'parent_node_id': 'parent_node',
      'data_json': '{}',
    });

    // Verify parent-child relation is correct initially
    final initialRows = await db.query(
      'properties',
      where: 'node_id = ?',
      whereArgs: ['child_node'],
    );
    expect(initialRows.first['parent_node_id'], equals('parent_node'));

    // 3. Initialize SqliteDataSource and invoke saveProperties for child node
    final dataSource = SqliteDataSource(db);
    await dataSource.saveProperties('child_node', {'field_1': 'new_value'});

    // 4. Assert that parent_node_id remains unchanged (i.e. 'parent_node' and not null)
    final afterRows = await db.query(
      'properties',
      where: 'node_id = ?',
      whereArgs: ['child_node'],
    );
    expect(afterRows.first['parent_node_id'], equals('parent_node'));

    await db.close();
  });

  test('database initialization creates idx_instances_parent_type and idx_instances_type_name indexes', () async {
    final db = await DatabaseInitializer.create(dbPath: inMemoryDatabasePath, seed: false);

    final results = await db.rawQuery(
      "SELECT name FROM sqlite_master WHERE type='index' AND name IN ('idx_instances_parent_type', 'idx_instances_type_name')"
    );

    final indexNames = results.map((row) => row['name'] as String).toList();
    expect(indexNames, contains('idx_instances_parent_type'));
    expect(indexNames, contains('idx_instances_type_name'));

    await db.close();
  });
}
