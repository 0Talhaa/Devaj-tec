// ignore_for_file: unused_field

import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:sql_conn/sql_conn.dart';
import 'package:start_app/database_halper.dart';

// --- THEME COLORS ---
const Color _primaryDark = Color(0xFF0D1D20); // Scaffold Background
const Color _surfaceDark = Color(0xFF153337); // App Bar & Summary Container
const Color _accentCyan = Color(0xFF75E5E2); // Highlight, Totals, Primary Buttons
const Color _dangerRed = Colors.redAccent; // Removal/KOT Printed Warning
const Color _cardBackground = Color(0xFF282828); // Card background

class EditOrderScreen extends StatefulWidget {
  final String tabUniqueId; // tab_unique_id jo order identify karta hai
  final String tableName;
  final List<Map<String, dynamic>> initialOrderItems;

  const EditOrderScreen({
    super.key,
    required this.tabUniqueId,
    required this.tableName,
    required this.initialOrderItems,
  });

  @override
  State<EditOrderScreen> createState() => _EditOrderScreenState();
}

class _EditOrderScreenState extends State<EditOrderScreen>
    with TickerProviderStateMixin {
  bool _isLoading = true;
  late List<Map<String, dynamic>> _currentOrder;

  // Right Panel State (OrderScreen ki tarah)
  Map<String, List<Map<String, dynamic>>> _categoryItems = {};
  List<Map<String, dynamic>> _categories = [];
  String? _selectedCategory;
  late TabController _tabController;

  double _subTotal = 0.0;
  double _totalTax = 0.0;
  double _totalDiscount = 0.0;
  double _grandTotal = 0.0;

  @override
  void initState() {
    super.initState();
    _currentOrder = [];
    _loadAllData();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  // -------------------- Data Loading --------------------

  Future<void> _loadAllData() async {
    setState(() {
      _isLoading = true;
    });

    // 1. Order Items Fetch karo
    await _fetchOrderItems();

    // 2. Categories aur Items Fetch karo (OrderScreen ki tarah)
    await _fetchLocalItemsAndCategories();

    setState(() {
      _isLoading = false;
    });
  }

  /// 🟢 Database se order items fetch karo
  Future<void> _fetchOrderItems() async {
    try {
      final conn = await DatabaseHelper.instance.getConnectionDetails();
      if (conn == null) throw Exception("⚠️ Database connection details missing");

      if (!await SqlConn.isConnected) {
        await SqlConn.connect(
          ip: conn['ip'],
          port: conn['port'],
          databaseName: conn['dbName'],
          username: conn['username'],
          password: conn['password'],
        );
      }

      String query = """
        select distinct d.itemid as itemid, d.item_name, d.qty, d.Comments,
        (i.sale_price) as item_unit_price, -- Item ki unit sale price
        d.id as orderDetailId, d.tax as tax,
        (select KotStatus from OrderKot where OrderDetailId=d.id) as kotstatus,
        1 as is_upload
        from order_detail d
        inner join dine_in_order m on d.order_key = m.order_key
        inner join itempos i on i.id = d.itemid
        where m.tab_unique_id = '${widget.tabUniqueId}'
      """;

      final result = await SqlConn.readData(query);
      List data = jsonDecode(result);

      _currentOrder = data.map((row) {
        final qty = int.tryParse(row["qty"].toString()) ?? 0;
        final unitPrice =
            double.tryParse(row["item_unit_price"].toString()) ?? 0.0;
        final itemTotal = qty * unitPrice;

        return {
          "itemId": row["itemid"],
          "itemName": row["item_name"],
          "orderDetailId": row["orderDetailId"],
          "itemQuantity": qty,
          "itemUnitPrice": unitPrice,
          "itemTotal": itemTotal,
          "comments": row["Comments"] ?? "",
          "tax": double.tryParse(row["tax"].toString()) ?? 0.0,
          "kotstatus": row["kotstatus"],
        };
      }).toList();
      _calculateBill();

      await SqlConn.disconnect();
    } catch (e) {
      print("❌ Error fetching order items: $e");
    }
  }

  /// 📦 Local database se items aur categories fetch karo
  Future<void> _fetchLocalItemsAndCategories() async {
    try {
        final categoriesResult = await SqlConn.readData(
        "SELECT * FROM tbl_categories",
      );
      final itemsResult = await SqlConn.readData("SELECT * FROM tbl_items");

      final parsedCategories = jsonDecode(categoriesResult) as List<dynamic>;
      final parsedItems = jsonDecode(itemsResult) as List<dynamic>;

      Map<String, List<Map<String, dynamic>>> groupedItems = {};
      for (var item in parsedItems) {
        final categoryName = item['category_name'] as String;
        if (!groupedItems.containsKey(categoryName)) {
          groupedItems[categoryName] = [];
        }
        groupedItems[categoryName]!.add(item as Map<String, dynamic>);
      }

      // TabController ko initialize karne ke liye categories zaroori hain
      _categories = parsedCategories.cast<Map<String, dynamic>>();
      _categoryItems = groupedItems;
      _selectedCategory = _categories.isNotEmpty ? _categories.first['category_name'] : null;

      _tabController = TabController(
        length: _categories.length,
        vsync: this,
      );
    } catch (e) {
      print('Error loading local items/categories: $e');
    }
  }

  // -------------------- Item Management --------------------

  void _addItemToOrder(Map<String, dynamic> item) {
    setState(() {
      final String itemId = item['id'].toString();
      final String itemName = item['item_name'] as String;
      final double unitPrice =
          double.tryParse(item['sale_price'].toString()) ?? 0.0;
      final double itemTax =
          double.tryParse(item['is_tax_apply'].toString()) ?? 0.0;

      int existingIndex = _currentOrder.indexWhere(
          (orderItem) => orderItem['itemId'].toString() == itemId);

      if (existingIndex != -1) {
        // Item pehle se hai, quantity badhao
        _currentOrder[existingIndex]['itemQuantity'] += 1;
        _currentOrder[existingIndex]['itemTotal'] =
            _currentOrder[existingIndex]['itemQuantity'] * unitPrice;
        // NOTE: agar item KOT printed tha, toh new quantity bhi abhi printed nahi hogi
        // isliye hum existing kotstatus ko rehne denge, sirf quantity update hogi.
        
      } else {
        // Naya item add karo
        _currentOrder.add({
          "itemId": itemId,
          "itemName": itemName,
          "orderDetailId": null, // Naye item ka orderDetailId null hoga
          "itemQuantity": 1,
          "itemUnitPrice": unitPrice,
          "itemTotal": unitPrice,
          "comments": "",
          "tax": itemTax,
          "kotstatus": 0, // Naya item, KOT not printed (0)
        });
      }
      _calculateBill();
    });
  }

  void _updateItemQuantity(Map<String, dynamic> item, int change) {
    setState(() {
      final String itemId = item['itemId'].toString();
      int existingIndex = _currentOrder.indexWhere(
          (orderItem) => orderItem['itemId'].toString() == itemId);

      if (existingIndex != -1) {
        _currentOrder[existingIndex]['itemQuantity'] += change;

        if (_currentOrder[existingIndex]['itemQuantity'] <= 0) {
          _currentOrder.removeAt(existingIndex);
        } else {
          _currentOrder[existingIndex]['itemTotal'] =
              _currentOrder[existingIndex]['itemQuantity'] *
                  (_currentOrder[existingIndex]['itemUnitPrice'] as double);
        }
      }
      _calculateBill();
    });
  }

  void _calculateBill() {
    double subTotal = 0.0;
    double taxTotal = 0.0;

    for (var item in _currentOrder) {
      final qty = (item['itemQuantity'] as int?) ?? 0;
      final unitPrice = (item['itemUnitPrice'] as double?) ?? 0.0;
      final itemTax = (item['tax'] as double?) ?? 0.0;

      final itemPriceBeforeTax = qty * unitPrice;

      subTotal += itemPriceBeforeTax;
      taxTotal += (itemPriceBeforeTax * itemTax / 100);
    }

    double grandTotal = subTotal + taxTotal - _totalDiscount;

    setState(() {
      _subTotal = subTotal;
      _totalTax = taxTotal;
      _totalDiscount = 0.0;
      _grandTotal = grandTotal;
    });
  }

  // -------------------- UI: Left Side (Order Summary) --------------------

  Widget _buildSummaryRow(String label, String value,
      {bool isGrandTotal = false}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: TextStyle(
              color: isGrandTotal ? _accentCyan : Colors.white,
              fontSize: isGrandTotal ? 18 : 16,
              fontWeight: isGrandTotal ? FontWeight.bold : FontWeight.normal,
              fontFamily: 'Raleway',
            ),
          ),
          Text(
            value,
            style: TextStyle(
              color: _accentCyan,
              fontSize: isGrandTotal ? 18 : 16,
              fontWeight: FontWeight.bold,
              fontFamily: 'Raleway',
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCurrentOrderSummary() {
    return Container(
      padding: const EdgeInsets.all(16.0),
      decoration: const BoxDecoration(
        color: _surfaceDark,
        borderRadius: BorderRadius.only(
            topRight: Radius.circular(16), bottomRight: Radius.circular(16)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Header
          Text(
            "Order ID: ${widget.tabUniqueId}",
            style: const TextStyle(
                color: _accentCyan,
                fontSize: 18,
                fontWeight: FontWeight.bold,
                fontFamily: 'Raleway'),
          ),
          Text(
            "Table: ${widget.tableName}",
            style:
                const TextStyle(color: Colors.white70, fontSize: 16, fontFamily: 'Raleway'),
          ),
          const Divider(color: Colors.white),

          // Item List
          Expanded(child: _buildCurrentOrderList()),
          const Divider(color: Colors.white),

          // Summary and Button
          _buildSummary(),
        ],
      ),
    );
  }

  Widget _buildCurrentOrderList() {
    if (_currentOrder.isEmpty) {
      return const Center(
          child: Text("Koi item nahi hai",
              style:
                  TextStyle(color: Colors.white70, fontFamily: 'Raleway')));
    }

    return ListView.builder(
      itemCount: _currentOrder.length,
      itemBuilder: (context, index) {
        final item = _currentOrder[index];
        final itemTotal = (item['itemTotal'] as double?) ?? 0.0;
        final itemQuantity = (item['itemQuantity'] as int?) ?? 0;

        // KOT Status check: 1 means printed/sent to kitchen
        final kotStatus = item['kotstatus'] ?? 0;
        final isKotPrinted = kotStatus == 1;

        return Column(
          children: [
            Row(
              children: [
                // Item Name
                Expanded(
                    flex: 4,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(item['itemName'],
                            style: TextStyle(
                                color: isKotPrinted ? _dangerRed : Colors.white,
                                fontWeight: FontWeight.w600,
                                fontFamily: 'Raleway')),
                        if (item['comments'] != null &&
                            item['comments'].isNotEmpty)
                          Text("(${item['comments']})",
                              style: const TextStyle(
                                  color: Colors.white54, fontSize: 12)),
                      ],
                    )),
                // Quantity buttons
                SizedBox(
                  width: 100,
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceAround,
                    children: [
                      // Remove Button (Disabled if KOT printed)
                      InkWell(
                        onTap:
                            isKotPrinted ? null : () => _updateItemQuantity(item, -1),
                        child: Icon(Icons.remove_circle,
                            color: isKotPrinted ? Colors.grey : _dangerRed),
                      ),
                      // Quantity Text
                      Text("$itemQuantity",
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: isKotPrinted ? _dangerRed : _accentCyan,
                            fontWeight: FontWeight.bold,
                            fontFamily: 'Raleway',
                            fontSize: 16,
                          )),
                      // Add Button (Disabled if KOT printed)
                      InkWell(
                        onTap:
                            isKotPrinted ? null : () => _updateItemQuantity(item, 1),
                        child: Icon(Icons.add_circle,
                            color: isKotPrinted ? Colors.grey : _accentCyan),
                      ),
                    ],
                  ),
                ),
                // Total Price
                Expanded(
                  flex: 2,
                  child: Text(itemTotal.toStringAsFixed(2),
                      textAlign: TextAlign.right,
                      style: const TextStyle(
                          color: _accentCyan,
                          fontWeight: FontWeight.bold,
                          fontFamily: 'Raleway',
                          fontSize: 16)),
                ),
              ],
            ),
            const Divider(color: Colors.white10),
          ],
        );
      },
    );
  }

  Widget _buildSummary() {
    return Column(
      children: [
        _buildSummaryRow("Sub Total", _subTotal.toStringAsFixed(2)),
        if (_totalDiscount > 0)
          _buildSummaryRow("Discount", "- ${_totalDiscount.toStringAsFixed(2)}"),
        _buildSummaryRow("Tax", _totalTax.toStringAsFixed(2)),
        const Divider(color: _accentCyan, thickness: 1.5),
        _buildSummaryRow("Grand Total", _grandTotal.toStringAsFixed(2),
            isGrandTotal: true),
        const SizedBox(height: 16),

        // Update Order Button
        ElevatedButton(
          onPressed: () => Navigator.pop(context, _currentOrder),
          style: ElevatedButton.styleFrom(
            minimumSize: const Size(double.infinity, 50),
            backgroundColor: _accentCyan, // Primary Accent BG
            foregroundColor: _primaryDark, // Dark Text FG
            textStyle: const TextStyle(
                fontSize: 18, fontWeight: FontWeight.bold, fontFamily: 'Raleway'),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            elevation: 5,
          ),
          child: const Text("Update Order"),
        ),
      ],
    );
  }

  // -------------------- UI: Right Side (Item Selector) --------------------

  Widget _buildItemSelector() {
    if (_categories.isEmpty) {
      return const Center(
          child: Text("Items load nahi ho paaye.",
              style: TextStyle(color: Colors.white70)));
    }

    return Column(
      children: [
        // Tab Bar for Categories
        Container(
          color: _surfaceDark,
          child: TabBar(
            controller: _tabController,
            isScrollable: true,
            indicatorColor: _accentCyan,
            labelColor: _accentCyan,
            unselectedLabelColor: Colors.white54,
            labelStyle: const TextStyle(fontWeight: FontWeight.bold, fontFamily: 'Raleway'),
            unselectedLabelStyle: const TextStyle(fontFamily: 'Raleway'),
            onTap: (index) {
              setState(() {
                _selectedCategory = _categories[index]['category_name'];
              });
            },
            tabs: _categories.map((category) {
              return Tab(text: category['category_name']);
            }).toList(),
          ),
        ),
        // Item Grid
        Expanded(
          child: TabBarView(
            controller: _tabController,
            children: _categories.map((category) {
              final categoryName = category['category_name'];
              final items = _categoryItems[categoryName] ?? [];
              return _buildItemGrid(items);
            }).toList(),
          ),
        ),
      ],
    );
  }

  Widget _buildItemGrid(List<Map<String, dynamic>> items) {
    if (items.isEmpty) {
      return const Center(
          child: Text("Is category mein koi item nahi hai.",
              style: TextStyle(color: Colors.white70, fontFamily: 'Raleway')));
    }

    return GridView.builder(
      padding: const EdgeInsets.all(8.0),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 3, // 3 columns for items on large screens
        crossAxisSpacing: 8.0,
        mainAxisSpacing: 8.0,
        childAspectRatio: 1.0, // Square card
      ),
      itemCount: items.length,
      itemBuilder: (context, index) {
        final item = items[index];
        final price = item['sale_price'] ?? 0.0;
        final itemName = item['item_name'];

        return InkWell(
          onTap: () => _addItemToOrder(item),
          child: Card(
            color: _cardBackground, // Darker card background
            elevation: 4,
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            child: Padding(
              padding: const EdgeInsets.all(8.0),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Expanded(
                    child: Center(
                      child: Text(
                        itemName,
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          color: _accentCyan, // Accent for item name
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                          fontFamily: 'Raleway',
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '₹${price.toStringAsFixed(2)}',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontFamily: 'Raleway',
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  // -------------------- Main Build --------------------

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _primaryDark, // Darkest background
      appBar: AppBar(
        title: Text("Edit Order: ${widget.tableName}",
            style: const TextStyle(
                fontFamily: 'Raleway',
                fontWeight: FontWeight.bold,
                color: Colors.white)),
        backgroundColor: _surfaceDark, // Surface background for app bar
        iconTheme: const IconThemeData(color: _accentCyan), // Back button icon
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: _accentCyan))
          : Row(
              children: [
                // Left Panel: Order Summary (30% width)
                Expanded(flex: 3, child: _buildCurrentOrderSummary()),

                // Right Panel: Item Selection (70% width)
                Expanded(flex: 7, child: _buildItemSelector()),
              ],
            ),
    );
  }
}
