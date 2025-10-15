import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:path/path.dart';
import 'package:sqflite/sqflite.dart';
import 'package:sql_conn/sql_conn.dart';

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
      version: 9, // Incremented version to add default connection details
      onCreate: _createDB,
      onUpgrade: _onUpgrade,
    );
  }

  // Create all tables on database creation
  Future<void> _createDB(Database db, int version) async {
    await db.execute('''
      CREATE TABLE tbl_connection_details (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        ip TEXT NOT NULL,
        serverName TEXT NOT NULL,
        dbName TEXT NOT NULL,
        username TEXT NOT NULL,
        password TEXT NOT NULL,
        port TEXT NOT NULL,
        tiltId TEXT,
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

    await db.execute('''
      CREATE TABLE logged_in_user (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        username TEXT NOT NULL
      )
    ''');

    // Insert default connection details from logs
    await db.execute('''
      INSERT INTO tbl_connection_details (
        ip, serverName, dbName, username, password, port, tiltId, tiltName, deviceName, isCashier
      ) VALUES (
        '192.168.137.117', 'Your_Default_Server_Name', 'HNFOODMULTAN', 'sa', '123321Pa', '1433', '30', 'T2', 'Lenovo TB-X505F', 1
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
      await db.execute('ALTER TABLE tbl_connection_details ADD COLUMN deviceName TEXT');
    }

    if (oldVersion < 4) {
      await db.execute('ALTER TABLE tbl_connection_details ADD COLUMN isCashier INTEGER DEFAULT 0');
    }

    if (oldVersion < 6) {
      await db.execute('ALTER TABLE tbl_connection_details ADD COLUMN tiltName TEXT');
    }

    if (oldVersion < 8) {
      await db.execute('''
        CREATE TABLE IF NOT EXISTS logged_in_user (
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          username TEXT NOT NULL
        )
      ''');
    }

    if (oldVersion < 9) {
      await db.execute('''
        INSERT INTO tbl_connection_details (
          ip, serverName, dbName, username, password, port, tiltId, tiltName, deviceName, isCashier
        ) VALUES (
          '192.168.137.117', 'Your_Default_Server_Name', 'HNFOODMULTAN', 'sa', '123321Pa', '1433', '30', 'T2', 'Lenovo TB-X505F', 1
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
        'password': password,
        'port': port,
        'tiltId': tiltId,
        'tiltName': tiltName,
        'deviceName': deviceName,
        'isCashier': isCashier,
      },
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
    debugPrint('🟢 Saved connection details: ip=$ip, dbName=$dbName');
  }

  // Get connection details
  Future<Map<String, dynamic>?> getConnectionDetails() async {
    final db = await database;
    final result = await db.query('tbl_connection_details', limit: 1);
    if (result.isNotEmpty) {
      debugPrint('📥 Retrieved connection details: ${result.first}');
      return result.first;
    }
    debugPrint('⚠️ No connection details found, returning defaults');
    return {
      'ip': '192.168.137.117',
      'serverName': 'Your_Default_Server_Name',
      'dbName': 'HNFOODMULTAN',
      'username': 'sa',
      'password': '123321Pa',
      'port': '1433',
      'tiltId': '30',
      'tiltName': 'T2',
      'deviceName': 'Lenovo TB-X505F',
      'isCashier': 1,
    };
  }

  // Get status from postransectionsetting
  Future<String> getSQLPosTransactionSetting(String type) async {
    try {
      if (!await SqlConn.isConnected) {
        final defaultConn = await getConnectionDetails();
        if (defaultConn == null) {
          debugPrint('⚠️ No default connection details available');
          return "";
        }

        await SqlConn.connect(
          ip: defaultConn['ip'],
          port: defaultConn['port'],
          databaseName: defaultConn['dbName'],
          username: defaultConn['username'],
          password: defaultConn['password'],
          timeout: 10, // Added timeout for consistency
        );
      }

      final query = "SELECT status FROM postransectionsetting WHERE type = '$type'";
      final result = await SqlConn.readData(query);
      debugPrint("📝 SQL Query for $type: $query");
      debugPrint("📤 SQL Result for $type: $result");

      final data = jsonDecode(result) as List<dynamic>;
      if (data.isEmpty) {
        debugPrint('⚠️ No status found for type=$type in postransectionsetting');
        return "0"; // Default status for TakeAwayServer and TakeAwayCustomerInfo
      }

      return data[0]['status']?.toString() ?? "0";
    } catch (e) {
      debugPrint('❌ Error fetching status for type=$type: $e');
      return "0";
    } finally {
      await SqlConn.disconnect();
    }
  }

  // Get combined TakeAway settings
  Future<Map<String, dynamic>?> getTakeAwaySettings() async {
    try {
      final connDetails = await getConnectionDetails();
      if (connDetails == null) {
        debugPrint('⚠️ No connection details available for TakeAway settings');
        return null;
      }

      final serverStatus = await getSQLPosTransactionSetting('TakeAwayServer');
      final customerStatus = await getSQLPosTransactionSetting('TakeAwayCustomerInfo');

      final settings = {
        'ip': connDetails['ip'],
        'port': connDetails['port'],
        'dbName': connDetails['dbName'],
        'username': connDetails['username'],
        'password': connDetails['password'],
        'tiltId': connDetails['tiltId'],
        'tiltName': connDetails['tiltName'],
        'deviceName': connDetails['deviceName'],
        'isPrintKot': 1,
        'defaultCustomerName': 'WalkIn',
        'defaultPhone': '',
        'defaultAddress': '',
        'requireAddress': customerStatus == '1',
        'serverStatus': serverStatus,
        'customerStatus': customerStatus,
      };

      debugPrint('✅ TakeAway Settings: $settings');
      return settings;
    } catch (e) {
      debugPrint('❌ Error fetching TakeAway settings: $e');
      return {
        'ip': '192.168.137.117',
        'port': '1433',
        'dbName': 'HNFOODMULTAN',
        'username': 'sa',
        'password': '123321Pa',
        'tiltId': '30',
        'tiltName': 'T2',
        'deviceName': 'Lenovo TB-X505F',
        'isPrintKot': 1,
        'defaultCustomerName': 'WalkIn',
        'defaultPhone': '',
        'defaultAddress': '',
        'requireAddress': true,
        'serverStatus': '0',
        'customerStatus': '0',
      };
    }
  }

  // Get connection details from postransectionsetting
  Future<Map<String, dynamic>?> getConnectionDetailsFromPostransectionSetting(String type) async {
    try {
      if (!await SqlConn.isConnected) {
        final defaultConn = await getConnectionDetails();
        if (defaultConn == null) {
          debugPrint('⚠️ No default connection details available');
          return null;
        }

        await SqlConn.connect(
          ip: defaultConn['ip'],
          port: defaultConn['port'],
          databaseName: defaultConn['dbName'],
          username: defaultConn['username'],
          password: defaultConn['password'],
          timeout: 10,
        );
      }

      final query = "SELECT status FROM postransectionsetting WHERE type = '$type'";
      final result = await SqlConn.readData(query);
      debugPrint("📝 SQL Query for $type: $query");
      debugPrint("📤 SQL Result for $type: $result");

      final data = jsonDecode(result) as List<dynamic>;
      if (data.isEmpty) {
        debugPrint('⚠️ No data found for type=$type in postransectionsetting');
        return {'status': '0'};
      }

      return {'status': data[0]['status']?.toString() ?? '0'};
    } catch (e) {
      debugPrint('❌ Error fetching postransectionsetting for type=$type: $e');
      return {'status': '0'};
    } finally {
      await SqlConn.disconnect();
    }
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
    debugPrint('🟢 Saved ${categories.length} categories');
  }

  // Get categories
  Future<List<Map<String, dynamic>>> getCategories() async {
    final db = await database;
    final result = await db.query(
      'tbl_categories',
      columns: ['id', 'category_name', 'is_tax_apply'],
    );
    debugPrint('📥 Retrieved ${result.length} categories');
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
    debugPrint('🟢 Saved ${items.length} items');
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
    debugPrint('📥 Retrieved ${result.length} items');
    return result;
  }

  // Check if tables are empty
  Future<bool> isCategoriesTableEmpty() async {
    final db = await database;
    final count = Sqflite.firstIntValue(
      await db.rawQuery('SELECT COUNT(*) FROM tbl_categories'),
    );
    debugPrint('📊 Categories table count: $count');
    return count == 0;
  }

  Future<bool> isItemsTableEmpty() async {
    final db = await database;
    final count = Sqflite.firstIntValue(
      await db.rawQuery('SELECT COUNT(*) FROM tbl_items'),
    );
    debugPrint('📊 Items table count: $count');
    return count == 0;
  }

  // Clear user and connection data
  Future<void> clearTblUser() async {
    final db = await database;
    await db.delete('tbl_user');
    debugPrint('🧹 Cleared tbl_user');
  }

  Future<void> clearConnectionDetails() async {
    final db = await database;
    await db.delete('tbl_connection_details');
    debugPrint('🧹 Cleared tbl_connection_details');
  }

  // Save logged-in user
  Future<void> saveLoggedInUser(String username) async {
    final db = await database;
    await db.delete('logged_in_user');
    await db.insert('logged_in_user', {'username': username});
    debugPrint('🟢 User saved locally: $username');
  }

  // Get logged-in user
  Future<String?> getLoggedInUser() async {
    final db = await database;
    final result = await db.query('logged_in_user');
    if (result.isNotEmpty) {
      debugPrint('📦 Current logged-in user: ${result.first['username']}');
      return result.first['username'] as String;
    }
    debugPrint('⚠️ No logged-in user found.');
    return null;
  }

  // Clear logged-in user
  Future<void> clearLoggedInUser() async {
    final db = await database;
    await db.delete('logged_in_user');
    debugPrint('🧹 Logged-in user cleared');
  }

  // Run custom SQL query
  Future<List<Map<String, dynamic>>> getData(String query) async {
    final db = await database;
    try {
      final result = await db.rawQuery(query);
      debugPrint('📊 Query executed successfully: $query');
      return result;
    } catch (e) {
      debugPrint('❌ Error executing query: $e');
      return [];
    }
  }

  // Close database
  Future<void> close() async {
    final db = _database;
    if (db != null) {
      await db.close();
      _database = null;
      debugPrint('🛑 Database closed');
    }
    if (await SqlConn.isConnected) {
      await SqlConn.disconnect();
      debugPrint('🛑 SQL Server connection closed');
    }
  }
}