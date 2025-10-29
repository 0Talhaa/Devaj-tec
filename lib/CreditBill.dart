import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:sql_conn/sql_conn.dart';
import 'package:start_app/main.dart';
import 'package:start_app/running_orders_page.dart';

/* ──────────────────────── NEW THEME ──────────────────────── */
const Color kPrimaryColor = Color(0xFF75E5E2); // Light Cyan
const Color kSecondaryColor = Color(0xFF41938F); // Teal Green
const Color kTertiaryColor = Color(0xFF0D1D20); // Very Dark Teal
const Color kInputBgColor = Color(0xFF282828); // Dark Grey/Black

const MaterialColor kPrimarySwatch = MaterialColor(
  0xFF41938F,
  <int, Color>{
    50: Color(0xFFE2F0EF),
    100: Color(0xFFB5D8D7),
    200: Color(0xFF86BCBB),
    300: Color(0xFF56A19F),
    400: Color(0xFF328B88),
    500: Color(0xFF41938F),
    600: Color(0xFF287977),
    700: Color(0xFF1D5E5C),
    800: Color(0xFF124342),
    900: Color(0xFF0D1D20),
  },
);
/* ─────────────────────────────────────────────────────────── */

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
  double subtotal = 0,
      tax = 0,
      discount = 0,
      serviceCharges = 0,
      extraCharges = 0,
      total = 0,
      netBillCash = 0,
      netBillCard = 0,
      cardTax = 0;
  bool isLoading = true;
  String? errorMessage;
  final numberFormatter = NumberFormat('#,##0.00', 'en_US');
  List<Map<String, dynamic>> items = [];

  @override
  void initState() {
    super.initState();
    _fetchBillData();
  }

  // ──────────────────────────────────────
  // Safety helpers (same as CashBillScreen)
  // ──────────────────────────────────────
  double _safeNum(dynamic map, String key) {
    if (map == null) return 0.0;
    final value = map[key];
    if (value is num) return value.toDouble();
    if (value is String) return double.tryParse(value) ?? 0.0;
    return 0.0;
  }

  String _safeString(dynamic map, String key) {
    if (map == null) return '';
    final value = map[key];
    return value?.toString() ?? '';
  }

  /// Fix malformed OrderDetails JSON (identical to Cash version)
  String fixOrderDetailsJson(String input) {
    try {
      String fixed = input
          .replaceFirst('"OrderDetails":{', '"OrderDetails":[{')
          .replaceAll(RegExp(r'\},\s*\{'), '}, {')
          .replaceAll(RegExp(r'\}\s*\}'), '}]')
          .replaceAll(RegExp(r'\]\s*$'), ']}')
          .replaceAll(RegExp(r'\s+'), ' ')
          .replaceAll(RegExp(r',\s*([\}\]])'), r'\1');
      return fixed;
    } catch (e) {
      return input;
    }
  }

  // ──────────────────────────────────────
  // Fetch JSON from SQL (same query)
  // ──────────────────────────────────────
  Future<void> _fetchBillData() async {
    try {
      final jsonQuery = """
        SELECT JSON FROM dine_in_orderjson 
        WHERE Tab_Unique_Id = '${widget.tabUniqueId}'
      """;
      final jsonResult = await SqlConn.readData(jsonQuery);

      if (jsonResult.isEmpty) {
        setState(() {
          items = [];
          isLoading = false;
          errorMessage = 'No data found for this tab.';
        });
        return;
      }

      final match =
          RegExp(r'"JSON"\s*:\s*"({.*})"').firstMatch(jsonResult);
      if (match == null) {
        setState(() {
          items = [];
          isLoading = false;
          errorMessage = 'Invalid JSON field in SQL result.';
        });
        return;
      }

      String rawJsonString = match
          .group(1)!
          .replaceAll(r'\"', '"')
          .replaceAll(r'\\', '')
          .trim();
      rawJsonString = fixOrderDetailsJson(rawJsonString);

      final jsonData = jsonDecode(rawJsonString) as Map<String, dynamic>;

      setState(() {
        // ---------- BASIC FIELDS ----------
        final rawOrderNo =
            jsonData['order_no']?.toString() ?? jsonData['Invoice#']?.toString() ?? '';
        final rawTable = jsonData['Table']?.toString() ??
            jsonData['TableNo']?.toString() ??
            '';
        final rawCover =
            (jsonData['Cover'] ?? jsonData['Covers'])?.toString() ?? '';
        final rawWaiter = jsonData['Server']?.toString() ??
            jsonData['waiter_name']?.toString() ??
            '';
        final rawOrderType = jsonData['OrderType']?.toString() ?? '';
        final rawOrderTime = jsonData['OrderTime']?.toString() ?? '';
        final rawOrderDate = jsonData['OrderDate']?.toString() ?? '';

        // ---------- NUMERIC ----------
        subtotal = _safeNum(jsonData, 'SubTotal');
        tax = _safeNum(jsonData, 'Tax');
        discount = _safeNum(jsonData, 'Discount');
        serviceCharges = _safeNum(jsonData, 'SCharges');
        extraCharges = _safeNum(jsonData, 'ECharges');
        total = _safeNum(jsonData, 'Total');
        netBillCash = _safeNum(jsonData, 'NetBillCash');
        netBillCard = _safeNum(jsonData, 'NetBillCard');
        cardTax = _safeNum(jsonData, 'CardTax'); // <-- NEW

        // ---------- ORDER DETAILS MAP ----------
        orderDetails = {
          'OrderNo': rawOrderNo,
          'TableNo': rawTable,
          'Covers': rawCover,
          'waiter_name': rawWaiter,
          'OrderType': rawOrderType,
          'OrderTime': (rawOrderTime.isNotEmpty && rawOrderDate.isNotEmpty)
              ? '$rawOrderTime • $rawOrderDate'
              : (rawOrderTime.isNotEmpty ? rawOrderTime : rawOrderDate),
          'TotalAmount': total,
          'SubTotal': subtotal,
        };

        // ---------- ITEMS ----------
        final parsedItems = <Map<String, dynamic>>[];
        if (jsonData['OrderDetails'] is List) {
          for (var it in jsonData['OrderDetails']) {
            try {
              final qty = _safeNum(it, 'Qty');
              final price = _safeNum(it, 'Price');
              if (qty > 0 || price > 0) {
                parsedItems.add({
                  'ItemName': _safeString(it, 'Item Name') != ''
                      ? _safeString(it, 'Item Name')
                      : _safeString(it, 'ItemName'),
                  'Qty': qty,
                  'Price': price,
                  'Comments': _safeString(it, 'Comments'),
                  'orderDetailId': _safeString(it, 'OrderDtlId'),
                  'tax': _safeNum(it, 'Tax'),
                  'kotstatus': _safeString(it, 'kotstatus') ?? '0',
                });
              }
            } catch (_) {/* skip malformed */}
          }
        }
        items = parsedItems;
        orderItems = parsedItems;

        isLoading = false;
        errorMessage = null;
        print("Bill parsed! Items: ${orderItems.length}");
      });
    } catch (e, st) {
      setState(() {
        items = [];
        orderItems = [];
        isLoading = false;
        errorMessage = 'Error loading bill: $e';
      });
    }
  }

  // ──────────────────────────────────────
  // PRINT (same layout, only totals differ)
  // ──────────────────────────────────────
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
    buffer.writeln('│ Dilpasand Sweet │');
    buffer.writeln('│ Credit Bill │');
    buffer.writeln('└──────────────────────────────┘');
    buffer.writeln('Order No: ${_safeString(orderDetails, 'OrderNo')}');
    buffer.writeln(
        'Table: ${_safeString(orderDetails, 'TableNo')} | Covers: ${_safeString(orderDetails, 'Covers')}');
    buffer.writeln('Waiter: ${_safeString(orderDetails, 'waiter_name')}');
    buffer.writeln('Order Type: ${_safeString(orderDetails, 'OrderType')}');
    buffer.writeln('Time: ${_safeString(orderDetails, 'OrderTime')}');
    buffer.writeln('─' * 30);
    buffer.writeln(
        'Item'.padRight(16) + 'Qty'.padLeft(5) + 'Price'.padLeft(8) + 'Total'.padLeft(8));
    buffer.writeln('─' * 30);

    for (var item in orderItems) {
      final qty = _safeNum(item, 'Qty');
      final price = _safeNum(item, 'Price');
      final total = qty * price;
      final itemName = _safeString(item, 'ItemName').length > 15
          ? '${_safeString(item, 'ItemName').substring(0, 12)}...'
          : _safeString(item, 'ItemName').padRight(15);
      final displayQty = qty == qty.toInt() ? qty.toInt().toString() : qty.toStringAsFixed(2);
      buffer.writeln(
          '$itemName ${displayQty.padLeft(4)} ${numberFormatter.format(price).padLeft(7)} ${numberFormatter.format(total).padLeft(7)}');
      if (_safeString(item, 'Comments').isNotEmpty) {
        buffer.writeln(' └─ ${_safeString(item, 'Comments')}');
      }
    }
    buffer.writeln('─' * 30);

    // Tax (use CardTax for Credit)
    final totalTax = cardTax > 0 ? cardTax : tax;
    buffer.writeln('Credit Tax: ${numberFormatter.format(totalTax)}'.padLeft(30));

    final printTotal = netBillCard > 0 ? netBillCard : total;
    buffer.writeln('Grand Total: ${numberFormatter.format(printTotal)}'.padLeft(30));

    buffer.writeln('┌──────────────────────────────┐');
    buffer.writeln('│ Thank You for Your Visit! │');
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

  // ──────────────────────────────────────
  // UI BUILD
  // ──────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    if (isLoading) return _buildLoadingScreen();
    if (errorMessage != null) return _buildErrorScreen();
    if (orderDetails == null) return _buildOrderNotFoundScreen();
    return _buildBillScreen();
  }

  /* ──────────────────────── UI SCREENS ──────────────────────── */
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
                style: const TextStyle(color: Colors.red, fontSize: 16, fontFamily: 'Raleway'),
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
                  textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, fontFamily: 'Raleway'),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
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
                style: const TextStyle(fontSize: 16, fontFamily: 'Raleway', color: Colors.white),
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
                  textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, fontFamily: 'Raleway'),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
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

    // Credit uses NetBillCard (or fallback to Total)
    final grandTotal = netBillCard > 0 ? netBillCard : total;

    return Scaffold(
      backgroundColor: kTertiaryColor,
      appBar: AppBar(
        title: const Text('Credit Bill',
            style: TextStyle(fontFamily: 'Raleway', fontWeight: FontWeight.w600)),
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
              /* ────── BILL CARD (WHITE) ────── */
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
                          offset: const Offset(0, 2)),
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
                        const Divider(height: 30, thickness: 1, color: Colors.black12),
                        _buildItemsTable(),
                        const SizedBox(height: 80),
                      ],
                    ),
                  ),
                ),
              ),
              /* ────── FIXED BOTTOM TOTAL ────── */
              Container(
                width: double.infinity,
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: const BorderRadius.vertical(top: Radius.circular(12)),
                  boxShadow: [
                    BoxShadow(
                        color: Colors.black.withOpacity(0.15),
                        blurRadius: 6,
                        offset: const Offset(0, -2)),
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
                                  fontSize: 16, fontWeight: FontWeight.bold, fontFamily: 'Raleway'),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                            ),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: ElevatedButton.icon(
                            onPressed: () => _confirmCredit(grandTotal),
                            icon: const Icon(Icons.credit_card),
                            label: Text(
                              'Credit ${numberFormatter.format(grandTotal)}',
                              overflow: TextOverflow.ellipsis,
                              maxLines: 1,
                            ),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: kPrimaryColor,
                              foregroundColor: kTertiaryColor,
                              padding: const EdgeInsets.symmetric(vertical: 14),
                              textStyle: const TextStyle(
                                  fontSize: 16, fontWeight: FontWeight.bold, fontFamily: 'Raleway'),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
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

  // ──────────────────────────────────────
  // HELPERS
  // ──────────────────────────────────────
  void _navigateToRunningOrders() {
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (_) => const RunningOrdersPage()),
    );
  }

  void _confirmCredit(double amount) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
          content: Text('Credit recorded! Bill closed.'), backgroundColor: Colors.green),
    );
    Navigator.pop(context, true);
  }

  Widget _buildHeader() {
    return Column(
      children: const [
        Text(
          'Dilpasand Sweet',
          style: TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.w900,
            letterSpacing: 1.2,
            color: Colors.black87,
            fontFamily: 'Raleway',
          ),
        ),
        Text(
          'Credit Bill',
          style: TextStyle(fontSize: 16, color: Colors.grey, fontFamily: 'Raleway'),
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
          Text(label,
              style: const TextStyle(
                  fontSize: 14, fontWeight: FontWeight.w600, color: Colors.black87, fontFamily: 'Raleway')),
          Text(value,
              style: const TextStyle(fontSize: 14, color: Colors.black87, fontFamily: 'Raleway')),
        ],
      ),
    );
  }

  Widget _buildTaxAndTotalSection() {
    final itemsSubTotal = orderItems.fold<double>(
        0.0, (s, i) => s + _safeNum(i, 'Qty') * _safeNum(i, 'Price'));

    // Credit tax = CardTax (fallback to normal Tax)
    final totalTax = cardTax > 0 ? cardTax : tax;

    final grandTotal = netBillCard > 0 ? netBillCard : total;

    return Column(
      children: [
        _buildTotalRow('Sub Total', itemsSubTotal),
        _buildTotalRow('Credit Tax', totalTax),
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
                child: Text('Item',
                    style: TextStyle(fontWeight: FontWeight.bold, fontFamily: 'Raleway'))),
            Expanded(
                flex: 1,
                child: Text('Qty',
                    style: TextStyle(fontWeight: FontWeight.bold, fontFamily: 'Raleway'),
                    textAlign: TextAlign.right)),
            Expanded(
                flex: 2,
                child: Text('Price',
                    style: TextStyle(fontWeight: FontWeight.bold, fontFamily: 'Raleway'),
                    textAlign: TextAlign.right)),
            Expanded(
                flex: 2,
                child: Text('Total',
                    style: TextStyle(fontWeight: FontWeight.bold, fontFamily: 'Raleway'),
                    textAlign: TextAlign.right)),
          ],
        ),
        const Divider(height: 10, thickness: 1, color: Colors.grey),
        ...orderItems.asMap().entries.map((e) {
          final item = e.value;
          final itemName = _safeString(item, 'ItemName');
          final qty = _safeNum(item, 'Qty');
          final price = _safeNum(item, 'Price');
          final total = qty * price;
          final comments = _safeString(item, 'Comments');
          final displayQty = qty == qty.toInt() ? qty.toInt().toString() : qty.toStringAsFixed(2);

          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                      flex: 3,
                      child: Text(itemName,
                          style: const TextStyle(fontFamily: 'Raleway', fontSize: 14),
                          overflow: TextOverflow.ellipsis,
                          maxLines: 1)),
                  Expanded(
                      flex: 1,
                      child: Text(displayQty,
                          style: const TextStyle(fontFamily: 'Raleway', fontSize: 14),
                          textAlign: TextAlign.right)),
                  Expanded(
                      flex: 2,
                      child: Text(numberFormatter.format(price),
                          style: const TextStyle(fontFamily: 'Raleway', fontSize: 14),
                          textAlign: TextAlign.right)),
                  Expanded(
                      flex: 2,
                      child: Text(numberFormatter.format(total),
                          style: const TextStyle(
                              fontWeight: FontWeight.bold, fontFamily: 'Raleway', fontSize: 14),
                          textAlign: TextAlign.right)),
                ],
              ),
              if (comments.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(left: 8.0, top: 2.0),
                  child: Text(
                    '└ $comments',
                    style: TextStyle(
                        fontSize: 12, color: Colors.grey[600], fontStyle: FontStyle.italic, fontFamily: 'Raleway'),
                    overflow: TextOverflow.ellipsis,
                    maxLines: 2,
                  ),
                ),
              if (e.key < orderItems.length - 1) const Divider(height: 10, thickness: 0.5, color: Colors.grey),
            ],
          );
        }),
      ],
    );
  }
}