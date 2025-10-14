import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:sql_conn/sql_conn.dart';
import 'package:start_app/database_halper.dart';
import 'package:start_app/main.dart'; // For color constants
import 'package:start_app/tables_page.dart';

class DiningPage extends StatefulWidget {
  const DiningPage({super.key});

  @override
  State<DiningPage> createState() => _DiningPageState();
}

class _DiningPageState extends State<DiningPage> {
  bool _isLoading = true;
  List<Map<String, dynamic>> _waiters = [];
  Map<String, dynamic>? _connectionDetails;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  // Load connection details and fetch waiters
  Future<void> _loadData() async {
    final details = await DatabaseHelper.instance.getConnectionDetails();
    if (details != null) {
      setState(() {
        _connectionDetails = details;
      });
      await _fetchWaiters();
    } else {
      setState(() {
        _isLoading = false;
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('No database connection details found.'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  // Fetch waiters from SQL Server
  Future<void> _fetchWaiters() async {
    if (_connectionDetails == null) return;

    setState(() {
      _isLoading = true;
    });

    try {
      await SqlConn.connect(
        ip: _connectionDetails!['ip'] as String,
        port: _connectionDetails!['port'] as String,
        databaseName: _connectionDetails!['dbName'] as String,
        username: _connectionDetails!['username'] as String,
        password: _connectionDetails!['password'] as String,
        timeout: 10, // Added timeout
      );

      const query = 'SELECT waiter_name FROM Waiter';
      final result = await SqlConn.readData(query);
      final parsedResult = jsonDecode(result) as List<dynamic>;
      final waiters = parsedResult.map((row) {
        return {
          'waiter_name': row['waiter_name'] as String,
          'is_update': row['is_update'] as int? ?? 0 , // Handle null
        };
      }).toList();

      setState(() {
        _waiters = waiters;
      });
      print('🟢 Fetched ${waiters.length} waiters: $waiters');

      await SqlConn.disconnect();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to load waiters: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
      print('❌ Error fetching waiters: $e');
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  // Show dialog for non-updated waiters
  void _showUnupdatedWaiterDialog() {
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          backgroundColor: kTertiaryColor,
          title: const Text(
            'Cannot Proceed',
            style: TextStyle(
              color: kPrimaryColor,
              fontFamily: 'Raleway',
              fontWeight: FontWeight.bold,
            ),
          ),
          content: const Text(
            'This waiter has not been updated. Please select an updated waiter to proceed.',
            style: TextStyle(color: Colors.white, fontFamily: 'Raleway'),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text(
                'OK',
                style: TextStyle(
                  color: kPrimaryColor,
                  fontFamily: 'Raleway',
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final crossAxisCount = screenWidth < 600 ? 3 : (screenWidth < 900 ? 4 : 5);
    final childAspectRatio =
        screenWidth < 600 ? 0.8 : (screenWidth < 900 ? 0.9 : 1.0);

    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Select Waiter',
          style: TextStyle(fontFamily: 'Raleway'),
        ),
        centerTitle: true,
        backgroundColor: kTertiaryColor,
        foregroundColor: kPrimaryColor,
      ),
      body: Container(
        color: kTertiaryColor,
        child: _isLoading
            ? Center(
                child: CircularProgressIndicator(
                  valueColor: AlwaysStoppedAnimation<Color>(kPrimaryColor),
                ),
              )
            : _waiters.isEmpty
                ? Center(
                    child: Text(
                      'Koi Waiter Nahi Mila.',
                      style: TextStyle(
                        fontSize: 20,
                        color: kPrimaryColor,
                        fontFamily: 'Raleway',
                      ),
                      textAlign: TextAlign.center,
                      semanticsLabel: 'No waiters found',
                    ),
                  )
                : Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: GridView.builder(
                      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: crossAxisCount,
                        crossAxisSpacing: 16.0,
                        mainAxisSpacing: 16.0,
                        childAspectRatio: childAspectRatio,
                      ),
                      itemCount: _waiters.length,
                      itemBuilder: (context, index) {
                        final waiter = _waiters[index];
                        final isUpdated = waiter['is_update'] == 0; // Simplified logic

                        return InkWell(
                          onTap: () {
                            if (isUpdated) {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (context) => TablesPage(
                                    waiterName: waiter['waiter_name'],
                                  ),
                                ),
                              );
                            } else {
                              _showUnupdatedWaiterDialog();
                            }
                          },
                          child: Container(
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(16),
                              gradient: isUpdated
                                  ? const LinearGradient(
                                      colors: [kPrimaryColor, kSecondaryColor],
                                      begin: Alignment.topLeft,
                                      end: Alignment.bottomRight,
                                    )
                                  : const LinearGradient(
                                      colors: [Color(0xFF1F2F32), kTertiaryColor],
                                      begin: Alignment.topLeft,
                                      end: Alignment.bottomRight,
                                    ),
                              boxShadow: isUpdated
                                  ? [
                                      BoxShadow(
                                        color: kPrimaryColor.withOpacity(0.4),
                                        spreadRadius: 2,
                                        blurRadius: 10,
                                        offset: const Offset(0, 4),
                                      ),
                                    ]
                                  : [],
                            ),
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(
                                  Icons.person_rounded,
                                  color: isUpdated ? kTertiaryColor : Colors.white,
                                  size: 32,
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  waiter['waiter_name'],
                                  style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                    color: isUpdated ? kTertiaryColor : Colors.white,
                                    fontFamily: 'Raleway',
                                  ),
                                  textAlign: TextAlign.center,
                                  semanticsLabel: waiter['waiter_name'],
                                ),
                                if (isUpdated)
                                  Padding(
                                    padding: const EdgeInsets.only(top: 4.0),
                                    child: Text(
                                      'Updated',
                                      style: TextStyle(
                                        fontSize: 12,
                                        color: kTertiaryColor.withOpacity(0.8),
                                        fontFamily: 'Raleway',
                                      ),
                                    ),
                                  ),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
                  ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _fetchWaiters,
        backgroundColor: kPrimaryColor,
        foregroundColor: kTertiaryColor,
        child: const Icon(Icons.refresh),
        tooltip: 'Refresh Waiters',
      ),
    );
  }
}