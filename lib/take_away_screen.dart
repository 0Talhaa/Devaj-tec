// ignore_for_file: unused_local_variable, unused_element, use_build_context_synchronously

import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:mssql_connection/mssql_connection.dart';
import 'package:sql_conn/sql_conn.dart';
import 'package:start_app/database_halper.dart';
import 'package:start_app/bill_screen.dart';
import 'package:intl/intl.dart';

// Placeholder for WaiterSelectionScreen
class WaiterSelectionScreen extends StatelessWidget {
  const WaiterSelectionScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0D1D20),
      body: const Center(
        child: Text(
          'Waiter Selection Screen',
          style: TextStyle(color: Colors.white, fontFamily: 'Raleway', fontSize: 20),
        ),
      ),
    );
  }
}

// Constants for map keys
class OrderConstants {
  static const String itemId = 'id';
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

class TakeAwayScreen extends StatefulWidget {
  final String waiterName;
  final int? selectedTiltId;
  final String? tabUniqueId;

  const TakeAwayScreen({
    super.key,
    required this.waiterName,
    required this.selectedTiltId,
    required this.tabUniqueId,
  });

  @override
  _TakeAwayScreenState createState() => _TakeAwayScreenState();
}

class _TakeAwayScreenState extends State<TakeAwayScreen> with TickerProviderStateMixin {
  late MssqlConnection _mssql;
  bool _isMssqlReady = false;
  bool _isLoading = true;
  Map<String, List<Map<String, dynamic>>> _categoryItems = {};
  List<Map<String, dynamic>> _categories = [];
  String? _selectedCategory;
  String _currentUser = "Admin";
  String _deviceNo = "POS01";
  int _isPrintKot = 1;
  Map<String, dynamic>? _takeAwaySettings;
  TabController? _tabController;
  List<OrderItem> _activeOrderItems = [];
  double _orderTotalAmount = 0.0;
  double _totalTax = 0.0;
  double _totalDiscount = 0.0;
  int? _finalTiltId;
  String? _finalTiltName;
  String? _tabUniqueId;
  String? _customerName;
  String? _phone;
  String? _address;
  String _customerPosId = "0";
  bool _customerDetailsCollected = false;
  bool _requireAddress = true;

  @override
  void initState() {
    super.initState();
    _checkTakeAwayCustomerInfoStatus();
  }

  @override
  void dispose() {
    _tabController?.dispose();
    super.dispose();
  }

  Future<void> _checkTakeAwayCustomerInfoStatus() async {
    setState(() => _isLoading = true);
    try {
      final status = await DatabaseHelper.instance.getSQLPosTransactionSetting('TakeAwayCustomerInfo');
      if (status == "0") {
        await _loadTakeAwaySettings();
        setState(() {
          _customerDetailsCollected = true;
          _customerName = _takeAwaySettings?['defaultCustomerName']?.toString() ?? 'WalkIn';
          _phone = _takeAwaySettings?['defaultPhone']?.toString() ?? '';
          _address = _takeAwaySettings?['defaultAddress']?.toString() ?? '';
        });
        await _initConnectionAndLoadData();
      } else {
        await _showCustomerDetailsDialog();
      }
    } catch (e) {
      debugPrint("❌ Error checking TakeAwayCustomerInfo: $e");
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $e')),
      );
      Navigator.of(context).pop(); // Navigate back on error
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _showCustomerDetailsDialog() async {
    await _loadTakeAwaySettings();
    final TextEditingController customerNameController = TextEditingController(
        text: _takeAwaySettings?['defaultCustomerName']?.toString() ?? '');
    final TextEditingController phoneController = TextEditingController(
        text: _takeAwaySettings?['defaultPhone']?.toString() ?? '');
    final TextEditingController addressController = TextEditingController(
        text: _takeAwaySettings?['defaultAddress']?.toString() ?? '');

    final result = await showDialog<Map<String, String>>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) {
        return AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          backgroundColor: const Color(0xFF182022),
          title: const Text('Customer Details', style: TextStyle(color: Colors.white)),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: customerNameController,
                  style: const TextStyle(color: Colors.white),
                  decoration: InputDecoration(
                    hintText: 'Enter customer name',
                    hintStyle: const TextStyle(color: Colors.white54),
                    filled: true,
                    fillColor: Colors.grey.shade800,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: phoneController,
                  style: const TextStyle(color: Colors.white),
                  keyboardType: TextInputType.phone,
                  decoration: InputDecoration(
                    hintText: 'Enter phone number',
                    hintStyle: const TextStyle(color: Colors.white54),
                    filled: true,
                    fillColor: Colors.grey.shade800,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                if (_requireAddress)
                  TextField(
                    controller: addressController,
                    style: const TextStyle(color: Colors.white),
                    maxLines: 3,
                    decoration: InputDecoration(
                      hintText: 'Enter Custiomer Name',
                      hintStyle: const TextStyle(color: Colors.white54),
                      filled: true,
                      fillColor: Colors.grey.shade800,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                  ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(ctx).pop(); // Only pop the dialog
              },
              child: const Text('Cancel', style: TextStyle(color: Colors.redAccent)),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF75E5E2),
                foregroundColor: const Color(0xFF0D1D20),
              ),
              onPressed: () async {
                final customerName = customerNameController.text.trim();
                final phone = phoneController.text.trim();
                final address = addressController.text.trim();

                if (phone.isEmpty) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Error: Mobile number missing'),
                      backgroundColor: Colors.red,
                    ),
                  );
                  return;
                }

                final serverStatus = await DatabaseHelper.instance.getSQLPosTransactionSetting('TakeAwayServer');
                Navigator.of(ctx).pop({
                  'customerName': customerName,
                  'phone': phone,
                  'address': address,
                });
                if (serverStatus != "0") {
                  Navigator.of(context).push(
                    MaterialPageRoute(builder: (_) => const WaiterSelectionScreen()),
                  );
                }
              },
              child: const Text('Confirm'),
            ),
          ],
        );
      },
    );

    if (result != null) {
      setState(() {
        _customerName = result['customerName'];
        _phone = result['phone'];
        _address = result['address'];
        _customerDetailsCollected = true;
      });
      await _initConnectionAndLoadData();
    }
  }

  Future<void> _initConnectionAndLoadData() async {
    setState(() => _isLoading = true);
    await _setupSqlConn();
    await _fetchMenuData();
    _generateNewTabUniqueId();
    if (widget.tabUniqueId != null && widget.tabUniqueId!.isNotEmpty) {
      await _fetchExistingOrder(widget.tabUniqueId!);
    }
    setState(() => _isLoading = false);
  }

  Future<void> _loadTakeAwaySettings() async {
    try {
      final settings = await DatabaseHelper.instance.getTakeAwaySettings();
      setState(() {
        _takeAwaySettings = settings ?? {
          'defaultCustomerName': 'WalkIn',
          'defaultPhone': '',
          'defaultAddress': '',
          'username': 'Admin',
          'deviceName': 'POS01',
          'isPrintKot': 1,
          'tiltId': '0',
          'tiltName': 'T1',
          'requireAddress': true,
        };
        _currentUser = _takeAwaySettings!['username'] ?? 'Admin';
        _deviceNo = _takeAwaySettings!['deviceName']?.isNotEmpty ?? false
            ? _takeAwaySettings!['deviceName']
            : 'POS01';
        _isPrintKot = _takeAwaySettings!['isPrintKot'] ?? 1;
        _finalTiltId = int.tryParse(_takeAwaySettings!['tiltId']?.toString() ?? '0') ?? 0;
        _finalTiltName = _takeAwaySettings!['tiltName'] ?? 'T1';
        _requireAddress = _takeAwaySettings!['requireAddress'] == 1 || _takeAwaySettings!['requireAddress'] == true;
      });
      debugPrint("✅ TakeAway Settings: $_takeAwaySettings");
    } catch (e) {
      debugPrint("❌ Error loading TakeAway settings: $e");
      setState(() {
        _takeAwaySettings = {
          'defaultCustomerName': 'WalkIn',
          'defaultPhone': '',
          'defaultAddress': '',
          'username': 'Admin',
          'deviceName': 'POS01',
          'isPrintKot': 1,
          'tiltId': '0',
          'tiltName': 'T1',
          'requireAddress': true,
        };
      });
    }
  }

  Future<void> _setupSqlConn() async {
    _mssql = MssqlConnection.getInstance();
    final settings = _takeAwaySettings ?? await DatabaseHelper.instance.getTakeAwaySettings();
    final connectionDetails = await DatabaseHelper.instance.getConnectionDetails();
    if (settings == null || connectionDetails == null) {
      setState(() => _isMssqlReady = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Connection details not found!'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    _isMssqlReady = await _mssql.connect(
      ip: connectionDetails['ip'] ?? '192.168.1.1',
      port: connectionDetails['port'] ?? '1433',
      databaseName: connectionDetails['dbName'] ?? 'POSDB',
      username: connectionDetails['username'] ?? 'sa',
      password: connectionDetails['password'] ?? '',
      timeoutInSeconds: 10,
    );

    if (!_isMssqlReady) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Failed to connect to SQL Server!'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  void _generateNewTabUniqueId() {
    if (widget.tabUniqueId != null && widget.tabUniqueId!.isNotEmpty) {
      setState(() {
        _tabUniqueId = widget.tabUniqueId!;
      });
      debugPrint("✅ Using existing tab_unique_id => $_tabUniqueId");
    } else {
      final now = DateTime.now();
      final formattedDate = DateFormat('yyyy-MM-dd HH:mm:ss').format(now);
      setState(() {
        _tabUniqueId = 'T1$formattedDate';
      });
      debugPrint("✅ Generated new tab_unique_id => $_tabUniqueId");
    }
    setState(() {
      _activeOrderItems = [];
    });
  }

  Future<void> _fetchExistingOrder(String tabUniqueId) async {
    try {
      final conn = _takeAwaySettings ?? await DatabaseHelper.instance.getTakeAwaySettings();
      if (conn == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Connection details missing')),
        );
        return;
      }

      if (!await SqlConn.isConnected) {
        await SqlConn.connect(
          ip: conn['ip'] ?? '192.168.1.1',
          port: conn['port'] ?? '1433',
          databaseName: conn['dbName'] ?? 'POSDB',
          username: conn['username'] ?? 'sa',
          password: conn['password'] ?? '',
        );
      }

      final query = """
        SELECT DISTINCT 
          d.itemid AS id, 
          d.item_name, 
          d.qty, 
          d.Comments,
          (i.sale_price) AS item_unit_price,
          d.id AS orderDetailId, 
          d.tax AS tax,
          d.discount AS discount_percent,
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

      final customerQuery = """
        SELECT Customer, Tele, Address
        FROM dine_in_order
        WHERE tab_unique_id = '$tabUniqueId'
      """;
      final customerResult = await SqlConn.readData(customerQuery);
      final customerData = jsonDecode(customerResult) as List<dynamic>;
      if (customerData.isNotEmpty) {
        setState(() {
          _customerName = customerData[0]['Customer']?.toString() ?? _takeAwaySettings?['defaultCustomerName']?.toString() ?? 'WalkIn';
          _phone = customerData[0]['Tele']?.toString() ?? _takeAwaySettings?['defaultPhone']?.toString() ?? '';
          _address = customerData[0]['Address']?.toString() ?? _takeAwaySettings?['defaultAddress']?.toString() ?? '';
          _customerDetailsCollected = true;
        });
      }

      setState(() {
        _tabUniqueId = tabUniqueId;
        _activeOrderItems = decoded.map((row) {
          final qty = (double.tryParse(row["qty"]?.toString() ?? '0') ?? 0).toInt();
          final unitPrice = double.tryParse(row["item_unit_price"]?.toString() ?? '0') ?? 0.0;
          final tax = double.tryParse(row["tax"]?.toString() ?? '0') == 0.0
              ? 5.0
              : double.tryParse(row["tax"]?.toString() ?? '5.0') ?? 5.0;
          final discount = double.tryParse(row["discount_percent"]?.toString() ?? '0') ?? 0.0;
          final itemId = row["id"]?.toString() ?? '0';
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
        } else {
          _selectedCategory = null;
          _tabController = null;
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

  Future<void> _loadLoggedUser() async {
    final user = await DatabaseHelper.instance.getLoggedInUser();
    setState(() {
      _currentUser = user ?? "Admin";
    });
    debugPrint("✅ Current user: $_currentUser");
  }

  Future<void> _checkUser() async {
    final user = await DatabaseHelper.instance.getLoggedInUser();
    debugPrint(user != null ? "✅ Logged-in user: $user" : "❌ No user found.");
  }

  Future<int> insertItemLess({
    required String tabUniqueId,
    required String orderDetailId,
    required String username,
    required String authenticateUsername,
    required String reason,
    required String tiltId,
    required int quantity,
  }) async {
    int id = 0;
    try {
      if (!_isMssqlReady) {
        await _setupSqlConn();
      }
      if (!_isMssqlReady) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Database connection not established'),
            backgroundColor: Colors.red,
          ),
        );
        return id;
      }

      final query = """
        DECLARE @Result INT;
        EXEC spItemLessPunch 
            @OrderDtlID = '$orderDetailId',
            @TabUniqueID = '$tabUniqueId',
            @qty = '$quantity',
            @Reason = '$reason',
            @UserLogin = '$username',
            @username = '$authenticateUsername',
            @Tiltid = $tiltId;
        SELECT @Result AS id;
      """;

      debugPrint("📝 ItemLess Query: $query");
      final result = await _mssql.getData(query);
      debugPrint("📤 ItemLess Result: $result");

      final decoded = jsonDecode(result);
      if (decoded is List && decoded.isNotEmpty) {
        id = int.tryParse(decoded[0]['id']?.toString() ?? '0') ?? 0;
      } else if (decoded is Map && decoded['id'] != null) {
        id = int.tryParse(decoded['id']?.toString() ?? '0') ?? 0;
      }

      if (id > 0) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Item reduced successfully, ID: $id')),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Failed to reduce item'),
            backgroundColor: Colors.red,
          ),
        );
      }

      return id;
    } catch (e) {
      debugPrint("❌ Error in insertItemLess: $e");
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error reducing item: $e'),
          backgroundColor: Colors.red,
        ),
      );
      return id;
    }
  }

  Future<void> _showReasonDialog(String itemId, String itemName, Function(int) onSuccess) async {
    final TextEditingController reasonController = TextEditingController();
    final TextEditingController authUsernameController = TextEditingController();

    final result = await showDialog<bool>(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          backgroundColor: const Color(0xFF182022),
          title: Text(
            'Reduce/Remove $itemName',
            style: const TextStyle(color: Colors.white),
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: reasonController,
                style: const TextStyle(color: Colors.white),
                decoration: InputDecoration(
                  hintText: 'Enter reason for reduction',
                  hintStyle: const TextStyle(color: Colors.white54),
                  filled: true,
                  fillColor: Colors.grey.shade800,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: authUsernameController,
                style: const TextStyle(color: Colors.white),
                decoration: InputDecoration(
                  hintText: 'Enter authenticate username',
                  hintStyle: const TextStyle(color: Colors.white54),
                  filled: true,
                  fillColor: Colors.grey.shade800,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(false),
              child: const Text(
                'Cancel',
                style: TextStyle(color: Colors.redAccent),
              ),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF75E5E2),
                foregroundColor: const Color(0xFF0D1D20),
              ),
              onPressed: () {
                final reason = reasonController.text.trim();
                final authUsername = authUsernameController.text.trim();
                if (reason.isEmpty || authUsername.isEmpty) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Please provide reason and authenticate username'),
                      backgroundColor: Colors.red,
                    ),
                  );
                  return;
                }
                Navigator.of(ctx).pop(true);
              },
              child: const Text('Next'),
            ),
          ],
        );
      },
    );

    if (result != true) return;

    final index = _activeOrderItems.indexWhere((o) => o.itemId == itemId);
    if (index == -1) return;
    final orderItem = _activeOrderItems[index];

    await _showAuthDialog(
      itemId: itemId,
      itemName: itemName,
      reason: reasonController.text.trim(),
      authUsername: authUsernameController.text.trim(),
      orderItem: orderItem,
      onSuccess: onSuccess,
    );
  }

  Future<void> _showAuthDialog({
    required String itemId,
    required String itemName,
    required String reason,
    required String authUsername,
    required OrderItem orderItem,
    required Function(int) onSuccess,
  }) async {
    final TextEditingController passwordController = TextEditingController();
    bool obscurePassword = true;

    await showDialog(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setState) {
            return AlertDialog(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              backgroundColor: const Color(0xFF182022),
              title: Text(
                'Authenticate for $itemName',
                style: const TextStyle(color: Colors.white),
              ),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(
                    controller: passwordController,
                    obscureText: obscurePassword,
                    style: const TextStyle(color: Colors.white),
                    decoration: InputDecoration(
                      hintText: 'Enter password',
                      hintStyle: const TextStyle(color: Colors.white54),
                      filled: true,
                      fillColor: Colors.grey.shade800,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                      suffixIcon: IconButton(
                        icon: Icon(
                          obscurePassword ? Icons.visibility_off : Icons.visibility,
                          color: Colors.white54,
                        ),
                        onPressed: () {
                          setState(() {
                            obscurePassword = !obscurePassword;
                          });
                        },
                      ),
                    ),
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(ctx).pop(),
                  child: const Text(
                    'Cancel',
                    style: TextStyle(color: Colors.redAccent),
                  ),
                ),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF75E5E2),
                    foregroundColor: const Color(0xFF0D1D20),
                  ),
                  onPressed: () async {
                    final password = passwordController.text.trim();
                    if (password.isEmpty) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Please enter a password'),
                          backgroundColor: Colors.red,
                        ),
                      );
                      return;
                    }

                    final connDetails = _takeAwaySettings ?? await DatabaseHelper.instance.getTakeAwaySettings();
                    final loggedUser = await DatabaseHelper.instance.getLoggedInUser();

                    if (connDetails == null || loggedUser == null) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('User not logged in or connection details missing'),
                          backgroundColor: Colors.red,
                        ),
                      );
                      Navigator.of(ctx).pop();
                      return;
                    }

                    if (authUsername == loggedUser && password == connDetails['password']) {
                      final result = await insertItemLess(
                        tabUniqueId: _tabUniqueId ?? '',
                        quantity: orderItem.quantity,
                        orderDetailId: orderItem.orderDetailId,
                        username: _currentUser,
                        authenticateUsername: authUsername,
                        reason: reason,
                        tiltId: (_finalTiltId ?? 0).toString(),
                      );

                      if (result > 0) {
                        onSuccess(result);
                      }
                      Navigator.of(ctx).pop();
                    } else {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Invalid username or password'),
                          backgroundColor: Colors.red,
                        ),
                      );
                    }
                  },
                  child: const Text('Authenticate'),
                ),
              ],
            );
          },
        );
      },
    );
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
          title: const Text('Add / Edit Comments', style: TextStyle(color: Colors.white)),
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
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(),
              child: const Text('Cancel', style: TextStyle(color: Colors.redAccent)),
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
                    SnackBar(content: Text('Cannot add comment for ${item.itemName}: Invalid item ID')),
                  );
                  Navigator.of(ctx).pop();
                  return;
                }
                setState(() {
                  final idx = _activeOrderItems.indexWhere((o) => o.itemId == item.itemId);
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
    if (!_customerDetailsCollected) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please provide customer details first'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    final itemId = item['id']?.toString() ?? '0';
    if (itemId == '0' || itemId.isEmpty) {
      debugPrint("⚠️ Warning: Invalid item ID for ${item['item_name']}");
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Cannot add ${item['item_name']}: Invalid item ID')),
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
          discountPercent: double.tryParse(item['discount_percent']?.toString() ?? '0') ?? 0.0,
          comments: item['Comments']?.toString() ?? 'Please prepare quickly!',
          orderDetailId: '0',
        ));
      }
      _calculateTotalBill();
    });
  }

  void _decreaseItemQuantity(String itemId) {
    final index = _activeOrderItems.indexWhere((o) => o.itemId == itemId);
    if (index == -1) return;

    final orderItem = _activeOrderItems[index];
    if (widget.tabUniqueId == null || widget.tabUniqueId!.isEmpty) {
      setState(() {
        if (orderItem.quantity > 1) {
          _activeOrderItems[index] = OrderItem(
            itemId: orderItem.itemId,
            itemName: orderItem.itemName,
            salePrice: orderItem.salePrice,
            quantity: orderItem.quantity - 1,
            taxPercent: orderItem.taxPercent,
            discountPercent: orderItem.discountPercent,
            comments: orderItem.comments,
            orderDetailId: orderItem.orderDetailId,
          );
        } else {
          _activeOrderItems.removeAt(index);
        }
        _calculateTotalBill();
      });
    } else {
      _showReasonDialog(
        itemId,
        orderItem.itemName,
        (int resultId) {
          setState(() {
            if (orderItem.quantity > 1) {
              _activeOrderItems[index] = OrderItem(
                itemId: orderItem.itemId,
                itemName: orderItem.itemName,
                salePrice: orderItem.salePrice,
                quantity: orderItem.quantity - 1,
                taxPercent: orderItem.taxPercent,
                discountPercent: orderItem.discountPercent,
                comments: orderItem.comments,
                orderDetailId: orderItem.orderDetailId,
              );
            } else {
              _activeOrderItems.removeAt(index);
            }
            _calculateTotalBill();
          });
        },
      );
    }
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

// [Previous imports and unchanged code omitted for brevity]

// Inside _TakeAwayScreenState class

String _buildOrderQuery({
  required String tabUniqueIdN,
  required String qtyList,
  required String productCodes,
  required String orderDtlIds,
  required String commentList,
  required int tiltId,
  required String deviceNo,
  required int isPrintKot,
}) {
  return """
    EXEC uspInsertDineInOrderAndriod_Sep
        @TiltId = $tiltId,
        @CounterId = 0,
        @Waiter = '${widget.waiterName}',
        @TableNo = '',
        @cover = 0,
        @tab_unique_id = '$tabUniqueIdN',
        @device_no = '$deviceNo',
        @totalAmount = $_orderTotalAmount,
        @qty2 = '$qtyList',
        @proditemcode = '$productCodes',
        @OrderDtlID = '$orderDtlIds',
        @User = '$_currentUser',
        @IsPrintKOT = $isPrintKot,
        @OrderType = 'TAKE AWAY',
        @Customer = '$_customerName',
        @Tele = '$_phone',
        @Address = '$_address',
        @Comment = '$commentList',
        @CustomerPOSId = '$_customerPosId';
  """;
}

Future<int?> _saveOrderToSqlServer() async {
  if (!_customerDetailsCollected) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Customer details not provided'),
        backgroundColor: Colors.red,
      ),
    );
    return null;
  }

  if (_activeOrderItems.isEmpty) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('No items in the order')),
    );
    return null;
  }

  final validOrderItems = _activeOrderItems
      .where((item) => item.itemId != '0' && item.itemId.isNotEmpty)
      .toList();
  if (validOrderItems.isEmpty) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('No valid items to save')),
    );
    return null;
  }

  final connDetails = _takeAwaySettings ?? await DatabaseHelper.instance.getTakeAwaySettings();
  final loggedUser = await DatabaseHelper.instance.getLoggedInUser();

  setState(() {
    _currentUser = loggedUser ?? "Admin";
  });

  final tiltId = int.tryParse(connDetails?['tiltId']?.toString() ?? '0') ?? 0;
  final deviceNo = connDetails?['deviceName']?.isNotEmpty ?? false
      ? connDetails!['deviceName']
      : 'POS01';
  final isPrintKot = connDetails?['isPrintKot'] ?? 1;
  final tabUniqueId = widget.tabUniqueId != null && widget.tabUniqueId!.isNotEmpty
      ? widget.tabUniqueId!
      : _tabUniqueId!;

  if (tabUniqueId.isEmpty) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Invalid tab_unique_id'), backgroundColor: Colors.red),
    );
    return null;
  }

  final qtyList = validOrderItems.map((e) => e.quantity.toString()).join(',');
  final productCodes = validOrderItems.map((e) => e.itemId).join(',');
  final orderDtlIds = validOrderItems.map((e) => e.orderDetailId).join(',');
  final commentList = validOrderItems.map((e) => e.comments).join(',');

  final query = _buildOrderQuery(
    tabUniqueIdN: tabUniqueId,
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
  debugPrint("📝 Customer Name => $_customerName");
  debugPrint("📝 Phone => $_phone");
  debugPrint("📝 Address => $_address");
  debugPrint("📝 CustomerPOSId => $_customerPosId");

  try {
    final result = await _mssql.getData(query);
    debugPrint("📤 Query Result: $result");

    int? newOrderId;
    try {
      final decoded = jsonDecode(result);
      if (decoded is List && decoded.isNotEmpty) {
        newOrderId = int.tryParse(decoded[0]['id']?.toString() ?? '');
      } else if (decoded is Map && decoded['id'] != null) {
        newOrderId = int.tryParse(decoded['id']?.toString() ?? '');
      } else {
        // Fallback: Query the inserted order to get the OrderKey
        final orderKeyQuery = "SELECT TOP 1 id FROM dine_in_order WHERE tab_unique_id = '$tabUniqueId'";
        final orderKeyResult = await _mssql.getData(orderKeyQuery);
        final orderKeyDecoded = jsonDecode(orderKeyResult);
        if (orderKeyDecoded is List && orderKeyDecoded.isNotEmpty) {
          newOrderId = int.tryParse(orderKeyDecoded[0]['id']?.toString() ?? '');
        }
      }
    } catch (e) {
      debugPrint("⚠️ JSON decode failed, attempting fallback: $e");
      // Fallback: Query the inserted order
      final orderKeyQuery = "SELECT TOP 1 id FROM dine_in_order WHERE tab_unique_id = '$tabUniqueId'";
      final orderKeyResult = await _mssql.getData(orderKeyQuery);
      final orderKeyDecoded = jsonDecode(orderKeyResult);
      if (orderKeyDecoded is List && orderKeyDecoded.isNotEmpty) {
        newOrderId = int.tryParse(orderKeyDecoded[0]['id']?.toString() ?? '');
      }
    }

    if (newOrderId != null && newOrderId > 0) {
      setState(() {
        _activeOrderItems.clear();
        _orderTotalAmount = 0.0;
        _totalTax = 0.0;
        _totalDiscount = 0.0;
      });
      _showSuccessDialog(newOrderId);
      return newOrderId;
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Failed to retrieve order ID'), backgroundColor: Colors.red),
      );
      return null;
    }
  } catch (e) {
    debugPrint('❌ Error placing order: $e');
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Error placing order: $e')),
    );
    return null;
  }
}

// [Rest of the file remains unchanged]

  void _showSuccessDialog(int orderId) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        backgroundColor: const Color(0xFF0D1D20),
        title: Column(
          children: const [
            Icon(Icons.check_circle_outline, color: Color(0xFF75E5E2), size: 60),
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
          "Your Take-Away Order Successfully Placed",
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
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
              onPressed: () {
                Navigator.pop(ctx);
                Navigator.push(
                    context,
                    MaterialPageRoute(
                        builder: (_) => BillScreen(tabUniqueId: _tabUniqueId)));
              },
              child: const Text("View Bill"),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSummaryRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: const TextStyle(color: Colors.white70, fontSize: 16, fontFamily: 'Raleway'),
          ),
          Text(
            value,
            style: const TextStyle(
                color: Color(0xFF75E5E2), fontSize: 16, fontWeight: FontWeight.bold, fontFamily: 'Raleway'),
          ),
        ],
      ),
    );
  }

  Widget _buildOrderListWithDetails() {
    return Expanded(
      child: _activeOrderItems.isEmpty
          ? const Center(
              child: Text(
                'No items in order',
                style: TextStyle(color: Colors.white70, fontSize: 16, fontFamily: 'Raleway'),
              ),
            )
          : ListView.builder(
              itemCount: _activeOrderItems.length,
              itemBuilder: (context, index) {
                final item = _activeOrderItems[index];
                final subtotal = item.salePrice * item.quantity;
                final taxAmount = subtotal * (item.taxPercent / 100);
                final discountAmount = subtotal * (item.discountPercent / 100);
                final itemTotal = subtotal + taxAmount - discountAmount;

                return Card(
                  color: Colors.grey.shade900,
                  child: ListTile(
                    title: Text(
                      item.itemName,
                      style: const TextStyle(color: Colors.white, fontFamily: 'Raleway'),
                    ),
                    subtitle: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Qty: ${item.quantity} | Price: ${item.salePrice.toStringAsFixed(2)}',
                          style: const TextStyle(color: Colors.white70, fontFamily: 'Raleway'),
                        ),
                        Text(
                          'Tax: ${taxAmount.toStringAsFixed(2)} | Disc: ${discountAmount.toStringAsFixed(2)}',
                          style: const TextStyle(color: Colors.white70, fontFamily: 'Raleway'),
                        ),
                        Text(
                          'Total: ${itemTotal.toStringAsFixed(2)}',
                          style: const TextStyle(
                              color: Color(0xFF75E5E2), fontWeight: FontWeight.bold, fontFamily: 'Raleway'),
                        ),
                        if (item.comments.isNotEmpty)
                          Text(
                            'Comments: ${item.comments}',
                            style: const TextStyle(color: Colors.white54, fontFamily: 'Raleway'),
                          ),
                      ],
                    ),
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        IconButton(
                          icon: const Icon(Icons.remove_circle_outline, color: Colors.redAccent),
                          onPressed: () => _decreaseItemQuantity(item.itemId),
                        ),
                        IconButton(
                          icon: const Icon(Icons.comment, color: Colors.white70),
                          onPressed: () => _showCommentDialog(item),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading || !_customerDetailsCollected) {
      return Scaffold(
        backgroundColor: const Color(0xFF0D1D20),
        body: const Center(
          child: CircularProgressIndicator(
            valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF75E5E2)),
          ),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(
          'Take Away - Waiter: ${widget.waiterName}',
          style: const TextStyle(fontFamily: 'Raleway'),
        ),
        backgroundColor: const Color(0xFF0D1D20),
        foregroundColor: Colors.white,
      ),
      body: Container(
        color: const Color(0xFF0D1D20),
        child: _categories.isEmpty
            ? const Center(
                child: Text(
                  'No menu items available',
                  style: TextStyle(color: Colors.white70, fontSize: 16, fontFamily: 'Raleway'),
                ),
              )
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
                Text(
                  'Customer: $_customerName',
                  style: const TextStyle(
                    color: Colors.white70,
                    fontSize: 16,
                    fontFamily: 'Raleway',
                  ),
                ),
                Text(
                  'Phone: $_phone',
                  style: const TextStyle(
                    color: Colors.white70,
                    fontSize: 16,
                    fontFamily: 'Raleway',
                  ),
                ),
                Text(
                  'Address: $_address',
                  style: const TextStyle(
                    color: Colors.white70,
                    fontSize: 16,
                    fontFamily: 'Raleway',
                  ),
                ),
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
                                        style: TextStyle(color: Colors.white70, fontSize: 12)),
                                    Text(' ${baseTax.toStringAsFixed(1)}%',
                                        style: const TextStyle(
                                            color: Colors.lightGreen,
                                            fontSize: 12,
                                            fontWeight: FontWeight.bold)),
                                    const Text(' | ',
                                        style: TextStyle(color: Colors.white70, fontSize: 12)),
                                    const Text('Disc:',
                                        style: TextStyle(color: Colors.white70, fontSize: 12)),
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
    return Column(
      children: [
        if (_tabController != null)
          SizedBox(
            height: 60,
            child: TabBar(
              controller: _tabController,
              isScrollable: true,
              labelColor: const Color(0xFF75E5E2),
              unselectedLabelColor: Colors.white,
              indicatorColor: const Color(0xFF75E5E2),
              tabs: _categories
                  .map((category) => Tab(text: category['category_name']))
                  .toList(),
            ),
          ),
        Expanded(
          child: _tabController == null
              ? const Center(
                  child: Text(
                    'No categories available',
                    style: TextStyle(color: Colors.white70, fontSize: 16, fontFamily: 'Raleway'),
                  ),
                )
              : TabBarView(
                  controller: _tabController,
                  children: _categories.map((category) {
                    final items = _categoryItems[category['category_name']] ?? [];
                    return GridView.builder(
                      padding: const EdgeInsets.all(8.0),
                      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: 2,
                        crossAxisSpacing: 8.0,
                        mainAxisSpacing: 8.0,
                        childAspectRatio: 0.7,
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
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          child: InkWell(
                            onTap: () => _addItemToOrder(item),
                            onLongPress: () => _showCommentDialog(OrderItem.fromMap(item)),
                            child: Padding(
                              padding: const EdgeInsets.all(8.0),
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  const Icon(Icons.local_dining, color: Color(0xFF75E5E2), size: 40),
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
                                        color: Colors.white70, fontSize: 14, fontFamily: 'Raleway'),
                                  ),
                                  const SizedBox(height: 4),
                                  Row(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      const Text('Tax:', style: TextStyle(color: Colors.white70, fontSize: 12)),
                                      Text(' ${baseTax.toStringAsFixed(1)}%',
                                          style: const TextStyle(
                                              color: Colors.lightGreen, fontSize: 12, fontWeight: FontWeight.bold)),
                                      const Text(' | ', style: TextStyle(color: Colors.white70, fontSize: 12)),
                                      const Text('Disc:', style: TextStyle(color: Colors.white70, fontSize: 12)),
                                      Text(' ${baseDiscount.toStringAsFixed(1)}%',
                                          style: const TextStyle(
                                              color: Colors.orange, fontSize: 12, fontWeight: FontWeight.bold)),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                          ),
                        );
                      },
                    );
                  }).toList(),
                ),
        ),
        Container(
          color: Colors.grey.shade900,
          padding: const EdgeInsets.all(16),
          child: Column(
            children: [
              Text(
                'Customer: $_customerName',
                style: const TextStyle(
                  color: Colors.white70,
                  fontSize: 16,
                  fontFamily: 'Raleway',
                ),
              ),
              Text(
                'Phone: $_phone',
                style: const TextStyle(
                  color: Colors.white70,
                  fontSize: 16,
                  fontFamily: 'Raleway',
                ),
              ),
              Text(
                'Address: $_address',
                style: const TextStyle(
                  color: Colors.white70,
                  fontSize: 16,
                  fontFamily: 'Raleway',
                ),
              ),
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
      ],
    );
  }
}