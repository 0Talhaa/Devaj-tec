import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:sql_conn/sql_conn.dart';
import 'package:start_app/database_halper.dart';
import 'package:start_app/main.dart'; // For color constants

class CashBillScreen extends StatefulWidget {
  final String orderNo;
  const CashBillScreen({super.key, required this.orderNo});

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
  String _safeString(Map<String, dynamic>? map, String key) {
    return map?[key]?.toString() ?? '';
  }

  // Helper to safely get numeric value
  double _safeNum(Map<String, dynamic>? map, String key) {
    final value = map?[key];
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

      // Fetch order details from dine_in_order using tab_unique_id
      final detailsQuery = """
        SELECT 
          tab_unique_id AS OrderNo,
          table_no AS TableNo,
          cover AS Covers,
          waiter AS waiter_name,
          order_type AS OrderType,
          order_time AS OrderTime,
          total_amount AS TotalAmount
        FROM dine_in_order
        WHERE tab_unique_id = ?
      """;
      final detailsResult = await SqlConn.readData(detailsQuery.replaceAll('?', "'${widget.orderNo}'"));
      final parsedDetails = jsonDecode(detailsResult) as List<dynamic>;

      if (parsedDetails.isEmpty) {
        setState(() {
          isLoading = false;
          errorMessage = 'No order details found for Order No: ${widget.orderNo}';
        });
        return;
      }

      // Fetch order items
      const itemsQuery = 'EXEC uspGetOrderItems @OrderNo = ?';
      final itemsResult = await SqlConn.readData(itemsQuery.replaceAll('?', "'${widget.orderNo}'"));
      final parsedItems = jsonDecode(itemsResult) as List<dynamic>;

      setState(() {
        orderDetails = parsedDetails.first.cast<String, dynamic>();
        orderItems = parsedItems.cast<Map<String, dynamic>>().map((item) {
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

  // Simulate printing (replace with actual printing logic if available)
  void _printBill() {
    if (orderDetails == null || orderItems.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No bill data to print'), backgroundColor: Colors.red),
      );
      return;
    }

    final buffer = StringBuffer();
    buffer.writeln('=== RESTAURANT NAME POS ===');
    buffer.writeln('Cash Bill');
    buffer.writeln('Order No: ${_safeString(orderDetails, 'OrderNo')}');
    buffer.writeln('Table/Covers: ${_safeString(orderDetails, 'TableNo')} / ${_safeString(orderDetails, 'Covers')}');
    buffer.writeln('Waiter: ${_safeString(orderDetails, 'waiter_name')}');
    buffer.writeln('Order Type: ${_safeString(orderDetails, 'OrderType')}');
    buffer.writeln('Time: ${_safeString(orderDetails, 'OrderTime')}');
    buffer.writeln('---------------------------');
    buffer.writeln('Item                Qty  Price  Total');
    for (var item in orderItems) {
      final qty = _safeNum(item, 'Qty');
      final price = _safeNum(item, 'Price');
      final total = qty * price;
      buffer.writeln('${_safeString(item, 'ItemName').padRight(20)} ${qty.toStringAsFixed(0).padLeft(3)}  ${price.toStringAsFixed(2).padLeft(6)}  ${total.toStringAsFixed(2).padLeft(6)}');
    }
    buffer.writeln('---------------------------');
    buffer.writeln('Grand Total: ${currencyFormatter.format(_safeNum(orderDetails, 'TotalAmount'))}');
    buffer.writeln('Thank You for your visit!');

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
        body: const Center(
          child: Text('❌ Order not found for this Order No.', style: TextStyle(fontSize: 16, fontFamily: 'Raleway')),
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
          child: Column(
            children: [
              Card(
                elevation: 8,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                child: Padding(
                  padding: const EdgeInsets.all(20.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      _buildHeader(),
                      const SizedBox(height: 15),
                      _buildDetailsRow('Order No.', orderNo),
                      _buildDetailsRow('Table/Covers', '$tableNo / $covers'),
                      _buildDetailsRow('waiter_name', waiterName),
                      _buildDetailsRow('Order Type', orderType),
                      _buildDetailsRow('Time', orderTime),
                      const Divider(height: 30, thickness: 1, color: Colors.grey),
                      _buildItemsTable(),
                      const Divider(height: 20, thickness: 2, color: Colors.black),
                      _buildTotalRow('Grand Total', grandTotal, isBold: true),
                      const SizedBox(height: 20),
                      const Text(
                        'Thank You for your visit!',
                        textAlign: TextAlign.center,
                        style: TextStyle(fontStyle: FontStyle.italic, fontFamily: 'Raleway'),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 20),
              SizedBox(
                width: 320,
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
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return const Column(
      children: [
        Text(
          'RESTAURANT NAME POS',
          style: TextStyle(
            fontSize: 22,
            fontWeight: FontWeight.w900,
            letterSpacing: 1.5,
            color: Colors.black87,
            fontFamily: 'Raleway',
          ),
          semanticsLabel: 'Restaurant Name POS',
        ),
        Text(
          'Cash Bill',
          style: TextStyle(fontSize: 16, color: Colors.grey, fontFamily: 'Raleway'),
        ),
      ],
    );
  }

  Widget _buildDetailsRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(fontWeight: FontWeight.w500, fontFamily: 'Raleway')),
          Text(value, style: const TextStyle(fontFamily: 'Raleway')),
        ],
      ),
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
    return DataTable(
      columnSpacing: 15,
      horizontalMargin: 10,
      headingRowHeight: 35,
      dataRowMinHeight: 35,
      columns: const [
        DataColumn(label: Text('Item', style: TextStyle(fontWeight: FontWeight.bold, fontFamily: 'Raleway'))),
        DataColumn(label: Text('Qty', style: TextStyle(fontWeight: FontWeight.bold, fontFamily: 'Raleway')), numeric: true),
        DataColumn(label: Text('Price', style: TextStyle(fontWeight: FontWeight.bold, fontFamily: 'Raleway')), numeric: true),
        DataColumn(label: Text('Total', style: TextStyle(fontWeight: FontWeight.bold, fontFamily: 'Raleway')), numeric: true),
      ],
      rows: orderItems.map((item) {
        final itemName = _safeString(item, 'ItemName');
        final qty = _safeNum(item, 'Qty');
        final price = _safeNum(item, 'Price');
        final total = qty * price;
        return DataRow(
          cells: [
            DataCell(SizedBox(width: 120, child: Text(itemName, overflow: TextOverflow.ellipsis, style: const TextStyle(fontFamily: 'Raleway')))),
            DataCell(Text(qty.toStringAsFixed(0), style: const TextStyle(fontFamily: 'Raleway'))),
            DataCell(Text(currencyFormatter.format(price), style: const TextStyle(fontFamily: 'Raleway'))),
            DataCell(Text(currencyFormatter.format(total), style: const TextStyle(fontWeight: FontWeight.bold, fontFamily: 'Raleway'))),
          ],
        );
      }).toList(),
    );
  }
}