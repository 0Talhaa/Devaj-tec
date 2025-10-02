import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:sql_conn/sql_conn.dart';
import 'package:start_app/database_halper.dart';
import 'package:start_app/cash_bill_screen.dart';

class RunningOrdersPage extends StatefulWidget {
  const RunningOrdersPage({super.key});

  @override
  State<RunningOrdersPage> createState() => _RunningOrdersPageState();
}

class _RunningOrdersPageState extends State<RunningOrdersPage> {
  bool _loading = true;
  List<Map<String, dynamic>> _orders = [];
  String? _error;

  @override
  void initState() {
    super.initState();
    _fetchOrders();
  }

  Future<void> _fetchOrders() async {
    try {
      final conn = await DatabaseHelper.instance.getConnectionDetails();
      if (conn == null) {
        setState(() {
          _error = "⚠️ No saved connection details found.";
          _loading = false;
        });
        return;
      }

      // Connect if not already connected
      if (!await SqlConn.isConnected) {
        await SqlConn.connect(
          ip: conn['ip'],
          port: conn['port'],
          databaseName: conn['dbName'],
          username: conn['username'],
          password: conn['password'],
        );
      }

      // Call stored procedure
      const query = "EXEC uspGetOrderList";
      final result = await SqlConn.readData(query);

      final decoded = jsonDecode(result) as List<dynamic>;
      setState(() {
        _orders = decoded.cast<Map<String, dynamic>>();
        _loading = false;
      });
    } catch (e) {
      setState(() {
        _error = "❌ Error fetching orders: $e";
        _loading = false;
      });
    } finally {
      await SqlConn.disconnect();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Running Orders"),
        backgroundColor: const Color(0xFF0D1D20),
        centerTitle: true,
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
                          flex: 3,
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
                                flex: 3,
                                child: Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    ElevatedButton(
                                      onPressed: () {
                                        // 💡 FIX APPLIED HERE: order['order_no'] ko .toString() mein convert kiya gaya hai.
                                        final dynamic orderNo =
                                            order['order_no'];
                                        final String orderNoString = orderNo
                                            .toString();

                                        Navigator.push(
                                          context,
                                          MaterialPageRoute(
                                            // ✅ Corrected Line: Order number ko String ki tarah pass kiya ja raha hai.
                                            builder: (_) => CashBillScreen(
                                              orderNo: orderNoString,
                                            ),
                                          ),
                                        );
                                      },
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: Colors.green,
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 20,
                                          vertical: 14,
                                        ),
                                        shape: RoundedRectangleBorder(
                                          borderRadius: BorderRadius.circular(
                                            12,
                                          ),
                                        ),
                                      ),
                                      child: const Text(
                                        "CASH",
                                        style: _buttonTextStyle,
                                      ),
                                    ),

                                    const SizedBox(width: 12),
                                    ElevatedButton(
                                      onPressed: () {
                                        // TODO: implement CREDIT action
                                      },
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: Colors.blue,
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 20,
                                          vertical: 14,
                                        ),
                                        shape: RoundedRectangleBorder(
                                          borderRadius: BorderRadius.circular(
                                            12,
                                          ),
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
