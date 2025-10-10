// ignore_for_file: unused_local_variable, unused_element, use_build_context_synchronously

import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:mssql_connection/mssql_connection.dart';
import 'package:start_app/database_halper.dart';
import 'package:sql_conn/sql_conn.dart';
import 'package:start_app/bill_screen.dart';
import 'package:intl/intl.dart';

// Constants for map keys
class OrderConstants {
  static const String itemId = 'itemid';
  static const String itemName = 'item_name';
  static const String salePrice = 'sale_price';
  static const String quantity = 'quantity';
  static const String taxPercent = 'tax_percent';
  static const String discountPercent = 'discount_percent';
  static const String comments = 'Comments';
}

// Model class for OrderItem
class OrderItem {
  final String itemId;
  final String itemName;
  final double salePrice;
  final int quantity;
  final double taxPercent;
  final double discountPercent;
  final String comments;
  final String orderDetailId;

  OrderItem({
    required this.itemId,
    required this.itemName,
    required this.salePrice,
    required this.quantity,
    required this.taxPercent,
    required this.discountPercent,
    required this.comments,
    this.orderDetailId = '0',
  });

  factory OrderItem.fromMap(Map<String, dynamic> map) {
    return OrderItem(
      itemId: map[OrderConstants.itemId]?.toString() ?? '0',
      itemName: map[OrderConstants.itemName] ?? 'Unknown',
      salePrice: double.tryParse(map[OrderConstants.salePrice]?.toString() ?? '0') ?? 0.0,
      quantity: (double.tryParse(map[OrderConstants.quantity]?.toString() ?? '0') ?? 0).toInt(),
      taxPercent: double.tryParse(map[OrderConstants.taxPercent]?.toString() ?? '0') == 0.0
          ? 5.0
          : double.tryParse(map[OrderConstants.taxPercent]?.toString() ?? '5.0') ?? 5.0,
      discountPercent: double.tryParse(map[OrderConstants.discountPercent]?.toString() ?? '0') ?? 0.0,
      comments: map[OrderConstants.comments]?.toString() ?? '',
      orderDetailId: map['orderDetailId']?.toString() ?? '0',
    );
  }

  Map<String, dynamic> toMap() {
    return {
      OrderConstants.itemId: itemId,
      OrderConstants.itemName: itemName,
      OrderConstants.salePrice: salePrice,
      OrderConstants.quantity: quantity,
      OrderConstants.taxPercent: taxPercent,
      OrderConstants.discountPercent: discountPercent,
      OrderConstants.comments: comments,
      'orderDetailId': orderDetailId,
    };
  }
}

final now = DateTime.now();
final formattedDate = DateFormat('yyyy-MM-dd HH:mm:ss').format(now);

class OrderScreen extends StatefulWidget {
  final int tableId;
  final String tableName;
  final String waiterName;
  final int customerCount;
  final int? selectedTiltId;
  final String? tabUniqueId;

  OrderScreen({
    required this.waiterName,
    required this.tableId,
    required this.tableName,
    required this.customerCount,
    required this.selectedTiltId,
    required this.tabUniqueId,
  });

  @override
  _OrderScreenState createState() => _OrderScreenState();
}

class _OrderScreenState extends State<OrderScreen> with TickerProviderStateMixin {
  late MssqlConnection _mssql;
  bool _isMssqlReady = false;
  bool _isLoading = true;
  Map<String, List<Map<String, dynamic>>> _categoryItems = {};
  List<Map<String, dynamic>> _categories = [];
  String? _selectedCategory;
  String _currentUser = "Admin";
  String _deviceNo = "POS01";
  int _isPrintKot = 1;
  Map<String, dynamic>? _connectionDetails;
  late TabController _tabController;
  List<OrderItem> _activeOrderItems = [];
  double _orderTotalAmount = 0.0;
  double _totalTax = 0.0;
  double _totalDiscount = 0.0;
  int? _finalTiltId;
  String? _finalTiltName;
  String? _tabUniqueId;

  @override
  void initState() {
    super.initState();
    _initConnectionAndLoadData();
    _loadConnectionDetails();
    _loadTiltFromLocal();
    _loadLoggedUser();
    _checkUser();
    if (widget.tabUniqueId != null && widget.tabUniqueId!.isNotEmpty) {
      _fetchExistingOrder(widget.tabUniqueId!);
    } else {
      _generateNewTabUniqueId();
    }
    _fetchMenuData();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadLoggedUser() async {
    final user = await DatabaseHelper.instance.getLoggedInUser();
    setState(() {
      _currentUser = user ?? "Admin";
    });
    debugPrint("✅ Current user: $_currentUser");
  }

  Future<void> _loadConnectionDetails() async {
    final connDetails = await DatabaseHelper.instance.getConnectionDetails();
    setState(() {
      _currentUser = connDetails?['user'] ?? 'Admin';
      _deviceNo = connDetails?['deviceName'] ?? 'POS01';
      _isPrintKot = connDetails?['isPrintKot'] ?? 1;
    });
  }

  Future<void> _initConnectionAndLoadData() async {
    await _setupSqlConn();
    await _loadData();
  }

  Future<void> _checkUser() async {
    final user = await DatabaseHelper.instance.getLoggedInUser();
    debugPrint(user != null ? "✅ Logged-in user: $user" : "❌ No user found.");
  }

  Future<void> _loadTiltFromLocal() async {
    final savedDetails = await DatabaseHelper.instance.getConnectionDetails();
    setState(() {
      _finalTiltId = int.tryParse(savedDetails?['tiltId'] ?? '0') ?? 0;
      _finalTiltName = savedDetails?['tiltName'] ?? '';
    });
    debugPrint("📥 Loaded Tilt => Id=$_finalTiltId, Name=$_finalTiltName");
  }

  Future<void> _fetchExistingOrder(String tabUniqueId) async {
    try {
      final conn = await DatabaseHelper.instance.getConnectionDetails();
      if (conn == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Connection details missing')),
        );
        return;
      }

      if (!await SqlConn.isConnected) {
        await SqlConn.connect(
          ip: conn['ip'],
          port: conn['port'],
          databaseName: conn['dbName'],
          username: conn['username'],
          password: conn['password'],
        );
      }

      final query = """
        SELECT DISTINCT 
          d.itemid AS itemid, 
          d.item_name, 
          d.qty, 
          d.Comments,
          (i.sale_price) AS item_unit_price,
          d.id AS orderDetailId, 
          d.tax AS tax,
          (SELECT KotStatus FROM OrderKot WHERE OrderDetailId=d.id) AS kotstatus,
          1 AS is_upload
        FROM order_detail d
        INNER JOIN dine_in_order m ON d.order_key = m.order_key
        INNER JOIN itempos i ON i.id = d.itemid
        WHERE m.tab_unique_id = '$tabUniqueId'
      """;

      final result = await SqlConn.readData(query);
      if (result.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('No items found for tabUniqueId=$tabUniqueId')),
        );
        return;
      }

      final decoded = jsonDecode(result) as List<dynamic>;
      debugPrint("🧩 Raw SQL Result: $result");
      setState(() {
        _activeOrderItems = decoded.map((row) {
          final qty = (double.tryParse(row["qty"]?.toString() ?? '0') ?? 0).toInt();
          final unitPrice = double.tryParse(row["item_unit_price"]?.toString() ?? '0') ?? 0.0;
          final tax = double.tryParse(row["tax"]?.toString() ?? '0') == 0.0
              ? 5.0
              : double.tryParse(row["tax"]?.toString() ?? '5.0') ?? 5.0;
          final discount = double.tryParse(row["discount"]?.toString() ?? '0') ?? 0.0;
          final itemId = row["itemid"]?.toString() ?? '0';
          final orderDetailId = row["orderDetailId"]?.toString() ?? '0';

          if (itemId == '0' || itemId.isEmpty) {
            debugPrint("⚠️ Warning: Invalid item ID for ${row['item_name']}");
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text('Invalid item ID for ${row['item_name']}')),
            );
            return null;
          }

          return OrderItem(
            itemId: itemId,
            itemName: row["item_name"] ?? 'Unknown',
            salePrice: unitPrice,
            quantity: qty,
            taxPercent: tax,
            discountPercent: discount,
            comments: row["Comments"]?.toString() ?? '',
            orderDetailId: orderDetailId,
          );
        }).where((item) => item != null).cast<OrderItem>().toList();
        _calculateTotalBill();
      });
      debugPrint("🧩 Loaded existing order: ${_activeOrderItems.length} items");
    } catch (e, stackTrace) {
      debugPrint('❌ Error fetching existing order: $e\n$stackTrace');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to fetch order: $e')),
      );
    }
  }

  void _generateNewTabUniqueId() {
    final now = DateTime.now();
    final formattedDate = DateFormat('yyyy-MM-dd HH:mm:ss').format(now);
    final tiltName = _finalTiltName ?? "T1";
    _tabUniqueId = "${tiltName}$formattedDate";
    debugPrint("🆕 Generated tab_unique_id => $_tabUniqueId");
    setState(() {
      _activeOrderItems = [];
    });
  }

  Future<void> _fetchMenuData() async {
    try {
      final categories = await DatabaseHelper.instance.getCategories();
      final items = await DatabaseHelper.instance.getItems();

      final Map<String, List<Map<String, dynamic>>> groupedData = {};
      for (var category in categories) {
        final categoryName = category['category_name'] as String;
        groupedData[categoryName] = items
            .where((item) =>
                item['category_name'] == categoryName &&
                item['id'] != null &&
                item['id'].toString() != '0')
            .toList();
      }

      setState(() {
        _categories = categories;
        _categoryItems = groupedData;
        if (_categories.isNotEmpty) {
          _selectedCategory = _categories[0]['category_name'];
          _tabController = TabController(length: _categories.length, vsync: this);
        }
      });
      debugPrint("📦 Menu Loaded: ${_categories.length} categories");
    } catch (e) {
      debugPrint("❌ Error fetching menu data: $e");
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Error loading menu: $e")),
      );
    }
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    try {
      final details = await DatabaseHelper.instance.getConnectionDetails();
      if (details == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
              content: Text('Database connection details not found.'),
              backgroundColor: Colors.red),
        );
        return;
      }
      _connectionDetails = details;
      await _fetchAndSaveDataLocally();
    } catch (e) {
      debugPrint('Error fetching data from local DB: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
            content: Text('Failed to load local data: $e'),
            backgroundColor: Colors.red),
      );
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _fetchAndSaveDataLocally() async {
    try {
      final isCategoriesTableEmpty =
          await DatabaseHelper.instance.isCategoriesTableEmpty();
      final isItemsTableEmpty =
          await DatabaseHelper.instance.isItemsTableEmpty();

      if (isCategoriesTableEmpty || isItemsTableEmpty) {
        if (!await _fetchAndSaveFromSqlServer()) {
          return;
        }
      }
      await _fetchDataFromLocalDb();
    } catch (e) {
      debugPrint('Error fetching and saving data: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
            content: Text('Failed to load data: $e'),
            backgroundColor: Colors.red),
      );
    }
  }

  Future<bool> _fetchAndSaveFromSqlServer() async {
    try {
      final isConnected = await SqlConn.connect(
        ip: _connectionDetails!['ip'] as String,
        port: _connectionDetails!['port'] as String,
        databaseName: _connectionDetails!['dbName'] as String,
        username: _connectionDetails!['username'] as String,
        password: _connectionDetails!['password'] as String,
      );

      if (!isConnected) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
              content: Text('Failed to connect to the database.'),
              backgroundColor: Colors.red),
        );
        return false;
      }

      final categoriesResult =
          await SqlConn.readData("SELECT * FROM tbl_categories");
      final itemsResult = await SqlConn.readData(
          "SELECT id, item_name, sale_price, tax_percent, discount_percent, category_name, Comments FROM tbl_items WHERE id IS NOT NULL AND id != '0'");

      final parsedCategories = jsonDecode(categoriesResult) as List<dynamic>;
      final parsedItems = jsonDecode(itemsResult) as List<dynamic>;

      await DatabaseHelper.instance
          .saveCategories(parsedCategories.cast<Map<String, dynamic>>());
      await DatabaseHelper.instance
          .saveItems(parsedItems.cast<Map<String, dynamic>>());

      SqlConn.disconnect();
      return true;
    } catch (e) {
      debugPrint('Error fetching from SQL Server: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
            content: Text('Failed to fetch data from SQL Server: $e'),
            backgroundColor: Colors.red),
      );
      return false;
    }
  }

  Future<void> _fetchDataFromLocalDb() async {
    final categories = await DatabaseHelper.instance.getCategories();
    final items = await DatabaseHelper.instance.getItems();
    final Map<String, List<Map<String, dynamic>>> groupedData = {};

    for (var category in categories) {
      final categoryName = category['category_name'] as String;
      groupedData[categoryName] = items
          .where((item) =>
              item['category_name'] == categoryName &&
              item['id'] != null &&
              item['id'].toString() != '0')
          .toList();
    }

    setState(() {
      _categories = categories;
      _categoryItems = groupedData;
      _selectedCategory = categories.isNotEmpty ? categories[0]['category_name'] as String : null;
      _tabController = TabController(length: categories.length, vsync: this);
    });
  }

  Future<void> _showCommentDialog(OrderItem item) async {
    final defaultText = item.comments.isNotEmpty ? item.comments : 'Please prepare quickly!';
    final TextEditingController _commentController = TextEditingController(text: defaultText);

    await showDialog(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          backgroundColor: const Color(0xFF182022),
          title: const Text('Add / Edit Comments',
              style: TextStyle(color: Colors.white)),
          content: SizedBox(
            width: double.maxFinite,
            child: TextField(
              controller: _commentController,
              maxLines: 4,
              style: const TextStyle(color: Colors.white),
              decoration: InputDecoration(
                hintText: 'Enter special instructions',
                hintStyle: const TextStyle(color: Colors.white54),
                filled: true,
                fillColor: Colors.grey.shade800,
                border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10)),
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(),
              child: const Text('Cancel',
                  style: TextStyle(color: Colors.redAccent)),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF75E5E2),
                foregroundColor: const Color(0xFF0D1D20),
              ),
              onPressed: () {
                final newComment = _commentController.text.trim();
                if (item.itemId == '0' || item.itemId.isEmpty) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                        content: Text(
                            'Cannot add comment for ${item.itemName}: Invalid item ID')),
                  );
                  Navigator.of(ctx).pop();
                  return;
                }
                setState(() {
                  final idx = _activeOrderItems
                      .indexWhere((o) => o.itemId == item.itemId);
                  if (idx != -1) {
                    _activeOrderItems[idx] = OrderItem(
                      itemId: item.itemId,
                      itemName: item.itemName,
                      salePrice: item.salePrice,
                      quantity: item.quantity,
                      taxPercent: item.taxPercent,
                      discountPercent: item.discountPercent,
                      comments: newComment.isNotEmpty ? newComment : "No Comments",
                      orderDetailId: item.orderDetailId,
                    );
                  } else {
                    _activeOrderItems.add(OrderItem(
                      itemId: item.itemId,
                      itemName: item.itemName,
                      salePrice: item.salePrice,
                      quantity: 1,
                      taxPercent: 5.0,
                      discountPercent: 0.0,
                      comments: newComment.isNotEmpty ? newComment : "No Comments",
                      orderDetailId: '0',
                    ));
                  }
                  _calculateTotalBill();
                });
                Navigator.of(ctx).pop();
              },
              child: const Text('Save'),
            ),
          ],
        );
      },
    );
  }

  void _addItemToOrder(Map<String, dynamic> item) {
    final itemId = item['id']?.toString() ?? '0';
    if (itemId == '0' || itemId.isEmpty) {
      debugPrint("⚠️ Warning: Invalid item ID for ${item['item_name']}");
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
            content: Text('Cannot add ${item['item_name']}: Invalid item ID')),
      );
      return;
    }

    setState(() {
      final existingIndex = _activeOrderItems.indexWhere((e) => e.itemId == itemId);
      if (existingIndex != -1) {
        final updatedItem = OrderItem(
          itemId: _activeOrderItems[existingIndex].itemId,
          itemName: _activeOrderItems[existingIndex].itemName,
          salePrice: _activeOrderItems[existingIndex].salePrice,
          quantity: _activeOrderItems[existingIndex].quantity + 1,
          taxPercent: _activeOrderItems[existingIndex].taxPercent,
          discountPercent: _activeOrderItems[existingIndex].discountPercent,
          comments: _activeOrderItems[existingIndex].comments,
          orderDetailId: _activeOrderItems[existingIndex].orderDetailId,
        );
        _activeOrderItems[existingIndex] = updatedItem;
      } else {
        _activeOrderItems.add(OrderItem(
          itemId: itemId,
          itemName: item['item_name'] ?? 'Unknown',
          salePrice: double.tryParse(item['sale_price']?.toString() ?? '0') ?? 0.0,
          quantity: 1,
          taxPercent: double.tryParse(item['tax_percent']?.toString() ?? '5.0') ?? 5.0,
          discountPercent:
              double.tryParse(item['discount_percent']?.toString() ?? '0') ?? 0.0,
          comments: item['Comments']?.toString() ?? 'Please prepare quickly!',
          orderDetailId: '0',
        ));
      }
      _calculateTotalBill();
    });
  }

  void _decreaseItemQuantity(String itemId) {
    setState(() {
      final index = _activeOrderItems.indexWhere((o) => o.itemId == itemId);
      if (index != -1) {
        if (_activeOrderItems[index].quantity > 1) {
          _activeOrderItems[index] = OrderItem(
            itemId: _activeOrderItems[index].itemId,
            itemName: _activeOrderItems[index].itemName,
            salePrice: _activeOrderItems[index].salePrice,
            quantity: _activeOrderItems[index].quantity - 1,
            taxPercent: _activeOrderItems[index].taxPercent,
            discountPercent: _activeOrderItems[index].discountPercent,
            comments: _activeOrderItems[index].comments,
            orderDetailId: _activeOrderItems[index].orderDetailId,
          );
        } else {
          _activeOrderItems.removeAt(index);
        }
        _calculateTotalBill();
      }
    });
  }

  void _calculateTotalBill() {
    double total = 0.0;
    double totalTaxAmount = 0.0;
    double totalDiscountAmount = 0.0;

    for (var item in _activeOrderItems) {
      final subtotal = item.salePrice * item.quantity;
      final taxAmount = subtotal * (item.taxPercent / 100);
      final discountAmount = subtotal * (item.discountPercent / 100);
      final itemTotal = subtotal + taxAmount - discountAmount;

      total += itemTotal;
      totalTaxAmount += taxAmount;
      totalDiscountAmount += discountAmount;

      debugPrint(
          "🧾 Item: ${item.itemName}, Qty: ${item.quantity}, Price: ${item.salePrice}, "
          "Subtotal: $subtotal, Tax%: ${item.taxPercent}, Discount%: ${item.discountPercent}, "
          "Final: $itemTotal");
    }

    setState(() {
      _orderTotalAmount = total;
      _totalTax = totalTaxAmount;
      _totalDiscount = totalDiscountAmount;
    });

    debugPrint(
        "💰 Final Bill => Total: $_orderTotalAmount | Tax: $_totalTax | Discount: $_totalDiscount");
  }

  Future<void> _setupSqlConn() async {
    _mssql = MssqlConnection.getInstance();
    final details = await DatabaseHelper.instance.getConnectionDetails();
    if (details == null) {
      setState(() => _isMssqlReady = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text('Database connection details not found!'),
            backgroundColor: Colors.red),
      );
      return;
    }

    _isMssqlReady = await _mssql.connect(
      ip: details['ip'],
      port: details['port'],
      databaseName: details['dbName'],
      username: details['username'],
      password: details['password'],
      timeoutInSeconds: 10,
    );

    if (!_isMssqlReady) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text('Failed to connect to SQL Server!'),
            backgroundColor: Colors.red),
      );
    }
  }

  String _buildOrderQuery({
    required String tabUniqueId,
    required String qtyList,
    required String productCodes,
    required String orderDtlIds,
    required String commentList,
    required int tiltId,
    required String deviceNo,
    required int isPrintKot,
  }) {
    return """
      DECLARE @OrderKey INT;
      EXEC uspInsertDineInOrderAndriod_Sep
          @TiltId = $tiltId,
          @CounterId = 0,
          @Waiter = '${widget.waiterName}',
          @TableNo = '${widget.tableName}',
          @cover = ${widget.customerCount},
          @tab_unique_id = '$tabUniqueId',
          @device_no = '$deviceNo',
          @totalAmount = $_orderTotalAmount,
          @qty2 = '$qtyList',
          @proditemcode = '$productCodes',
          @OrderDtlID = '$orderDtlIds',
          @User = '$_currentUser',
          @IsPrintKOT = $isPrintKot,
          @OrderType = 'DINE IN',
          @Customer = 'WalkIn',
          @Tele = '',
          @Comment = '$commentList',
          @OrderKey = @OrderKey OUTPUT;
      SELECT @OrderKey AS id;
    """;
  }

  Future<int?> _saveOrderToSqlServer() async {
    if (_activeOrderItems.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No items in the order')),
      );
      return null;
    }

    // Filter out invalid items
    final validOrderItems = _activeOrderItems
        .where((item) => item.itemId != '0' && item.itemId.isNotEmpty)
        .toList();
    if (validOrderItems.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No valid items to save')),
      );
      return null;
    }

    final now = DateTime.now();
    final formattedDate = DateFormat('yyyy-MM-dd HH:mm:ss').format(now);
    final connDetails = await DatabaseHelper.instance.getConnectionDetails();
    final loggedUser = await DatabaseHelper.instance.getLoggedInUser();

    setState(() {
      _currentUser = loggedUser ?? "Admin";
    });

    final tiltId = int.tryParse(connDetails?['tiltId'] ?? '0') ?? 0;
    final tiltName = connDetails?['tiltName'] ?? "T1";
    final deviceNo = connDetails?['deviceName']?.isNotEmpty ?? false
        ? connDetails!['deviceName']
        : 'POS01';
    final isPrintKot = connDetails?['isCashier'] ?? 1;
    final tabUniqueId = _tabUniqueId ?? '$tiltName$formattedDate';

    final qtyList = validOrderItems.map((e) => e.quantity.toString()).join(',');
    final productCodes = validOrderItems.map((e) => e.itemId).join(',');
    final orderDtlIds = validOrderItems.map((e) => e.orderDetailId).join(',');
    final commentList = validOrderItems.map((e) => e.comments).join(',');

    final query = _buildOrderQuery(
      tabUniqueId: tabUniqueId,
      qtyList: qtyList,
      productCodes: productCodes,
      orderDtlIds: orderDtlIds,
      commentList: commentList,
      tiltId: tiltId,
      deviceNo: deviceNo,
      isPrintKot: isPrintKot,
    );

    debugPrint("===== FINAL QUERY =====\n$query");
    debugPrint("📝 Qty List => $qtyList");
    debugPrint("📝 Product Codes => $productCodes");
    debugPrint("📝 Order Detail IDs => $orderDtlIds");
    debugPrint("📝 Comments => $commentList");

    try {
      final result = await _mssql.getData(query);
      int? newOrderId;

      try {
        final decoded = jsonDecode(result);
        if (decoded is List && decoded.isNotEmpty) {
          newOrderId = int.tryParse(decoded[0]['id']?.toString() ?? '');
        } else if (decoded is Map && decoded['id'] != null) {
          newOrderId = int.tryParse(decoded['id']?.toString() ?? '');
        } else {
          newOrderId = int.tryParse(result.trim());
        }
      } catch (_) {
        newOrderId = int.tryParse(result.trim());
      }

      if (newOrderId != null && newOrderId > 0) {
        setState(() {
          _activeOrderItems.clear();
          _orderTotalAmount = 0.0;
          _totalTax = 0.0;
          _totalDiscount = 0.0;
        });
        _showSuccessDialog(newOrderId);
      }

      return newOrderId;
    } catch (e) {
      debugPrint('Error placing order: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error placing order: $e')),
      );
      return null;
    }
  }

  void _showSuccessDialog(int orderId) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        backgroundColor: const Color(0xFF0D1D20),
        title: Column(
          children: const [
            Icon(Icons.check_circle_outline,
                color: Color(0xFF75E5E2), size: 60),
            SizedBox(height: 10),
            Text(
              "Success!",
              style: TextStyle(
                  color: Colors.white,
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                  fontFamily: 'Raleway'),
            ),
          ],
        ),
        content: const Text(
          "Your Order Successfully Placed",
          textAlign: TextAlign.center,
          style: TextStyle(
              color: Colors.white70, fontSize: 16, fontFamily: 'Raleway'),
        ),
        actions: [
          Center(
            child: ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF75E5E2),
                foregroundColor: const Color(0xFF0D1D20),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10)),
              ),
              onPressed: () {
                Navigator.pop(ctx);
                Navigator.push(
                    context, MaterialPageRoute(builder: (_) => BillScreen()));
              },
              child: const Text("View Bill"),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          'Table ${widget.tableName} - Waiter: ${widget.waiterName}',
          style: const TextStyle(fontFamily: 'Raleway'),
        ),
        backgroundColor: const Color(0xFF0D1D20),
        foregroundColor: Colors.white,
      ),
      body: Container(
        color: const Color(0xFF0D1D20),
        child: _isLoading
            ? const Center(
                child: CircularProgressIndicator(
                    valueColor:
                        AlwaysStoppedAnimation<Color>(Color(0xFF75E5E2))))
            : LayoutBuilder(
                builder: (context, constraints) {
                  return constraints.maxWidth > 600
                      ? _buildDesktopLayout()
                      : _buildMobileLayout();
                },
              ),
      ),
    );
  }

  Widget _buildDesktopLayout() {
    return Row(
      children: [
        Expanded(
          flex: 3,
          child: Container(
            color: Colors.grey.shade900,
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Divider(color: Colors.white24),
                _buildOrderListWithDetails(),
                _buildSummaryRow('Total Items', '${_activeOrderItems.length}'),
                _buildSummaryRow('Order Tax', ' ${_totalTax.toStringAsFixed(2)}'),
                _buildSummaryRow('Discount', ' ${_totalDiscount.toStringAsFixed(2)}'),
                const Divider(color: Colors.white),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text('Total Bill:',
                        style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                            fontFamily: 'Raleway')),
                    Text(' ${_orderTotalAmount.toStringAsFixed(2)}',
                        style: const TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF75E5E2),
                            fontFamily: 'Raleway')),
                  ],
                ),
                const SizedBox(height: 16),
                ElevatedButton(
                  onPressed: _activeOrderItems.isEmpty ? null : _saveOrderToSqlServer,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF75E5E2),
                    foregroundColor: const Color(0xFF0D1D20),
                    minimumSize: const Size(double.infinity, 50),
                    textStyle: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        fontFamily: 'Raleway'),
                  ),
                  child: const Text('Place Order'),
                ),
              ],
            ),
          ),
        ),
        Expanded(
          flex: 2,
          child: Column(
            children: [
              SizedBox(
                height: 60,
                child: ListView.builder(
                  scrollDirection: Axis.horizontal,
                  itemCount: _categories.length,
                  itemBuilder: (context, index) {
                    final category = _categories[index];
                    final isSelected = _selectedCategory == category['category_name'];
                    return Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 4.0),
                      child: ActionChip(
                        label: Text(category['category_name']),
                        backgroundColor: isSelected
                            ? const Color(0xFF75E5E2)
                            : Colors.grey.shade800,
                        labelStyle: TextStyle(
                            color: isSelected
                                ? const Color(0xFF0D1D20)
                                : Colors.white,
                            fontFamily: 'Raleway'),
                        onPressed: () {
                          setState(() {
                            _selectedCategory = category['category_name'] as String;
                          });
                        },
                      ),
                    );
                  },
                ),
              ),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.all(8.0),
                  child: GridView.builder(
                    gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 2,
                      crossAxisSpacing: 8.0,
                      mainAxisSpacing: 8.0,
                      childAspectRatio: 0.7,
                    ),
                    itemCount: _categoryItems[_selectedCategory]?.length ?? 0,
                    itemBuilder: (context, index) {
                      final items = _categoryItems[_selectedCategory] ?? [];
                      final item = items[index];
                      final double baseTax = 5.0 + (1 * 0.1);
                      double baseDiscount = 0.0;
                      if (1 >= 10) {
                        baseDiscount = 15.0;
                      } else if (1 >= 5) {
                        baseDiscount = 10.0;
                      }

                      return Card(
                        color: Colors.grey.shade900,
                        elevation: 4,
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12)),
                        child: InkWell(
                          onTap: () => _addItemToOrder(item),
                          onLongPress: () => _showCommentDialog(OrderItem.fromMap(item)),
                          child: Padding(
                            padding: const EdgeInsets.all(8.0),
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                const Icon(Icons.local_dining,
                                    color: Color(0xFF75E5E2), size: 40),
                                const SizedBox(height: 8),
                                Text(
                                  item['item_name'],
                                  textAlign: TextAlign.center,
                                  style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 16,
                                      fontWeight: FontWeight.bold,
                                      fontFamily: 'Raleway'),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  ' ${item['sale_price'].toStringAsFixed(2)}',
                                  style: const TextStyle(
                                      color: Colors.white70,
                                      fontSize: 14,
                                      fontFamily: 'Raleway'),
                                ),
                                const SizedBox(height: 4),
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    const Text('Tax:',
                                        style:
                                            TextStyle(color: Colors.white70, fontSize: 12)),
                                    Text(' ${baseTax.toStringAsFixed(1)}%',
                                        style: const TextStyle(
                                            color: Colors.lightGreen,
                                            fontSize: 12,
                                            fontWeight: FontWeight.bold)),
                                    const Text(' | ',
                                        style:
                                            TextStyle(color: Colors.white70, fontSize: 12)),
                                    const Text('Disc:',
                                        style:
                                            TextStyle(color: Colors.white70, fontSize: 12)),
                                    Text(' ${baseDiscount.toStringAsFixed(1)}%',
                                        style: const TextStyle(
                                            color: Colors.orange,
                                            fontSize: 12,
                                            fontWeight: FontWeight.bold)),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildMobileLayout() {
    return Scaffold(
      backgroundColor: const Color(0xFF0D1D20),
      body: Column(
        children: [
          SizedBox(
            height: 60,
            child: AppBar(
              backgroundColor: const Color(0xFF0D1D20),
              bottom: TabBar(
                controller: _tabController,
                isScrollable: true,
                labelColor: const Color(0xFF75E5E2),
                unselectedLabelColor: Colors.white,
                indicatorColor: const Color(0xFF75E5E2),
                tabs: _categoryItems.keys.map((category) => Tab(text: category)).toList(),
              ),
            ),
          ),
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: _categoryItems.keys.map((category) {
                final items = _categoryItems[category] ?? [];
                return Padding(
                  padding: const EdgeInsets.all(8.0),
                  child: GridView.builder(
                    gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 2,
                      crossAxisSpacing: 8.0,
                      mainAxisSpacing: 8.0,
                      childAspectRatio: 0.8,
                    ),
                    itemCount: items.length,
                    itemBuilder: (context, index) {
                      final item = items[index];
                      final double baseTax = 5.0 + (1 * 0.1);
                      double baseDiscount = 0.0;
                      if (1 >= 10) {
                        baseDiscount = 15.0;
                      } else if (1 >= 5) {
                        baseDiscount = 10.0;
                      }
                      return Card(
                        color: Colors.grey.shade900,
                        elevation: 4,
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12)),
                        child: InkWell(
                          onTap: () => _addItemToOrder(item),
                          onLongPress: () => _showCommentDialog(OrderItem.fromMap(item)),
                          child: Padding(
                            padding: const EdgeInsets.all(8.0),
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                const Icon(Icons.local_dining,
                                    color: Color(0xFF75E5E2), size: 40),
                                const SizedBox(height: 8),
                                Text(
                                  item['item_name'],
                                  textAlign: TextAlign.center,
                                  style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 16,
                                      fontWeight: FontWeight.bold,
                                      fontFamily: 'Raleway'),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  ' ${item['sale_price'].toStringAsFixed(2)}',
                                  style: const TextStyle(
                                      color: Colors.white70,
                                      fontSize: 14,
                                      fontFamily: 'Raleway'),
                                ),
                                const SizedBox(height: 4),
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    const Text('Tax:',
                                        style:
                                            TextStyle(color: Colors.white70, fontSize: 12)),
                                    Text(' ${baseTax.toStringAsFixed(1)}%',
                                        style: const TextStyle(
                                            color: Colors.lightGreen,
                                            fontSize: 12,
                                            fontWeight: FontWeight.bold)),
                                    const Text(' | ',
                                        style:
                                            TextStyle(color: Colors.white70, fontSize: 12)),
                                    const Text('Disc:',
                                        style:
                                            TextStyle(color: Colors.white70, fontSize: 12)),
                                    Text(' ${baseDiscount.toStringAsFixed(1)}%',
                                        style: const TextStyle(
                                            color: Colors.orange,
                                            fontSize: 12,
                                            fontWeight: FontWeight.bold)),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                );
              }).toList(),
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _showOrderSheet,
        label: Text('Order Dekho (${_activeOrderItems.length})'),
        icon: const Icon(Icons.shopping_cart),
        backgroundColor: const Color(0xFF75E5E2),
        foregroundColor: const Color(0xFF0D1D20),
      ),
    );
  }

  void _showOrderSheet() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (BuildContext context) {
        return Container(
          color: Colors.grey.shade900,
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('Current Order',
                          style: TextStyle(
                              fontSize: 24,
                              fontWeight: FontWeight.bold,
                              color: Color(0xFF75E5E2),
                              fontFamily: 'Raleway')),
                      Text('Waiter: ${widget.waiterName}',
                          style: const TextStyle(
                              fontSize: 16,
                              color: Colors.white70,
                              fontFamily: 'Raleway')),
                    ],
                  ),
                  IconButton(
                      icon: const Icon(Icons.close, color: Colors.white),
                      onPressed: () => Navigator.pop(context)),
                ],
              ),
              const Divider(color: Colors.white24),
              _buildOrderListWithDetails(),
              const Divider(color: Colors.white),
              _buildSummaryRow('Total Items', '${_activeOrderItems.length}'),
              _buildSummaryRow('Order Tax', ' ${_totalTax.toStringAsFixed(2)}'),
              _buildSummaryRow('Discount', ' ${_totalDiscount.toStringAsFixed(2)}'),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text('Total Bill:',
                      style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                          fontFamily: 'Raleway')),
                  Text(' ${_orderTotalAmount.toStringAsFixed(2)}',
                      style: const TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF75E5E2),
                          fontFamily: 'Raleway')),
                ],
              ),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: _activeOrderItems.isEmpty ? null : _saveOrderToSqlServer,
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF75E5E2),
                  foregroundColor: const Color(0xFF0D1D20),
                  minimumSize: const Size(double.infinity, 50),
                  textStyle: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      fontFamily: 'Raleway'),
                ),
                child: const Text('Place Order'),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildOrderListWithDetails() {
    final isRunningOrder = widget.tabUniqueId != null && widget.tabUniqueId!.isNotEmpty;

    return Expanded(
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.symmetric(vertical: 12.0, horizontal: 8.0),
            decoration: BoxDecoration(
                color: Colors.grey.shade800,
                borderRadius: BorderRadius.circular(8.0)),
            child: const Row(
              children: [
                Expanded(
                    flex: 3,
                    child: Text('Item',
                        style: TextStyle(
                            color: Colors.white, fontWeight: FontWeight.w900))),
                Expanded(
                    flex: 2,
                    child: Text('Price',
                        style: TextStyle(
                            color: Colors.white, fontWeight: FontWeight.bold))),
                Expanded(
                    flex: 3,
                    child: Center(
                        child: Text('Qty',
                            style: TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.bold)))),
                Expanded(
                    flex: 2,
                    child: Text('Disc',
                        style: TextStyle(
                            color: Colors.white, fontWeight: FontWeight.bold))),
                Expanded(
                    flex: 2,
                    child: Text('Tax',
                        style: TextStyle(
                            color: Colors.white, fontWeight: FontWeight.bold))),
                Expanded(
                    flex: 3,
                    child: Text('Total',
                        style: TextStyle(
                            color: Colors.white, fontWeight: FontWeight.bold),
                        textAlign: TextAlign.right)),
              ],
            ),
          ),
          Expanded(
            child: ListView.builder(
              shrinkWrap: true,
              itemCount: _activeOrderItems.length,
              itemBuilder: (context, index) {
                final orderItem = _activeOrderItems[index];
                final subtotal = orderItem.salePrice * orderItem.quantity;
                final taxAmount = subtotal * orderItem.taxPercent / 100;
                final discountAmount = subtotal * orderItem.discountPercent / 100;
                final itemTotal = subtotal + taxAmount - discountAmount;

                return Padding(
                  padding: const EdgeInsets.symmetric(vertical: 7.0),
                  child: Column(
                    children: [
                      Row(
                        children: [
                          Expanded(
                            flex: 3,
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(orderItem.itemName,
                                    style: const TextStyle(
                                        color: Colors.white,
                                        fontWeight: FontWeight.w500,
                                        fontFamily: 'Raleway')),
                                if (orderItem.comments.isNotEmpty)
                                  Text(orderItem.comments,
                                      style: const TextStyle(
                                          color: Colors.white70,
                                          fontSize: 12,
                                          fontStyle: FontStyle.italic)),
                              ],
                            ),
                          ),
                          Expanded(
                              flex: 2,
                              child: Text(
                                  orderItem.salePrice.toStringAsFixed(2),
                                  style: const TextStyle(
                                      color: Colors.white,
                                      fontWeight: FontWeight.w500,
                                      fontFamily: 'Raleway'))),
                          Expanded(
                            flex: 3,
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                InkWell(
                                  onTap: () => _decreaseItemQuantity(orderItem.itemId),
                                  borderRadius: BorderRadius.circular(20),
                                  child: Container(
                                    padding: const EdgeInsets.all(3),
                                    decoration: BoxDecoration(
                                        shape: BoxShape.circle,
                                        border: Border.all(
                                            color: Color(0xFF75E5E2), width: 1.5)),
                                    child: const Icon(Icons.remove,
                                        size: 14, color: Color(0xFF75E5E2)),
                                  ),
                                ),
                                const SizedBox(width: 4),
                                SizedBox(
                                  width: 24,
                                  child: Text(
                                      orderItem.quantity.toString(),
                                      textAlign: TextAlign.center,
                                      style: const TextStyle(
                                          color: Colors.white,
                                          fontWeight: FontWeight.w500,
                                          fontFamily: 'Raleway')),
                                ),
                                const SizedBox(width: 4),
                                InkWell(
                                  onTap: isRunningOrder
                                      ? null
                                      : () => _addItemToOrder(orderItem.toMap()),
                                  onLongPress: isRunningOrder
                                      ? null
                                      : () => _showCommentDialog(orderItem),
                                  borderRadius: BorderRadius.circular(20),
                                  child: Container(
                                    padding: const EdgeInsets.all(3),
                                    decoration: BoxDecoration(
                                      shape: BoxShape.circle,
                                      border: Border.all(
                                          color: isRunningOrder
                                              ? Colors.grey
                                              : Color(0xFF75E5E2),
                                          width: 1.5),
                                    ),
                                    child: Icon(
                                        Icons.add,
                                        size: 14,
                                        color: isRunningOrder
                                            ? Colors.grey
                                            : Color(0xFF75E5E2)),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          Expanded(
                              flex: 2,
                              child: Text(
                                  '${orderItem.discountPercent.toStringAsFixed(0)}%',
                                  style: const TextStyle(
                                      color: Colors.white,
                                      fontWeight: FontWeight.w500,
                                      fontFamily: 'Raleway'))),
                          Expanded(
                              flex: 2,
                              child: Text(taxAmount.toStringAsFixed(2),
                                  style: const TextStyle(
                                      color: Colors.white,
                                      fontWeight: FontWeight.w500,
                                      fontFamily: 'Raleway'))),
                          Expanded(
                              flex: 3,
                              child: Text(itemTotal.toStringAsFixed(2),
                                  style: const TextStyle(
                                      color: Color(0xFF75E5E2),
                                      fontWeight: FontWeight.bold,
                                      fontFamily: 'Raleway'),
                                  textAlign: TextAlign.right)),
                        ],
                      ),
                      const Divider(color: Colors.white10),
                    ],
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSummaryRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label,
              style: const TextStyle(
                  color: Colors.white, fontSize: 16, fontFamily: 'Raleway')),
          Text(value,
              style: const TextStyle(
                  color: Color(0xFF75E5E2),
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  fontFamily: 'Raleway')),
        ],
      ),
    );
  }
}