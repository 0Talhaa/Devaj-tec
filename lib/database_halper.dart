import 'package:path/path.dart';
// ignore: depend_on_referenced_packages
import 'package:sqflite/sqflite.dart';
// ignore: unused_import
import 'dart:convert';

class DatabaseHelper {
  static final DatabaseHelper instance = DatabaseHelper._init();
  static Database? _database;

  DatabaseHelper._init();

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDB('pos.db');
    return _database!;
  }

  Future<Database> _initDB(String filePath) async {
    final dbPath = await getDatabasesPath();
    final path = join(dbPath, filePath);

    return await openDatabase(
      path,
      version: 6, // 🔺 latest version
      onCreate: _createDB,
      onUpgrade: _onUpgrade,
    );
  }

  // Sirf pehli dafa tables create honge
  Future _createDB(Database db, int version) async {
    await db.execute('''
      CREATE TABLE tbl_connection_details (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        ip TEXT NOT NULL,
        serverName TEXT NOT NULL,
        dbName TEXT NOT NULL,
        username TEXT NOT NULL,
        password TEXT NOT NULL,
        port TEXT NOT NULL,
        tiltId TEXT,              -- 🔹 Correct spelling
        tiltName TEXT,
        deviceName TEXT,
        isCashier INTEGER DEFAULT 0
      )
    ''');

    await db.execute('''
      CREATE TABLE tbl_orders (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        order_no TEXT,
        waiter_name TEXT,
        table_no INTEGER,
        customer_count INTEGER,
        total_amount REAL,
        order_date TEXT,
        items TEXT,
        quantities TEXT,
        comments TEXT
      )
    ''');

    await db.execute('''
      CREATE TABLE tbl_user (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        username TEXT NOT NULL,
        pwd TEXT NOT NULL
      )
    ''');

    await db.execute('''
      CREATE TABLE tbl_categories (
        id INTEGER PRIMARY KEY,
        category_name TEXT NOT NULL,
        is_tax_apply INTEGER NOT NULL
      )
    ''');

    await db.execute('''
      CREATE TABLE tbl_items (
        id INTEGER PRIMARY KEY,
        item_name TEXT NOT NULL,
        sale_price REAL NOT NULL,
        codes TEXT,
        category_name TEXT NOT NULL,
        is_tax_apply INTEGER NOT NULL
      )
    ''');
  }

  // Migration handler
  Future _onUpgrade(Database db, int oldVersion, int newVersion) async {
    if (oldVersion < 2) {
      await db.execute('''
        CREATE TABLE tbl_categories (
          id INTEGER PRIMARY KEY,
          category_name TEXT NOT NULL,
          is_tax_apply INTEGER NOT NULL
        )
      ''');
      await db.execute('''
        CREATE TABLE tbl_items (
          id INTEGER PRIMARY KEY,
          item_name TEXT NOT NULL,
          sale_price REAL NOT NULL,
          codes TEXT,
          category_name TEXT NOT NULL,
          is_tax_apply INTEGER NOT NULL
        )
      ''');
    }

    if (oldVersion < 3) {
      await db.execute("ALTER TABLE tbl_connection_details ADD COLUMN deviceName TEXT");
    }

    if (oldVersion < 4) {
      await db.execute("ALTER TABLE tbl_connection_details ADD COLUMN isCashier INTEGER DEFAULT 0");
    }

    if (oldVersion < 6) {
      await db.execute("ALTER TABLE tbl_connection_details ADD COLUMN tiltName TEXT");
    }
  }

  // Connection details save
Future<void> saveConnectionDetails({
  required String ip,
  required String serverName,
  required String dbName,
  required String username,
  required String password,
  required String port,
  required String tiltId,     // ✅ ye rakho
  required String tiltName,   // ✅ ye bhi rakho
  required String deviceName,
  required int isCashier,
}) async {
  final db = await instance.database;
  await db.insert(
    'tbl_connection_details',
    {
      'ip': ip,
      'serverName': serverName,
      'dbName': dbName,
      'username': username,
      'password': password,
      'port': port,
      'tiltId': tiltId,
      'tiltName': tiltName,
      'deviceName': deviceName,
      'isCashier': isCashier,
    },
    conflictAlgorithm: ConflictAlgorithm.replace,
  );
}


  Future<Map<String, dynamic>?> getConnectionDetails() async {
    final db = await instance.database;
    final result = await db.query('tbl_connection_details', limit: 1);
    return result.isNotEmpty ? result.first : null;
  }

  Future<void> saveCategories(List<Map<String, dynamic>> categories) async {
    final db = await instance.database;
    for (var category in categories) {
      final isTaxApply = category['is_tax_apply'] ?? 0;
      await db.insert(
        'tbl_categories',
        {
          'id': category['id'],
          'category_name': category['category_name'],
          'is_tax_apply': isTaxApply,
        },
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
    }
  }

  Future<List<Map<String, dynamic>>> getCategories() async {
    final db = await instance.database;
    return await db.query(
      'tbl_categories',
      columns: ['id', 'category_name'],
    );
  }

  Future<void> saveItems(List<Map<String, dynamic>> items) async {
    final db = await instance.database;
    for (var item in items) {
      await db.insert(
        'tbl_items',
        {
          'id': item['id'],
          'item_name': item['item_name'],
          'sale_price': item['sale_price'],
          'codes': item['codes'],
          'category_name': item['category_name'],
          'is_tax_apply': item['is_tax_apply'],
        },
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
    }
  }

  Future<List<Map<String, dynamic>>> getItems() async {
    final db = await instance.database;
    return await db.query(
      'tbl_items',
      columns: [
        'id',
        'item_name',
        'sale_price',
        'codes',
        'category_name',
        'is_tax_apply'
      ],
    );
  }

  Future<bool> isCategoriesTableEmpty() async {
    final db = await instance.database;
    final count = Sqflite.firstIntValue(
      await db.rawQuery('SELECT COUNT(*) FROM tbl_categories'),
    );
    return count == 0;
  }

  Future<bool> isItemsTableEmpty() async {
    final db = await instance.database;
    final count = Sqflite.firstIntValue(
      await db.rawQuery('SELECT COUNT(*) FROM tbl_items'),
    );
    return count == 0;
  }

  Future<void> clearTblUser() async {
    final db = await instance.database;
    await db.delete('tbl_user');
  }

  Future getData(String query) async {}
}
