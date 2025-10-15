import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:mssql_connection/mssql_connection.dart';
import 'package:sql_conn/sql_conn.dart';
import 'package:start_app/database_helper.dart';
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
}

// Screen for selecting a waiter
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
    return Scaffold(
      appBar: AppBar(title: const Text('Select Waiter')),
      body: ListView.builder(
        itemCount: waiters.length,
        itemBuilder: (context, index) {
          final waiter = waiters[index];
          return ListTile(
            title: Text(waiter),
            onTap: () {
              onWaiterSelected(waiter);
              Navigator.pop(context);
            },
          );
        },
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
  String? _finalTiltName;
  String? _tabUniqueId;
  String? _customerName;
  String? _phone;
  String _customerPosId = "0";
  bool _customerDetailsCollected = false;

  @override
  void initState() {
    super.initState();
    _mssql = MssqlConnection.getInstance();
    _checkTakeAwayCustomerInfoStatus();
  }

  @override
  void dispose() {
    _tabController?.dispose();
    super.dispose();
  }

  Future<void> _checkTakeAwayCustomerInfoStatus() async {
    try {
      _takeAwaySettings = await DatabaseHelper.instance.getTakeAwaySettings();
      setState(() {
        _finalTiltId = int.tryParse(_takeAwaySettings?['tiltId']?.toString() ?? '33') ?? 33;
        _finalTiltName = _takeAwaySettings?['tiltName']?.toString() ?? 'T2';
        _deviceNo = _takeAwaySettings?['deviceName']?.toString() ?? 'Lenovo TB-X505F';
        _isPrintKot = _takeAwaySettings?['isPrintKot'] ?? 1;
      });
      await _initConnectionAndLoadData();
    } catch (e) {
      debugPrint('❌ Error checking TakeAway settings: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error loading settings: $e')),
      );
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
      await _fetchExistingOrder();
    } catch (e) {
      debugPrint('❌ Error initializing connection and data: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error initializing: $e')),
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
      _customerName = _takeAwaySettings?['defaultCustomerName'] ?? 'WalkIn';
      _phone = _takeAwaySettings?['defaultPhone'] ?? '';
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
    }
  }

  Future<String> _generateNewTabUniqueId() async {
    final now = DateTime.now();
    final formatter = DateFormat('yyyy-MM-dd HH:mm:ss');
    return 'T1${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')} ${formatter.format(now).split(' ')[1]}';
  }

  Future<void> _fetchExistingOrder() async {
    // Placeholder for fetching existing order, if needed
    debugPrint('📥 Checking for existing order with tab_unique_id: $_tabUniqueId');
  }

  Future<void> _fetchMenuData() async {
    try {
      final categories = await DatabaseHelper.instance.getCategories();
      final items = await DatabaseHelper.instance.getItems();
      final Map<String, List<Map<String, dynamic>>> categoryItems = {};

      for (var category in categories) {
        final categoryName = category['category_name'] as String;
        categoryItems[categoryName] = items.where((item) => item['category_name'] == categoryName).toList();
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
    }
  }

  Future<void> _loadLoggedUser() async {
    final loggedUser = await DatabaseHelper.instance.getLoggedInUser();
    setState(() {
      _currentUser = loggedUser ?? 'Admin';
    });
    debugPrint('📦 Current logged-in user: $_currentUser');
  }

  Future<bool> _checkUser(String username, String password) async {
    // Placeholder for user authentication
    return true;
  }

  Future<void> _showReasonDialog(String itemId, String itemName) async {
    // Placeholder for reason dialog, if needed
  }

  Future<void> _showAuthDialog() async {
    // Placeholder for authentication dialog, if needed
  }

  Future<String?> _showCommentDialog() async {
    // Placeholder for comment dialog
    return 'Please prepare quickly!';
  }

  void _addItemToOrder(String itemId, String itemName, double price) {
    setState(() {
      final existingItemIndex = _activeOrderItems.indexWhere((item) => item.itemId == itemId);
      if (existingItemIndex != -1) {
        _activeOrderItems[existingItemIndex].quantity++;
      } else {
        _activeOrderItems.add(OrderItem(
          itemId: itemId,
          itemName: itemName,
          quantity: 1,
          price: price,
          orderDetailId: '0',
          comments: 'Please prepare quickly!',
        ));
      }
      _calculateTotalBill();
    });

    debugPrint('🧾 Item: $itemName, Qty: 1, Price: $price, Subtotal: ${price}, Tax%: ${OrderConstants.taxRate * 100}, Discount%: ${OrderConstants.discountRate * 100}, Final: ${price * (1 + OrderConstants.taxRate)}');
  }

  void _calculateTotalBill() {
    double total = 0.0;
    double tax = 0.0;
    for (var item in _activeOrderItems) {
      total += item.subtotal;
      tax += item.tax;
    }
    setState(() {
      _orderTotalAmount = total + tax;
      _totalTax = tax;
      _totalDiscount = 0.0;
    });
    debugPrint('💰 Final Bill => Total: $_orderTotalAmount | Tax: $_totalTax | Discount: $_totalDiscount');
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
          @Comment = '$commentList',
          @CustomerPOSId = '$_customerPosId',
          @OrderKey = @OrderKey OUTPUT;
      SELECT @OrderKey AS id;
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

    debugPrint("===== FINAL QUERY =====\n$query");
    debugPrint("📝 Qty List => $qtyList");
    debugPrint("📝 Product Codes => $productCodes");
    debugPrint("📝 Order Detail IDs => $orderDtlIds");
    debugPrint("📝 Comments => $commentList");
    debugPrint("📝 Customer Name => $_customerName");
    debugPrint("📝 Phone => $_phone");
    debugPrint("📝 CustomerPOSId => $_customerPosId");

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
      debugPrint("📤 Query Result: $result");

      int? newOrderId;
      try {
        final decoded = jsonDecode(result);
        if (decoded is List && decoded.isNotEmpty) {
          newOrderId = int.tryParse(decoded[0]['id']?.toString() ?? '');
        } else if (decoded is Map && decoded['id'] != null) {
          newOrderId = int.tryParse(decoded['id']?.toString() ?? '');
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
    } finally {
      if (await SqlConn.isConnected) {
        await SqlConn.disconnect();
        debugPrint('🛑 SQL Server connection closed');
      }
    }
  }

  void _showSuccessDialog(int orderId) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Order Placed'),
        content: Text('Order #$orderId placed successfully!'),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              Navigator.pushReplacement(
                context,
                MaterialPageRoute(
                  builder: (context) => BillScreen(orderId: orderId),
                ),
              );
            },
            child: const Text('OK'),
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
          Text(label, style: const TextStyle(fontWeight: FontWeight.bold)),
          Text(value),
        ],
      ),
    );
  }

  Widget _buildOrderListWithDetails() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Order Summary',
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 10),
        Expanded(
          child: ListView.builder(
            itemCount: _activeOrderItems.length,
            itemBuilder: (context, index) {
              final item = _activeOrderItems[index];
              return ListTile(
                title: Text(item.itemName),
                subtitle: Text('Qty: ${item.quantity} | Subtotal: ${item.subtotal.toStringAsFixed(2)} | Tax: ${item.tax.toStringAsFixed(2)}'),
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    IconButton(
                      icon: const Icon(Icons.add),
                      onPressed: () => _addItemToOrder(item.itemId, item.itemName, item.price),
                    ),
                  ],
                ),
              );
            },
          ),
        ),
        _buildSummaryRow('Total', _orderTotalAmount.toStringAsFixed(2)),
        _buildSummaryRow('Tax', _totalTax.toStringAsFixed(2)),
        _buildSummaryRow('Discount', _totalDiscount.toStringAsFixed(2)),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
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
          ? const Center(child: CircularProgressIndicator())
          : Row(
              children: [
                Expanded(
                  flex: 2,
                  child: _selectedCategory != null && _categoryItems[_selectedCategory] != null
                      ? _buildDesktopLayout()
                      : const Center(child: Text('No items available')),
                ),
                Expanded(
                  flex: 1,
                  child: _buildOrderListWithDetails(),
                ),
              ],
            ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _showCustomerDetailsDialog(),
        child: const Icon(Icons.check),
      ),
    );
  }

  Widget _buildDesktopLayout() {
    final items = _categoryItems[_selectedCategory] ?? [];
    return GridView.builder(
      padding: const EdgeInsets.all(10),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 3,
        crossAxisSpacing: 10,
        mainAxisSpacing: 10,
        childAspectRatio: 1.5,
      ),
      itemCount: items.length,
      itemBuilder: (context, index) {
        final item = items[index];
        return Card(
          child: InkWell(
            onTap: () => _addItemToOrder(
              item['id'].toString(),
              item['item_name'] as String,
              (item['sale_price'] as num).toDouble(),
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(item['item_name'] as String, textAlign: TextAlign.center),
                Text('Price: ${(item['sale_price'] as num).toDouble().toStringAsFixed(2)}'),
              ],
            ),
          ),
        );
      },
    );
  }

  Future<void> _showCustomerDetailsDialog() async {
    TextEditingController nameController = TextEditingController(text: _customerName);
    TextEditingController phoneController = TextEditingController(text: _phone);

    final result = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Customer Details'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: nameController,
              decoration: const InputDecoration(labelText: 'Customer Name'),
            ),
            TextField(
              controller: phoneController,
              decoration: const InputDecoration(labelText: 'Phone Number'),
              keyboardType: TextInputType.phone,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              if (nameController.text.isEmpty || phoneController.text.isEmpty) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Please fill all required fields')),
                );
                return;
              }
              Navigator.pop(context, true);
            },
            child: const Text('OK'),
          ),
        ],
      ),
    );

    if (result == true) {
      setState(() {
        _customerName = nameController.text;
        _phone = phoneController.text;
        _customerDetailsCollected = true;
      });
      final orderId = await _saveOrderToSqlServer();
      if (orderId != null) {
        // Navigation handled in _showSuccessDialog
      }
    }
  }
}