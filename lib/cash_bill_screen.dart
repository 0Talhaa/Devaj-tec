import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:sql_conn/sql_conn.dart';
import 'package:intl/intl.dart';

import 'database_halper.dart';

class CashBillScreen extends StatefulWidget {
  final String orderNo;
  const CashBillScreen({super.key, required this.orderNo});

  @override
  State<CashBillScreen> createState() => _CashBillScreenState();
}

class _CashBillScreenState extends State<CashBillScreen> {
  // Map keys can be dynamic (String or Int)
  Map<dynamic, dynamic>? orderDetails;
  List<Map<dynamic, dynamic>> orderItems = [];
  bool isLoading = true;
  String? errorMessage;

  final currencyFormatter = NumberFormat.currency(locale: 'en_IN', symbol: '₹');

  @override
  void initState() {
    super.initState();
    _fetchBillData();
  }

  // Helper function to safely get a value as String, defaults to ''
  // Ab key 'dynamic' type ki hai (ya toh String, ya Int)
  String _safeString(Map<dynamic, dynamic>? map, dynamic key) {
    return map?[key]?.toString() ?? '';
  }

  // Helper function to safely get a numeric value, defaults to 0.0
  double _safeNum(Map<dynamic, dynamic>? map, dynamic key) {
    final value = map?[key];
    if (value is num) {
      return value.toDouble();
    } else if (value is String) {
      return double.tryParse(value) ?? 0.0;
    }
    return 0.0;
  }
 
  

Future<void> _fetchBillData() async {
  try {
    // 1. Order Details Fetching
  final conn = await DatabaseHelper.instance.getConnectionDetails();
      if (!await SqlConn.isConnected) {
      await SqlConn.connect(
        ip: conn!['ip'],
        port: conn['port'],
        databaseName: conn['dbName'],
        username: conn['username'],
        password: conn['password'],
      );
    }
    final detailsQuery = "EXEC uspGetOrderDetails '${widget.orderNo}'";
    final detailsResult = await SqlConn.readData(detailsQuery);
    final parsedDetails = jsonDecode(detailsResult) as List<dynamic>;

    if (parsedDetails.isNotEmpty) {
      // Order Details: Cast the first item to Map<dynamic, dynamic>
      orderDetails = parsedDetails.first.cast<dynamic, dynamic>();
    }

    // 2. Order Items Fetching
    final itemsQuery = "EXEC uspGetOrderItems '${widget.orderNo}'";
    final itemsResult = await SqlConn.readData(itemsQuery);
    final parsedItems = jsonDecode(itemsResult) as List<dynamic>;

    // ✅ FINAL FIX FOR ITEM LIST ASSIGNMENT
    // We map each dynamic item, cast its keys to dynamic, and then 
    // assign the resulting Iterable to the List<Map<dynamic, dynamic>> variable.
    orderItems = parsedItems.map((item) {
      // Ensure each item is treated as a Map with dynamic keys (Int/String)
      return item as Map<dynamic, dynamic>; 
    }).toList();


    setState(() {
      isLoading = false;
      errorMessage = null;
    });
  } catch (e) {
    print("❌ Error fetching bill: $e");
    setState(() {
      isLoading = false;
      errorMessage = "Error fetching data. Please try again. ($e)";
    });
  }
}

  @override
  Widget build(BuildContext context) {
    // 💥 FIX 3: Integer indices (Numeric Keys) use karein
    // Agar stored procedure column names (Strings) return kar raha hai,
    // toh aapko inhein wapas String mein badalna hoga. Lekin 
    // 'int is not a subtype of String' error ke liye, yeh fix zaroori hai.
    
    // Order Details Indices (Maan lijiye ye order hai)
    const orderNoKey = 0;
    const tableNoKey = 1;
    const coversKey = 2;
    const waiterNameKey = 3;
    const orderTypeKey = 4;
    const orderTimeKey = 5;
    const totalAmountKey = 6;
    
    // Order Items Indices (Maan lijiye ye order hai)
    const itemNameKey = 0;
    const qtyKey = 1;
    const priceKey = 2;


    if (isLoading) {
      return const Center(child: CircularProgressIndicator(color: Colors.deepOrange));
    }
    if (errorMessage != null) {
      return Center(
        child: Text(errorMessage!, textAlign: TextAlign.center, style: const TextStyle(color: Colors.red, fontSize: 16)),
      );
    }
    if (orderDetails == null) {
      return const Center(child: Text("❌ Order not found for this Order No."));
    }

    // Safely extract details using helper functions and numeric keys
    final orderNo = _safeString(orderDetails, orderNoKey);
    final tableNo = _safeString(orderDetails, tableNoKey);
    final covers = _safeString(orderDetails, coversKey);
    final waiterName = _safeString(orderDetails, waiterNameKey);
    final orderType = _safeString(orderDetails, orderTypeKey);
    final orderTime = _safeString(orderDetails, orderTimeKey);
    final grandTotal = _safeNum(orderDetails, totalAmountKey);

    // ... (UI part is the same as before)
    return Scaffold(
      backgroundColor: Colors.grey.shade50,
      appBar: AppBar(
        title: const Text('Cash Bill'),
        backgroundColor: Colors.white,
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
                      _buildDetailsRow('Waiter', waiterName),
                      _buildDetailsRow('Order Type', orderType),
                      _buildDetailsRow('Time', orderTime),
                      const Divider(height: 30, thickness: 1, color: Colors.grey),
                      _buildItemsTable(itemNameKey, qtyKey, priceKey),
                      const Divider(height: 20, thickness: 2, color: Colors.black),
                      _buildTotalRow('Grand Total', grandTotal, isBold: true),
                      const SizedBox(height: 20),
                      const Text('Thank You for your visit!', textAlign: TextAlign.center, style: TextStyle(fontStyle: FontStyle.italic)),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 30),
              SizedBox(
                width: 320,
                child: ElevatedButton.icon(
                  onPressed: () {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text("✅ Payment Confirmed! Bill Closed."),
                        backgroundColor: Colors.green,
                      ),
                    );
                  },
                  icon: const Icon(Icons.payment),
                  label: Text("CONFIRM PAYMENT ${currencyFormatter.format(grandTotal)}"),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.deepOrange.shade700,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 15),
                    textStyle: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
  
  // Helper methods (Header, Details Row, Total Row) are the same...
  Widget _buildHeader() {
    return const Column(
      children: [
        Text(
          "RESTAURANT NAME POS",
          style: TextStyle(
            fontSize: 22,
            fontWeight: FontWeight.w900,
            letterSpacing: 1.5,
            color: Colors.black87,
          ),
        ),
        Text("Cash Bill", style: TextStyle(fontSize: 16, color: Colors.grey)),
      ],
    );
  }

  Widget _buildDetailsRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(fontWeight: FontWeight.w500)),
          Text(value),
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
            ),
          ),
          Text(
            currencyFormatter.format(amount),
            style: TextStyle(
              fontSize: 18,
              fontWeight: isBold ? FontWeight.bold : FontWeight.normal,
              color: isBold ? Colors.deepOrange : Colors.black87,
            ),
          ),
        ],
      ),
    );
  }

  // ✅ Items Table mein bhi numeric keys use ki hain
  Widget _buildItemsTable(dynamic itemNameKey, dynamic qtyKey, dynamic priceKey) {
    return DataTable(
      columnSpacing: 10,
      horizontalMargin: 0,
      headingRowHeight: 30,
      dataRowMinHeight: 30,
      columns: const [
        DataColumn(label: Text('Item', style: TextStyle(fontWeight: FontWeight.bold))),
        DataColumn(label: Text('Qty', style: TextStyle(fontWeight: FontWeight.bold)), numeric: true),
        DataColumn(label: Text('Price', style: TextStyle(fontWeight: FontWeight.bold)), numeric: true),
        DataColumn(label: Text('Total', style: TextStyle(fontWeight: FontWeight.bold)), numeric: true),
      ],
      rows: orderItems.map((item) {
        final itemName = _safeString(item, itemNameKey);
        final qty = _safeNum(item, qtyKey);
        final price = _safeNum(item, priceKey);
        final total = qty * price;

        return DataRow(
          cells: [
            DataCell(SizedBox(width: 120, child: Text(itemName, overflow: TextOverflow.ellipsis))),
            DataCell(Text(qty.toStringAsFixed(0))),
            DataCell(Text(price.toStringAsFixed(2))),
            DataCell(Text(total.toStringAsFixed(2), style: const TextStyle(fontWeight: FontWeight.bold))),
          ],
        );
      }).toList(),
    );
  }
}