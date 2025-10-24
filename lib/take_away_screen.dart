// ignore_for_file: unused_local_variable, unused_element, use_build_context_synchronously, no_leading_underscores_for_local_identifiers, unused_field, dead_code

import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:mssql_connection/mssql_connection.dart';
import 'package:sql_conn/sql_conn.dart';
import 'package:start_app/custom_loader.dart';
import 'package:start_app/database_halper.dart';
import 'package:start_app/bill_screen.dart';
import 'package:intl/intl.dart';


// Constants for order calculations
class OrderConstants {
  static const double taxRate = 0.05; // 5% tax rate
  static const double discountRate = 0.0; // 0% discount
}

// Model for order items
class OrderItem {
  String itemId;
  String itemName;
  int quantity;
  double price;
  String orderDetailId;
  String comments;

  OrderItem({
    required this.itemId,
    required this.itemName,
    required this.quantity,
    required this.price,
    required this.orderDetailId,
    required this.comments,
  });

  double get subtotal => quantity * price;

  double get tax => subtotal * OrderConstants.taxRate;

  double get total => subtotal + tax;

  Map<String, dynamic> toMap() {
    return {
      'id': itemId,
      'item_name': itemName,
      'sale_price': price,
      'quantity': quantity,
      'tax_percent': OrderConstants.taxRate * 100,
      'discount_percent': OrderConstants.discountRate * 100,
      'Comments': comments,
      'orderDetailId': orderDetailId,
    };
  }

  factory OrderItem.fromMap(Map<String, dynamic> map) {
    return OrderItem(
      itemId: map['id']?.toString() ?? '0',
      itemName: map['item_name'] ?? 'Unknown',
      price: double.tryParse(map['sale_price']?.toString() ?? '0') ?? 0.0,
      quantity: (double.tryParse(map['quantity']?.toString() ?? '0') ?? 0).toInt(),
      orderDetailId: map['orderDetailId']?.toString() ?? '0',
      comments: map['Comments']?.toString() ?? 'Please prepare quickly!',
    );
  }
}

// Stub for MainPOSScreen
class MainPOSScreen extends StatelessWidget {
  final String waiterName;
  final String tabUniqueId;
  final List<OrderItem> orderItems;
  final String customerName;
  final String customerPhone;
  final String customerPosId;

  const MainPOSScreen({
    super.key,
    required this.waiterName,
    required this.tabUniqueId,
    required this.orderItems,
    required this.customerName,
    required this.customerPhone,
    required this.customerPosId,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Main POS')),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Text('Main POS Screen', style: TextStyle(color: Colors.white, fontFamily: 'Raleway')),
            Text('Waiter: $waiterName'),
            Text('Customer: $customerName ($customerPhone)'),
            ElevatedButton(
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => BillScreen()),
                );
              },
              child: const Text('Proceed to Bill'),
            ),
          ],
        ),
      ),
    );
  }
}

// WaiterSelectionScreen
class WaiterSelectionScreen extends StatelessWidget {
  final List<String> waiters;
  final Function(String) onWaiterSelected;

  const WaiterSelectionScreen({
    super.key,
    required this.waiters,
    required this.onWaiterSelected,
  });

  @override
  Widget build(BuildContext context) {
    // Responsive grid
    final crossAxisCount = MediaQuery.of(context).size.width > 600 ? 4 : 2;
    final childAspectRatio = MediaQuery.of(context).size.width > 600 ? 1.1 : 0.9;

    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Select Waiter',
          style: TextStyle(
            fontFamily: 'Raleway',
            fontWeight: FontWeight.bold,
            fontSize: 20,
          ),
        ),
        centerTitle: true,
        backgroundColor: Colors.transparent,
        elevation: 0,
        foregroundColor: kPrimaryColor,
      ),
      body: Container(
        color: kTertiaryColor,
        child: waiters.isEmpty
            ? Center(
                child: Text(
                  'Koi Waiter Nahi Mila.',
                  style: TextStyle(
                    fontSize: 20,
                    color: kPrimaryColor,
                    fontFamily: 'Raleway',
                  ),
                  textAlign: TextAlign.center,
                  semanticsLabel: 'No waiters found',
                ),
              )
            : Padding(
                padding: const EdgeInsets.all(16.0),
                child: GridView.builder(
                  gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: crossAxisCount,
                    crossAxisSpacing: 16.0,
                    mainAxisSpacing: 16.0,
                    childAspectRatio: childAspectRatio,
                  ),
                  itemCount: waiters.length,
                  itemBuilder: (context, index) {
                    final waiterName = waiters[index];
                    // No per-waiter metadata available here, so use default styling.
                    final isUpdated = true;

                    return InkWell(
                      onTap: () {
                        onWaiterSelected(waiterName);
                        Navigator.pop(context);
                      },
                      child: Container(
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(16),
                          gradient: isUpdated
                              ? const LinearGradient(
                                  colors: [kPrimaryColor, kSecondaryColor],
                                  begin: Alignment.topLeft,
                                  end: Alignment.bottomRight,
                                )
                              : const LinearGradient(
                                  colors: [Color(0xFF1F2F32), kTertiaryColor],
                                  begin: Alignment.topLeft,
                                  end: Alignment.bottomRight,
                                ),
                          boxShadow: isUpdated
                              ? [
                                  BoxShadow(
                                    color: kPrimaryColor.withOpacity(0.4),
                                    spreadRadius: 2,
                                    blurRadius: 10,
                                    offset: const Offset(0, 4),
                                  ),
                                ]
                              : [],
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.center,
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text(
                              waiterName,
                              textAlign: TextAlign.center,
                              style: const TextStyle(
                                color: Colors.white,
                                fontFamily: 'Raleway',
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
              ),
      ),
    );
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
  String _deviceNo = "Lenovo TB-X505F";
  int _isPrintKot = 1;
  Map<String, dynamic>? _takeAwaySettings;
  TabController? _tabController;
  List<OrderItem> _activeOrderItems = [];
  double _orderTotalAmount = 0.0;
  double _totalTax = 0.0;
  double _totalDiscount = 0.0;
  int? _finalTiltId;
  int? _is_update;
  String? _finalTiltName;
  String? _tabUniqueId;
  String? _customerName;
  String? _phone;
  String _customerPosId = "0";
  bool _customerDetailsCollected = false;
  String _takeAwayCustomerInfoStatus = '';
  String _takeAwayServerStatus = '';

  @override
  void initState() {
    super.initState();
    _mssql = MssqlConnection.getInstance();
    // Show customer details dialog first
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _showCustomerDetailsDialog();
    });
  }

  @override
  void dispose() {
    _tabController?.dispose();
    super.dispose();
  }

  // Show customer details dialog and then check settings
  Future<void> _showCustomerDetailsDialog() async {
    final nameController = TextEditingController(text: _customerName ?? 'WalkIn');
    final phoneController = TextEditingController(text: _phone ?? '');

    final result = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) {
        return AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          backgroundColor: const Color(0xFF182022),
          title: const Text(
            'Customer Details',
            style: TextStyle(color: Colors.white, fontFamily: 'Raleway'),
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: nameController,
                style: const TextStyle(color: Colors.white, fontFamily: 'Raleway'),
                decoration: InputDecoration(
                  labelText: 'Customer Name',
                  hintText: 'Enter customer name',
                  hintStyle: const TextStyle(color: Colors.white54, fontFamily: 'Raleway'),
                  filled: true,
                  fillColor: Colors.grey.shade800,
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                ),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: phoneController,
                style: const TextStyle(color: Colors.white, fontFamily: 'Raleway'),
                decoration: InputDecoration(
                  labelText: 'Mobile Number',
                  hintText: 'Enter mobile number',
                  hintStyle: const TextStyle(color: Colors.white54, fontFamily: 'Raleway'),
                  filled: true,
                  fillColor: Colors.grey.shade800,
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                ),
                keyboardType: TextInputType.phone,
                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              ),
            ],
          ),
          actions: [
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF75E5E2),
                foregroundColor: const Color(0xFF0D1D20),
              ),
              onPressed: () {
                setState(() {
                  _customerName = nameController.text.trim().isEmpty ? 'WalkIn' : nameController.text.trim();
                  _phone = phoneController.text.trim();
                  _customerDetailsCollected = true;
                });
                Navigator.of(ctx).pop(true);
              },
              child: const Text('Submit', style: TextStyle(fontFamily: 'Raleway')),
            ),
          ],
        );
      },
    );

    if (result == true) {
      // After collecting customer details, check settings and proceed
      await _checkSettingsAndNavigate();
    } else {
      // If dialog is dismissed, pop back
      Navigator.of(context).pop();
    }
  }

  // Check settings and navigate based on TakeAwayCustomerInfo and TakeAwayServer
  Future<void> _checkSettingsAndNavigate() async {
    try {
      // Fetch settings
      _takeAwayCustomerInfoStatus = await _getSQLPosTransactionSetting('TakeAwayCustomerInfo');
      _takeAwayServerStatus = await _getSQLPosTransactionSetting('TakeAwayServer');

      // Validate customer details if TakeAwayCustomerInfo is not "0"
      if (_takeAwayCustomerInfoStatus != '0' && (_phone == null || _phone!.isEmpty)) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Error: Mobile number is required'),
            backgroundColor: Colors.red,
          ),
        );
        // Re-show dialog
        await _showCustomerDetailsDialog();
        return;
      }

      // Fetch other settings
      _takeAwaySettings = await DatabaseHelper.instance.getTakeAwaySettings();
      setState(() {
        _is_update = int.tryParse(_takeAwaySettings?['is_update']?.toString() ?? '0') ?? 0;
        _finalTiltId = int.tryParse(_takeAwaySettings?['tiltId']?.toString() ?? '33') ?? 33;
        _finalTiltName = _takeAwaySettings?['tiltName']?.toString() ?? 'T2';
        _deviceNo = _takeAwaySettings?['deviceName']?.toString() ?? 'Lenovo TB-X505F';
        _isPrintKot = _takeAwaySettings?['isPrintKot'] ?? 1;
      });

      // Navigate based on TakeAwayServer
      if (_takeAwayServerStatus == '0') {
        // Navigate to MainPOSScreen
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (_) => MainPOSScreen(
              waiterName: widget.waiterName,
              tabUniqueId: widget.tabUniqueId ?? '',
              orderItems: _activeOrderItems,
              customerName: _customerName ?? 'WalkIn',
              customerPhone: _phone ?? '',
              customerPosId: _customerPosId,
            ),
          ),
        );
      } else {
        // Navigate to WaiterSelectionScreen
        await _showWaiterSelectionScreen();
      }
    } catch (e) {
      debugPrint('❌ Error checking settings: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error loading settings: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  // Fetch setting from postransectionsetting
  Future<String> _getSQLPosTransactionSetting(String type) async {
    try {
      final connDetails = await DatabaseHelper.instance.getConnectionDetails();
      if (connDetails == null) return '';

      if (!await SqlConn.isConnected) {
        await SqlConn.connect(
          ip: connDetails['ip'] ?? '192.168.137.117',
          port: connDetails['port'] ?? '1433',
          databaseName: connDetails['dbName'] ?? 'HNFOODMULTAN',
          username: connDetails['username'] ?? 'sa',
          password: connDetails['password'] ?? '123321Pa',
          timeout: 10,
        );
      }

      final query = "SELECT status FROM postransectionsetting WHERE type = '$type'";
      final result = await SqlConn.readData(query);
      final decoded = jsonDecode(result) as List<dynamic>;
      String status = '';
      if (decoded.isNotEmpty) {
        status = decoded.first['status']?.toString() ?? '';
      }
      await SqlConn.disconnect();
      return status;
    } catch (e) {
      debugPrint('❌ Error fetching setting $type: $e');
      return '';
    }
  }

  // Show WaiterSelectionScreen
  Future<void> _showWaiterSelectionScreen() async {
    List<String> waiters = await _fetchWaiters();
    if (waiters.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('No waiters available'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => WaiterSelectionScreen(
          waiters: waiters,
          onWaiterSelected: (selectedWaiter) {
            setState(() {
              _currentUser = selectedWaiter;
            });
            // Proceed to load data
            _initConnectionAndLoadData();
          },
        ),
      ),
    );
  }

  // Fetch waiters from Waiter table
  Future<List<String>> _fetchWaiters() async {
    try {
      final connDetails = await DatabaseHelper.instance.getConnectionDetails();
      if (connDetails == null) {
        debugPrint('⚠️ No connection details available');
        return [];
      }

      if (!await SqlConn.isConnected) {
        await SqlConn.connect(
          ip: connDetails['ip'] as String,
          port: connDetails['port'] as String,
          databaseName: connDetails['dbName'] as String,
          username: connDetails['username'] as String,
          password: connDetails['password'] as String,
          timeout: 10,
        );
      }

      // Filter waiters by Tiltid to match _finalTiltId
      final query = "SELECT waiter_name FROM Waiter WHERE is_update = '$_is_update'";
      final result = await SqlConn.readData(query);
      debugPrint("📝 Waiter Query: $query");
      debugPrint("📤 Waiter Result: $result");

      final decoded = jsonDecode(result) as List<dynamic>;
      final waiters = decoded
          .map((row) => row['waiter_name']?.toString())
          .where((waiterName) => waiterName != null && waiterName.isNotEmpty)
          .cast<String>()
          .toList();

      return waiters;
    } catch (e) {
      debugPrint('❌ Error fetching waiters: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to fetch waiters: $e'),
          backgroundColor: Colors.red,
        ),
      );
      return [];
    } finally {
      if (await SqlConn.isConnected) {
        await SqlConn.disconnect();
        debugPrint('🛑 SQL Server connection closed');
      }
    }
  }

  Future<void> _initConnectionAndLoadData() async {
    setState(() {
      _isLoading = true;
    });

    try {
      await _loadTakeAwaySettings();
      await _setupSqlConn();
      await _loadLoggedUser();
      await _fetchMenuData();
      _tabUniqueId = widget.tabUniqueId ?? await _generateNewTabUniqueId();
      debugPrint('✅ Generated new tab_unique_id => $_tabUniqueId');
      if (widget.tabUniqueId != null && widget.tabUniqueId!.isNotEmpty) {
        await _fetchExistingOrder();
      }
    } catch (e) {
      debugPrint('❌ Error initializing connection and data: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error initializing: $e'),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _loadTakeAwaySettings() async {
    _takeAwaySettings = await DatabaseHelper.instance.getTakeAwaySettings();
    setState(() {
      _is_update = int.tryParse(_takeAwaySettings?['is_update']?.toString() ?? '0') ?? 0;
      _finalTiltId = int.tryParse(_takeAwaySettings?['tiltId']?.toString() ?? '33') ?? 33;
      _finalTiltName = _takeAwaySettings?['tiltName']?.toString() ?? 'T2';
      _deviceNo = _takeAwaySettings?['deviceName']?.toString() ?? 'Lenovo TB-X505F';
      _isPrintKot = _takeAwaySettings?['isPrintKot'] ?? 1;
    });
  }

  Future<void> _setupSqlConn() async {
    try {
      final connDetails = await DatabaseHelper.instance.getConnectionDetails();
      if (connDetails != null && !_isMssqlReady) {
        _isMssqlReady = await _mssql.connect(
          ip: connDetails['ip'] ?? '192.168.137.117',
          port: connDetails['port'] ?? '1433',
          databaseName: connDetails['dbName'] ?? 'HNFOODMULTAN',
          username: connDetails['username'] ?? 'sa',
          password: connDetails['password'] ?? '123321Pa',
          timeoutInSeconds: 10,
        );
      }
    } catch (e) {
      debugPrint('❌ Error setting up SQL connection: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error setting up SQL connection: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<String> _generateNewTabUniqueId() async {
    final now = DateTime.now();
    final formatter = DateFormat('yyyy-MM-dd HH:mm:ss');
    return 'T2${formatter.format(now)}';
  }

  Future<void> _fetchExistingOrder() async {
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
          d.itemid AS id, 
          d.item_name, 
          d.qty AS quantity, 
          d.Comments,
          (i.sale_price) AS sale_price,
          d.id AS orderDetailId
        FROM order_detail d
        INNER JOIN dine_in_order m ON d.order_key = m.order_key
        INNER JOIN itempos i ON i.id = d.itemid
        WHERE m.tab_unique_id = '$_tabUniqueId'
      """;

      final result = await SqlConn.readData(query);
      if (result.isEmpty) {
        debugPrint("⚠️ No items found for tabUniqueId=$_tabUniqueId");
        return;
      }

      final decoded = jsonDecode(result) as List<dynamic>;
      debugPrint("🧩 Raw SQL Result: $result");
      setState(() {
        _activeOrderItems = decoded
            .map((row) {
              final itemId = row["id"]?.toString() ?? '0';
              if (itemId == '0' || itemId.isEmpty) {
                debugPrint("⚠️ Warning: Invalid item ID for ${row['item_name']}");
                return null;
              }
              return OrderItem.fromMap(row);
            })
            .where((item) => item != null)
            .cast<OrderItem>()
            .toList();
        _calculateTotalBill();
      });
      debugPrint("🧩 Loaded existing order: ${_activeOrderItems.length} items");
    } catch (e, stackTrace) {
      debugPrint('❌ Error fetching existing order: $e\n$stackTrace');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to fetch order: $e')),
      );
    } finally {
      if (await SqlConn.isConnected) {
        await SqlConn.disconnect();
        debugPrint('🛑 SQL Server connection closed');
      }
    }
  }

  Future<void> _fetchMenuData() async {
    try {
      final categories = await DatabaseHelper.instance.getCategories();
      final items = await DatabaseHelper.instance.getItems();
      final Map<String, List<Map<String, dynamic>>> categoryItems = {};

      for (var category in categories) {
        final categoryName = category['category_name'] as String;
        categoryItems[categoryName] = items
            .where((item) =>
                item['category_name'] == categoryName &&
                item['id'] != null &&
                item['id'].toString() != '0')
            .toList();
      }

      setState(() {
        _categories = categories;
        _categoryItems = categoryItems;
        _selectedCategory = categories.isNotEmpty ? categories.first['category_name'] as String : null;
        _tabController = TabController(length: categories.length, vsync: this);
      });

      debugPrint('📦 Menu Loaded: ${categories.length} categories');
      debugPrint('📥 Retrieved ${items.length} items');
    } catch (e) {
      debugPrint('❌ Error fetching menu data: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error fetching menu data: $e')),
      );
    }
  }

  Future<void> _loadLoggedUser() async {
    final loggedUser = await DatabaseHelper.instance.getLoggedInUser();
    setState(() {
      _currentUser = loggedUser ?? 'Admin';
    });
    debugPrint('📦 Current logged-in user: $_currentUser');
  }

  void _addItemToOrder(Map<String, dynamic> item) {
    final itemId = item['id']?.toString() ?? '0';
    if (itemId == '0' || itemId.isEmpty) {
      debugPrint("⚠️ Warning: Invalid item ID for ${item['item_name']}");
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Cannot add ${item['item_name']}: Invalid item ID'),
        ),
      );
      return;
    }

    final isExistingOrder = widget.tabUniqueId != null && widget.tabUniqueId!.isNotEmpty;

    setState(() {
      if (isExistingOrder) {
        _activeOrderItems.add(
          OrderItem(
            itemId: itemId,
            itemName: item['item_name'] ?? 'Unknown',
            quantity: 1,
            price: double.tryParse(item['sale_price']?.toString() ?? '0') ?? 0.0,
            orderDetailId: '0',
            comments: item['Comments']?.toString() ?? 'Please prepare quickly!',
          ),
        );
      } else {
        final existingIndex = _activeOrderItems.indexWhere((e) => e.itemId == itemId);
        if (existingIndex != -1) {
          _activeOrderItems[existingIndex] = OrderItem(
            itemId: _activeOrderItems[existingIndex].itemId,
            itemName: _activeOrderItems[existingIndex].itemName,
            quantity: _activeOrderItems[existingIndex].quantity + 1,
            price: _activeOrderItems[existingIndex].price,
            orderDetailId: _activeOrderItems[existingIndex].orderDetailId,
            comments: _activeOrderItems[existingIndex].comments,
          );
        } else {
          _activeOrderItems.add(
            OrderItem(
              itemId: itemId,
              itemName: item['item_name'] ?? 'Unknown',
              quantity: 1,
              price: double.tryParse(item['sale_price']?.toString() ?? '0') ?? 0.0,
              orderDetailId: '0',
              comments: item['Comments']?.toString() ?? 'Please prepare quickly!',
            ),
          );
        }
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
            quantity: orderItem.quantity - 1,
            price: orderItem.price,
            orderDetailId: orderItem.orderDetailId,
            comments: orderItem.comments,
          );
        } else {
          _activeOrderItems.removeAt(index);
        }
        _calculateTotalBill();
      });
    } else {
      _showReasonDialog(itemId, orderItem.itemName, (int resultId) {
        setState(() {
          if (orderItem.quantity > 1) {
            _activeOrderItems[index] = OrderItem(
              itemId: orderItem.itemId,
              itemName: orderItem.itemName,
              quantity: orderItem.quantity - 1,
              price: orderItem.price,
              orderDetailId: orderItem.orderDetailId,
              comments: orderItem.comments,
            );
          } else {
            _activeOrderItems.removeAt(index);
          }
          _calculateTotalBill();
        });
      });
    }
  }

  void _calculateTotalBill() {
    double total = 0.0;
    double tax = 0.0;
    for (var item in _activeOrderItems) {
      final subtotal = item.subtotal;
      final taxAmount = item.tax;
      total += subtotal + taxAmount;
      tax += taxAmount;
    }
    setState(() {
      _orderTotalAmount = total;
      _totalTax = tax;
      _totalDiscount = 0.0;
    });
  }

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
      DECLARE @OrderKey INT;
      EXEC uspInsertDineInOrderAndriod_Sep
          @TiltId = $tiltId,
          @CounterId = 0,
          @Waiter = '${_currentUser.replaceAll(r'\/', '/').replaceAll('\\', '\\\\')}',
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
          @Comment = '$commentList',
          @CustomerMasterid = '$_customerPosId',
          @OrderKey = @OrderKey OUTPUT;
      SELECT @OrderKey AS id;
    """;
  }

  Future<int?> _saveOrderToSqlServer() async {
    if (_takeAwayCustomerInfoStatus != '0' && (_phone == null || _phone!.isEmpty)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Error: MobileNo missing'),
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

    final tiltId = int.tryParse(connDetails?['tiltId']?.toString() ?? '33') ?? 33;
    final deviceNo = connDetails?['deviceName']?.isNotEmpty ?? false
        ? connDetails!['deviceName']
        : 'Lenovo TB-X505F';
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

    try {
      if (!_isMssqlReady) {
        final conn = await DatabaseHelper.instance.getConnectionDetails();
        if (conn == null) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Connection details missing'), backgroundColor: Colors.red),
          );
          return null;
        }
        _isMssqlReady = await _mssql.connect(
          ip: conn['ip'] ?? '192.168.137.117',
          port: conn['port'] ?? '1433',
          databaseName: conn['dbName'] ?? 'HNFOODMULTAN',
          username: conn['username'] ?? 'sa',
          password: conn['password'] ?? '123321Pa',
          timeoutInSeconds: 10,
        );
      }

      final result = await _mssql.getData(query);
      int? newOrderId;
      try {
        final decoded = jsonDecode(result);
        if (decoded is List && decoded.isNotEmpty) {
          newOrderId = int.tryParse(decoded[0]['id']?.toString() ?? '');
        } else if (decoded is Map && decoded['id'] != null) {
          newOrderId = int.tryParse(decoded['id']?.toString() ?? '');
        }
      } catch (e) {
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
        SnackBar(content: Text('Error placing order: $e'), backgroundColor: Colors.red),
      );
      return null;
    } finally {
      if (await SqlConn.isConnected) {
        await SqlConn.disconnect();
        debugPrint('🛑 SQL Server connection closed');
      }
    }
  }

  Future<String?> _showCommentDialog(OrderItem item) async {
    final defaultText = item.comments.isNotEmpty ? item.comments : 'Please prepare quickly!';
    final TextEditingController _commentController = TextEditingController(text: defaultText);

    final result = await showDialog<String>(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          backgroundColor: const Color(0xFF182022),
          title: const Text(
            'Add / Edit Comments',
            style: TextStyle(color: Colors.white, fontFamily: 'Raleway'),
          ),
          content: SizedBox(
            width: double.maxFinite,
            child: TextField(
              controller: _commentController,
              maxLines: 4,
              style: const TextStyle(color: Colors.white, fontFamily: 'Raleway'),
              decoration: InputDecoration(
                hintText: 'Enter special instructions',
                hintStyle: const TextStyle(color: Colors.white54, fontFamily: 'Raleway'),
                filled: true,
                fillColor: Colors.grey.shade800,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(),
              child: const Text(
                'Cancel',
                style: TextStyle(color: Colors.redAccent, fontFamily: 'Raleway'),
              ),
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
                      content: Text('Cannot add comment for ${item.itemName}: Invalid item ID'),
                    ),
                  );
                  Navigator.of(ctx).pop();
                  return;
                }
                Navigator.of(ctx).pop(newComment.isNotEmpty ? newComment : 'Please prepare quickly!');
              },
              child: const Text('Save', style: TextStyle(fontFamily: 'Raleway')),
            ),
          ],
        );
      },
    );

    if (result != null) {
      setState(() {
        final idx = _activeOrderItems.indexWhere((o) => o.itemId == item.itemId);
        if (idx != -1) {
          _activeOrderItems[idx] = OrderItem(
            itemId: item.itemId,
            itemName: item.itemName,
            quantity: item.quantity,
            price: item.price,
            orderDetailId: item.orderDetailId,
            comments: result,
          );
        }
        _calculateTotalBill();
      });
    }
    return result;
  }

  Future<void> _showReasonDialog(String itemId, String itemName, Function(int) onSuccess) async {
    final TextEditingController reasonController = TextEditingController();
    String? selectedWaiterName;
    List<String> waiters = await _fetchWaiters();

    if (waiters.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('No waiters found for authentication'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    final result = await showDialog<bool>(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          backgroundColor: const Color(0xFF182022),
          title: Text(
            'Reduce/Remove $itemName',
            style: const TextStyle(color: Colors.white, fontFamily: 'Raleway'),
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: reasonController,
                style: const TextStyle(color: Colors.white, fontFamily: 'Raleway'),
                decoration: InputDecoration(
                  hintText: 'Enter reason for reduction',
                  hintStyle: const TextStyle(color: Colors.white54, fontFamily: 'Raleway'),
                  filled: true,
                  fillColor: Colors.grey.shade800,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
              ),
              const SizedBox(height: 8),
              DropdownButtonFormField<String>(
                value: selectedWaiterName,
                decoration: InputDecoration(
                  hintText: 'Select authenticate waiter',
                  hintStyle: const TextStyle(color: Colors.white54, fontFamily: 'Raleway'),
                  filled: true,
                  fillColor: Colors.grey.shade800,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
                dropdownColor: Colors.grey.shade800,
                style: const TextStyle(color: Colors.white, fontFamily: 'Raleway'),
                items: waiters.map((waiter) {
                  return DropdownMenuItem<String>(
                    value: waiter,
                    child: Text(waiter),
                  );
                }).toList(),
                onChanged: (value) {
                  selectedWaiterName = value;
                },
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(false),
              child: const Text(
                'Cancel',
                style: TextStyle(color: Colors.redAccent, fontFamily: 'Raleway'),
              ),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF75E5E2),
                foregroundColor: const Color(0xFF0D1D20),
              ),
              onPressed: () {
                final reason = reasonController.text.trim();
                if (reason.isEmpty || selectedWaiterName == null) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Please provide reason and select a waiter'),
                      backgroundColor: Colors.red,
                    ),
                  );
                  return;
                }
                Navigator.of(ctx).pop(true);
              },
              child: const Text('Next', style: TextStyle(fontFamily: 'Raleway')),
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
      authWaiterName: selectedWaiterName!,
      orderItem: orderItem,
      onSuccess: onSuccess,
    );
  }

  Future<void> _showAuthDialog({
    required String itemId,
    required String itemName,
    required String reason,
    required String authWaiterName,
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
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              backgroundColor: const Color(0xFF182022),
              title: Text(
                'Authenticate for $itemName',
                style: const TextStyle(color: Colors.white, fontFamily: 'Raleway'),
              ),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(
                    controller: passwordController,
                    obscureText: obscurePassword,
                    style: const TextStyle(color: Colors.white, fontFamily: 'Raleway'),
                    decoration: InputDecoration(
                      hintText: 'Enter password',
                      hintStyle: const TextStyle(color: Colors.white54, fontFamily: 'Raleway'),
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
                    style: TextStyle(color: Colors.redAccent, fontFamily: 'Raleway'),
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

                    final connDetails = await DatabaseHelper.instance.getConnectionDetails();
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

                    try {
                      await SqlConn.connect(
                        ip: connDetails['ip'] as String,
                        port: connDetails['port'] as String,
                        databaseName: connDetails['dbName'] as String,
                        username: connDetails['username'] as String,
                        password: connDetails['password'] as String,
                        timeout: 10,
                      );

                      // Check if waiter exists with the provided name
                      final loginQuery = "SELECT waiter_name FROM Waiter WHERE waiter_name = '$authWaiterName'";
                      final loginResult = await SqlConn.readData(loginQuery);

                      if (jsonDecode(loginResult).isNotEmpty) {
                        final result = await insertItemLess(
                          tabUniqueId: _tabUniqueId ?? '',
                          quantity: orderItem.quantity,
                          orderDetailId: orderItem.orderDetailId,
                          username: _currentUser,
                          authenticateUsername: authWaiterName,
                          reason: reason,
                          tiltId: (_finalTiltId ?? 33).toString(),
                        );

                        if (result > 0) {
                          onSuccess(result);
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text('Item reduced successfully, ID: $result'),
                              backgroundColor: Colors.green,
                            ),
                          );
                        } else {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('Failed to reduce item'),
                              backgroundColor: Colors.red,
                            ),
                          );
                        }
                        Navigator.of(ctx).pop();
                      } else {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('Invalid waiter name'),
                            backgroundColor: Colors.red,
                          ),
                        );
                      }
                    } catch (e) {
                      debugPrint('❌ Error during authentication: $e');
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text('Authentication failed: $e'),
                          backgroundColor: Colors.red,
                        ),
                      );
                    } finally {
                      if (await SqlConn.isConnected) {
                        await SqlConn.disconnect();
                      }
                    }
                  },
                  child: const Text('Authenticate', style: TextStyle(fontFamily: 'Raleway')),
                ),
              ],
            );
          },
        );
      },
    );
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
      final connDetails = await DatabaseHelper.instance.getConnectionDetails();
      if (connDetails == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Database connection details not found'),
            backgroundColor: Colors.red,
          ),
        );
        return id;
      }

      if (!await SqlConn.isConnected) {
        await SqlConn.connect(
          ip: connDetails['ip'] as String,
          port: connDetails['port'] as String,
          databaseName: connDetails['dbName'] as String,
          username: connDetails['username'] as String,
          password: connDetails['password'] as String,
          timeout: 10,
        );
      }

      final query = """
        DECLARE @Output INT;
        EXEC spItemLessPunch 
            @OrderDtlID = '$orderDetailId',
            @TabUniqueID = '$tabUniqueId',
            @qty = $quantity,
            @Reason = '$reason',
            @UserLogin = '$username',
            @UserApproval = '$authenticateUsername',
            @TiltId = '$tiltId',
            @Output = @Output OUTPUT;
        SELECT @Output AS id;
      """;

      debugPrint("📝 ItemLess Query: $query");
      final result = await SqlConn.readData(query);
      debugPrint("📤 ItemLess Result: $result");

      final decoded = jsonDecode(result);
      if (decoded is List && decoded.isNotEmpty && decoded[0]['id'] != null) {
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
    } finally {
      if (await SqlConn.isConnected) {
        await SqlConn.disconnect();
        debugPrint('🛑 SQL Server connection closed');
      }
    }
  }

  Widget _buildSummaryRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 16,
              fontFamily: 'Raleway',
            ),
          ),
          Text(
            value,
            style: const TextStyle(
              color: Color(0xFF75E5E2),
              fontSize: 16,
              fontWeight: FontWeight.bold,
              fontFamily: 'Raleway',
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildOrderListWithDetails() {
    final isRunningOrder = widget.tabUniqueId != null && widget.tabUniqueId!.isNotEmpty;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.symmetric(vertical: 12.0, horizontal: 8.0),
          decoration: BoxDecoration(
            color: Colors.grey.shade800,
            borderRadius: BorderRadius.circular(8.0),
          ),
          child: const Row(
            children: [
              Expanded(
                flex: 3,
                child: Text(
                  'Item',
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w900,
                    fontFamily: 'Raleway',
                  ),
                ),
              ),
              Expanded(
                flex: 2,
                child: Text(
                  'Price',
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontFamily: 'Raleway',
                  ),
                ),
              ),
              Expanded(
                flex: 3,
                child: Center(
                  child: Text(
                    'Qty',
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontFamily: 'Raleway',
                    ),
                  ),
                ),
              ),
              Expanded(
                flex: 2,
                child: Text(
                  'Tax',
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontFamily: 'Raleway',
                  ),
                ),
              ),
              Expanded(
                flex: 3,
                child: Text(
                  'Total',
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontFamily: 'Raleway',
                  ),
                  textAlign: TextAlign.right,
                ),
              ),
            ],
          ),
        ),
        Expanded(
          child: ListView.builder(
            shrinkWrap: true,
            itemCount: _activeOrderItems.length,
            itemBuilder: (context, index) {
              final orderItem = _activeOrderItems[index];
              final subtotal = orderItem.subtotal;
              final taxAmount = orderItem.tax;
              final total = orderItem.total;

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
                              Text(
                                orderItem.itemName,
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.w500,
                                  fontFamily: 'Raleway',
                                ),
                              ),
                              if (orderItem.comments.isNotEmpty)
                                Text(
                                  orderItem.comments,
                                  style: const TextStyle(
                                    color: Colors.white70,
                                    fontSize: 12,
                                    fontStyle: FontStyle.italic,
                                    fontFamily: 'Raleway',
                                  ),
                                ),
                            ],
                          ),
                        ),
                        Expanded(
                          flex: 2,
                          child: Text(
                            orderItem.price.toStringAsFixed(2),
                            style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.w500,
                              fontFamily: 'Raleway',
                            ),
                          ),
                        ),
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
                                      color: const Color(0xFF75E5E2),
                                      width: 1.5,
                                    ),
                                  ),
                                  child: const Icon(
                                    Icons.remove,
                                    size: 14,
                                    color: Color(0xFF75E5E2),
                                  ),
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
                                    fontFamily: 'Raleway',
                                  ),
                                ),
                              ),
                              const SizedBox(width: 4),
                              InkWell(
                                onTap: () => _addItemToOrder(orderItem.toMap()),
                                onLongPress: () => _showCommentDialog(orderItem),
                                borderRadius: BorderRadius.circular(20),
                                child: Container(
                                  padding: const EdgeInsets.all(3),
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    border: Border.all(
                                      color: const Color(0xFF75E5E2),
                                      width: 1.5,
                                    ),
                                  ),
                                  child: const Icon(
                                    Icons.add,
                                    size: 14,
                                    color: Color(0xFF75E5E2),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                        Expanded(
                          flex: 2,
                          child: Text(
                            taxAmount.toStringAsFixed(2),
                            style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.w500,
                              fontFamily: 'Raleway',
                            ),
                          ),
                        ),
                        Expanded(
                          flex: 3,
                          child: Text(
                            total.toStringAsFixed(2),
                            style: const TextStyle(
                              color: Color(0xFF75E5E2),
                              fontWeight: FontWeight.bold,
                              fontFamily: 'Raleway',
                            ),
                            textAlign: TextAlign.right,
                          ),
                        ),
                      ],
                    ),
                    const Divider(color: Colors.white10),
                  ],
                ),
              );
            },
          ),
        ),
        _buildSummaryRow('Total Items', '${_activeOrderItems.length}'),
        _buildSummaryRow('Order Tax', ' ${_totalTax.toStringAsFixed(2)}'),
        _buildSummaryRow('Discount', ' ${_totalDiscount.toStringAsFixed(2)}'),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text(
              'Total Bill:',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: Colors.white,
                fontFamily: 'Raleway',
              ),
            ),
            Text(
              ' ${_orderTotalAmount.toStringAsFixed(2)}',
              style: const TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: Color(0xFF75E5E2),
                fontFamily: 'Raleway',
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        ElevatedButton(
          onPressed: _activeOrderItems.isEmpty
              ? null
              : () async {
                  final orderId = await _saveOrderToSqlServer();
                  if (orderId != null) {
                    _showSuccessDialog(orderId);
                  }
                },
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFF75E5E2),
            foregroundColor: const Color(0xFF0D1D20),
            minimumSize: const Size(double.infinity, 50),
            textStyle: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              fontFamily: 'Raleway',
            ),
          ),
          child: const Text('Place Order'),
        ),
      ],
    );
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
            Icon(
              Icons.check_circle_outline,
              color: Color(0xFF75E5E2),
              size: 60,
            ),
            SizedBox(height: 10),
            Text(
              "Success!",
              style: TextStyle(
                color: Colors.white,
                fontSize: 22,
                fontWeight: FontWeight.bold,
                fontFamily: 'Raleway',
              ),
            ),
          ],
        ),
        content: const Text(
          "Your Order Successfully Placed",
          textAlign: TextAlign.center,
          style: TextStyle(
            color: Colors.white70,
            fontSize: 16,
            fontFamily: 'Raleway',
          ),
        ),
        actions: [
          Center(
            child: ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF75E5E2),
                foregroundColor: const Color(0xFF0D1D20),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
              onPressed: () {
                Navigator.pop(ctx);
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => BillScreen()),
                );
              },
              child: const Text("View Bill", style: TextStyle(fontFamily: 'Raleway')),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Theme(
      data: ThemeData(
        primaryColor: const Color(0xFF75E5E2),
        scaffoldBackgroundColor: const Color(0xFF0D1D20),
        appBarTheme: const AppBarTheme(
          backgroundColor: Color(0xFF0D1D20),
          foregroundColor: Colors.white,
          elevation: 4,
          titleTextStyle: TextStyle(fontFamily: 'Raleway', fontSize: 20, fontWeight: FontWeight.bold),
        ),
        tabBarTheme: const TabBarThemeData(
          labelColor: Color(0xFF75E5E2),
          unselectedLabelColor: Colors.white70,
          labelStyle: TextStyle(fontFamily: 'Raleway', fontWeight: FontWeight.bold),
          unselectedLabelStyle: TextStyle(fontFamily: 'Raleway'),
          indicator: UnderlineTabIndicator(
            borderSide: BorderSide(color: Color(0xFF75E5E2), width: 2),
          ),
        ),
        cardTheme: CardThemeData(
          color: Colors.grey.shade900,
          elevation: 4,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
        textTheme: const TextTheme(
          titleLarge: TextStyle(fontFamily: 'Raleway', fontSize: 20, fontWeight: FontWeight.bold, color: Colors.white),
          bodyMedium: TextStyle(fontFamily: 'Raleway', fontSize: 16, color: Colors.white),
          bodySmall: TextStyle(fontFamily: 'Raleway', fontSize: 14, color: Colors.white70),
        ),
        floatingActionButtonTheme: const FloatingActionButtonThemeData(
          backgroundColor: Color(0xFF75E5E2),
          foregroundColor: Color(0xFF0D1D20),
        ),
        snackBarTheme: const SnackBarThemeData(
          backgroundColor: Colors.red,
          contentTextStyle: TextStyle(fontFamily: 'Raleway', color: Colors.white),
        ),
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFF75E5E2),
            foregroundColor: const Color(0xFF0D1D20),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            textStyle: const TextStyle(fontFamily: 'Raleway'),
          ),
        ),
        textButtonTheme: TextButtonThemeData(
          style: TextButton.styleFrom(
            foregroundColor: Colors.redAccent,
            textStyle: const TextStyle(fontFamily: 'Raleway'),
          ),
        ),
        inputDecorationTheme: InputDecorationTheme(
          filled: true,
          fillColor: Colors.grey.shade800,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide: const BorderSide(color: Color(0xFF75E5E2)),
          ),
          hintStyle: const TextStyle(color: Colors.white54, fontFamily: 'Raleway'),
          labelStyle: const TextStyle(color: Colors.white54, fontFamily: 'Raleway'),
        ),
      ),
      child: Scaffold(
        appBar: AppBar(
          title: Text('Take Away - ${_finalTiltName ?? "T2"}'),
          bottom: _tabController != null && _categories.isNotEmpty
              ? TabBar(
                  controller: _tabController,
                  isScrollable: true,
                  tabs: _categories.map((category) => Tab(text: category['category_name'] as String)).toList(),
                  onTap: (index) {
                    setState(() {
                      _selectedCategory = _categories[index]['category_name'] as String;
                    });
                  },
                )
              : null,
        ),
        body: _isLoading
            ? const Center(child: CircularProgressIndicator(color: Color(0xFF75E5E2)))
            : LayoutBuilder(
                builder: (context, constraints) {
                  return constraints.maxWidth > 600
                      ? _buildDesktopLayout()
                      : _buildMobileLayout();
                },
              ),
        floatingActionButton: FloatingActionButton.extended(
          onPressed: () async {
            final orderId = await _saveOrderToSqlServer();
            if (orderId != null) {
              _showSuccessDialog(orderId);
            }
          },
          label: Text('Order Dekho (${_activeOrderItems.length})'),
          icon: const Icon(Icons.shopping_cart),
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
            child: _buildOrderListWithDetails(),
          ),
        ),
        Expanded(
          flex: 2,
          child: Column(
            children: [
              SizedBox(
                height: 50,
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
                        backgroundColor: isSelected ? const Color(0xFF75E5E2) : Colors.grey.shade800,
                        labelStyle: TextStyle(
                          color: isSelected ? const Color(0xFF0D1D20) : Colors.white,
                          fontFamily: 'Raleway',
                        ),
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
                  child: _selectedCategory != null && _categoryItems[_selectedCategory] != null
                      ? GridView.builder(
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
                            return Card(
                              child: InkWell(
                                onTap: () => _addItemToOrder(item),
                                onLongPress: () => _showCommentDialog(OrderItem.fromMap(item)),
                                child: Padding(
                                  padding: const EdgeInsets.all(8.0),
                                  child: Column(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      const Icon(
                                        Icons.local_dining,
                                        color: Color(0xFF75E5E2),
                                        size: 40,
                                      ),
                                      const SizedBox(height: 8),
                                      Text(
                                        item['item_name'],
                                        textAlign: TextAlign.center,
                                        style: const TextStyle(
                                          color: Colors.white,
                                          fontSize: 16,
                                          fontWeight: FontWeight.bold,
                                          fontFamily: 'Raleway',
                                        ),
                                      ),
                                      const SizedBox(height: 4),
                                      Text(
                                        ' ${item['sale_price'].toStringAsFixed(2)}',
                                        style: const TextStyle(
                                          color: Colors.white70,
                                          fontSize: 14,
                                          fontFamily: 'Raleway',
                                        ),
                                      ),
                                      const SizedBox(height: 4),
                                      Row(
                                        mainAxisAlignment: MainAxisAlignment.center,
                                        children: [
                                          const Text(
                                            'Tax:',
                                            style: TextStyle(
                                              color: Colors.white70,
                                              fontSize: 12,
                                              fontFamily: 'Raleway',
                                            ),
                                          ),
                                          Text(
                                            ' ${(OrderConstants.taxRate * 100).toStringAsFixed(1)}%',
                                            style: const TextStyle(
                                              color: Colors.lightGreen,
                                              fontSize: 12,
                                              fontWeight: FontWeight.bold,
                                              fontFamily: 'Raleway',
                                            ),
                                          ),
                                          const Text(
                                            ' | ',
                                            style: TextStyle(
                                              color: Colors.white70,
                                              fontSize: 12,
                                              fontFamily: 'Raleway',
                                            ),
                                          ),
                                          const Text(
                                            'Disc:',
                                            style: TextStyle(
                                              color: Colors.white70,
                                              fontSize: 12,
                                              fontFamily: 'Raleway',
                                            ),
                                          ),
                                          Text(
                                            ' ${(OrderConstants.discountRate * 100).toStringAsFixed(1)}%',
                                            style: const TextStyle(
                                              color: Colors.orange,
                                              fontSize: 12,
                                              fontWeight: FontWeight.bold,
                                              fontFamily: 'Raleway',
                                            ),
                                          ),
                                        ],
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            );
                          },
                        )
                      : const Center(
                          child: Text(
                            'No items available',
                            style: TextStyle(color: Colors.white70, fontFamily: 'Raleway'),
                          ),
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
        SizedBox(
          height: 60,
          child: AppBar(
            backgroundColor: const Color(0xFF0D1D20),
            bottom: TabBar(
              controller: _tabController,
              isScrollable: true,
              tabs: _categories.map((category) => Tab(text: category['category_name'] as String)).toList(),
            ),
          ),
        ),
        Expanded(
          child: _selectedCategory != null && _categoryItems[_selectedCategory] != null
              ? TabBarView(
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
                          return Card(
                            child: InkWell(
                              onTap: () => _addItemToOrder(item),
                              onLongPress: () => _showCommentDialog(OrderItem.fromMap(item)),
                              child: Padding(
                                padding: const EdgeInsets.all(8.0),
                                child: Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    const Icon(
                                      Icons.local_dining,
                                      color: Color(0xFF75E5E2),
                                      size: 40,
                                    ),
                                    const SizedBox(height: 8),
                                    Text(
                                      item['item_name'],
                                      textAlign: TextAlign.center,
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontSize: 16,
                                        fontWeight: FontWeight.bold,
                                        fontFamily: 'Raleway',
                                      ),
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      ' ${item['sale_price'].toStringAsFixed(2)}',
                                      style: const TextStyle(
                                        color: Colors.white70,
                                        fontSize: 14,
                                        fontFamily: 'Raleway',
                                      ),
                                    ),
                                    const SizedBox(height: 4),
                                    Row(
                                      mainAxisAlignment: MainAxisAlignment.center,
                                      children: [
                                        const Text(
                                          'Tax:',
                                          style: TextStyle(
                                            color: Colors.white70,
                                            fontSize: 12,
                                            fontFamily: 'Raleway',
                                          ),
                                        ),
                                        Text(
                                          ' ${(OrderConstants.taxRate * 100).toStringAsFixed(1)}%',
                                          style: const TextStyle(
                                            color: Colors.lightGreen,
                                            fontSize: 12,
                                            fontWeight: FontWeight.bold,
                                            fontFamily: 'Raleway',
                                          ),
                                        ),
                                        const Text(
                                          ' | ',
                                          style: TextStyle(
                                            color: Colors.white70,
                                            fontSize: 12,
                                            fontFamily: 'Raleway',
                                          ),
                                        ),
                                        const Text(
                                          'Disc:',
                                          style: TextStyle(
                                            color: Colors.white70,
                                            fontSize: 12,
                                            fontFamily: 'Raleway',
                                          ),
                                        ),
                                        Text(
                                          ' ${(OrderConstants.discountRate * 100).toStringAsFixed(1)}%',
                                          style: const TextStyle(
                                            color: Colors.orange,
                                            fontSize: 12,
                                            fontWeight: FontWeight.bold,
                                            fontFamily: 'Raleway',
                                          ),
                                        ),
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
                )
              : const Center(
                  child: Text(
                    'No items available',
                    style: TextStyle(color: Colors.white70, fontFamily: 'Raleway'),
                  ),
                ),
        ),
      ],
    );
  }
}