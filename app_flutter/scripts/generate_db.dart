import 'dart:io';
import 'package:path/path.dart' as p;
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

Future<void> main(List<String> args) async {
  sqfliteFfiInit();
  databaseFactory = databaseFactoryFfi;

  final outputPath = args.isNotEmpty
      ? args[0]
      : p.join(Directory.current.path, 'assets', 'properties_db.db');

  final dir = Directory(p.dirname(outputPath));
  if (!await dir.exists()) {
    await dir.create(recursive: true);
  }

  if (await File(outputPath).exists()) {
    await databaseFactory.deleteDatabase(outputPath);
  }

  print('Creating database at: $outputPath');
  final db = await databaseFactory.openDatabase(outputPath);

  await db.execute('''
    CREATE TABLE IF NOT EXISTS properties (
      node_id TEXT PRIMARY KEY,
      data_json TEXT NOT NULL
    )
  ''');

  await db.execute('''
    CREATE TABLE IF NOT EXISTS elements (
      id TEXT PRIMARY KEY,
      parent_node_id TEXT NOT NULL,
      name TEXT NOT NULL,
      type TEXT NOT NULL,
      status TEXT NOT NULL
    )
  ''');

  await db.execute('''
    CREATE TABLE IF NOT EXISTS alarms (
      id TEXT PRIMARY KEY,
      parent_node_id TEXT NOT NULL,
      target TEXT NOT NULL,
      severity TEXT NOT NULL,
      timestamp TEXT NOT NULL
    )
  ''');

  await db.execute('''
    CREATE TABLE IF NOT EXISTS events (
      id TEXT PRIMARY KEY,
      parent_node_id TEXT NOT NULL,
      source TEXT NOT NULL,
      message TEXT NOT NULL,
      timestamp TEXT NOT NULL
    )
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

  await db.close();

  final fullPath = File(outputPath).absolute.path;
  final size = File(outputPath).lengthSync();
  print('Database generated: $fullPath ($size bytes)');
}
