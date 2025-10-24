// ignore_for_file: unused_field

import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:mssql_connection/mssql_connection.dart';
import 'package:start_app/database_halper.dart';
import 'package:sql_conn/sql_conn.dart';
import 'package:start_app/bill_screen.dart';
import 'package:intl/intl.dart';
import 'package:start_app/customer_search_screen.dart'; // <--- अब Customer मॉडल केवल यहीं से लिया जाएगा

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

class DeliveryScreen extends StatefulWidget {
  final String waiterName;
  final int? selectedTiltId;
  final String? tabUniqueId;

  const DeliveryScreen({
    required this.waiterName,
    required this.selectedTiltId,
    required this.tabUniqueId,
    super.key,
  });

  @override
  _DeliveryScreenState createState() => _DeliveryScreenState();
}

class _DeliveryScreenState extends State<DeliveryScreen> with TickerProviderStateMixin {
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
  TabController? _tabController;
  List<OrderItem> _activeOrderItems = [];
  double _orderTotalAmount = 0.0;
  double _totalTax = 0.0;
  double _totalDiscount = 0.0;
  int? _finalTiltId;
  String? _finalTiltName;
  String? _tabUniqueId;
  bool _hasCustomerDetails = false;
  String? _customerName;
  String? _phone;
  String? _address;
  String? _address2;
  String? _telNo;
  String? _customerMasterId;

  @override
  void initState() {
    super.initState();
    _initConnectionAndLoadData();
  }

  Future<void> _initConnectionAndLoadData() async {
    if (!mounted) return;
    await _setupSqlConn();
    await _loadConnectionDetails();
    await _loadLoggedUser();
    await _loadTiltFromLocal();
    await _checkUser();
    await _fetchMenuData();
    if (widget.tabUniqueId != null && widget.tabUniqueId!.isNotEmpty) {
      _tabUniqueId = widget.tabUniqueId;
      await _fetchExistingOrder(widget.tabUniqueId!);
    } else {
      _generateNewTabUniqueId();
    }
    if (mounted) {
      await _showCustomerDetailsDialog(); // Use the updated dialog function
      setState(() {
        _isLoading = false;
      });
    }
  }

  @override
  void dispose() {
    _tabController?.dispose();
    SqlConn.disconnect();
    super.dispose();
  }

  Future<void> _loadLoggedUser() async {
    final user = await DatabaseHelper.instance.getLoggedInUser();
    if (mounted) {
      setState(() {
        _currentUser = user ?? "Admin";
      });
    }
    debugPrint("✅ Current user: $_currentUser");
  }

  Future<void> _loadConnectionDetails() async {
    final connDetails = await DatabaseHelper.instance.getConnectionDetails();
    if (mounted) {
      setState(() {
        _connectionDetails = connDetails;
        _currentUser = connDetails?['user'] ?? 'Admin';
        _deviceNo = connDetails?['deviceName']?.isNotEmpty ?? false
            ? connDetails!['deviceName']
            : 'POS01';
        _isPrintKot = connDetails?['isCashier'] ?? 1;
      });
    }
  }

  Future<void> _checkUser() async {
    final user = await DatabaseHelper.instance.getLoggedInUser();
    debugPrint(user != null ? "✅ Logged-in user: $user" : "❌ No user found.");
  }

  Future<void> _loadTiltFromLocal() async {
    final savedDetails = await DatabaseHelper.instance.getConnectionDetails();
    if (mounted) {
      setState(() {
        _finalTiltId = int.tryParse(savedDetails?['tiltId'] ?? '0') ?? 0;
        _finalTiltName = savedDetails?['tiltName'] ?? '';
      });
    }
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

      if (mounted) {
        setState(() {
          _tabUniqueId = tabUniqueId;
        });
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
      if (mounted) {
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

            if (itemId == '1' || itemId.isEmpty) {
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
      }
      debugPrint("🧩 Loaded existing order: ${_activeOrderItems.length} items");
    } catch (e, stackTrace) {
      debugPrint('❌ Error fetching existing order: $e\n$stackTrace');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to fetch order: $e')),
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
      final tiltName = _connectionDetails?['tiltName'] ?? 'D1';
      setState(() {
        _tabUniqueId = '$tiltName$formattedDate';
      });
      debugPrint("✅ Generated new tab_unique_id => $_tabUniqueId");
    }
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

      if (mounted) {
        setState(() {
          _categories = categories;
          _categoryItems = groupedData;
          if (_categories.isNotEmpty) {
            _selectedCategory = _categories[0]['category_name'];
            _tabController?.dispose();
            _tabController = TabController(length: _categories.length, vsync: this);
          }
        });
      }
      debugPrint("📦 Menu Loaded: ${_categories.length} categories");
    } catch (e) {
      debugPrint("❌ Error fetching menu data: $e");
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Error loading menu: $e")),
      );
    }
  }

  Future<bool> _ensureSqlConnection() async {
    if (await SqlConn.isConnected) return true;
    final conn = await DatabaseHelper.instance.getConnectionDetails();
    if (conn == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Connection details missing'),
          backgroundColor: Colors.red,
        ),
      );
      return false;
    }
    try {
      await SqlConn.connect(
        ip: conn['ip'],
        port: conn['port'],
        databaseName: conn['dbName'],
        username: conn['username'],
        password: conn['password'],
      );
      return true;
    } catch (e) {
      debugPrint("❌ Error connecting to SQL: $e");
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to connect to SQL Server: $e'), backgroundColor: Colors.red),
      );
      return false;
    }
  }

  Future<void> _setupSqlConn() async {
    _mssql = MssqlConnection.getInstance();
    final details = await DatabaseHelper.instance.getConnectionDetails();
    if (details == null) {
      setState(() => _isMssqlReady = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Database connection details not found!'),
          backgroundColor: Colors.red,
        ),
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
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<String?> _insertCustomerToDatabase(String customerName, String phone, String telNo, String address, String address2) async {
    try {
      if (!await _ensureSqlConnection()) {
        debugPrint("❌ Failed to establish SQL connection for customer insertion");
        return null;
      }

      final sanitizedCustomerName = customerName.replaceAll(RegExp(r'[\%_\\]'), '');
      final sanitizedPhone = phone.replaceAll(RegExp(r'[\%_\\]'), '');
      final sanitizedTelNo = telNo.replaceAll(RegExp(r'[\%_\\]'), '');
      final sanitizedAddress = address.replaceAll(RegExp(r'[\%_\\]'), '');
      final sanitizedAddress2 = address2.replaceAll(RegExp(r'[\%_\\]'), '');

      final query = """
        DECLARE @NewID INT;
        EXEC usp_SaveCustomerWithOutOrderKey
            @customer_name = '$sanitizedCustomerName',
            @address = '$sanitizedAddress',
            @tel_no = '$sanitizedTelNo',
            @cell_no = '$sanitizedPhone',
            @CustomerCode = 0,
            @Active = 1,
            @Address2 = '$sanitizedAddress2',
            @customer_group_id = 0,
            @NewID = @NewID OUTPUT;
        SELECT @NewID AS id;
      """;

      debugPrint("📝 Insert Customer Query: $query");
      final result = await SqlConn.readData(query);
      debugPrint("📤 Insert Customer Result: $result");

      final decoded = jsonDecode(result);
      if (decoded is List && decoded.isNotEmpty && decoded[0]['id'] != null) {
        final newId = decoded[0]['id'].toString();
        debugPrint("✅ Customer saved with ID: $newId");
        return newId;
      } else {
        debugPrint("❌ Failed to retrieve customer ID: Invalid result format");
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Failed to save customer details: Invalid result from server'),
            backgroundColor: Colors.red,
          ),
        );
        return null;
      }
    } catch (e, stackTrace) {
      debugPrint("❌ Error saving customer: $e\nStackTrace: $stackTrace");
      String errorMessage = 'Error saving customer details: $e';
      if (e.toString().contains('Subquery returned more than 1 value')) {
        errorMessage = 'Multiple customers found with the same phone number. Please use a unique phone number or search for an existing customer.';
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(errorMessage),
          backgroundColor: Colors.red,
        ),
      );
      return null;
    }
  }

  Future<void> _showCustomerDetailsDialog({Customer? prefilledCustomer}) async {
    final TextEditingController customerNameController = TextEditingController(text: prefilledCustomer?.customerName);
    final TextEditingController phoneController = TextEditingController(text: prefilledCustomer?.cellNo);
    final TextEditingController telController = TextEditingController(text: prefilledCustomer?.telNo);
    final TextEditingController addressController = TextEditingController(text: prefilledCustomer?.address);
    final TextEditingController address2Controller = TextEditingController(text: prefilledCustomer?.address2);
    
    String? currentCustomerId = prefilledCustomer?.id;

    bool isValidPhone(String phone) {
      return RegExp(r'^\d{10,15}$').hasMatch(phone);
    }

    bool isValidTel(String tel) {
      return tel.isEmpty || RegExp(r'^\d{7,15}$').hasMatch(tel);
    }

    void _setCustomerDetails(Customer customer) {
      customerNameController.text = customer.customerName;
      phoneController.text = customer.cellNo;
      telController.text = customer.telNo;
      addressController.text = customer.address;
      address2Controller.text = customer.address2;
      currentCustomerId = customer.id;
    }

    final result = await showDialog<Map<String, String>>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (dialogContext, setDialogState) {
            return AlertDialog(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              backgroundColor: const Color(0xFF182022),
              title: const Text(
                'Customer Details (Delivery)',
                style: TextStyle(
                  color: Colors.white,
                  fontFamily: 'Raleway',
                  fontWeight: FontWeight.bold,
                ),
              ),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Search Button
                    ElevatedButton.icon(
                      onPressed: () async {
                        // Navigate to the new search screen
                        // NOTE: Customer is correctly imported from customer_search_screen.dart
                        final Customer? selectedCustomer = await Navigator.push(
                          dialogContext,
                          MaterialPageRoute(
                            builder: (context) => const CustomerSearchScreen(),
                          ),
                        );
                        
                        // Use the correct Customer type here (the one imported)
                        if (selectedCustomer != null) {
                          setDialogState(() {
                            _setCustomerDetails(selectedCustomer);
                          });
                        }
                      },
                      icon: const Icon(Icons.person_search, color: Color(0xFF0D1D20)),
                      label: const Text(
                        'Search Existing Customer',
                        style: TextStyle(fontFamily: 'Raleway', color: Color(0xFF0D1D20)),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF75E5E2),
                        minimumSize: const Size(double.infinity, 40),
                      ),
                    ),
                    const SizedBox(height: 20),
                    
                    // Fields
                    TextField(
                      controller: customerNameController,
                      style: const TextStyle(color: Colors.white, fontFamily: 'Raleway'),
                      decoration: InputDecoration(
                        hintText: 'Enter customer name',
                        hintStyle: const TextStyle(color: Colors.white54, fontFamily: 'Raleway'),
                        filled: true,
                        fillColor: Colors.grey.shade800,
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: phoneController,
                      style: const TextStyle(color: Colors.white, fontFamily: 'Raleway'),
                      keyboardType: TextInputType.phone,
                      decoration: InputDecoration(
                        hintText: 'Enter phone number',
                        hintStyle: const TextStyle(color: Colors.white54, fontFamily: 'Raleway'),
                        filled: true,
                        fillColor: Colors.grey.shade800,
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: telController,
                      style: const TextStyle(color: Colors.white, fontFamily: 'Raleway'),
                      keyboardType: TextInputType.phone,
                      decoration: InputDecoration(
                        hintText: 'Enter tell number (optional)',
                        hintStyle: const TextStyle(color: Colors.white54, fontFamily: 'Raleway'),
                        filled: true,
                        fillColor: Colors.grey.shade800,
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: addressController,
                      style: const TextStyle(color: Colors.white, fontFamily: 'Raleway'),
                      maxLines: 2,
                      decoration: InputDecoration(
                        hintText: 'Enter delivery address',
                        hintStyle: const TextStyle(color: Colors.white54, fontFamily: 'Raleway'),
                        filled: true,
                        fillColor: Colors.grey.shade800,
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: address2Controller,
                      style: const TextStyle(color: Colors.white, fontFamily: 'Raleway'),
                      maxLines: 2,
                      decoration: InputDecoration(
                        hintText: 'Enter additional address (optional)',
                        hintStyle: const TextStyle(color: Colors.white54, fontFamily: 'Raleway'),
                        filled: true,
                        fillColor: Colors.grey.shade800,
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                      ),
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () {
                    Navigator.of(dialogContext).pop(
                      {'action': 'cancel'}
                    );
                    // This line ensures the main DeliveryScreen also closes if canceled on first load
                    Navigator.of(context).pop(); 
                  },
                  child: const Text(
                    'Cancel',
                    style: TextStyle(
                      color: Colors.redAccent,
                      fontFamily: 'Raleway',
                    ),
                  ),
                ),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF75E5E2),
                    foregroundColor: const Color(0xFF0D1D20),
                  ),
                  onPressed: () {
                    final customerName = customerNameController.text.trim();
                    final phone = phoneController.text.trim();
                    final tel = telController.text.trim();
                    final address = addressController.text.trim();
                    final address2 = address2Controller.text.trim();
                    
                    // Validation
                    if (customerName.isEmpty || phone.isEmpty || address.isEmpty) {
                      ScaffoldMessenger.of(dialogContext).showSnackBar(
                        const SnackBar(
                          content: Text('Please provide customer name, phone number, and address'),
                          backgroundColor: Colors.red,
                        ),
                      );
                      return;
                    }
                    if (!isValidPhone(phone)) {
                      ScaffoldMessenger.of(dialogContext).showSnackBar(
                        const SnackBar(
                          content: Text('Invalid phone number format (10-15 digits required)'),
                          backgroundColor: Colors.red,
                        ),
                      );
                      return;
                    }
                    if (!isValidTel(tel)) {
                      ScaffoldMessenger.of(dialogContext).showSnackBar(
                        const SnackBar(
                          content: Text('Invalid tell number format (7-15 digits if provided)'),
                          backgroundColor: Colors.red,
                        ),
                      );
                      return;
                    }

                    Navigator.of(dialogContext).pop({
                      'customerName': customerName,
                      'phone': phone,
                      'tel': tel,
                      'address': address,
                      'address2': address2,
                      'customerId': currentCustomerId ?? '0', 
                      'action': 'confirm',
                    });
                  },
                  child: const Text(
                    'Confirm',
                    style: TextStyle(fontFamily: 'Raleway'),
                  ),
                ),
              ],
            );
          },
        );
      },
    );

    if (result != null && result['action'] == 'confirm' && mounted) {
      final customerIdFromForm = result['customerId'] ?? '0';
      String? finalCustomerId;

      if (customerIdFromForm != '0' && customerIdFromForm.isNotEmpty) {
        // Use existing customer ID if available (from search)
        finalCustomerId = customerIdFromForm;
      } else {
        // Insert new customer if no existing ID was found
        finalCustomerId = await _insertCustomerToDatabase(
            result['customerName']!,
            result['phone']!,
            result['tel']!,
            result['address']!,
            result['address2']!,
          );
      }
      
      if (finalCustomerId != null && finalCustomerId != '0' && mounted) {
        setState(() {
          _hasCustomerDetails = true;
          _customerName = result['customerName'];
          _phone = result['phone'];
          _telNo = result['tel'];
          _address = result['address'];
          _address2 = result['address2'];
          _customerMasterId = finalCustomerId;
        });
      } else if (mounted) {
        // If insert failed, and there was no pre-existing ID, close the screen
        if (customerIdFromForm == '0' || customerIdFromForm.isEmpty) {
          Navigator.of(context).pop();
        }
      }
    } else if (result != null && result['action'] == 'cancel') {
        // Cancellation is handled by closing the DeliveryScreen in the dialog action.
    }
  }

  Future<void> _showCommentDialog(OrderItem item) async {
    final defaultText = item.comments.isNotEmpty ? item.comments : 'Please prepare quickly!';
    final TextEditingController _commentController = TextEditingController(text: defaultText);

    await showDialog(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          backgroundColor: const Color(0xFF182022),
          title: const Text('Add / Edit Comments',
              style: TextStyle(color: Colors.white, fontFamily: 'Raleway')),
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
                    borderRadius: BorderRadius.circular(10)),
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(),
              child: const Text('Cancel',
                  style: TextStyle(color: Colors.redAccent, fontFamily: 'Raleway')),
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
                  Navigator.of(dialogContext).pop();
                  return;
                }
                if (mounted) {
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
                }
                Navigator.of(dialogContext).pop();
              },
              child: const Text('Save', style: TextStyle(fontFamily: 'Raleway')),
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

    if (mounted) {
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
  }

  void _decreaseItemQuantity(String itemId) {
    final index = _activeOrderItems.indexWhere((o) => o.itemId == itemId);
    if (index == -1) return;

    final orderItem = _activeOrderItems[index];
    if (mounted) {
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
          "Subtotal: ${subtotal.toStringAsFixed(2)}, Tax: ${taxAmount.toStringAsFixed(2)} "
          "(${item.taxPercent}%), Discount: ${discountAmount.toStringAsFixed(2)} "
          "(${item.discountPercent}%), Item Total: ${itemTotal.toStringAsFixed(2)}");
    }

    if (mounted) {
      setState(() {
        _orderTotalAmount = total;
        _totalTax = totalTaxAmount;
        _totalDiscount = totalDiscountAmount;
      });
    }

    debugPrint(
        "💰 Final Bill => Grand Total: ${_orderTotalAmount.toStringAsFixed(2)} | "
        "Total Tax: ${_totalTax.toStringAsFixed(2)} | "
        "Total Discount: ${_totalDiscount.toStringAsFixed(2)}");
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
    required String customerMasterId,
  }) {
    final sanitizedCommentList = commentList.replaceAll(RegExp(r'[\%_\\]'), '');
    final sanitizedCustomerMasterId = customerMasterId.replaceAll(RegExp(r'[\%_\\]'), '');
    final sanitizedTabUniqueId = tabUniqueIdN.replaceAll(RegExp(r'[\%_\\]'), '');

    return """
      DECLARE @OrderKey INT;
      EXEC uspInsertDineInOrderAndriod_Sep
          @TiltId = $tiltId,
          @CounterId = 0,
          @Waiter = '${widget.waiterName}',
          @ShiftNo = '',
          @TableNo = '',
          @cover = 0,
          @tab_unique_id = '$sanitizedTabUniqueId',
          @device_no = '$deviceNo',
          @totalAmount = $_orderTotalAmount,
          @qty2 = '$qtyList',
          @proditemcode = '$productCodes',
          @OrderDtlID = '$orderDtlIds',
          @User = '$_currentUser',
          @IsPrintKOT = $isPrintKot,
          @OrderType = 'DELIVERY',
          @Customer = '',
          @Tele = '',
          @Comment = '$sanitizedCommentList',
          @CustomerMasterId = '$sanitizedCustomerMasterId',
          @OrderKey = @OrderKey OUTPUT;
      SELECT @OrderKey AS id;
    """;
  }

  Future<int?> _saveOrderToSqlServer() async {
    if (_activeOrderItems.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No items in the order'), backgroundColor: Colors.red),
      );
      return null;
    }

    final validOrderItems = _activeOrderItems
        .where((item) => item.itemId != '0' && item.itemId.isNotEmpty)
        .toList();

    if (validOrderItems.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No valid items to save'), backgroundColor: Colors.red),
      );
      return null;
    }

    if (!_isMssqlReady) {
      await _setupSqlConn();
      if (!_isMssqlReady) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Failed to connect to SQL Server'),
            backgroundColor: Colors.red,
          ),
        );
        return null;
      }
    }

    final connDetails = await DatabaseHelper.instance.getConnectionDetails();
    final loggedUser = await DatabaseHelper.instance.getLoggedInUser();

    if (connDetails == null || loggedUser == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Connection details or user not found'),
          backgroundColor: Colors.red,
        ),
      );
      return null;
    }

    if (mounted) {
      setState(() {
        _currentUser = loggedUser;
      });
    }

    final tiltId = int.tryParse(connDetails['tiltId']?.toString() ?? '0') ?? 0;
    final deviceNo = connDetails['deviceName']?.isNotEmpty ?? false
        ? connDetails['deviceName']
        : 'POS01';
    final isPrintKot = connDetails['isCashier'] ?? 1;
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
    final commentList = validOrderItems
        .map((e) => e.comments.replaceAll("'", "''"))
        .join(',');

    if (qtyList.isEmpty || productCodes.isEmpty || orderDtlIds.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Invalid order data: Empty quantities, product codes, or order detail IDs'),
          backgroundColor: Colors.red,
        ),
      );
      return null;
    }

    final query = _buildOrderQuery(
      tabUniqueIdN: tabUniqueId,
      qtyList: qtyList,
      productCodes: productCodes,
      orderDtlIds: orderDtlIds,
      commentList: commentList,
      tiltId: tiltId,
      deviceNo: deviceNo,
      isPrintKot: isPrintKot,
      customerMasterId: _customerMasterId ?? '',
    );

    debugPrint("===== FINAL ORDER QUERY =====");
    debugPrint(query);

    try {
      final result = await _mssql.getData(query);
      debugPrint("===== RAW SQL RESULT =====");
      debugPrint(result);

      int? newOrderId;

      try {
        final decoded = jsonDecode(result);
        if (decoded is List && decoded.isNotEmpty) {
          if (decoded[0].containsKey('ErrorMessage')) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('SQL Error: ${decoded[0]['ErrorMessage']}'),
                backgroundColor: Colors.red,
              ),
            );
            return null;
          } else if (decoded[0]['id'] != null) {
            newOrderId = int.tryParse(decoded[0]['id'].toString());
          }
        } else if (decoded is Map && decoded['id'] != null) {
          newOrderId = int.tryParse(decoded['id'].toString());
        } else {
          newOrderId = int.tryParse(result.trim());
        }
      } catch (e) {
        newOrderId = int.tryParse(result.trim());
        if (newOrderId == null) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Failed to parse order ID: $e'), backgroundColor: Colors.red),
          );
          return null;
        }
      }

      if (newOrderId != null && newOrderId > 0 && mounted) {
        setState(() {
          _activeOrderItems.clear();
          _orderTotalAmount = 0.0;
          _totalTax = 0.0;
          _totalDiscount = 0.0;
          _tabUniqueId = null;
        });

        _showSuccessDialog(newOrderId);
        debugPrint("✅ Order saved successfully with ID: $newOrderId");
        return newOrderId;
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Failed to save order: Invalid order ID returned'),
            backgroundColor: Colors.red,
          ),
        );
        return null;
      }
    } catch (e, stackTrace) {
      debugPrint("❌ Error saving order: $e\nStackTrace: $stackTrace");
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error saving order: $e'), backgroundColor: Colors.red),
      );
      SqlConn.disconnect();
      return null;
    }
  }

  void _showSuccessDialog(int orderId) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => AlertDialog(
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
          "Your Delivery Order Successfully Placed",
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
                Navigator.pop(dialogContext);
                if (mounted) {
                  Navigator.push(
                      context, MaterialPageRoute(builder: (_) => BillScreen()));
                }
              },
              child: const Text("View Bill", style: TextStyle(fontFamily: 'Raleway')),
            ),
          ),
        ],
      ),
    );
  }

  // --- Start of Utility Widgets ---

  Widget _buildSummaryRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4.0),
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
    // Note: The second duplicate definition of this function has been removed
    final isRunningOrder = widget.tabUniqueId != null && widget.tabUniqueId!.isNotEmpty;

    return SingleChildScrollView(
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.symmetric(vertical: 12.0, horizontal: 8.0),
            decoration: BoxDecoration(
              color: Colors.grey.shade800,
              borderRadius: BorderRadius.circular(8.0),
            ),
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  SizedBox(
                    width: 120,
                    child: Text(
                      'Item',
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w900,
                        fontFamily: 'Raleway',
                      ),
                    ),
                  ),
                  SizedBox(
                    width: 60,
                    child: Text(
                      'Price',
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontFamily: 'Raleway',
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ),
                  // FIX: Changed width from 100 to 110.0 to prevent RenderFlex overflow
                  SizedBox( 
                    width: 110.0, 
                    child: Center(
                      child: Text(
                        'Qty',
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontFamily: 'Raleway',
                        ),
                      ),
                    ),
                  ),
                  SizedBox(
                    width: 60,
                    child: Text(
                      'Disc',
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontFamily: 'Raleway',
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ),
                  SizedBox(
                    width: 60,
                    child: Text(
                      'Tax',
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontFamily: 'Raleway',
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ),
                  SizedBox(
                    width: 80,
                    child: Text(
                      'Total',
                      style: const TextStyle(
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
          ),
          SizedBox(
            height: 200,
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
                  padding: const EdgeInsets.symmetric(vertical: 5.0),
                  child: Column(
                    children: [
                      SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            SizedBox(
                              width: 120,
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    orderItem.itemName,
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 14,
                                      fontFamily: 'Raleway',
                                    ),
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                  if (orderItem.comments.isNotEmpty)
                                    Text(
                                      orderItem.comments,
                                      style: const TextStyle(
                                        color: Colors.white70,
                                        fontSize: 12,
                                        fontFamily: 'Raleway',
                                      ),
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                ],
                              ),
                            ),
                            SizedBox(
                              width: 60,
                              child: Text(
                                orderItem.salePrice.toStringAsFixed(2),
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 14,
                                  fontFamily: 'Raleway',
                                ),
                                textAlign: TextAlign.center,
                              ),
                            ),
                            // FIX: Changed width from 100 to 110.0 to prevent RenderFlex overflow
                            SizedBox(
                              width: 110.0, 
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  IconButton(
                                    icon: const Icon(Icons.remove, color: Colors.redAccent),
                                    onPressed: () => _decreaseItemQuantity(orderItem.itemId),
                                  ),
                                  Text(
                                    '${orderItem.quantity}',
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 14,
                                      fontFamily: 'Raleway',
                                    ),
                                  ),
                                  IconButton(
                                    icon: const Icon(Icons.add, color: Color(0xFF75E5E2)),
                                    onPressed: () => _addItemToOrder({
                                      'id': orderItem.itemId,
                                      'item_name': orderItem.itemName,
                                      'sale_price': orderItem.salePrice,
                                      'tax_percent': orderItem.taxPercent,
                                      'discount_percent': orderItem.discountPercent,
                                      'Comments': orderItem.comments,
                                    }),
                                  ),
                                ],
                              ),
                            ),
                            SizedBox(
                              width: 60,
                              child: Text(
                                '${orderItem.discountPercent.toStringAsFixed(1)}%',
                                style: const TextStyle(
                                  color: Colors.orange,
                                  fontSize: 14,
                                  fontFamily: 'Raleway',
                                ),
                                textAlign: TextAlign.center,
                              ),
                            ),
                            SizedBox(
                              width: 60,
                              child: Text(
                                '${orderItem.taxPercent.toStringAsFixed(1)}%',
                                style: const TextStyle(
                                  color: Colors.lightGreen,
                                  fontSize: 14,
                                  fontFamily: 'Raleway',
                                ),
                                textAlign: TextAlign.center,
                              ),
                            ),
                            SizedBox(
                              width: 80,
                              child: Text(
                                itemTotal.toStringAsFixed(2),
                                style: const TextStyle(
                                  color: Color(0xFF75E5E2),
                                  fontSize: 14,
                                  fontFamily: 'Raleway',
                                ),
                                textAlign: TextAlign.right,
                              ),
                            ),
                          ],
                        ),
                      ),
                      if (isRunningOrder)
                        Align(
                          alignment: Alignment.centerRight,
                          child: TextButton(
                            onPressed: () => _showCommentDialog(orderItem),
                            child: const Text(
                              'Add/Edit Comment',
                              style: TextStyle(
                                color: Color(0xFF75E5E2),
                                fontSize: 12,
                                fontFamily: 'Raleway',
                              ),
                            ),
                          ),
                        ),
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
  
  // --- End of Utility Widgets (Duplicate functions removed here) ---

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
          titleTextStyle: TextStyle(
            fontFamily: 'Raleway',
            fontSize: 20,
            fontWeight: FontWeight.bold,
          ),
        ),
        tabBarTheme: const TabBarThemeData(
          labelColor: Color(0xFF75E5E2),
          unselectedLabelColor: Colors.white70,
          labelStyle: TextStyle(
            fontFamily: 'Raleway',
            fontWeight: FontWeight.bold,
          ),
          unselectedLabelStyle: TextStyle(fontFamily: 'Raleway'),
          indicator: UnderlineTabIndicator(
            borderSide: BorderSide(
              color: Color(0xFF75E5E2),
              width: 2,
            ),
          ),
        ),
        cardTheme: const CardThemeData(
          color: Color(0xFF1C2526),
          elevation: 4,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.all(Radius.circular(12)),
          ),
        ),
        textTheme: const TextTheme(
          titleLarge: TextStyle(
            fontFamily: 'Raleway',
            fontSize: 20,
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
          bodyMedium: TextStyle(
            fontFamily: 'Raleway',
            fontSize: 16,
            color: Colors.white,
          ),
          bodySmall: TextStyle(
            fontFamily: 'Raleway',
            fontSize: 14,
            color: Colors.white70,
          ),
        ),
        floatingActionButtonTheme: const FloatingActionButtonThemeData(
          backgroundColor: Color(0xFF75E5E2),
          foregroundColor: Color(0xFF0D1D20),
        ),
        snackBarTheme: const SnackBarThemeData(
          backgroundColor: Colors.red,
          contentTextStyle: TextStyle(
            fontFamily: 'Raleway',
            color: Colors.white,
          ),
        ),
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFF75E5E2),
            foregroundColor: const Color(0xFF0D1D20),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
            ),
            textStyle: const TextStyle(fontFamily: 'Raleway'),
          ),
        ),
        textButtonTheme: TextButtonThemeData(
          style: TextButton.styleFrom(
            foregroundColor: Colors.redAccent,
            textStyle: const TextStyle(fontFamily: 'Raleway'),
          ),
        ),
        inputDecorationTheme: const InputDecorationTheme(
          filled: true,
          fillColor: Color(0xFF2C3E40),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.all(Radius.circular(10)),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.all(Radius.circular(10)),
            borderSide: BorderSide(color: Color(0xFF75E5E2)),
          ),
          hintStyle: TextStyle(
            color: Colors.white54,
            fontFamily: 'Raleway',
          ),
          labelStyle: TextStyle(
            color: Colors.white54,
            fontFamily: 'Raleway',
          ),
        ),
      ),
      child: Scaffold(
        appBar: _hasCustomerDetails
            ? AppBar(
                title: Text('Delivery - ${_finalTiltName ?? "D1"}'),
                bottom: _tabController != null && _categories.isNotEmpty
                    ? TabBar(
                        controller: _tabController,
                        isScrollable: true,
                        tabs: _categories
                            .map((category) => Tab(text: category['category_name'] as String))
                            .toList(),
                        onTap: (index) {
                          if (mounted) {
                            setState(() {
                              _selectedCategory = _categories[index]['category_name'] as String;
                            });
                          }
                        },
                      )
                    : null,
              )
            : AppBar(
                title: const Text('Enter Customer Details'),
              ),
        body: _isLoading
            ? const Center(
                child: CircularProgressIndicator(
                  color: Color(0xFF75E5E2),
                ),
              )
            : _hasCustomerDetails
                ? LayoutBuilder(
                    builder: (context, constraints) {
                      return constraints.maxWidth > 600
                          ? _buildDesktopLayout()
                          : _buildMobileLayout();
                    },
                  )
                : Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Text(
                          'Please provide customer details to proceed',
                          style: TextStyle(
                            color: Colors.white70,
                            fontSize: 18,
                            fontFamily: 'Raleway',
                          ),
                        ),
                        const SizedBox(height: 20),
                        ElevatedButton(
                          onPressed: _showCustomerDetailsDialog,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF75E5E2),
                            foregroundColor: const Color(0xFF0D1D20),
                            minimumSize: const Size(200, 50),
                          ),
                          child: const Text(
                            'Enter Customer Details',
                            style: TextStyle(fontFamily: 'Raleway'),
                          ),
                        ),
                      ],
                    ),
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
                Expanded(child: _buildOrderListWithDetails()),
                _buildSummaryRow('Total Items', '${_activeOrderItems.length}'),
                _buildSummaryRow('Total Tax', _totalTax.toStringAsFixed(2)),
                _buildSummaryRow('Total Discount', _totalDiscount.toStringAsFixed(2)),
                const Divider(color: Colors.white),
                _buildSummaryRow('Grand Total', _orderTotalAmount.toStringAsFixed(2)),
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
                      fontFamily: 'Raleway',
                    ),
                  ),
                  child: const Text('Place Order'),
                ),
              ],
            ),
          ),
        ),
        Expanded(
          flex: 2,
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
                      final double baseTax = double.tryParse(item['tax_percent']?.toString() ?? '5.0') ?? 5.0;
                      final double baseDiscount = double.tryParse(item['discount_percent']?.toString() ?? '0.0') ?? 0.0;

                      return Card(
                        color: Colors.grey.shade900,
                        elevation: 4,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
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
                                  overflow: TextOverflow.ellipsis,
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
                                      ' ${baseTax.toStringAsFixed(1)}%',
                                      style: const TextStyle(
                                        color: Colors.lightGreen,
                                        fontSize: 12,
                                        fontWeight: FontWeight.bold,
                                        fontFamily: 'Raleway',
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    const Text(
                                      'Disc:',
                                      style: TextStyle(
                                        color: Colors.white70,
                                        fontSize: 12,
                                        fontFamily: 'Raleway',
                                      ),
                                    ),
                                    Text(
                                      ' ${baseDiscount.toStringAsFixed(1)}%',
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
                      style: TextStyle(
                        color: Colors.white70,
                        fontFamily: 'Raleway',
                      ),
                    ),
                  ),
          ),
        ),
      ],
    );
  }

  Widget _buildMobileLayout() {
    return Column(
      children: [
        if (_tabController != null && _categories.isNotEmpty)
          Container(
            color: const Color(0xFF0D1D20),
            child: TabBar(
              controller: _tabController,
              isScrollable: true,
              tabs: _categories
                  .map((category) => Tab(text: category['category_name'] as String))
                  .toList(),
              onTap: (index) {
                if (mounted) {
                  setState(() {
                    _selectedCategory = _categories[index]['category_name'] as String;
                  });
                }
              },
            ),
          ),
        Expanded(
          child: _selectedCategory != null && _categoryItems[_selectedCategory] != null
              ? GridView.builder(
                  padding: const EdgeInsets.all(8.0),
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
                    final double baseTax = double.tryParse(item['tax_percent']?.toString() ?? '5.0') ?? 5.0;
                    final double baseDiscount = double.tryParse(item['discount_percent']?.toString() ?? '0.0') ?? 0.0;

                    return Card(
                      color: Colors.grey.shade900,
                      elevation: 4,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
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
                                    ' ${baseTax.toStringAsFixed(1)}%',
                                    style: const TextStyle(
                                      color: Colors.lightGreen,
                                      fontSize: 12,
                                      fontWeight: FontWeight.bold,
                                      fontFamily: 'Raleway',
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  const Text(
                                    'Disc:',
                                    style: TextStyle(
                                      color: Colors.white70,
                                      fontSize: 12,
                                      fontFamily: 'Raleway',
                                    ),
                                  ),
                                  Text(
                                    ' ${baseDiscount.toStringAsFixed(1)}%',
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
                    style: TextStyle(
                      color: Colors.white70,
                      fontFamily: 'Raleway',
                    ),
                  ),
                ),
        ),
      ],
    );
  }
}