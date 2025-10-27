// ignore_for_file: await_only_futures, dead_code

import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:sql_conn/sql_conn.dart';
import 'package:start_app/custom_loader.dart' show kTertiaryColor;
import 'package:start_app/database_halper.dart';
import 'package:start_app/main.dart' show kPrimaryColor, kTertiaryColor;
import 'package:start_app/running_orders_page.dart';


class CreditBillScreen extends StatefulWidget {
  final String orderNo;
  final String tabUniqueId;

  const CreditBillScreen({
    super.key,
    required this.orderNo,
    required this.tabUniqueId,
  });

  @override
  State<CreditBillScreen> createState() => _CreditBillScreenState();
}

class _CreditBillScreenState extends State<CreditBillScreen> {
  Map<String, dynamic>? orderDetails;
  List<Map<String, dynamic>> orderItems = [];
  bool isLoading = true;
  String? errorMessage;
  final numberFormatter = NumberFormat('#,##0.00', 'en_US');

  @override
  void initState() {
    super.initState();
    _fetchBillData();
  }

  String _safeString(dynamic map, String key) {
    return map[key]?.toString() ?? '';
  }

  double _safeNum(dynamic map, String key) {
    final value = map[key];
    if (value is num) return value.toDouble();
    if (value is String) return double.tryParse(value) ?? 0.0;
    return 0.0;
  }

  String _fixJsonFormat(String rawJson) {
    return rawJson
        .replaceFirst(RegExp(r'"OrderDetails"\s*:\s*{'), '"OrderDetails":[')
        .replaceAllMapped(RegExp(r'}\s*,\s*{'), (match) => '},{')
        .replaceAll('}}', ']}')
        .replaceAll(r'\"', '"')
        .replaceAll('\\\\', '\\')
        .replaceAll('\n', '')
        .replaceAll('\r', '');
  }

  String _escapeJsonValue(String rawResult) {
    const prefix = '[{"JSON":"';
    const suffix = '"}]';
    if (!rawResult.startsWith(prefix) || !rawResult.endsWith(suffix)) {
      return rawResult;
    }
    String inner = rawResult.substring(prefix.length, rawResult.length - suffix.length);
    inner = inner.replaceAll('\\', '\\\\').replaceAll('"', '\\"');
    return '$prefix$inner$suffix';
  }

  String _sanitizeJson(String jsonString) {
    String cleaned = jsonString
        .replaceAll(r'\"', '"')
        .replaceAll(RegExp(r'[\x00-\x1F\x7F]'), '');

    final orderDetailsStart = cleaned.indexOf('"OrderDetails":');
    if (orderDetailsStart == -1) {
      return cleaned + ',"OrderDetails":[]}';
    }

    final beforeDetails = cleaned.substring(0, orderDetailsStart + '"OrderDetails":'.length);
    final afterDetailsStart = cleaned.indexOf('{', orderDetailsStart + '"OrderDetails":'.length);
    if (afterDetailsStart == -1) {
      return cleaned + '[]}';
    }

    String detailsContent = cleaned.substring(afterDetailsStart);
    if (!detailsContent.trim().startsWith('[')) {
      final items = <String>[];
      final itemRegex = RegExp(r'\{[^}]*\}', multiLine: true);
      final matches = itemRegex.allMatches(detailsContent).toList();

      for (var match in matches) {
        final item = match.group(0)!;
        try {
          final itemJson = jsonDecode(item) as Map<String, dynamic>;
          if (itemJson['Qty'] != null &&
              itemJson['Item Name'] != null &&
              itemJson['Price'] != null &&
              itemJson['Tax'] != null) {
            final price = (itemJson['Price'] is num)
                ? itemJson['Price'].toDouble()
                : double.tryParse(itemJson['Price'].toString()) ?? 0.0;
            final qty = (itemJson['Qty'] is num)
                ? itemJson['Qty'].toDouble()
                : double.tryParse(itemJson['Qty'].toString()) ?? 0.0;
            if (price > 0 && price < 100000 && qty > 0 && qty < 100) {
              items.add(item);
            }
          }
        } catch (e) {}
      }

      detailsContent = items.isEmpty ? '[]' : '[${items.join(',')}]';
      cleaned = '$beforeDetails$detailsContent';
    }

    return cleaned.endsWith('}') ? cleaned : '$cleaned}';
  }

  Future<void> _fetchBillData() async {
    setState(() {
      isLoading = true;
      errorMessage = null;
    });

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
          timeout: 30, // Increased timeout to handle potential Socket closed errors
        );
      }

      final jsonQuery = "SELECT JSON FROM dine_in_orderjson WHERE Tab_Unique_Id = '${widget.tabUniqueId}'";
      final jsonResult = await SqlConn.readData(jsonQuery);

      final fixedJsonResult = _escapeJsonValue(jsonResult);
      final outerJson = jsonDecode(fixedJsonResult) as List<dynamic>;

      if (outerJson.isEmpty) {
        setState(() {
          isLoading = false;
          errorMessage = 'No order found for Tab Unique ID: ${widget.tabUniqueId}';
        });
        return;
      }

      final rawJsonString = outerJson.first['JSON']?.toString();
      if (rawJsonString == null || rawJsonString.isEmpty) {
        await _fetchFromTables();
        return;
      }

      String cleanJson = _fixJsonFormat(rawJsonString);
      cleanJson = _sanitizeJson(cleanJson).trim();

      final jsonData = jsonDecode(cleanJson) as Map<String, dynamic>;

      final List<Map<String, dynamic>> items = [];
      if (jsonData['OrderDetails'] is List) {
        for (var item in jsonData['OrderDetails']) {
          if (item['Qty'] != null &&
              item['Item Name'] != null &&
              item['Price'] != null) {
            final price = _safeNum(item, 'Price');
            final qty = _safeNum(item, 'Qty');
            if (price > 0 && qty > 0) {
              items.add({
                'ItemName': _safeString(item, 'Item Name'),
                'Qty': qty,
                'Price': price,
                'Comments': '',
                'orderDetailId': '',
                'tax': _safeNum(item, 'Tax'),
                'kotstatus': '0',
              });
            }
          }
        }
      }

      final itemsSubTotal = items.fold<double>(
        0.0,
        (sum, item) => sum + (_safeNum(item, 'Qty') * _safeNum(item, 'Price')),
      );
      // Use NetBillCard for credit bill total, fallback to Total if not available
      final jsonTotal = _safeNum(jsonData, 'NetBillCard') > 0
          ? _safeNum(jsonData, 'NetBillCard')
          : _safeNum(jsonData, 'Total');

      if (items.isNotEmpty || jsonTotal > 0) {
        setState(() {
          orderDetails = {
            'OrderNo': _safeString(jsonData, 'order_no') ?? _safeString(jsonData, 'Invoice#'),
            'TableNo': _safeString(jsonData, 'Table'),
            'Covers': _safeString(jsonData, 'Cover'),
            'waiter_name': _safeString(jsonData, 'Server'),
            'OrderType': 'Dine In',
            'OrderTime': '${_safeString(jsonData, 'OrderTime')} ${_safeString(jsonData, 'OrderDate')}',
            'TotalAmount': jsonTotal,
            'SubTotal': itemsSubTotal,
            'CardTax': _safeNum(jsonData, 'CardTax'), // Added for credit bill
            'SCharges': _safeNum(jsonData, 'SCharges'),
            'Discount': _safeNum(jsonData, 'Discount'),
          };
          orderItems = items;
          isLoading = false;
          errorMessage = null;
        });
      } else {
        await _fetchFromTables();
      }
    } catch (e) {
      setState(() {
        isLoading = false;
        errorMessage = 'Error fetching data: $e';
      });
      await _fetchFromTables();
    } finally {
      if (await SqlConn.isConnected) {
        await SqlConn.disconnect();
      }
    }
  }

  Future<void> _fetchFromTables() async {
    setState(() {
      isLoading = false;
      errorMessage = 'Data not available.';
    });
  }

  void _printBill() {
    if (orderDetails == null || orderItems.isEmpty) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('No bill data to print'),
            backgroundColor: Colors.red,
          ),
        );
      }
      return;
    }

    final buffer = StringBuffer();
    buffer.writeln('┌──────────────────────────────┐');
    buffer.writeln('│      Dilpasand Sweet         │');
    buffer.writeln('│        Credit Bill           │');
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
      buffer.writeln('$itemName ${qty.toStringAsFixed(0).padLeft(4)} ${numberFormatter.format(price).padLeft(7)} ${numberFormatter.format(total).padLeft(7)}');
      if (_safeString(item, 'Comments').isNotEmpty) {
        buffer.writeln('  └─ ${_safeString(item, 'Comments')}');
      }
    }

    buffer.writeln('─' * 30);
    final subTotal = _safeNum(orderDetails, 'SubTotal');
    final cardTax = _safeNum(orderDetails, 'CardTax');
    final sCharges = _safeNum(orderDetails, 'SCharges');
    final discount = _safeNum(orderDetails, 'Discount');
    final grandTotal = _safeNum(orderDetails, 'TotalAmount');

    buffer.writeln('Sub Total: ${numberFormatter.format(subTotal)}'.padLeft(30));
    if (cardTax > 0) {
      buffer.writeln('Card Tax: ${numberFormatter.format(cardTax)}'.padLeft(30));
    }
    if (sCharges > 0) {
      buffer.writeln('Service Charges: ${numberFormatter.format(sCharges)}'.padLeft(30));
    }
    if (discount > 0) {
      buffer.writeln('Discount: -${numberFormatter.format(discount)}'.padLeft(30));
    }
    buffer.writeln('Grand Total: ${numberFormatter.format(grandTotal)}'.padLeft(30));
    buffer.writeln('┌──────────────────────────────┐');
    buffer.writeln('│   Thank You for Your Visit!   │');
    buffer.writeln('└──────────────────────────────┘');

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Bill sent to printer'),
          backgroundColor: Colors.green,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    if (isLoading) {
      return _buildLoadingScreen();
    }

    if (errorMessage != null) {
      return _buildErrorScreen();
    }

    if (orderDetails == null) {
      return _buildOrderNotFoundScreen();
    }

    return _buildBillScreen();
  }

  Widget _buildLoadingScreen() {
    return Scaffold(
      backgroundColor: kTertiaryColor,
      appBar: AppBar(
        title: const Text('Loading...', style: TextStyle(fontFamily: 'Raleway')),
        backgroundColor: kTertiaryColor,
        foregroundColor: kPrimaryColor,
        elevation: 1,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: const Center(child: CircularProgressIndicator(color: kPrimaryColor)),
    );
  }

  Widget _buildErrorScreen() {
    return Scaffold(
      backgroundColor: kTertiaryColor,
      appBar: AppBar(
        title: const Text('Credit Bill', style: TextStyle(fontFamily: 'Raleway')),
        backgroundColor: kTertiaryColor,
        foregroundColor: kPrimaryColor,
        elevation: 1,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: _navigateToRunningOrders,
        ),
      ),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(20.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.error_outline, size: 80, color: Colors.red[300]),
              const SizedBox(height: 16),
              Text(
                errorMessage!,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: Colors.red,
                  fontSize: 16,
                  fontFamily: 'Raleway',
                ),
              ),
              const SizedBox(height: 24),
              ElevatedButton.icon(
                onPressed: _navigateToRunningOrders,
                icon: const Icon(Icons.arrow_back),
                label: const Text('Go Back'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: kPrimaryColor,
                  foregroundColor: kTertiaryColor,
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                  textStyle: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    fontFamily: 'Raleway',
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildOrderNotFoundScreen() {
    return Scaffold(
      backgroundColor: kTertiaryColor,
      appBar: AppBar(
        title: const Text('Order Not Found', style: TextStyle(fontFamily: 'Raleway')),
        backgroundColor: kTertiaryColor,
        foregroundColor: kPrimaryColor,
        elevation: 1,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: _navigateToRunningOrders,
        ),
      ),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(20.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.search_off, size: 80, color: Colors.orange[300]),
              const SizedBox(height: 16),
              Text(
                'Order not found for Tab Unique ID: ${widget.tabUniqueId}',
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 16,
                  fontFamily: 'Raleway',
                  color: Colors.white,
                ),
              ),
              const SizedBox(height: 24),
              ElevatedButton.icon(
                onPressed: _navigateToRunningOrders,
                icon: const Icon(Icons.arrow_back),
                label: const Text('Go Back'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: kPrimaryColor,
                  foregroundColor: kTertiaryColor,
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                  textStyle: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    fontFamily: 'Raleway',
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildBillScreen() {
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
        title: const Text(
          'Credit Bill',
          style: TextStyle(fontFamily: 'Raleway', fontWeight: FontWeight.w600),
        ),
        backgroundColor: kTertiaryColor,
        foregroundColor: kPrimaryColor,
        elevation: 1,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new, color: Colors.white),
          onPressed: () => Navigator.pop(context),
          tooltip: 'Back',
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.print, color: Colors.white),
            onPressed: _printBill,
            tooltip: 'Quick Print',
          ),
        ],
      ),
      body: SafeArea(
        child: Container(
          width: double.infinity,
          height: double.infinity,
          padding: const EdgeInsets.all(12),
          child: Column(
            children: [
              Expanded(
                child: Container(
                  width: double.infinity,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.1),
                        blurRadius: 6,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: ListView(
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
                        const SizedBox(height: 80),
                      ],
                    ),
                  ),
                ),
              ),
              Container(
                width: double.infinity,
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: const BorderRadius.vertical(top: Radius.circular(12)),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.15),
                      blurRadius: 6,
                      offset: const Offset(0, -2),
                    ),
                  ],
                ),
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    _buildTaxAndTotalSection(),
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        Expanded(
                          child: ElevatedButton.icon(
                            onPressed: _printBill,
                            icon: const Icon(Icons.print),
                            label: const Text('Print Bill'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: kPrimaryColor,
                              foregroundColor: kTertiaryColor,
                              padding: const EdgeInsets.symmetric(vertical: 14),
                              textStyle: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                                fontFamily: 'Raleway',
                              ),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(8),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: ElevatedButton.icon(
                            onPressed: () => _confirmPayment(grandTotal),
                            icon: const Icon(Icons.payment),
                            label: Text(
                              'Pay ${numberFormatter.format(grandTotal)}',
                              overflow: TextOverflow.ellipsis,
                              maxLines: 1,
                            ),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: kPrimaryColor,
                              foregroundColor: kTertiaryColor,
                              padding: const EdgeInsets.symmetric(vertical: 14),
                              textStyle: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                                fontFamily: 'Raleway',
                              ),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(8),
                              ),
                            ),
                          ),
                        ),
                      ],
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

  void _navigateToRunningOrders() {
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (context) => const RunningOrdersPage()),
    );
  }

  void _confirmPayment(double amount) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: const Text('Credit Payment Confirmed! Bill Closed.'),
        backgroundColor: Colors.green,
      ),
    );
    Navigator.pop(context, true);
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
          'Credit Bill',
          style: TextStyle(
            fontSize: 16,
            color: Colors.grey[600],
            fontFamily: 'Raleway',
          ),
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
    final subTotal = _safeNum(orderDetails, 'SubTotal');
    final cardTax = _safeNum(orderDetails, 'CardTax');
    final sCharges = _safeNum(orderDetails, 'SCharges');
    final discount = _safeNum(orderDetails, 'Discount');
    final grandTotal = _safeNum(orderDetails, 'TotalAmount');

    return Column(
      children: [
        _buildTotalRow('Sub Total', subTotal),
        if (cardTax > 0) _buildTotalRow('Card Tax', cardTax),
        if (sCharges > 0) _buildTotalRow('Service Charges', sCharges),
        if (discount > 0) _buildTotalRow('Discount', -discount),
        const Divider(height: 20, thickness: 1, color: Colors.grey),
        _buildTotalRow('Grand Total', grandTotal, isBold: true),
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
            numberFormatter.format(amount),
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
            Expanded(
              flex: 3,
              child: Text(
                'Item',
                style: TextStyle(fontWeight: FontWeight.bold, fontFamily: 'Raleway'),
              ),
            ),
            Expanded(
              flex: 1,
              child: Text(
                'Qty',
                style: TextStyle(fontWeight: FontWeight.bold, fontFamily: 'Raleway'),
                textAlign: TextAlign.right,
              ),
            ),
            Expanded(
              flex: 2,
              child: Text(
                'Price',
                style: TextStyle(fontWeight: FontWeight.bold, fontFamily: 'Raleway'),
                textAlign: TextAlign.right,
              ),
            ),
            Expanded(
              flex: 2,
              child: Text(
                'Total',
                style: TextStyle(fontWeight: FontWeight.bold, fontFamily: 'Raleway'),
                textAlign: TextAlign.right,
              ),
            ),
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
                      maxLines: 1,
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
                      numberFormatter.format(price),
                      style: const TextStyle(fontFamily: 'Raleway', fontSize: 14),
                      textAlign: TextAlign.right,
                    ),
                  ),
                  Expanded(
                    flex: 2,
                    child: Text(
                      numberFormatter.format(total),
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontFamily: 'Raleway',
                        fontSize: 14,
                      ),
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
                    overflow: TextOverflow.ellipsis,
                    maxLines: 2,
                  ),
                ),
              if (index < orderItems.length - 1)
                const Divider(height: 10, thickness: 0.5, color: Colors.grey),
            ],
          );
        }),
      ],
    );
  }
}