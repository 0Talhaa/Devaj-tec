import 'package:path/path.dart';
import 'package:sqflite/sqflite.dart';

class DatabaseHelper {
  static final DatabaseHelper instance = DatabaseHelper._init();
  static Database? _database;

  DatabaseHelper._init();

  // Get database instance, initializing if necessary
  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDB('pos.db');
    return _database!;
  }

  // Initialize database with path
  Future<Database> _initDB(String filePath) async {
    final dbPath = await getDatabasesPath();
    final path = join(dbPath, filePath);

    return await openDatabase(
      path,
      version: 8, // Current schema version
      onCreate: _createDB,
      onUpgrade: _onUpgrade,
    );
  }

  // Create all tables on database creation
  Future<void> _createDB(Database db, int version) async {
    // Connection details table
    await db.execute('''
      CREATE TABLE tbl_connection_details (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        ip TEXT NOT NULL,
        serverName TEXT NOT NULL,
        dbName TEXT NOT NULL,
        username TEXT NOT NULL,
        password TEXT NOT NULL, -- Consider encrypting in production
        port TEXT NOT NULL,
        tiltId TEXT,
        tiltName TEXT,
        deviceName TEXT,
        isCashier INTEGER DEFAULT 0
      )
    ''');

    // Orders table
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

    // User credentials table
    await db.execute('''
      CREATE TABLE tbl_user (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        username TEXT NOT NULL,
        pwd TEXT NOT NULL -- Consider encrypting in production
      )
    ''');

    // Categories table
    await db.execute('''
      CREATE TABLE tbl_categories (
        id INTEGER PRIMARY KEY,
        category_name TEXT NOT NULL,
        is_tax_apply INTEGER NOT NULL
      )
    ''');

    // Items table
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

    // Logged-in user table
    await db.execute('''
      CREATE TABLE logged_in_user (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        username TEXT NOT NULL
      )
    ''');
  }

  // Handle schema upgrades
  Future<void> _onUpgrade(Database db, int oldVersion, int newVersion) async {
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
      await db.execute(
        'ALTER TABLE tbl_connection_details ADD COLUMN deviceName TEXT',
      );
    }

    if (oldVersion < 4) {
      await db.execute(
        'ALTER TABLE tbl_connection_details ADD COLUMN isCashier INTEGER DEFAULT 0',
      );
    }

    if (oldVersion < 6) {
      await db.execute(
        'ALTER TABLE tbl_connection_details ADD COLUMN tiltName TEXT',
      );
    }

    if (oldVersion < 8) {
      await db.execute('''
        CREATE TABLE IF NOT EXISTS logged_in_user (
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          username TEXT NOT NULL
        )
      ''');
    }
  }

  // Save connection details
  Future<void> saveConnectionDetails({
    required String ip,
    required String serverName,
    required String dbName,
    required String username,
    required String password,
    required String port,
    required String tiltId,
    required String tiltName,
    required String deviceName,
    required int isCashier,
  }) async {
    final db = await database;
    await db.insert(
      'tbl_connection_details',
      {
        'ip': ip,
        'serverName': serverName,
        'dbName': dbName,
        'username': username,
        'password': password, // Security note: Consider flutter_secure_storage
        'port': port,
        'tiltId': tiltId,
        'tiltName': tiltName,
        'deviceName': deviceName,
        'isCashier': isCashier,
      },
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
    print('🟢 Saved connection details: ip=$ip, dbName=$dbName');
  }

  // Get connection details
  Future<Map<String, dynamic>?> getConnectionDetails() async {
    final db = await database;
    final result = await db.query('tbl_connection_details', limit: 1);
    if (result.isNotEmpty) {
      print('📥 Retrieved connection details: ${result.first}');
      return result.first;
    }
    print('⚠️ No connection details found.');
    return null;
  }

  // Save categories
  Future<void> saveCategories(List<Map<String, dynamic>> categories) async {
    final db = await database;
    final batch = db.batch();
    for (var category in categories) {
      final isTaxApply = category['is_tax_apply'] ?? 0;
      batch.insert(
        'tbl_categories',
        {
          'id': category['id'],
          'category_name': category['category_name'],
          'is_tax_apply': isTaxApply,
        },
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
    }
    await batch.commit(noResult: true);
    print('🟢 Saved ${categories.length} categories');
  }

  // Get categories
  Future<List<Map<String, dynamic>>> getCategories() async {
    final db = await database;
    final result = await db.query(
      'tbl_categories',
      columns: ['id', 'category_name', 'is_tax_apply'],
    );
    print('📥 Retrieved ${result.length} categories');
    return result;
  }

  // Save items
  Future<void> saveItems(List<Map<String, dynamic>> items) async {
    final db = await database;
    final batch = db.batch();
    for (var item in items) {
      batch.insert(
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
    await batch.commit(noResult: true);
    print('🟢 Saved ${items.length} items');
  }

  // Get items
  Future<List<Map<String, dynamic>>> getItems() async {
    final db = await database;
    final result = await db.query(
      'tbl_items',
      columns: [
        'id',
        'item_name',
        'sale_price',
        'codes',
        'category_name',
        'is_tax_apply',
      ],
    );
    print('📥 Retrieved ${result.length} items');
    return result;
  }

  // Check if tables are empty
  Future<bool> isCategoriesTableEmpty() async {
    final db = await database;
    final count = Sqflite.firstIntValue(
      await db.rawQuery('SELECT COUNT(*) FROM tbl_categories'),
    );
    print('📊 Categories table count: $count');
    return count == 0;
  }

  Future<bool> isItemsTableEmpty() async {
    final db = await database;
    final count = Sqflite.firstIntValue(
      await db.rawQuery('SELECT COUNT(*) FROM tbl_items'),
    );
    print('📊 Items table count: $count');
    return count == 0;
  }

  // Clear user and connection data
  Future<void> clearTblUser() async {
    final db = await database;
    await db.delete('tbl_user');
    print('🧹 Cleared tbl_user');
  }

  Future<void> clearConnectionDetails() async {
    final db = await database;
    await db.delete('tbl_connection_details');
    print('🧹 Cleared tbl_connection_details');
  }

  // Save logged-in user
  Future<void> saveLoggedInUser(String username) async {
    final db = await database;
    await db.delete('logged_in_user'); // Clear previous user
    await db.insert('logged_in_user', {'username': username});
    print('🟢 User saved locally: $username');
  }

  // Get logged-in user
  Future<String?> getLoggedInUser() async {
    final db = await database;
    final result = await db.query('logged_in_user');
    if (result.isNotEmpty) {
      print('📦 Current logged-in user: ${result.first['username']}');
      return result.first['username'] as String;
    }
    print('⚠️ No logged-in user found.');
    return null;
  }

  // Clear logged-in user (for logout)
  Future<void> clearLoggedInUser() async {
    final db = await database;
    await db.delete('logged_in_user');
    print('🧹 Logged-in user cleared');
  }

  // Run custom SQL query and return result
  Future<List<Map<String, dynamic>>> getData(String query) async {
    final db = await database;
    try {
      final result = await db.rawQuery(query);
      print('📊 Query executed successfully: $query');
      return result;
    } catch (e) {
      print('❌ Error executing query: $e');
      return [];
    }
  }

  // Close database (optional, as sqflite manages it)
  Future<void> close() async {
    final db = _database;
    if (db != null) {
      await db.close();
      _database = null;
      print('🛑 Database closed');
    }
  }
}