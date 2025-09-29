import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:start_app/database_halper.dart';

class BillScreen extends StatefulWidget {
  @override
  _BillScreenState createState() => _BillScreenState();
}

class _BillScreenState extends State<BillScreen> {
  List<Map<String, dynamic>> _bills = [];
  List<Map<String, dynamic>> _filteredBills = [];
  bool _isLoading = true;
  // ignore: unused_field
  String _searchText = '';

  @override
  void initState() {
    super.initState();
    _fetchBills();
  }

  Future<void> _fetchBills() async {
    setState(() => _isLoading = true);

    try {
      String query = """
      SELECT id, waiter_name, table_no, cover, amount, order_date, Customer
      FROM Order_Detail
      ORDER BY order_date DESC
    """;

      var result = await DatabaseHelper.instance.getData(query);

      List<Map<String, dynamic>> billsList = [];

      if (result is List) {
        billsList = List<Map<String, dynamic>>.from(result);
      } else if (result is String) {
        final decoded = jsonDecode(result);
        if (decoded is List) {
          billsList = List<Map<String, dynamic>>.from(decoded);
        }
      }

      setState(() {
        _bills = billsList;
        _filteredBills = billsList;
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Error fetching bills: $e')));
    }
  }

  void _filterBills(String text) {
    setState(() {
      _searchText = text;
      _filteredBills = _bills
          .where(
            (bill) =>
                bill['Customer'].toString().toLowerCase().contains(
                  text.toLowerCase(),
                ) ||
                bill['table_no'].toString().contains(text) ||
                bill['waiter_name'].toString().toLowerCase().contains(
                  text.toLowerCase(),
                ),
          )
          .toList();
    });
  }

Future<List<Map<String, dynamic>>> _fetchBillItems(int orderKey) async {
  try {
    String query = """
      SELECT item_name, qty, price, category_name
      FROM order_detail
      WHERE order_key = $orderKey
    """;

    var result = await DatabaseHelper.instance.getData(query);

    if (result is List) {
      return List<Map<String, dynamic>>.from(result);
    } else if (result is String) {
      final decoded = jsonDecode(result);
      if (decoded is List) {
        return List<Map<String, dynamic>>.from(decoded);
      }
    }
  } catch (e) {
    print('Error fetching bill items: $e');
  }
  return [];
}


void _showBillDetails(Map<String, dynamic> bill) async {
  final items = await _fetchBillItems(bill['order_id']); // 👈 yahan order_id ka relation hoga

  double totalAmount = 0;
  for (var item in items) {
    final qty = (item['qty'] ?? 0).toInt();
    final price = (item['price'] ?? 0).toDouble();
    totalAmount += qty * price;
  }

  showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    builder: (_) {
      return Padding(
        padding: EdgeInsets.all(12),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'Bill Details - Table ${bill['table_no']}',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            SizedBox(height: 8),
            Container(
              height: 300,
              child: ListView.builder(
                itemCount: items.length,
                itemBuilder: (context, index) {
                  final item = items[index];
                  return ListTile(
                    title: Text(item['item_name']),
                    subtitle: Text(
                      'Qty: ${item['qty']} | Price: ₹${item['price']} | Category: ${item['category_name']}',
                    ),
                    trailing: Text(
                      '₹ ${(item['qty'] * item['price']).toStringAsFixed(2)}',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                  );
                },
              ),
            ),
            SizedBox(height: 12),
            Text(
              'Total: ₹${totalAmount.toStringAsFixed(2)}',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            SizedBox(height: 12),
            ElevatedButton(
              onPressed: () => Navigator.pop(context),
              child: Text('Close'),
            )
          ],
        ),
      );
    },
  );
}


  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('All Bills')),
      body: _isLoading
          ? Center(child: CircularProgressIndicator())
          : Column(
              children: [
                Padding(
                  padding: EdgeInsets.all(8),
                  child: TextField(
                    decoration: InputDecoration(
                      hintText: 'Search by customer, table, or waiter',
                      border: OutlineInputBorder(),
                      prefixIcon: Icon(Icons.search),
                    ),
                    onChanged: _filterBills,
                  ),
                ),
                Expanded(
                  child: _filteredBills.isEmpty
                      ? Center(child: Text('No bills found.'))
                      : ListView.builder(
                          itemCount: _filteredBills.length,
                          itemBuilder: (context, index) {
                            final bill = _filteredBills[index];
                            return Card(
                              margin: EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 6,
                              ),
                              child: ListTile(
                                title: Text(
                                  'Table: ${bill['table_no']} | Waiter: ${bill['waiter_name']}',
                                ),
                                subtitle: Text(
                                  'Customer: ${bill['Customer']} \nDate: ${bill['order_date']}',
                                ),
                                trailing: Text(
                                  '₹ ${bill['amount']}',
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 16,
                                  ),
                                ),
                                onTap: () => _showBillDetails(bill),
                              ),
                            );
                          },
                        ),
                ),
              ],
            ),
    );
  }
}
