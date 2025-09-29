import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:sql_conn/sql_conn.dart';
import 'package:start_app/database_halper.dart';
import 'package:start_app/tables_page.dart';

// Yeh DiningPage ki class hai, jo waiters ki list dikhati hai.
class DiningPage extends StatefulWidget {
  const DiningPage({super.key});

  @override
  State<DiningPage> createState() => _DiningPageState();
}

class _DiningPageState extends State<DiningPage> {
  // Loading state ko track karne ke liye boolean variable
  bool _isLoading = true;
  // Waiters ki data store karne ke liye list
  List<Map<String, dynamic>> _waiters = [];
  // Database connection details store karne ke liye map
  Map<String, dynamic>? _connectionDetails;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  // Connection details load karne aur waiters fetch karne ka function
  Future<void> _loadData() async {
    final details = await DatabaseHelper.instance.getConnectionDetails();
    if (details != null) {
      _connectionDetails = details;
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

  // Database se waiters ka data fetch karne ka function
  Future<void> _fetchWaiters() async {
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
      );

      final result = await SqlConn.readData(
        "SELECT waiter_name, is_update FROM Waiter",
      );
      final parsedResult = jsonDecode(result) as List<dynamic>;
      final waiters = parsedResult.map((row) {
        return {
          'waiter_name': (row as Map<String, dynamic>)['waiter_name'] as String,
          // ignore: unnecessary_cast
          'is_update': (row as Map<String, dynamic>)['is_update'] as int,
        };
      }).toList();

      setState(() {
        _waiters = waiters;
      });

      SqlConn.disconnect();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to load waiters: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
      print('Error fetching waiters: $e');
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  // Pop-up dialog dikhane ke liye function
  void _showUnupdatedWaiterDialog() {
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          backgroundColor: const Color(0xFF0D1D20),
          title: const Text(
            'Cannot Proceed',
            style: TextStyle(
              color: Color(0xFF75E5E2),
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
              onPressed: () {
                Navigator.of(context).pop();
              },
              child: const Text(
                'OK',
                style: TextStyle(
                  color: Color(0xFF75E5E2),
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
    // Screen ke size ke hisaab se layout adjust karna
    final screenWidth = MediaQuery.of(context).size.width;
    final crossAxisCount = screenWidth < 600 ? 3 : (screenWidth < 900 ? 4 : 5);
    final childAspectRatio = screenWidth < 600
        ? 0.8
        : (screenWidth < 900 ? 0.9 : 1.0);

    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Select Waiter',
          style: TextStyle(fontFamily: 'Raleway'),
        ),
        centerTitle: true,
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
            : _waiters.isEmpty
            ? const Center(
                child: Text(
                  'Koi Waiter Nahi Mila.',
                  style: TextStyle(
                    fontSize: 20,
                    color: Color(0xFF75E5E2),
                    fontFamily: 'Raleway',
                  ),
                  textAlign: TextAlign.center,
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
                    final isUpdated = waiter['is_update'] == 0 || waiter['is_update'] == 1;

                    return InkWell(
                      onTap: () {
                        if (isUpdated) {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) =>
                                  TablesPage(waiterName: waiter['waiter_name']),
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
                                  colors: [
                                    Color(0xFF75E5E2),
                                    Color(0xFF41938F),
                                  ],
                                  begin: Alignment.topLeft,
                                  end: Alignment.bottomRight,
                                )
                              : const LinearGradient(
                                  colors: [
                                    Color(0xFF1F2F32),
                                    Color(0xFF0D1D20),
                                  ],
                                  begin: Alignment.topLeft,
                                  end: Alignment.bottomRight,
                                ),
                          boxShadow: isUpdated
                              ? [
                                  BoxShadow(
                                    color: const Color(
                                      0xFF75E5E2,
                                    ).withOpacity(0.4),
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
                              color: isUpdated
                                  ? const Color(0xFF0D1D20)
                                  : Colors.white,
                              size: 32,
                            ),
                            const SizedBox(height: 8),
                            Text(
                              waiter['waiter_name'],
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                                color: isUpdated
                                    ? const Color(0xFF0D1D20)
                                    : Colors.white,
                                fontFamily: 'Raleway',
                              ),
                              textAlign: TextAlign.center,
                            ),
                            if (isUpdated)
                              Padding(
                                padding: const EdgeInsets.only(top: 4.0),
                                child: Text(
                                  'Updated',
                                  style: TextStyle(
                                    fontSize: 12,
                                    color:
                                        (isUpdated ? const Color(0xFF0D1D20) : Colors.white)
                                            .withOpacity(0.8),
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
        backgroundColor: const Color(0xFF75E5E2),
        foregroundColor: const Color(0xFF0D1D20),
        child: const Icon(Icons.refresh),
      ),
    );
  }
}
