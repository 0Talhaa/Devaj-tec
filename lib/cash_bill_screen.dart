
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:sql_conn/sql_conn.dart';
import 'package:start_app/database_halper.dart';
import 'package:start_app/main.dart'; // For color constants

class CashBillScreen extends StatefulWidget {
  final String orderNo; // This is the Tab_Unique_Id
  final String tabUniqueId;
  const CashBillScreen({super.key, required this.orderNo,required this.tabUniqueId});

  @override
  State<CashBillScreen> createState() => _CashBillScreenState();
}

class _CashBillScreenState extends State<CashBillScreen> {
  Map<String, dynamic>? orderDetails;
  List<Map<String, dynamic>> orderItems = [];
  bool isLoading = true;
  String? errorMessage;
  final currencyFormatter = NumberFormat.currency(locale: 'en_IN', symbol: '₹');

  @override
  void initState() {
    super.initState();
    _fetchBillData();
  }

  // Helper to safely get string value
  String _safeString(dynamic map, String key) {
    return map[key]?.toString() ?? '';
  }

  // Helper to safely get numeric value
  double _safeNum(dynamic map, String key) {
    final value = map[key];
    if (value is num) return value.toDouble();
    if (value is String) return double.tryParse(value) ?? 0.0;
    return 0.0;
  }

  Future<void> _fetchBillData() async {
    try {
      final conn = await DatabaseHelper.instance.getConnectionDetails();
      if (conn == null) {
        setState(() {
          isLoading = false;
          errorMessage = 'Database connection details not found.';
        });
        return;
      }

      if (!await SqlConn.isConnected) {
        await SqlConn.connect(
          ip: conn['ip'],
          port: conn['port'],
          databaseName: conn['dbName'],
          username: conn['username'],
          password: conn['password'],
          timeout: 10,
        );
      }

      // SELECT * FROM dine_in_orderjson WHERE Tab_Unique_Id = 'your_order_no_value';
      final jsonQuery = """SELECT * FROM dine_in_orderjson WHERE Tab_Unique_Id = ${widget.tabUniqueId}""";
      final jsonResult = await SqlConn.readData(jsonQuery.replaceAll('?', "'${widget.tabUniqueId}'"));
      debugPrint("📝 JSON Query: $jsonQuery");
      debugPrint("📤 JSON Result: $jsonResult");

      final parsedJson = jsonDecode(jsonResult) as List<dynamic>;
      if (parsedJson.isEmpty) {
        setState(() {
          isLoading = false;
          errorMessage = 'No order found for Order No: ${widget.orderNo}';
        });
        return;
      }

      // Assume the JSON data is stored in a column named 'OrderJson' (adjust if different)
      final jsonData = jsonDecode(parsedJson.first['OrderJson']) as Map<String, dynamic>;

      // Extract order details and items from JSON
      setState(() {
        orderDetails = {
          'OrderNo': _safeString(jsonData, 'OrderNo'),
          'TableNo': _safeString(jsonData, 'TableNo'),
          'Covers': _safeString(jsonData, 'Covers'),
          'waiter_name': _safeString(jsonData, 'waiter_name'),
          'OrderType': _safeString(jsonData, 'OrderType'),
          'OrderTime': _safeString(jsonData, 'OrderTime'),
          'TotalAmount': _safeNum(jsonData, 'TotalAmount'),
        };

        orderItems = (jsonData['Items'] as List<dynamic>).map((item) {
          return {
            'ItemName': _safeString(item, 'item_name'),
            'Qty': _safeNum(item, 'qty'),
            'Price': _safeNum(item, 'price') / _safeNum(item, 'qty'), // Normalize price per unit
            'Comments': _safeString(item, 'Comments'),
            'orderDetailId': _safeString(item, 'orderDetailId'),
            'tax': _safeNum(item, 'tax'),
            'kotstatus': _safeString(item, 'kotstatus'),
          };
        }).toList();
        isLoading = false;
        errorMessage = null;
      });

      await SqlConn.disconnect();
    } catch (e, stackTrace) {
      debugPrint('❌ Error fetching bill: $e\n$stackTrace');
      setState(() {
        isLoading = false;
        errorMessage = 'Error fetching data: $e';
      });
    }
  }

  // Enhanced print bill function with formatted layout
  void _printBill() {
    if (orderDetails == null || orderItems.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No bill data to print'), backgroundColor: Colors.red),
      );
      return;
    }

    final buffer = StringBuffer();
    buffer.writeln('┌──────────────────────────────┐');
    buffer.writeln('│      Dilpasand Sweet         │');
    buffer.writeln('│         Cash Bill            │');
    buffer.writeln('└──────────────────────────────┘');
    buffer.writeln('Order No: ${_safeString(orderDetails, 'OrderNo')}');
    buffer.writeln('Table: ${_safeString(orderDetails, 'TableNo')} | Covers: ${_safeString(orderDetails, 'Covers')}');
    buffer.writeln('Waiter: ${_safeString(orderDetails, 'waiter_name')}');
    buffer.writeln('Order Type: ${_safeString(orderDetails, 'OrderType')}');
    buffer.writeln('Time: ${_safeString(orderDetails, 'OrderTime')}');
    buffer.writeln('─' * 30);
    buffer.writeln('Item'.padRight(16) + 'Qty'.padLeft(5) + 'Price'.padLeft(8) + 'Total'.padLeft(8));
    buffer.writeln('─' * 30);
    for (var item in orderItems) {
      final qty = _safeNum(item, 'Qty');
      final price = _safeNum(item, 'Price');
      final total = qty * price;
      final itemName = _safeString(item, 'ItemName').length > 15
          ? '${_safeString(item, 'ItemName').substring(0, 12)}...'
          : _safeString(item, 'ItemName').padRight(15);
      buffer.writeln('$itemName ${qty.toStringAsFixed(0).padLeft(4)} ${currencyFormatter.format(price).padLeft(7)} ${currencyFormatter.format(total).padLeft(7)}');
      if (_safeString(item, 'Comments').isNotEmpty) {
        buffer.writeln('  └─ ${_safeString(item, 'Comments')}');
      }
    }
    buffer.writeln('─' * 30);
    // Calculate total tax
    final totalTax = orderItems.fold(0.0, (sum, item) {
      final qty = _safeNum(item, 'Qty');
      final price = _safeNum(item, 'Price');
      final taxPercent = _safeNum(item, 'tax');
      return sum + (qty * price * taxPercent / 100);
    });
    buffer.writeln('Tax: ${currencyFormatter.format(totalTax)}'.padLeft(30));
    buffer.writeln('Grand Total: ${currencyFormatter.format(_safeNum(orderDetails, 'TotalAmount'))}'.padLeft(30));
    buffer.writeln('┌──────────────────────────────┐');
    buffer.writeln('│   Thank You for Your Visit!   │');
    buffer.writeln('└──────────────────────────────┘');

    // Simulate printing (replace with actual printing logic, e.g., `flutter_bluetooth_printer`)
    debugPrint('🖨️ Printing Bill:\n${buffer.toString()}');
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Bill sent to printer'), backgroundColor: Colors.green),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (isLoading) {
      return Scaffold(
        backgroundColor: kTertiaryColor,
        body: Center(child: CircularProgressIndicator(color: kPrimaryColor)),
      );
    }
    if (errorMessage != null) {
      return Scaffold(
        backgroundColor: kTertiaryColor,
        body: Center(
          child: Text(
            errorMessage!,
            textAlign: TextAlign.center,
            style: const TextStyle(color: Colors.red, fontSize: 16, fontFamily: 'Raleway'),
          ),
        ),
      );
    }
    if (orderDetails == null) {
      return Scaffold(
        backgroundColor: kTertiaryColor,
        body: Center(
          child: Text(
            '❌ Order not found for Order No: ${widget.orderNo}',
            style: const TextStyle(fontSize: 16, fontFamily: 'Raleway', color: Colors.white),
          ),
        ),
      );
    }

    // Extract details using string keys
    final orderNo = _safeString(orderDetails, 'OrderNo');
    final tableNo = _safeString(orderDetails, 'TableNo');
    final covers = _safeString(orderDetails, 'Covers');
    final waiterName = _safeString(orderDetails, 'waiter_name');
    final orderType = _safeString(orderDetails, 'OrderType');
    final orderTime = _safeString(orderDetails, 'OrderTime');
    final grandTotal = _safeNum(orderDetails, 'TotalAmount');

    return Scaffold(
      backgroundColor: kTertiaryColor,
      appBar: AppBar(
        title: const Text('Cash Bill', style: TextStyle(fontFamily: 'Raleway')),
        backgroundColor: kTertiaryColor,
        foregroundColor: kPrimaryColor,
        elevation: 1,
      ),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20.0),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 600),
            child: Card(
              elevation: 8,
              color: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              child: Padding(
                padding: const EdgeInsets.all(20.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _buildHeader(),
                    const SizedBox(height: 20),
                    _buildDetailsRow('Order No.', orderNo),
                    _buildDetailsRow('Table/Covers', '$tableNo / $covers'),
                    _buildDetailsRow('Waiter', waiterName),
                    _buildDetailsRow('Order Type', orderType),
                    _buildDetailsRow('Time', orderTime),
                    const Divider(height: 30, thickness: 1, color: Colors.grey),
                    _buildItemsTable(),
                    const Divider(height: 30, thickness: 2, color: Colors.black54),
                    _buildTaxAndTotalSection(),
                    const SizedBox(height: 20),
                    const Text(
                      'Thank You for Your Visit!',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 16,
                        fontStyle: FontStyle.italic,
                        color: Colors.grey,
                        fontFamily: 'Raleway',
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
      bottomNavigationBar: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Expanded(
              child: ElevatedButton.icon(
                onPressed: _printBill,
                icon: const Icon(Icons.print),
                label: const Text('Print Bill'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: kPrimaryColor,
                  foregroundColor: kTertiaryColor,
                  padding: const EdgeInsets.symmetric(vertical: 15),
                  textStyle: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, fontFamily: 'Raleway'),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                ),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: ElevatedButton.icon(
                onPressed: () {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('✅ Payment Confirmed! Bill Closed.'),
                      backgroundColor: Colors.green,
                    ),
                  );
                },
                icon: const Icon(Icons.payment),
                label: Text('Pay ${currencyFormatter.format(grandTotal)}'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: kPrimaryColor,
                  foregroundColor: kTertiaryColor,
                  padding: const EdgeInsets.symmetric(vertical: 15),
                  textStyle: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, fontFamily: 'Raleway'),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Column(
      children: [
        const Text(
          'Dilpasand Sweet',
          style: TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.w900,
            letterSpacing: 1.2,
            color: Colors.black87,
            fontFamily: 'Raleway',
          ),
          semanticsLabel: 'Dilpasand Sweet',
        ),
        Text(
          'Cash Bill',
          style: TextStyle(fontSize: 16, color: Colors.grey[600], fontFamily: 'Raleway'),
        ),
      ],
    );
  }

  Widget _buildDetailsRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: Colors.black87,
              fontFamily: 'Raleway',
            ),
          ),
          Text(
            value,
            style: const TextStyle(
              fontSize: 14,
              color: Colors.black87,
              fontFamily: 'Raleway',
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTaxAndTotalSection() {
    double totalTax = orderItems.fold(0.0, (sum, item) {
      final qty = _safeNum(item, 'Qty');
      final price = _safeNum(item, 'Price');
      final taxPercent = _safeNum(item, 'tax');
      return sum + (qty * price * taxPercent / 100);
    });

    return Column(
      children: [
        _buildTotalRow('Tax', totalTax),
        _buildTotalRow('Grand Total', _safeNum(orderDetails, 'TotalAmount'), isBold: true),
      ],
    );
  }

  Widget _buildTotalRow(String label, double amount, {bool isBold = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: 18,
              fontWeight: isBold ? FontWeight.bold : FontWeight.normal,
              color: isBold ? Colors.black : Colors.black87,
              fontFamily: 'Raleway',
            ),
          ),
          Text(
            currencyFormatter.format(amount),
            style: TextStyle(
              fontSize: 18,
              fontWeight: isBold ? FontWeight.bold : FontWeight.normal,
              color: isBold ? kPrimaryColor : Colors.black87,
              fontFamily: 'Raleway',
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildItemsTable() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Row(
          children: [
            Expanded(flex: 3, child: Text('Item', style: TextStyle(fontWeight: FontWeight.bold, fontFamily: 'Raleway'))),
            Expanded(flex: 1, child: Text('Qty', style: TextStyle(fontWeight: FontWeight.bold, fontFamily: 'Raleway'), textAlign: TextAlign.right)),
            Expanded(flex: 2, child: Text('Price', style: TextStyle(fontWeight: FontWeight.bold, fontFamily: 'Raleway'), textAlign: TextAlign.right)),
            Expanded(flex: 2, child: Text('Total', style: TextStyle(fontWeight: FontWeight.bold, fontFamily: 'Raleway'), textAlign: TextAlign.right)),
          ],
        ),
        const Divider(height: 10, thickness: 1, color: Colors.grey),
        ...orderItems.asMap().entries.map((entry) {
          final index = entry.key;
          final item = entry.value;
          final itemName = _safeString(item, 'ItemName');
          final qty = _safeNum(item, 'Qty');
          final price = _safeNum(item, 'Price');
          final total = qty * price;
          final comments = _safeString(item, 'Comments');

          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    flex: 3,
                    child: Text(
                      itemName,
                      style: const TextStyle(fontFamily: 'Raleway', fontSize: 14),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  Expanded(
                    flex: 1,
                    child: Text(
                      qty.toStringAsFixed(0),
                      style: const TextStyle(fontFamily: 'Raleway', fontSize: 14),
                      textAlign: TextAlign.right,
                    ),
                  ),
                  Expanded(
                    flex: 2,
                    child: Text(
                      currencyFormatter.format(price),
                      style: const TextStyle(fontFamily: 'Raleway', fontSize: 14),
                      textAlign: TextAlign.right,
                    ),
                  ),
                  Expanded(
                    flex: 2,
                    child: Text(
                      currencyFormatter.format(total),
                      style: const TextStyle(fontWeight: FontWeight.bold, fontFamily: 'Raleway', fontSize: 14),
                      textAlign: TextAlign.right,
                    ),
                  ),
                ],
              ),
              if (comments.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(left: 8.0, top: 2.0),
                  child: Text(
                    '└ $comments',
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.grey[600],
                      fontStyle: FontStyle.italic,
                      fontFamily: 'Raleway',
                    ),
                  ),
                ),
              if (index < orderItems.length - 1) const Divider(height: 10, thickness: 0.5, color: Colors.grey),
            ],
          );
        }),
      ],
    );
  }
}
