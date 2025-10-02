// ignore_for_file: unused_local_variable, unused_element, use_build_context_synchronously

import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:mssql_connection/mssql_connection.dart';
import 'package:start_app/database_halper.dart';
import 'package:sql_conn/sql_conn.dart';
import 'package:start_app/bill_screen.dart';
// ignore: unused_import
import 'package:start_app/main.dart';
// import 'package:start_app/device_helper.dart';

class OrderScreen extends StatefulWidget {
  final int tableId;
  final String tableName;
  final String waiterName;
  final int customerCount;
  final int? selectedTiltId;

  OrderScreen({
    required this.waiterName,
    required this.tableId,
    required this.tableName,
    required this.customerCount,
    required this.selectedTiltId,
  }) {
    debugPrint("📌 OrderScreen received TiltId=$selectedTiltId");
  }
  @override
  _OrderScreenState createState() => _OrderScreenState();
}

class _OrderScreenState extends State<OrderScreen>
    with SingleTickerProviderStateMixin {
  late MssqlConnection _mssql;
  // ignore: unused_field, prefer_final_fields
  bool _isMssqlReady = false; // ✅ flag
  bool _isLoading = true;
  Map<String, List<Map<String, dynamic>>> _categoryItems = {};
  List<Map<String, dynamic>> _categories = [];
  String? _selectedCategory;
  String _currentUser = "Admin";
  String _deviceNo = "POS01";
  int _isPrintKot = 1;
  Map<String, dynamic>? _connectionDetails;
  late TabController _tabController;
  final List<Map<String, dynamic>> _currentOrder = [];
  double _totalBill = 0.0;
  double _totalTax = 0.0;
  double _totalDiscount = 0.0;
int? _finalTiltId;
String? _finalTiltName;

@override
void initState() {
  super.initState();
  _initConnectionAndLoadData();
  _loadConnectionDetails();
  _loadTiltFromLocal();
}

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }
  Future<void> _loadConnectionDetails() async {
    Map<String, dynamic>? connDetails =
        await DatabaseHelper.instance.getConnectionDetails();

    setState(() {
      _currentUser = connDetails?['user'] ?? 'Admin';
      _deviceNo = connDetails?['deviceName'] ?? 'POS01';
      _isPrintKot = connDetails?['isPrintKot'] ?? 1;
    });
  }
  Future<void> _initConnectionAndLoadData() async {
    await _setupSqlConn(); // ✅ wait for connection
    await _loadData(); // ✅ ab local data load karo
  }

Future<void> _loadTiltFromLocal() async {
  final savedDetails = await DatabaseHelper.instance.getConnectionDetails();
  setState(() {
    _finalTiltId = int.tryParse(savedDetails?['tiltId'] ?? '0') ?? 0;
    _finalTiltName = savedDetails?['tiltName'] ?? '';
  });

  debugPrint("📥 Loaded Tilt from local DB => Id=$_finalTiltId, Name=$_finalTiltName");
}

  Future<void> _loadData() async {
    final details = await DatabaseHelper.instance.getConnectionDetails();

    if (details != null) {
      _connectionDetails = details;
      await _fetchAndSaveDataLocally();
    } else {
      setState(() {
        _isLoading = false;
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Database connection details not found.'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _fetchAndSaveDataLocally() async {
    setState(() {
      _isLoading = true;
    });

    try {
      final isCategoriesTableEmpty = await DatabaseHelper.instance
          .isCategoriesTableEmpty();
      final isItemsTableEmpty = await DatabaseHelper.instance
          .isItemsTableEmpty();

      if (isCategoriesTableEmpty || isItemsTableEmpty) {
        if (!await _fetchAndSaveFromSqlServer()) {
          setState(() {
            _isLoading = false;
          });
          return;
        }
      }

      await _fetchDataFromLocalDb();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to load local data: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
      // ignore: avoid_print
      print('Error fetching data from local DB: $e');
    } finally {
      setState(() {
        _isLoading = false;
      });
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

      if (!(isConnected ?? false)) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Failed to connect to the database.'),
              backgroundColor: Colors.red,
            ),
          );
        }
        return false;
      }

      final categoriesResult = await SqlConn.readData(
        "SELECT * FROM tbl_categories",
      );
      final itemsResult = await SqlConn.readData("SELECT * FROM tbl_items");

      final parsedCategories = jsonDecode(categoriesResult) as List<dynamic>;
      final parsedItems = jsonDecode(itemsResult) as List<dynamic>;

      await DatabaseHelper.instance.saveCategories(
        parsedCategories.cast<Map<String, dynamic>>(),
      );
      await DatabaseHelper.instance.saveItems(
        parsedItems.cast<Map<String, dynamic>>(),
      );

      SqlConn.disconnect();
      return true;
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Failed to fetch data from SQL Server. Check table names.',
            ),
            backgroundColor: Colors.red,
          ),
        );
      }
      // ignore: avoid_print
      print('Error fetching from SQL Server: $e');
      return false;
    }
  }

  Future<void> _fetchDataFromLocalDb() async {
    final categories = await DatabaseHelper.instance.getCategories();
    final items = await DatabaseHelper.instance.getItems();
    _categories = categories;

    final Map<String, List<Map<String, dynamic>>> groupedData = {};

    for (var category in categories) {
      final categoryName = category['category_name'] as String;
      groupedData[categoryName] = [];
      for (var item in items) {
        if (item['category_name'] == categoryName) {
          groupedData[categoryName]!.add(item);
        }
      }
    }

    if (categories.isNotEmpty) {
      _selectedCategory = categories[0]['category_name'] as String;
    }

    final categoryNames = groupedData.keys.toList();
    if (categoryNames.isNotEmpty) {
      _tabController = TabController(length: categoryNames.length, vsync: this);
    } else {
      _tabController = TabController(length: 0, vsync: this);
    }

    setState(() {
      _categoryItems = groupedData;
    });
  }

  //  This is Comment Section

  Future<void> _showCommentDialog(Map<String, dynamic> item) async {
    // default text (you can change this)
    final defaultText = (item['Comments'] ?? 'Please prepare quickly!')
        .toString();
    final TextEditingController _commentController = TextEditingController(
      text: defaultText,
    );

    await showDialog(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          backgroundColor: const Color(0xFF182022),
          title: const Text(
            'Add / Edit Comments',
            style: TextStyle(color: Colors.white),
          ),
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
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(ctx).pop();
              },
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
                final newComment = _commentController.text.trim();
         setState((){
          final idx = _currentOrder.indexWhere((o) => o['id'] == item['id']);
          if (idx != -1) {
            _currentOrder[idx]['Comments'] = newComment;
          } else {
            _currentOrder.add({
              'id': item['id'],
              'item_name': item['item_name'],
              'sale_price': (item['sale_price'] ?? 0).toDouble(),
              'quantity': 1,
              'tax_percent': 5.0, // ✅ default 5%
              'discount_percent': 0.0,
              'Comments': newComment.isNotEmpty ? newComment : "No Comments",
            });
          }
          _calculateTotalBill(); // ✅ yahan bhi bill refresh
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
  setState(() {
    final idx = _currentOrder.indexWhere((o) => o['id'] == item['id']);
    if (idx != -1) {
      _currentOrder[idx]['quantity'] =
          (_currentOrder[idx]['quantity'] ?? 0) + 1;
      _updateItemCalculation(_currentOrder[idx]); // ✅ update tax/discount
    } else {
      _currentOrder.add({
        'id': item['id'],
        'item_name': item['item_name'],
        'sale_price': (item['sale_price'] ?? 0).toDouble(),
        'quantity': 1,
        'tax_percent': 5.0, // ✅ default 5%
        'discount_percent': 0.0,
        'Comments': '',
      });
    }
    _calculateTotalBill(); // ✅ bill update karo
  });
}


  void _decreaseItemQuantity(int itemId) {
    setState(() {
      final index = _currentOrder.indexWhere((o) => o['id'] == itemId);
      if (index != -1) {
        if (_currentOrder[index]['quantity'] > 1) {
          _currentOrder[index]['quantity']--;
          _updateItemCalculation(_currentOrder[index]);
        } else {
          _currentOrder.removeAt(index);
        }
        _calculateTotalBill();
      }
    });
  }

  // Har item ka tax aur discount calculate karta hai
  void _updateItemCalculation(Map<String, dynamic> item) {
    final int quantity = item['quantity'] as int;

    // Quantity ke hisaab se tax calculate karen
    final double taxPercentage = 5.0 + (quantity * 0.1);
    item['tax_percent'] = taxPercentage;

    // Quantity ke hisaab se discount calculate karen
    double discountPercentage = 0.0;
    if (quantity >= 10) {
      discountPercentage = 15.0; // 15% discount
    } else if (quantity >= 5) {
      discountPercentage = 10.0; // 10% discount
    }
    item['discount_percent'] = discountPercentage;
  }

  void _calculateTotalBill() {
    double total = 0.0;
    double totalTaxAmount = 0.0;
    double totalDiscountAmount = 0.0;

    for (var item in _currentOrder) {
      final double itemPrice = (item['sale_price'] ?? 0).toDouble();
      final int quantity = (item['quantity'] ?? 0).toInt();
      final double tax = (item['tax_percent'] ?? 0).toDouble();
      final double discount = (item['discount_percent'] ?? 0).toDouble();

      final double subtotal = itemPrice * quantity;
      final double taxAmount = subtotal * (tax / 100);
      final double discountAmount = subtotal * (discount / 100);

      final double itemTotal = subtotal + taxAmount - discountAmount;

      total += subtotal + taxAmount - discountAmount;
      totalTaxAmount += taxAmount;
      totalDiscountAmount += discountAmount;
    }
    setState(() {
      _totalBill = total;
      _totalTax = totalTaxAmount;
      _totalDiscount = totalDiscountAmount;
    });
  }

  Future<void> _initMssqlAndLoadData() async {
    await _setupSqlConn(); // wait for connection
    await _loadData();
  }

  Future<void> _setupSqlConn() async {
    _mssql = MssqlConnection.getInstance();

    final details = await DatabaseHelper.instance.getConnectionDetails();
    final connDetails = await DatabaseHelper.instance.getConnectionDetails();
    print("🔎 Connection Details => $connDetails");

    final tiltId = details?['tiltId'] ?? "";
    final tiltName = details?['tiltName'] ?? "";
    if (details == null) {
      _isMssqlReady = false;
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Database connection details not found!'),
            backgroundColor: Colors.red,
          ),
        );
      }
      return;
    }

    _isMssqlReady = await _mssql.connect(
      ip: details['ip'], // ✅ real IP ya hostname
      port: details['port'], // ✅ usually '1433'
      databaseName: details['dbName'], // ✅ real DB name
      username: details['username'], // ✅ DB username
      password: details['password'], // ✅ DB password
      timeoutInSeconds: 10,
    );

    if (!_isMssqlReady && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Failed to connect to SQL Server!'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

Future<int?> _saveOrderToSqlServer() async {
  if (_currentOrder.isEmpty) return null;

  final now = DateTime.now();
  final formattedDate =
      "${now.year.toString().padLeft(4, '0')}-"
      "${now.month.toString().padLeft(2, '0')}-"
      "${now.day.toString().padLeft(2, '0')} "
      "${now.hour.toString().padLeft(2, '0')}:"
      "${now.minute.toString().padLeft(2, '0')}:"
      "${now.second.toString().padLeft(2, '0')}";

  // ✅ Get connection details
final connDetails = await DatabaseHelper.instance.getConnectionDetails();
final loggedUser = await DatabaseHelper.instance.getLoggedInUser();
setState(() {
  _currentUser = loggedUser ?? "Admin";
});
// String currentUser = connDetails?['username'] ?? 'Admin';   // 👈 user ki jagah username
String deviceNo = (connDetails?['deviceName']?.isNotEmpty ?? false)
    ? connDetails!['deviceName']
    : 'POS01';  // 👈 agar khali hai to default POS01
int isPrintKot = connDetails?['isCashier'] ?? 1;  // 👈 agar isCashier use karna hai
int tiltId = int.tryParse(connDetails?['tiltId'] ?? "0") ?? 0;
String tiltName = connDetails?['tiltName'] ?? "Unknown";


  final tabUniqueId = DateTime.now().millisecondsSinceEpoch.toString();

  // ✅ Build lists
  final qtyList = _currentOrder.map((e) => e['quantity'].toString()).join(",");
  final prodItemCodes = _currentOrder.map((e) => e['id'].toString()).join(",");
  final orderDtlIds = _currentOrder.map((e) => "0").join(",");
  final commentList = _currentOrder
      .map((e) => (e['Comments'] ?? "No Comment").toString())
      .join(",");
      

  // ✅ Final query (param names fixed)
      String query = """
      DECLARE @OrderKey INT;
      EXEC uspInsertDineInOrderAndriod_Sep
          @TiltId = $tiltId,
          @CounterId = 0,
          @Waiter = '${widget.waiterName}',
          @TableNo = '${widget.tableName}',
          @cover = ${widget.customerCount},
          @tab_unique_id = '$tabUniqueId',
          @device_no = '$deviceNo',
          @totalAmount = $_totalBill,
          @qty2 = '$qtyList',
          @proditemcode = '$prodItemCodes',
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



  debugPrint("===== FINAL QUERY =====\n$query");
  print("📝 Qty List => $qtyList");
  print("📝 Product Codes => $prodItemCodes");
  print("📝 Comments => $commentList");


  try {
    String result = await _mssql.getData(query);
    int? newOrderId;

    try {
      final decoded = jsonDecode(result);
      if (decoded is List && decoded.isNotEmpty) {
        newOrderId = int.tryParse(decoded[0]['id'].toString());
      } else if (decoded is Map && decoded['id'] != null) {
        newOrderId = int.tryParse(decoded['id'].toString());
      } else {
        newOrderId = int.tryParse(result.trim());
      }
    } catch (_) {
      newOrderId = int.tryParse(result.trim());
    }

    setState(() {
      _currentOrder.clear();
      _totalBill = 0.0;
      _totalTax = 0.0;
      _totalDiscount = 0.0;
    });

    if (mounted && newOrderId != null && newOrderId > 0) {
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (ctx) => AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          backgroundColor: const Color(0xFF0D1D20),
          title: Column(
            children: const [
              Icon(Icons.check_circle_outline,
                  color: Color(0xFF75E5E2), size: 60),
              SizedBox(height: 10),
              Text("Success!",
                  style: TextStyle(
                      color: Colors.white,
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                      fontFamily: 'Raleway')),
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
                  backgroundColor: Color(0xFF75E5E2),
                  foregroundColor: Color(0xFF0D1D20),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
                onPressed: () => Navigator.pop(ctx),
                child: const Text("OK"),
              ),
            ),
          ],
        ),
      );
    }

    return newOrderId;
  } catch (e) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error placing order: $e')),
      );
    }
    return null;
  }
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
                  valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF75E5E2)),
                ),
              )
            : LayoutBuilder(
                builder: (context, constraints) {
                  if (constraints.maxWidth > 600) {
                    return _buildDesktopLayout();
                  } else {
                    return _buildMobileLayout();
                  }
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
                _buildSummaryRow('Total Items', '${_currentOrder.length}'),
                _buildSummaryRow(
                  'Order Tax',
                  ' ${_totalTax.toStringAsFixed(2)}',
                ),
                _buildSummaryRow(
                  'Discount',
                  ' ${_totalDiscount.toStringAsFixed(2)}',
                ),
                const Divider(color: Colors.white),
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
                      ' ${_totalBill.toStringAsFixed(2)}',
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
  onPressed: _currentOrder.isEmpty
      ? null
      : () async {
          int? newOrderId = await _saveOrderToSqlServer();

          if (newOrderId != null) {
            // ✅ Order placed successfully
            showDialog(
              context: context,
              barrierDismissible: false,
              builder: (BuildContext context) {
                return AlertDialog(
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(20),
                  ),
                  backgroundColor: Colors.white,
                  title: Column(
                    children: const [
                      Icon(
                        Icons.check_circle,
                        color: Colors.green,
                        size: 60,
                      ),
                      SizedBox(height: 10),
                      Text(
                        "Order Placed!",
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 22,
                          fontFamily: "Raleway",
                        ),
                      ),
                    ],
                  ),
                  content: const Text(
                    "Your order has been placed successfully.",
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 16),
                  ),
                  actions: [
                    Center(
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Color(0xFF75E5E2),
                          foregroundColor: Color(0xFF0D1D20),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                        ),
                        onPressed: () {
                          Navigator.of(context).pop();
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => BillScreen(),
                            ),
                          );
                        },
                        child: const Text("View Bill"),
                      ),
                    ),
                  ],
                );
              },
            );
          } else {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text("❌ Failed to place order"),
              ),
            );
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
                    final isSelected =
                        _selectedCategory == category['category_name'];
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
                          fontFamily: 'Raleway',
                        ),
                        onPressed: () {
                          setState(() {
                            _selectedCategory =
                                category['category_name'] as String;
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
                    gridDelegate:
                        const SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: 2,
                          crossAxisSpacing: 8.0,
                          mainAxisSpacing: 8.0,
                          childAspectRatio: 0.7,
                        ),
                    itemCount: _categoryItems[_selectedCategory]?.length ?? 0,
                    itemBuilder: (context, index) {
                      final items = _categoryItems[_selectedCategory] ?? [];
                      final item = items[index];
                      // Tax aur discount ke liye base values calculate karen
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
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: InkWell(
                          onTap: () => _addItemToOrder(item),
                          onLongPress: () => _showCommentDialog(item),
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
                                      ),
                                    ),
                                    Text(
                                      ' ${baseTax.toStringAsFixed(1)}%',
                                      style: const TextStyle(
                                        color: Colors.lightGreen,
                                        fontSize: 12,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                    const Text(
                                      ' | ',
                                      style: TextStyle(
                                        color: Colors.white70,
                                        fontSize: 12,
                                      ),
                                    ),
                                    const Text(
                                      'Disc:',
                                      style: TextStyle(
                                        color: Colors.white70,
                                        fontSize: 12,
                                      ),
                                    ),
                                    Text(
                                      ' ${baseDiscount.toStringAsFixed(1)}%',
                                      style: const TextStyle(
                                        color: Colors.orange,
                                        fontSize: 12,
                                        fontWeight: FontWeight.bold,
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
                tabs: _categoryItems.keys
                    .map((category) => Tab(text: category))
                    .toList(),
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
                    gridDelegate:
                        const SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: 2,
                          crossAxisSpacing: 8.0,
                          mainAxisSpacing: 8.0,
                          childAspectRatio: 0.8,
                        ),
                    itemCount: items.length,
                    itemBuilder: (context, index) {
                      final item = items[index];
                      // Tax aur discount ke liye base values calculate karen
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
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: InkWell(
                          onTap: () => _addItemToOrder(item),
                          onLongPress: () => _showCommentDialog(item),
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
                                      ),
                                    ),
                                    Text(
                                      ' ${baseTax.toStringAsFixed(1)}%',
                                      style: const TextStyle(
                                        color: Colors.lightGreen,
                                        fontSize: 12,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                    const Text(
                                      ' | ',
                                      style: TextStyle(
                                        color: Colors.white70,
                                        fontSize: 12,
                                      ),
                                    ),
                                    const Text(
                                      'Disc:',
                                      style: TextStyle(
                                        color: Colors.white70,
                                        fontSize: 12,
                                      ),
                                    ),
                                    Text(
                                      ' ${baseDiscount.toStringAsFixed(1)}%',
                                      style: const TextStyle(
                                        color: Colors.orange,
                                        fontSize: 12,
                                        fontWeight: FontWeight.bold,
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
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () {
          _showOrderSheet();
        },
        label: Text('Order Dekho (${_currentOrder.length})'),
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
                      Text(
                        'Current Order',
                        style: const TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF75E5E2),
                          fontFamily: 'Raleway',
                        ),
                      ),
                      Text(
                        'Waiter: ${widget.waiterName}',
                        style: const TextStyle(
                          fontSize: 16,
                          color: Colors.white70,
                          fontFamily: 'Raleway',
                        ),
                      ),
                    ],
                  ),
                  IconButton(
                    icon: const Icon(Icons.close, color: Colors.white),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),

              const Divider(color: Colors.white24),
              _buildOrderListWithDetails(),
              const Divider(color: Colors.white),
              _buildSummaryRow('Total Items', '${_currentOrder.length}'),
              _buildSummaryRow('Order Tax', ' ${_totalTax.toStringAsFixed(2)}'),
              _buildSummaryRow(
                'Discount',
                ' ${_totalDiscount.toStringAsFixed(2)}',
              ),
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
                    ' ${_totalBill.toStringAsFixed(2)}',
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
                onPressed: _currentOrder.isEmpty ? null : _saveOrderToSqlServer,
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
        );
      },
    );
  }

  Widget _buildOrderListWithDetails() {
    return Expanded(
      child: Column(
        children: [
          // Table Header
          Container(
            padding: const EdgeInsets.symmetric(
              vertical: 12.0,
              horizontal: 8.0,
            ),
            decoration: BoxDecoration(
              color: Colors.grey.shade800,
              borderRadius: BorderRadius.circular(8.0),
            ),
            child: const Row(
              children: [
                Expanded(
                  flex: 3, // 👈 Item column
                  child: Text(
                    'Item',
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ),
                Expanded(
                  flex: 2, // 👈 Price column
                  child: Text(
                    'Price',
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                Expanded(
                  flex: 3, // 👈 Qty column
                  child: Center(
                    child: Text(
                      'Qty',
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
                Expanded(
                  flex: 2, // 👈 Disc column
                  child: Text(
                    'Disc',
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                Expanded(
                  flex: 2, // 👈 Tax column
                  child: Text(
                    'Tax',
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                Expanded(
                  flex: 3, // 👈 Total column
                  child: Text(
                    'Total',
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                    ),
                    textAlign: TextAlign.right,
                  ),
                ),
              ],
            ),
          ),

          // Table Body
          Expanded(
            child: ListView.builder(
              shrinkWrap: true,
              itemCount: _currentOrder.length,
              itemBuilder: (context, index) {
                   final orderItem = _currentOrder[index]; // 👈 yahan define hai

    final double salePrice = (orderItem['sale_price'] ?? 0).toDouble();
    final int quantity = (orderItem['quantity'] ?? 0).toInt();
    final double taxPercent = (orderItem['tax_percent'] ?? 0).toDouble();
    final double discountPercent = (orderItem['discount_percent'] ?? 0).toDouble();

    final double subtotal = salePrice * quantity;
    final double taxAmount = subtotal * taxPercent / 100;
    final double discountAmount = subtotal * discountPercent / 100;
    final double itemTotal = subtotal + taxAmount - discountAmount;
    //     return ListTile(
    //   title: Text(orderItem['item_name']),
    //   subtitle: Text(orderItem['comment'] ?? 'No comment'),
    //   trailing: Text("Total: ${itemTotal.toStringAsFixed(2)}"),
    // );
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
                                  orderItem['item_name'],
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.w500,
                                    fontFamily: 'Raleway',
                                  ),
                                ),
                                if (orderItem['Comments'] != null &&
                                    orderItem['Comments'].toString().isNotEmpty)
                                  Text(
                                    orderItem['Comments'],
                                    style: const TextStyle(
                                      color: Colors.white70,
                                      fontSize: 12,
                                      fontStyle: FontStyle.italic,
                                    ),
                                  ),
                              ],
                            ),
                          ),

                          Expanded(
                            flex: 2,
                            child: Text(
                              orderItem['sale_price'].toStringAsFixed(2),
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
                                  onTap: () =>
                                      _decreaseItemQuantity(orderItem['id']),
                                  borderRadius: BorderRadius.circular(20),
                                  child: Container(
                                    padding: const EdgeInsets.all(
                                      3,
                                    ), // 👈 chhota kiya
                                    decoration: BoxDecoration(
                                      shape: BoxShape.circle,
                                      border: Border.all(
                                        color: Color(0xFF75E5E2),
                                        width: 1.5,
                                      ),
                                    ),
                                    child: const Icon(
                                      Icons.remove,
                                      size: 14,
                                      color: Color(0xFF75E5E2),
                                    ), // 👈 thoda chhota icon
                                  ),
                                ),
                                const SizedBox(width: 4), // 👈 kam spacing
                                SizedBox(
                                  width: 24, // 👈 pehle 28 tha
                                  child: Text(
                                    orderItem['quantity'].toString(),
                                    textAlign: TextAlign.center,
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontWeight: FontWeight.w500,
                                      fontFamily: 'Raleway',
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 4), // 👈 kam spacing
                                InkWell(
                                  onTap: () => _addItemToOrder(orderItem),
                                  onLongPress: () => _showCommentDialog(
                                    orderItem,
                                  ), // <-- use orderItem, not item
                                  borderRadius: BorderRadius.circular(20),
                                  child: Container(
                                    padding: const EdgeInsets.all(3),
                                    decoration: BoxDecoration(
                                      shape: BoxShape.circle,
                                      border: Border.all(
                                        color: Color(0xFF75E5E2),
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
                              '${(orderItem['discount_percent'] as double).toStringAsFixed(0)}%',
                              style: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.w500,
                                fontFamily: 'Raleway',
                              ),
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
                              itemTotal.toStringAsFixed(2),
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
}
