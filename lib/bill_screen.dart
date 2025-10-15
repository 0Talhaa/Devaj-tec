// ignore_for_file: unused_local_variable, use_build_context_synchronously

import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:mssql_connection/mssql_connection.dart';
import 'package:sql_conn/sql_conn.dart';
import 'package:start_app/database_halper.dart';
import 'package:intl/intl.dart';
import 'package:share_plus/share_plus.dart';

// Reuse OrderItem and OrderConstants from delivery_screen.dart
class OrderConstants {
  static const String itemId = 'id';
  static const String itemName = 'item_name';
  static const String salePrice = 'sale_price';
  static const String quantity = 'quantity';
  static const String taxPercent = 'tax_percent';
  static const String discountPercent = 'discount_percent';
  static const String comments = 'Comments';
}

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
}

class BillScreen extends StatefulWidget {
  final String? tabUniqueId;

  BillScreen({this.tabUniqueId});

  @override
  _BillScreenState createState() => _BillScreenState();
}

class _BillScreenState extends State<BillScreen> {
  bool _isLoading = true;
  List<OrderItem> _orderItems = [];
  Map<String, dynamic>? _orderDetails;
  double _subtotal = 0.0;
  double _totalTax = 0.0;
  double _totalDiscount = 0.0;
  double _grandTotal = 0.0;
  Map<String, dynamic>? _connectionDetails;
  late MssqlConnection _mssql;
  bool _isMssqlReady = false;

  @override
  void initState() {
    super.initState();
    _initConnectionAndLoadData();
  }

  Future<void> _initConnectionAndLoadData() async {
    setState(() => _isLoading = true);
    await _setupSqlConn();
    await _loadConnectionDetails();
    if (widget.tabUniqueId != null && widget.tabUniqueId!.isNotEmpty) {
      await _fetchOrderDetails(widget.tabUniqueId!);
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Invalid order ID'),
          backgroundColor: Colors.red,
        ),
      );
    }
    setState(() => _isLoading = false);
  }

  Future<void> _loadConnectionDetails() async {
    final connDetails = await DatabaseHelper.instance.getConnectionDetails();
    setState(() {
      _connectionDetails = connDetails;
    });
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

  Future<void> _fetchOrderDetails(String tabUniqueId) async {
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

      // Fetch order metadata
      final orderQuery = """
        SELECT 
          tab_unique_id,
          order_date,
          waiter,
          OrderType,
          Customer,
          Tele,
          Address,
          total_amount
        FROM dine_in_order
        WHERE tab_unique_id = '$tabUniqueId'
      """;
      final orderResult = await SqlConn.readData(orderQuery);
      final orderData = jsonDecode(orderResult) as List<dynamic>;

      if (orderData.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('No order found for tabUniqueId=$tabUniqueId')),
        );
        return;
      }

      // Fetch order items
      final itemsQuery = """
        SELECT 
          d.itemid AS id, 
          d.item_name, 
          d.qty AS quantity, 
          d.Comments,
          (i.sale_price) AS sale_price,
          d.id AS orderDetailId, 
          d.tax AS tax_percent,
          d.discount AS discount_percent
        FROM order_detail d
        INNER JOIN dine_in_order m ON d.order_key = m.order_key
        INNER JOIN itempos i ON i.id = d.itemid
        WHERE m.tab_unique_id = '$tabUniqueId'
      """;
      final itemsResult = await SqlConn.readData(itemsQuery);
      final itemsData = jsonDecode(itemsResult) as List<dynamic>;

      setState(() {
        _orderDetails = orderData[0] as Map<String, dynamic>;
        _orderItems = itemsData.map((row) => OrderItem.fromMap(row)).toList();
        _calculateTotals();
      });

      debugPrint("📝 Order Details: $_orderDetails");
      debugPrint("📝 Order Items: ${_orderItems.length} items");
    } catch (e, stackTrace) {
      debugPrint('❌ Error fetching order details: $e\n$stackTrace');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to fetch order: $e')),
      );
    }
  }

  void _calculateTotals() {
    double subtotal = 0.0;
    double totalTax = 0.0;
    double totalDiscount = 0.0;

    for (var item in _orderItems) {
      final itemSubtotal = item.salePrice * item.quantity;
      final taxAmount = itemSubtotal * (item.taxPercent / 100);
      final discountAmount = itemSubtotal * (item.discountPercent / 100);
      subtotal += itemSubtotal;
      totalTax += taxAmount;
      totalDiscount += discountAmount;
    }

    setState(() {
      _subtotal = subtotal;
      _totalTax = totalTax;
      _totalDiscount = totalDiscount;
      _grandTotal = subtotal + totalTax - totalDiscount;
    });

    debugPrint(
        "💰 Bill Totals => Subtotal: $_subtotal | Tax: $_totalTax | Discount: $_totalDiscount | Grand Total: $_grandTotal");
  }

  void _printBill() {
    // Simulate printing (replace with actual printer integration)
    final billText = _generateBillText();
    debugPrint("🖨️ Printing Bill:\n$billText");
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Bill sent to printer')),
    );
  }

  void _shareBill() {
    final billText = _generateBillText();
    Share.share(billText, subject: 'Delivery Order Bill - ${_orderDetails?['tab_unique_id']}');
  }

  String _generateBillText() {
    final buffer = StringBuffer();
    buffer.writeln('=== Delivery Order Bill ===');
    buffer.writeln('Order ID: ${_orderDetails?['tab_unique_id']}');
    buffer.writeln('Date: ${_orderDetails?['order_date'] ?? 'N/A'}');
    buffer.writeln('Waiter: ${_orderDetails?['waiter'] ?? 'N/A'}');
    buffer.writeln('Customer: ${_orderDetails?['Customer'] ?? 'N/A'}');
    buffer.writeln('Phone: ${_orderDetails?['Tele'] ?? 'N/A'}');
    buffer.writeln('Address: ${_orderDetails?['Address'] ?? 'N/A'}');
    buffer.writeln('Order Type: ${_orderDetails?['OrderType'] ?? 'DELIVERY'}');
    buffer.writeln('==========================');
    buffer.writeln('Items:');
    for (var item in _orderItems) {
      final subtotal = item.salePrice * item.quantity;
      final tax = subtotal * (item.taxPercent / 100);
      final discount = subtotal * (item.discountPercent / 100);
      final total = subtotal + tax - discount;
      buffer.writeln('${item.itemName}');
      buffer.writeln('  Qty: ${item.quantity} x ${item.salePrice.toStringAsFixed(2)}');
      buffer.writeln('  Tax: ${tax.toStringAsFixed(2)} (${item.taxPercent}%)');
      buffer.writeln('  Discount: ${discount.toStringAsFixed(2)} (${item.discountPercent}%)');
      buffer.writeln('  Total: ${total.toStringAsFixed(2)}');
      if (item.comments.isNotEmpty) {
        buffer.writeln('  Comments: ${item.comments}');
      }
      buffer.writeln('---');
    }
    buffer.writeln('==========================');
    buffer.writeln('Subtotal: ${_subtotal.toStringAsFixed(2)}');
    buffer.writeln('Total Tax: ${_totalTax.toStringAsFixed(2)}');
    buffer.writeln('Total Discount: ${_totalDiscount.toStringAsFixed(2)}');
    buffer.writeln('Grand Total: ${_grandTotal.toStringAsFixed(2)}');
    buffer.writeln('==========================');
    buffer.writeln('Thank you for your order!');
    return buffer.toString();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Bill Details',
          style: TextStyle(fontFamily: 'Raleway'),
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
            : _orderDetails == null
                ? const Center(
                    child: Text(
                      'No order details available',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                        fontFamily: 'Raleway',
                      ),
                    ),
                  )
                : LayoutBuilder(
                    builder: (context, constraints) {
                      return constraints.maxWidth > 600
                          ? _buildDesktopLayout()
                          : _buildMobileLayout();
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
                _buildOrderHeader(),
                const Divider(color: Colors.white24),
                _buildOrderItemsList(),
                const Divider(color: Colors.white),
                _buildSummaryRow('Subtotal', _subtotal.toStringAsFixed(2)),
                _buildSummaryRow('Total Tax', _totalTax.toStringAsFixed(2)),
                _buildSummaryRow('Total Discount', _totalDiscount.toStringAsFixed(2)),
                _buildSummaryRow('Grand Total', _grandTotal.toStringAsFixed(2), isBold: true),
              ],
            ),
          ),
        ),
        Expanded(
          flex: 2,
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                ElevatedButton(
                  onPressed: _printBill,
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
                  child: const Text('Print Bill'),
                ),
                const SizedBox(height: 16),
                ElevatedButton(
                  onPressed: _shareBill,
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
                  child: const Text('Share Bill'),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildMobileLayout() {
    return Column(
      children: [
        Expanded(
          child: SingleChildScrollView(
            child: Container(
              color: Colors.grey.shade900,
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildOrderHeader(),
                  const Divider(color: Colors.white24),
                  _buildOrderItemsList(),
                  const Divider(color: Colors.white),
                  _buildSummaryRow('Subtotal', _subtotal.toStringAsFixed(2)),
                  _buildSummaryRow('Total Tax', _totalTax.toStringAsFixed(2)),
                  _buildSummaryRow('Total Discount', _totalDiscount.toStringAsFixed(2)),
                  _buildSummaryRow('Grand Total', _grandTotal.toStringAsFixed(2), isBold: true),
                ],
              ),
            ),
          ),
        ),
        Container(
          color: Colors.grey.shade900,
          padding: const EdgeInsets.all(16),
          child: Column(
            children: [
              ElevatedButton(
                onPressed: _printBill,
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
                child: const Text('Print Bill'),
              ),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: _shareBill,
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
                child: const Text('Share Bill'),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildOrderHeader() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Order ID: ${_orderDetails?['tab_unique_id'] ?? 'N/A'}',
          style: const TextStyle(
            color: Colors.white,
            fontSize: 18,
            fontWeight: FontWeight.bold,
            fontFamily: 'Raleway',
          ),
        ),
        const SizedBox(height: 8),
        Text(
          'Date: ${_orderDetails?['order_date'] ?? 'N/A'}',
          style: const TextStyle(
            color: Colors.white70,
            fontSize: 16,
            fontFamily: 'Raleway',
          ),
        ),
        Text(
          'Waiter: ${_orderDetails?['waiter'] ?? 'N/A'}',
          style: const TextStyle(
            color: Colors.white70,
            fontSize: 16,
            fontFamily: 'Raleway',
          ),
        ),
        Text(
          'Customer: ${_orderDetails?['Customer'] ?? 'N/A'}',
          style: const TextStyle(
            color: Colors.white70,
            fontSize: 16,
            fontFamily: 'Raleway',
          ),
        ),
        Text(
          'Phone: ${_orderDetails?['Tele'] ?? 'N/A'}',
          style: const TextStyle(
            color: Colors.white70,
            fontSize: 16,
            fontFamily: 'Raleway',
          ),
        ),
        Text(
          'Address: ${_orderDetails?['Address'] ?? 'N/A'}',
          style: const TextStyle(
            color: Colors.white70,
            fontSize: 16,
            fontFamily: 'Raleway',
          ),
        ),
        Text(
          'Order Type: ${_orderDetails?['OrderType'] ?? 'DELIVERY'}',
          style: const TextStyle(
            color: Colors.white70,
            fontSize: 16,
            fontFamily: 'Raleway',
          ),
        ),
      ],
    );
  }

  Widget _buildOrderItemsList() {
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.symmetric(vertical: 12.0, horizontal: 8.0),
          decoration: BoxDecoration(
            color: Colors.grey.shade800,
            borderRadius: BorderRadius.circular(8.0),
          ),
          child: const Row(
            children: [
              Expanded(
                flex: 3,
                child: Text(
                  'Item',
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontFamily: 'Raleway',
                  ),
                ),
              ),
              Expanded(
                flex: 2,
                child: Text(
                  'Price',
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontFamily: 'Raleway',
                  ),
                ),
              ),
              Expanded(
                flex: 2,
                child: Text(
                  'Qty',
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontFamily: 'Raleway',
                  ),
                  textAlign: TextAlign.center,
                ),
              ),
              Expanded(
                flex: 2,
                child: Text(
                  'Tax',
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontFamily: 'Raleway',
                  ),
                ),
              ),
              Expanded(
                flex: 2,
                child: Text(
                  'Disc',
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontFamily: 'Raleway',
                  ),
                ),
              ),
              Expanded(
                flex: 3,
                child: Text(
                  'Total',
                  style: TextStyle(
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
        ListView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: _orderItems.length,
          itemBuilder: (context, index) {
            final item = _orderItems[index];
            final subtotal = item.salePrice * item.quantity;
            final taxAmount = subtotal * (item.taxPercent / 100);
            final discountAmount = subtotal * (item.discountPercent / 100);
            final itemTotal = subtotal + taxAmount - discountAmount;

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
                              item.itemName,
                              style: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.w500,
                                fontFamily: 'Raleway',
                              ),
                            ),
                            if (item.comments.isNotEmpty)
                              Text(
                                item.comments,
                                style: const TextStyle(
                                  color: Colors.white70,
                                  fontSize: 12,
                                  fontStyle: FontStyle.italic,
                                  fontFamily: 'Raleway',
                                ),
                              ),
                          ],
                        ),
                      ),
                      Expanded(
                        flex: 2,
                        child: Text(
                          item.salePrice.toStringAsFixed(2),
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
                          item.quantity.toString(),
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w500,
                            fontFamily: 'Raleway',
                          ),
                          textAlign: TextAlign.center,
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
                        flex: 2,
                        child: Text(
                          discountAmount.toStringAsFixed(2),
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
      ],
    );
  }

  Widget _buildSummaryRow(String label, String value, {bool isBold = false}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: TextStyle(
              color: Colors.white,
              fontSize: 16,
              fontWeight: isBold ? FontWeight.bold : FontWeight.normal,
              fontFamily: 'Raleway',
            ),
          ),
          Text(
            value,
            style: TextStyle(
              color: const Color(0xFF75E5E2),
              fontSize: 16,
              fontWeight: isBold ? FontWeight.bold : FontWeight.normal,
              fontFamily: 'Raleway',
            ),
          ),
        ],
      ),
    );
  }
}