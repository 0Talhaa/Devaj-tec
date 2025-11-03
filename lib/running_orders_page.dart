import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:sql_conn/sql_conn.dart';
import 'package:start_app/CreditBill.dart' as credit;
import 'package:start_app/database_halper.dart';
import 'package:start_app/cash_bill_screen.dart';
import 'package:start_app/order_screen.dart';
import 'package:start_app/custom_app_loader.dart';
import 'package:start_app/loader_utils.dart';
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
    SqlConn.disconnect(); // ✅ Disconnect only when screen closes
    super.dispose();
  }

  Future<bool> _ensureConnection() async {
    if (_connDetails == null) {
      final conn = await DatabaseHelper.instance.getConnectionDetails();
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

  // 🟩 Fetch Orders
  Future<void> _fetchOrders() async {
    if (!LoaderUtils.hasConnection()) {
      setState(() {
        _error = "No internet connection. Please check your network.";
        _loading = false;
      });
      return;
    }

    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      if (!await _ensureConnection()) return;

      // Get database name from SQLite
      final savedDbName = await DatabaseHelper.instance.getSavedDatabaseName();
      final dbName = savedDbName ?? 'HNFOODMULTAN_';
      
      final query = "EXEC $dbName.dbo.uspGetOrderList";
      final result = await SqlConn.readData(query);

      // Safe decode
      final decoded = jsonDecode(result) as List<dynamic>;
      final uniqueOrders = <String, Map<String, dynamic>>{};

      for (var order in decoded) {
        final safeOrder = Map<String, dynamic>.from(order as Map);
        final uniqueKey = safeOrder['tab_unique_id']?.toString() ?? '';
        if (!uniqueOrders.containsKey(uniqueKey)) {
          uniqueOrders[uniqueKey] = safeOrder.map((key, value) {
            return MapEntry(key.toString(), value?.toString() ?? '');
          });
        }
      }

      setState(() {
        _orders = uniqueOrders.values.toList();
        _loading = false;
      });
    } catch (e) {
      setState(() {
        _error = "❌ Error fetching orders: $e";
        _loading = false;
      });
    }
  }

  // 🟩 Navigate to Edit Screen
  Future<void> _navigateToEditScreen(Map<String, dynamic> order) async {
    AppLoaderOverlay.show(context, message: 'Opening order...');
    try {
      final String tabUniqueId = order["tab_unique_id"] ?? "";
      final String tableName = order["table_no"] ?? "N/A";
      final int tableId = int.tryParse(order["table_id"] ?? "0") ?? 0;
      final int customerCount = int.tryParse(order["cover"] ?? "1") ?? 1;
      final int? selectedTiltId =
          int.tryParse(order["tilt_id"] ?? "") ?? null;
      final String waiterName = order["waiter"] ?? "Admin";

      AppLoaderOverlay.hide();
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
      AppLoaderOverlay.hide();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("❌ Edit navigation error: $e")),
      );
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
            ? const AppLoader(message: 'Loading orders...')
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
                          Container(
                            padding: const EdgeInsets.symmetric(
                              vertical: 10,
                              horizontal: 8,
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
                                Expanded(flex: 2, child: Text("OrderNo", style: _headerStyle)),
                                Expanded(flex: 2, child: Text("OrderType", style: _headerStyle)),
                                Expanded(flex: 2, child: Text("TableNo", style: _headerStyle)),
                                Expanded(flex: 1, child: Text("Covers", style: _headerStyle)),
                                Expanded(flex: 2, child: Text("OrderTime", style: _headerStyle)),
                                Expanded(flex: 4, child: Text("Action", style: _headerStyle, textAlign: TextAlign.center)),
                              ],
                            ),
                          ),

                          Expanded(
                            child: ListView.builder(
                              itemCount: _orders.length,
                              itemBuilder: (context, index) {
                                final order = _orders[index];
                                final isEven = index % 2 == 0;

                                return Container(
                                  padding: const EdgeInsets.symmetric(
                                    vertical: 12,
                                    horizontal: 7,
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
                                      Expanded(flex: 2, child: Text(order["order_no"] ?? "-", style: _rowStyle)),
                                      Expanded(flex: 2, child: Text(order["order_type"] ?? "-", style: _rowStyle)),
                                      Expanded(flex: 2, child: Text(order["table_no"] ?? "-", style: _rowStyle)),
                                      Expanded(flex: 1, child: Text(order["cover"] ?? "-", style: _rowStyle)),
                                      Expanded(flex: 2, child: Text(order["order_time"] ?? "-", style: _rowStyle)),

                                      Expanded(
                                        flex: 4,
                                        child: Row(
                                          mainAxisAlignment: MainAxisAlignment.center,
                                          children: [
                                            ElevatedButton.icon(
                                              onPressed: () => _navigateToEditScreen(order),
                                              icon: const Icon(Icons.edit, size: 18, color: Colors.white),
                                              label: const Text("EDIT", style: _buttonTextStyle),
                                              style: ElevatedButton.styleFrom(
                                                backgroundColor: const Color(0xFFD66022),
                                                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 12),
                                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                              ),
                                            ),
                                            const SizedBox(width: 8),
                                            ElevatedButton(
                                              onPressed: () {
                                                final orderNo = order['order_no'] ?? '-';
                                                final tabUniqueId = order['tab_unique_id'] ?? '';
                                                Navigator.push(
                                                  context,
                                                  MaterialPageRoute(
                                                    builder: (context) => CashBillScreen(
                                                      orderNo: orderNo,
                                                      tabUniqueId: tabUniqueId,
                                                    ),
                                                  ),
                                                );
                                              },
                                              style: ElevatedButton.styleFrom(
                                                backgroundColor: Colors.green,
                                                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 14),
                                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                              ),
                                              child: const Text("CASH", style: _buttonTextStyle),
                                            ),
                                            const SizedBox(width: 8),
                                            ElevatedButton(
                                              onPressed: () {
                                                final orderNo = order['order_no'] ?? '-';
                                                final tabUniqueId = order['tab_unique_id'] ?? '';
                                                Navigator.push(
                                                  context,
                                                  MaterialPageRoute(
                                                    builder: (context) => credit.CreditBillScreen(
                                                      orderNo: orderNo,
                                                      tabUniqueId: tabUniqueId,
                                                    ),
                                                  ),
                                                );
                                              },
                                              style: ElevatedButton.styleFrom(
                                                backgroundColor: Colors.blue,
                                                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 14),
                                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                              ),
                                              child: const Text("CREDIT", style: _buttonTextStyle),
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