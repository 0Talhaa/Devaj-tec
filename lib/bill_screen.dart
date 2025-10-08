import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:sql_conn/sql_conn.dart';
import 'package:start_app/database_halper.dart';

class BillScreen extends StatefulWidget {
  @override
  _BillScreenState createState() => _BillScreenState();
}

class _BillScreenState extends State<BillScreen> {
  List<Map<String, dynamic>> _bills = [];
  List<Map<String, dynamic>> _filteredBills = [];
  bool _isLoading = true;
  String _searchText = '';

  @override
  void initState() {
    super.initState();
    _fetchBills();
  }

  /// 🔹 Connect to SQL Server and fetch all bills
  Future<void> _fetchBills() async {
    setState(() => _isLoading = true);

    try {
      final conn = await DatabaseHelper.instance.getConnectionDetails();
      if (conn == null) throw Exception("Connection details not found!");

      if (!await SqlConn.isConnected) {
        await SqlConn.connect(
          ip: conn['ip'],
          port: conn['port'],
          databaseName: conn['dbName'],
          username: conn['username'],
          password: conn['password'],
        );
      }

      String query = """
        SELECT 
          o.order_key AS order_id,
          o.waiter AS waiter_name,
          o.table_no,
          o.cover,
          o.total_amount AS amount,
          o.order_date,
          o.customer
        FROM Dine_In_Order o
        ORDER BY o.order_date DESC
      """;

      var result = await SqlConn.readData(query);

      List<Map<String, dynamic>> billsList = [];
      if (result.isNotEmpty) {
        billsList = List<Map<String, dynamic>>.from(jsonDecode(result));
      }

      setState(() {
        _bills = billsList;
        _filteredBills = billsList;
        _isLoading = false;
      });

      debugPrint("📦 Loaded ${_bills.length} bills");
    } catch (e) {
      setState(() => _isLoading = false);
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('Error fetching bills: $e')));
      debugPrint("❌ Error fetching bills: $e");
    }
  }

  /// 🔹 Filter bills by user input
  void _filterBills(String text) {
    setState(() {
      _searchText = text;
      _filteredBills = _bills.where((bill) {
        final search = text.toLowerCase();
        return bill['customer'].toString().toLowerCase().contains(search) ||
            bill['table_no'].toString().contains(search) ||
            bill['waiter_name'].toString().toLowerCase().contains(search);
      }).toList();
    });
  }

  /// 🔹 Fetch items for a selected order
  Future<List<Map<String, dynamic>>> _fetchBillItems(int orderKey) async {
    try {
      final conn = await DatabaseHelper.instance.getConnectionDetails();
      if (conn == null) throw Exception("Connection details not found!");

      if (!await SqlConn.isConnected) {
        await SqlConn.connect(
          ip: conn['ip'],
          port: conn['port'],
          databaseName: conn['dbName'],
          username: conn['username'],
          password: conn['password'],
        );
      }

      String query = """
        SELECT 
          d.item_name, 
          d.qty, 
          i.sale_price AS price, 
          i.category_name
        FROM order_detail d
        INNER JOIN itempos i ON i.id = d.itemid
        WHERE d.order_key = $orderKey
      """;

      var result = await SqlConn.readData(query);

      if (result.isNotEmpty) {
        return List<Map<String, dynamic>>.from(jsonDecode(result));
      }
    } catch (e) {
      debugPrint('❌ Error fetching bill items: $e');
    }
    return [];
  }

  /// 🔹 Show bottom sheet with detailed bill items
  void _showBillDetails(Map<String, dynamic> bill) async {
    final items = await _fetchBillItems(bill['order_id']);

    double totalAmount = 0;
    for (var item in items) {
      final qty = double.tryParse(item['qty'].toString()) ?? 0;
      final price = double.tryParse(item['price'].toString()) ?? 0;
      totalAmount += qty * price;
    }

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: const Color(0xFF182022),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (_) {
        return Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'Bill Details - Table ${bill['table_no']}',
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF75E5E2),
                ),
              ),
              const SizedBox(height: 12),
              Container(
                height: 300,
                child: items.isEmpty
                    ? const Center(
                        child: Text(
                          'No items found for this order.',
                          style: TextStyle(color: Colors.white),
                        ),
                      )
                    : ListView.builder(
                        itemCount: items.length,
                        itemBuilder: (context, index) {
                          final item = items[index];
                          final qty =
                              double.tryParse(item['qty'].toString()) ?? 0;
                          final price =
                              double.tryParse(item['price'].toString()) ?? 0;
                          final total = qty * price;

                          return ListTile(
                            title: Text(
                              item['item_name'] ?? 'Unknown',
                              style: const TextStyle(color: Colors.white),
                            ),
                            subtitle: Text(
                              'Qty: $qty × ₹${price.toStringAsFixed(2)}',
                              style: const TextStyle(color: Colors.white70),
                            ),
                            trailing: Text(
                              '₹${total.toStringAsFixed(2)}',
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                color: Color(0xFF75E5E2),
                              ),
                            ),
                          );
                        },
                      ),
              ),
              const Divider(color: Colors.white24),
              Text(
                'Total: ₹${totalAmount.toStringAsFixed(2)}',
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
              const SizedBox(height: 12),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF75E5E2),
                  foregroundColor: const Color(0xFF0D1D20),
                ),
                onPressed: () => Navigator.pop(context),
                child: const Text('Close'),
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
      backgroundColor: const Color(0xFF0D1D20),
      appBar: AppBar(
        backgroundColor: const Color(0xFF0D1D20),
        title: const Text('All Bills'),
        foregroundColor: Colors.white,
      ),
      body: _isLoading
          ? const Center(
              child: CircularProgressIndicator(
                valueColor: AlwaysStoppedAnimation(Color(0xFF75E5E2)),
              ),
            )
          : Column(
              children: [
                Padding(
                  padding: const EdgeInsets.all(8),
                  child: TextField(
                    decoration: InputDecoration(
                      hintText: 'Search by customer, table, or waiter',
                      hintStyle: const TextStyle(color: Colors.white54),
                      filled: true,
                      fillColor: Colors.grey.shade900,
                      prefixIcon: const Icon(Icons.search, color: Colors.white),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide.none,
                      ),
                    ),
                    style: const TextStyle(color: Colors.white),
                    onChanged: _filterBills,
                  ),
                ),
                Expanded(
                  child: _filteredBills.isEmpty
                      ? const Center(
                          child: Text(
                            'No bills found.',
                            style: TextStyle(color: Colors.white70),
                          ),
                        )
                      : ListView.builder(
                          itemCount: _filteredBills.length,
                          itemBuilder: (context, index) {
                            final bill = _filteredBills[index];
                            return Card(
                              color: Colors.grey.shade900,
                              margin: const EdgeInsets.symmetric(
                                  horizontal: 12, vertical: 6),
                              child: ListTile(
                                title: Text(
                                  'Table: ${bill['table_no']} | Waiter: ${bill['waiter_name']}',
                                  style: const TextStyle(color: Colors.white),
                                ),
                                subtitle: Text(
                                  'Customer: ${bill['customer']}\nDate: ${bill['order_date']}',
                                  style:
                                      const TextStyle(color: Colors.white70),
                                ),
                                trailing: Text(
                                  '₹ ${bill['amount']}',
                                  style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                    color: Color(0xFF75E5E2),
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
