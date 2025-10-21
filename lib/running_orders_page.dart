import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:sql_conn/sql_conn.dart';
import 'package:start_app/custom_loader.dart';
import 'package:start_app/custom_loader.dart' as Loader show showLoader, hideLoader;
import 'package:start_app/database_halper.dart';
import 'package:start_app/cash_bill_screen.dart';
import 'package:start_app/order_screen.dart' show OrderScreen;
// 1. New Import: EditOrderScreen ko import karein
import 'edit_order_screen.dart';

class RunningOrdersPage extends StatefulWidget {
  const RunningOrdersPage({super.key});

  @override
  State<RunningOrdersPage> createState() => _RunningOrdersPageState();
}

class _RunningOrdersPageState extends State<RunningOrdersPage> {
  bool _loading = true;
  List<Map<String, dynamic>> _orders = [];
  String? _error;
  Map<String, dynamic>? _connDetails;

  @override
  void initState() {
    super.initState();
    _fetchOrders();
  }

  @override
  void dispose() {
    SqlConn.disconnect(); // ✅ Page close hone pe hi connection band hoga
    super.dispose();
  }

  // Helper function to handle connection logic
  Future<bool> _ensureConnection() async {
    if (_connDetails == null) {
      final conn = await DatabaseHelper.instance.getConnectionDetails();
      // Loader.showLoader(context);
      if (conn == null) {
        setState(() {
          _error = "⚠️ No saved connection details found.";
          _loading = false;
        });
        return false;
      }
      _connDetails = conn;
    }

    if (!await SqlConn.isConnected) {
      await SqlConn.connect(
        ip: _connDetails!['ip'],
        port: _connDetails!['port'],
        databaseName: _connDetails!['dbName'],
        username: _connDetails!['username'],
        password: _connDetails!['password'],
      );
    }
    return true;
  }

  // Fetches the summary list of running orders
  Future<void> _fetchOrders() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      if (!await _ensureConnection()) return;

      // Call stored procedure to get list of orders
      const query = "EXEC uspGetOrderList";
      final result = await SqlConn.readData(query);

final decoded = jsonDecode(result) as List<dynamic>;
  // De-duplicate by tab_unique_id (or order_no, whichever is unique)
  final uniqueOrders = <String, Map<String, dynamic>>{};
  for (var order in decoded) {
    final uniqueKey = order['tab_unique_id']?.toString() ?? '';
    if (!uniqueOrders.containsKey(uniqueKey)) {
      uniqueOrders[uniqueKey] = order.cast<String, dynamic>();
    }
  }

  setState(() {
    _orders = uniqueOrders.values.toList();
    _loading = false;
  });
    } finally {
      await SqlConn.disconnect();
    }
  }

  // 2. New Function: Fetches detailed items for a specific order
  // ignore: unused_element
  Future<List<Map<String, dynamic>>?> _fetchOrderItems(
    String tabUniqueId,
  ) async {
    try {
      if (!await _ensureConnection()) return null;

      final query =
          """
      select distinct 
          d.itemid as itemId,
          d.item_name as itemName,
          d.qty as itemQuantity,
          d.Comments as comments,
          (isnull(d.Qty,0) * isnull(i.sale_price,0)) as itemTotal,
          d.id as orderDetailId,
          d.tax as tax,
          (select KotStatus from OrderKot where OrderDetailId=d.id) as kotstatus,
          1 as is_upload,
          i.sale_price as itemPrice
      from order_detail d
      inner join dine_in_order m on d.order_key = m.order_key
      inner join itempos i on i.id = d.itemid
      where m.tab_unique_id = '$tabUniqueId'
    """;

      final result = await SqlConn.readData(query);

      final decoded = jsonDecode(result) as List<dynamic>;
      return decoded.cast<Map<String, dynamic>>();
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error fetching order details: $e')),
      );
      return null;
    }
  }

  // 3. New Function: Navigation to EditOrderScreen
  Future<void> _navigateToEditScreen(Map<String, dynamic> order) async {
    try {
      final String tabUniqueId = order["tab_unique_id"]?.toString() ?? "";
      final String tableName = order["table_no"]?.toString() ?? "N/A";
      final int tableId =
          int.tryParse(order["table_id"]?.toString() ?? "0") ?? 0;
      final int customerCount =
          int.tryParse(order["cover"]?.toString() ?? "1") ?? 1;
      final int? selectedTiltId = order["tilt_id"] != null
          ? int.tryParse(order["tilt_id"].toString())
          : null;
      final String waiterName = order["waiter"]?.toString() ?? "Admin";

      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => OrderScreen(
            waiterName: waiterName,
            tableId: tableId,
            tableName: tableName,
            customerCount: customerCount,
            selectedTiltId: selectedTiltId,
            tabUniqueId: tabUniqueId,
          ),
        ),
      );
    } catch (e) {
    
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text("❌ Edit navigation error: $e")));
    }
  }

  @override
Widget build(BuildContext context) {
  return Scaffold(
    appBar: AppBar(
      title: const Text("Running Orders"),
      backgroundColor: const Color(0xFF0D1D20),
      centerTitle: true,
      actions: [
        IconButton(
          icon: const Icon(Icons.refresh, color: Color(0xFF75E5E2)),
          onPressed: _fetchOrders,
        ),
      ],
    ),
    body: Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [Color(0xFF0D1D20), Color(0xFF1D3538)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: _loading
          ? const Center(
              child: CircularProgressIndicator(color: Color(0xFF75E5E2)),
            )
          : _error != null
              ? Center(
                  child: Text(
                    _error!,
                    style: const TextStyle(color: Colors.red, fontSize: 16),
                  ),
                )
              : _orders.isEmpty
                  ? const Center(
                      child: Text(
                        "No running orders found.",
                        style: TextStyle(color: Colors.white, fontSize: 16),
                      ),
                    )
                  : Column(
                      children: [
                        // Header Row
                        Container(
                          padding: const EdgeInsets.symmetric(
                            vertical: 14,
                            horizontal: 10,
                          ),
                          decoration: const BoxDecoration(
                            color: Color(0xFF41938F),
                            borderRadius: BorderRadius.only(
                              topLeft: Radius.circular(12),
                              topRight: Radius.circular(12),
                            ),
                          ),
                          child: Row(
                            children: const [
                              Expanded(
                                flex: 2,
                                child: Text("OrderNo", style: _headerStyle),
                              ),
                              Expanded(
                                flex: 2,
                                child: Text("OrderType", style: _headerStyle),
                              ),
                              Expanded(
                                flex: 2,
                                child: Text("TableNo", style: _headerStyle),
                              ),
                              Expanded(
                                flex: 1,
                                child: Text("Covers", style: _headerStyle),
                              ),
                              Expanded(
                                flex: 2,
                                child: Text("OrderTime", style: _headerStyle),
                              ),
                              Expanded(
                                flex: 4,
                                child: Text(
                                  "Action",
                                  style: _headerStyle,
                                  textAlign: TextAlign.center,
                                ),
                              ),
                            ],
                          ),
                        ),

                        // Data Rows
                        Expanded(
                          child: ListView.builder(
                            itemCount: _orders.length,
                            itemBuilder: (context, index) {
                              final order = _orders[index];
                              final isEven = index % 2 == 0;

                              return Container(
                                padding: const EdgeInsets.symmetric(
                                  vertical: 14,
                                  horizontal: 10,
                                ),
                                decoration: BoxDecoration(
                                  color: isEven
                                      ? const Color(0xFF162A2D)
                                      : const Color(0xFF1F3C40),
                                  border: Border(
                                    bottom: BorderSide(
                                      color: Colors.grey.shade800,
                                      width: 0.5,
                                    ),
                                  ),
                                ),
                                child: Row(
                                  children: [
                                    Expanded(
                                      flex: 2,
                                      child: Text(
                                        order["order_no"]?.toString() ?? "-",
                                        style: _rowStyle,
                                      ),
                                    ),
                                    Expanded(
                                      flex: 2,
                                      child: Text(
                                        order["order_type"] ?? "-",
                                        style: _rowStyle,
                                      ),
                                    ),
                                    Expanded(
                                      flex: 2,
                                      child: Text(
                                        order["table_no"] ?? "-",
                                        style: _rowStyle,
                                      ),
                                    ),
                                    Expanded(
                                      flex: 1,
                                      child: Text(
                                        order["cover"]?.toString() ?? "-",
                                        style: _rowStyle,
                                      ),
                                    ),
                                    Expanded(
                                      flex: 2,
                                      child: Text(
                                        order["order_time"] ?? "-",
                                        style: _rowStyle,
                                      ),
                                    ),

                                    Expanded(
                                      flex: 4,
                                      child: Row(
                                        mainAxisAlignment:
                                            MainAxisAlignment.center,
                                        children: [
                                          // 🔸 Edit Button
                                          ElevatedButton.icon(
                                            onPressed: () =>
                                                _navigateToEditScreen(order),
                                            icon: const Icon(
                                              Icons.edit,
                                              size: 18,
                                              color: Colors.white,
                                            ),
                                            label: const Text(
                                              "EDIT",
                                              style: _buttonTextStyle,
                                            ),
                                            style: ElevatedButton.styleFrom(
                                              backgroundColor:
                                                  const Color(0xFFD66022),
                                              padding:
                                                  const EdgeInsets.symmetric(
                                                horizontal: 10,
                                                vertical: 12,
                                              ),
                                              shape: RoundedRectangleBorder(
                                                borderRadius:
                                                    BorderRadius.circular(12),
                                              ),
                                            ),
                                          ),

                                          const SizedBox(width: 8),

                                          // 💵 CASH Button
                                          ElevatedButton(
                                            onPressed: () {
                                              final dynamic orderNo =
                                                  order['order_no'];
                                              final String orderNoString =
                                                  orderNo.toString();

                                              // ✅ Yeh line fix ki gayi hai:
                                              final String tabUniqueIdString =
                                                  order['tab_unique_id']
                                                          ?.toString() ??
                                                      '';

                                              Navigator.push(
                                                context,
                                                MaterialPageRoute(
                                                  builder: (context) =>
                                                      CashBillScreen(
                                                    orderNo: orderNoString,
                                                    tabUniqueId:
                                                        tabUniqueIdString,
                                                  ),
                                                ),
                                              );
                                            },
                                            style: ElevatedButton.styleFrom(
                                              backgroundColor: Colors.green,
                                              padding:
                                                  const EdgeInsets.symmetric(
                                                horizontal: 10,
                                                vertical: 14,
                                              ),
                                              shape: RoundedRectangleBorder(
                                                borderRadius:
                                                    BorderRadius.circular(12),
                                              ),
                                            ),
                                            child: const Text(
                                              "CASH",
                                              style: _buttonTextStyle,
                                            ),
                                          ),

                                          const SizedBox(width: 8),

                                          // 💳 CREDIT Button
                                          ElevatedButton(
                                            onPressed: () {
                                              // TODO: implement CREDIT action
                                            },
                                            style: ElevatedButton.styleFrom(
                                              backgroundColor: Colors.blue,
                                              padding:
                                                  const EdgeInsets.symmetric(
                                                horizontal: 10,
                                                vertical: 14,
                                              ),
                                              shape: RoundedRectangleBorder(
                                                borderRadius:
                                                    BorderRadius.circular(12),
                                              ),
                                            ),
                                            child: const Text(
                                              "CREDIT",
                                              style: _buttonTextStyle,
                                            ),
                                          ),
                                        ],
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
    ),
  );
}
}

// Styles
const _headerStyle = TextStyle(
  color: Colors.white,
  fontWeight: FontWeight.bold,
  fontSize: 16,
  fontFamily: 'Raleway',
);

const _rowStyle = TextStyle(
  color: Colors.white,
  fontSize: 15,
  fontFamily: 'Raleway',
);

const _buttonTextStyle = TextStyle(
  color: Colors.white,
  fontWeight: FontWeight.bold,
  fontSize: 14,
  letterSpacing: 1,
);
