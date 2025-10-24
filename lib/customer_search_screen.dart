// lib/customer_search_screen.dart

import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:sql_conn/sql_conn.dart';
import 'package:start_app/database_halper.dart';

// NOTE: The Customer model is defined here for self-containment.
// If your models are in a separate file, please adjust the import.
class Customer {
  final String id;
  final String customerName;
  final String address;
  final String address2;
  final String cellNo;
  final String telNo;
  final bool active;

  Customer({
    required this.id,
    required this.customerName,
    required this.address,
    required this.address2,
    required this.cellNo,
    required this.telNo,
    required this.active,
  });

  factory Customer.fromMap(Map<String, dynamic> map) {
    return Customer(
      id: map['id']?.toString() ?? '0',
      customerName: map['customer_name']?.toString() ?? '',
      address: map['address']?.toString() ?? '',
      address2: map['address2']?.toString() ?? '',
      cellNo: map['cell_no']?.toString() ?? '',
      telNo: map['tel_no']?.toString() ?? '',
      active: map['active'] == 1,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'customer_name': customerName,
      'address': address,
      'address2': address2,
      'cell_no': cellNo,
      'tel_no': telNo,
      'active': active ? 1 : 0,
    };
  }
}


class CustomerSearchScreen extends StatefulWidget {
  const CustomerSearchScreen({super.key});

  @override
  State<CustomerSearchScreen> createState() => _CustomerSearchScreenState();
}

class _CustomerSearchScreenState extends State<CustomerSearchScreen> {
  final TextEditingController _searchController = TextEditingController();
  List<Customer> _searchResults = [];
  bool _isLoading = false;
  String _searchQuery = '';

  String _sanitize(String input) {
    return input.replaceAll(RegExp(r'[\%_\\]'), '');
  }

  // Helper function to ensure SQL connection is ready
  Future<bool> _ensureSqlConnection() async {
    if (await SqlConn.isConnected) return true;
    final conn = await DatabaseHelper.instance.getConnectionDetails();
    if (conn == null) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Connection details missing'),
            backgroundColor: Colors.red,
          ),
        );
      }
      return false;
    }
    try {
      await SqlConn.connect(
        ip: conn['ip'],
        port: conn['port'],
        databaseName: conn['dbName'],
        username: conn['username'],
        password: conn['password'],
      );
      return true;
    } catch (e) {
      debugPrint("❌ Error connecting to SQL: $e");
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to connect to SQL Server: $e'), backgroundColor: Colors.red),
        );
      }
      return false;
    }
  }

  Future<void> _searchCustomer(String searchTerm) async {
    if (searchTerm.isEmpty) {
      setState(() {
        _searchResults = [];
      });
      return;
    }

    if (!mounted) return;

    setState(() {
      _isLoading = true;
    });

    try {
      if (!await _ensureSqlConnection()) return;

      final sanitizedSearchTerm = _sanitize(searchTerm);
      final query = """
        SELECT
          id,
          customer_name,
          address,
          address2,
          CAST(cell_no AS NVARCHAR(50)) AS cell_no,
          CAST(tel_no AS NVARCHAR(50)) AS tel_no,
          active
        FROM CustomerPOS_
        WHERE active = 1
        AND (customer_name LIKE '%$sanitizedSearchTerm%'
             OR cell_no LIKE '%$sanitizedSearchTerm%'
             OR tel_no LIKE '%$sanitizedSearchTerm%')
      """;

      final result = await SqlConn.readData(query);

      // Sanitize the result to handle potential number-to-string conversion issues
      String sanitizedResult = result.replaceAllMapped(
        RegExp(r'("cell_no":\s*)(\d+)(,|\s*})'),
        (match) => '${match[1]}"${match[2]}"${match[3]}',
      ).replaceAllMapped(
        RegExp(r'("tel_no":\s*)(\d+)(,|\s*})'),
        (match) => '${match[1]}"${match[2]}"${match[3]}',
      );

      final decoded = jsonDecode(sanitizedResult);
      if (decoded is List && decoded.isNotEmpty) {
        setState(() {
          _searchResults = decoded.map((map) => Customer.fromMap(map)).toList();
        });
      } else {
        setState(() {
          _searchResults = [];
        });
        if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                    content: Text('No active customers found.'),
                    backgroundColor: Colors.orange,
                ),
            );
        }
      }
    } catch (e) {
      debugPrint("❌ Error searching customer: $e");
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error searching customer: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
      setState(() {
        _searchResults = [];
      });
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Theme(
      data: Theme.of(context).copyWith(
        scaffoldBackgroundColor: const Color(0xFF0D1D20),
        appBarTheme: const AppBarTheme(
          backgroundColor: Color(0xFF0D1D20),
          foregroundColor: Colors.white,
          elevation: 4,
          titleTextStyle: TextStyle(
            fontFamily: 'Raleway',
            fontSize: 20,
            fontWeight: FontWeight.bold,
          ),
        ),
        inputDecorationTheme: const InputDecorationTheme(
          filled: true,
          fillColor: Color(0xFF2C3E40),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.all(Radius.circular(10)),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.all(Radius.circular(10)),
            borderSide: BorderSide(color: Color(0xFF75E5E2)),
          ),
          hintStyle: TextStyle(
            color: Colors.white54,
            fontFamily: 'Raleway',
          ),
        ),
      ),
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Search & Select Customer'),
        ),
        body: Column(
          children: [
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: TextField(
                controller: _searchController,
                onChanged: (value) {
                  _searchQuery = value;
                  if (value.length > 2 || value.isEmpty) {
                    _searchCustomer(value);
                  }
                },
                style: const TextStyle(color: Colors.white, fontFamily: 'Raleway'),
                decoration: InputDecoration(
                  hintText: 'Search by Name, Cell, or Tel No...',
                  suffixIcon: _isLoading
                      ? const Padding(
                          padding: EdgeInsets.all(8.0),
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Color(0xFF75E5E2),
                          ),
                        )
                      : IconButton(
                          icon: const Icon(Icons.search, color: Color(0xFF75E5E2)),
                          onPressed: () => _searchCustomer(_searchQuery),
                        ),
                ),
              ),
            ),
            Expanded(
              child: _searchResults.isEmpty && !_isLoading
                  ? Center(
                      child: Text(
                        _searchController.text.isEmpty
                            ? 'Start typing to search for customers.'
                            : 'No customers found for "${_searchController.text}".',
                        style: const TextStyle(color: Colors.white70, fontFamily: 'Raleway'),
                        textAlign: TextAlign.center,
                      ),
                    )
                  : ListView.builder(
                      itemCount: _searchResults.length > 100 ? 100 : _searchResults.length, // Limit results
                      itemBuilder: (context, index) {
                        final customer = _searchResults[index];
                        return Card(
                          color: const Color(0xFF1C2526),
                          margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                          child: ListTile(
                            onTap: () {
                              // Return the selected customer to the previous screen
                              Navigator.pop(context, customer);
                            },
                            title: Text(
                              customer.customerName,
                              style: const TextStyle(
                                  color: Color(0xFF75E5E2),
                                  fontWeight: FontWeight.bold,
                                  fontFamily: 'Raleway'),
                            ),
                            subtitle: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Cell: ${customer.cellNo}',
                                  style: const TextStyle(
                                      color: Colors.white70, fontFamily: 'Raleway'),
                                ),
                                if (customer.telNo.isNotEmpty)
                                  Text(
                                    'Tel: ${customer.telNo}',
                                    style: const TextStyle(
                                        color: Colors.white70, fontFamily: 'Raleway'),
                                  ),
                                Text(
                                  'Address: ${customer.address}',
                                  style: const TextStyle(
                                      color: Colors.white, fontFamily: 'Raleway'),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ],
                            ),
                            trailing: const Icon(Icons.arrow_forward_ios,
                                color: Colors.white54, size: 16),
                          ),
                        );
                      },
                    ),
            ),
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: ElevatedButton.icon(
                onPressed: () {
                  // Simply pop to return to the details form
                  Navigator.pop(context);
                },
                icon: const Icon(Icons.keyboard_backspace),
                label: const Text('Go Back / Enter New Details'),
                style: ElevatedButton.styleFrom(
                  minimumSize: const Size(double.infinity, 50),
                  backgroundColor: const Color(0xFF75E5E2),
                  foregroundColor: const Color(0xFF0D1D20),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}