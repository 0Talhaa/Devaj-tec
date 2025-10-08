// ignore_for_file: unused_local_variable, unused_import, unused_field, avoid_print

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:start_app/database_halper.dart';
import 'dart:convert';
import 'package:sql_conn/sql_conn.dart';
import 'package:start_app/order_screen.dart';

class TablesPage extends StatefulWidget {
  // Waiter's name ko class ke constructor mein store karne ke liye final variable.
  final String waiterName;
  const TablesPage({super.key, required this.waiterName});

  @override
  State<TablesPage> createState() => _TablesPageState();
}

class _TablesPageState extends State<TablesPage> {
  bool _isLoading = true;
  List<Map<String, dynamic>> _masterTables = [];
  List<Map<String, dynamic>> _filteredTables = [];
  Map<String, dynamic>? _connectionDetails;
  int? _selectedMtblId;
  int? _selectedTiltId;
  String? _selectedTiltName; // 👈 yeh line add karo
  String _selectedHallName = "Select a Hall";

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    final details = await DatabaseHelper.instance.getConnectionDetails();
    if (details != null) {
      _connectionDetails = details;
      await _fetchMasterTables();
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

  Future<void> _fetchMasterTables() async {
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

      final masterTableQuery =
          "SELECT Mtbl_Id, PTable FROM HNFOODMULTAN.dbo.MasterTable";
      final masterTableResult = await SqlConn.readData(masterTableQuery);

      final parsedResult = jsonDecode(masterTableResult) as List<dynamic>;
      final masterTables = parsedResult
          .map((row) => (row as Map<String, dynamic>))
          .toList();

      setState(() {
        _masterTables = masterTables;
      });

      // Automatically select the first dining hall if the list is not empty
      if (_masterTables.isNotEmpty) {
        final firstHall = _masterTables.first;
        await _fetchFilteredTables(firstHall['Mtbl_Id'], firstHall['PTable']);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to load dining halls: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
      print('Error fetching master tables: $e');
    } finally {
      SqlConn.disconnect();
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _fetchFilteredTables(int mtblId, String hallName) async {
    setState(() {
      _isLoading = true;
      _selectedMtblId = mtblId;
      _selectedHallName = hallName;
      _filteredTables = [];
    });

    try {
      await SqlConn.connect(
        ip: _connectionDetails!['ip'] as String,
        port: _connectionDetails!['port'] as String,
        databaseName: _connectionDetails!['dbName'] as String,
        username: _connectionDetails!['username'] as String,
        password: _connectionDetails!['password'] as String,
      );

      // Tables ko Mtbl_Id ke mutabiq filter kar rahe hain
      final tablesQuery =
          "SELECT Mtbl_Id, tables, table_status FROM HNFOODMULTAN.dbo.Tables WHERE Mtbl_Id = $mtblId";

      final tablesResult = await SqlConn.readData(tablesQuery);

      final parsedResult = jsonDecode(tablesResult) as List<dynamic>;
      final tables = parsedResult
          .map((row) => (row as Map<String, dynamic>))
          .toList();

      setState(() {
        _filteredTables = tables;
      });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to load tables: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
      print('Error fetching filtered tables: $e');
    } finally {
      SqlConn.disconnect();
      setState(() {
        _isLoading = false;
      });
    }
  }

  void _showClosedTableDialog(String tableName) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF282828),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.lock_outline, color: Colors.redAccent, size: 60),
            const SizedBox(height: 20),
            Text(
              '$tableName Closed Now!',
              style: const TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.bold,
                color: Colors.white,
                fontFamily: 'Raleway',
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 10),
            const Text(
              'You Can Not Take Order This Table.',
              style: TextStyle(
                fontSize: 16,
                color: Colors.white70,
                fontFamily: 'Raleway',
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 20),
            ElevatedButton(
              onPressed: () {
                Navigator.of(context).pop();
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.redAccent,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              child: const Text('OK'),
            ),
          ],
        ),
      ),
    );
  }

  void _showCalculatorDialog(Map<String, dynamic> table) {
    String currentInput = '0';
    // Fix: Yahan 'waiterName' ko widget se liya gaya hai.
    final waiterName = widget.waiterName;

    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setState) {
            void onNumberTap(String value) {
              setState(() {
                if (currentInput == '0') {
                  currentInput = value;
                } else {
                  currentInput += value;
                }
              });
            }

            void onClear() {
              setState(() {
                currentInput = '0';
              });
            }
void onProceed() {
  int customerCount = int.tryParse(currentInput) ?? 0;
  Navigator.of(context).pop();

  Navigator.push(
    context,
    MaterialPageRoute(
      builder: (context) => OrderScreen(
        waiterName: waiterName,
        tableId: (table['id'] ?? 0) as int,
        tableName: table['tables'] as String,
        customerCount: customerCount,
        selectedTiltId: _selectedTiltId ?? 0,
        tabUniqueId: null,
      ),
    ),
  );
}






            return AlertDialog(
              backgroundColor: const Color(0xFF0D1D20),
              title: Text(
                'Table ${table['tables']}',
                style: const TextStyle(
                  color: Color(0xFF75E5E2),
                  fontFamily: 'Raleway',
                ),
              ),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    'Waiter: $waiterName',
                    style: const TextStyle(
                      color: Colors.white70,
                      fontFamily: 'Raleway',
                    ),
                  ),
                  const SizedBox(height: 20),
                  const Text(
                    'Calculator',
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontFamily: 'Raleway',
                    ),
                  ),
                  const SizedBox(height: 10),
                  Container(
                    alignment: Alignment.centerRight,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 12,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.grey.shade800,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      currentInput,
                      style: const TextStyle(
                        fontSize: 32,
                        color: Colors.white,
                        fontFamily: 'Raleway',
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),
                  Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: _buildCalculatorButton(
                              '7',
                              () => onNumberTap('7'),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: _buildCalculatorButton(
                              '8',
                              () => onNumberTap('8'),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: _buildCalculatorButton(
                              '9',
                              () => onNumberTap('9'),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),
                      Row(
                        children: [
                          Expanded(
                            child: _buildCalculatorButton(
                              '4',
                              () => onNumberTap('4'),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: _buildCalculatorButton(
                              '5',
                              () => onNumberTap('5'),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: _buildCalculatorButton(
                              '6',
                              () => onNumberTap('6'),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),
                      Row(
                        children: [
                          Expanded(
                            child: _buildCalculatorButton(
                              '1',
                              () => onNumberTap('1'),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: _buildCalculatorButton(
                              '2',
                              () => onNumberTap('2'),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: _buildCalculatorButton(
                              '3',
                              () => onNumberTap('3'),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),
                      Row(
                        children: [
                          Expanded(
                            child: _buildCalculatorButton('AC', onClear),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: _buildCalculatorButton(
                              '0',
                              () => onNumberTap('0'),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: _buildCalculatorButton('OK', onProceed),
                          ),
                        ],
                      ),
                    ],
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildCalculatorButton(String text, VoidCallback onPressed) {
    return ElevatedButton(
      onPressed: onPressed,
      style: ElevatedButton.styleFrom(
        backgroundColor: text == 'OK'
            ? const Color(0xFF75E5E2)
            : Colors.grey.shade700,
        foregroundColor: const Color(0xFF0D1D20),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
      child: Text(
        text,
        style: TextStyle(
          fontSize: text == 'OK' ? 18 : 24,
          fontWeight: FontWeight.bold,
          fontFamily: 'Raleway',
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final crossAxisCount = screenWidth < 600 ? 3 : (screenWidth < 900 ? 4 : 5);
    final hallCrossAxisCount = screenWidth < 600
        ? 2
        : (screenWidth < 900 ? 3 : 4);
    final childAspectRatio = screenWidth < 600
        ? 0.9
        : (screenWidth < 900 ? 1.0 : 1.1);

    return Scaffold(
      appBar: AppBar(
        title: Text(
          'Dining Halls & Tables',
          style: const TextStyle(fontFamily: 'Raleway'),
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
            : Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        Text(
                          "Waiter: ${widget.waiterName}",
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w600,
                            color: Color(0xFF75E5E2), // thoda highlight color
                            fontFamily: 'Raleway',
                          ),
                        ),
                        const Text(
                          'Select a Dining Hall:',
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                            fontFamily: 'Raleway',
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),

                    // MasterTables (Halls) ka GridView
                    SizedBox(
                      height: 120,
                      child: GridView.builder(
                        scrollDirection: Axis.horizontal,
                        gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: 1,
                          mainAxisSpacing: 16.0,
                          childAspectRatio: 1.2,
                        ),
                        itemCount: _masterTables.length,
                        itemBuilder: (context, index) {
                          final hall = _masterTables[index];
                          final isSelected = _selectedMtblId == hall['Mtbl_Id'];
                          return InkWell(
                            onTap: () {
                              _fetchFilteredTables(
                                hall['Mtbl_Id'],
                                hall['PTable'],
                              );
                            },
                            child: Card(
                              color: isSelected
                                  ? const Color(0xFF75E5E2)
                                  : const Color(0xFF282828),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                                side: isSelected
                                    ? const BorderSide(
                                        color: Colors.white,
                                        width: 2,
                                      )
                                    : BorderSide.none,
                              ),
                              child: Center(
                                child: Text(
                                  hall['PTable'] ?? 'N/A',
                                  style: TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.bold,
                                    color: isSelected
                                        ? const Color(0xFF0D1D20)
                                        : Colors.white,
                                    fontFamily: 'Raleway',
                                  ),
                                  textAlign: TextAlign.center,
                                ),
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                    const SizedBox(height: 24),
                    // Filtered Tables ka GridView
                    Text(
                      'Tables for $_selectedHallName:',
                      style: const TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                        fontFamily: 'Raleway',
                      ),
                    ),
                    const SizedBox(height: 16),
                    Expanded(
                      child: _filteredTables.isEmpty
                          ? Center(
                              child: Text(
                                _selectedMtblId == null
                                    ? 'Please select a hall to view tables.'
                                    : 'No tables found for $_selectedHallName.',
                                style: const TextStyle(
                                  fontSize: 18,
                                  color: Colors.white70,
                                  fontFamily: 'Raleway',
                                ),
                                textAlign: TextAlign.center,
                              ),
                            )
                          : GridView.builder(
                              gridDelegate:
                                  SliverGridDelegateWithFixedCrossAxisCount(
                                    crossAxisCount: crossAxisCount,
                                    crossAxisSpacing: 16.0,
                                    mainAxisSpacing: 16.0,
                                    childAspectRatio: childAspectRatio,
                                  ),
                              itemCount: _filteredTables.length,
                              itemBuilder: (context, index) {
                                final table = _filteredTables[index];
                                final tableStatus =
                                    (table['table_status'] as String).trim();
                                final isClosed =
                                    tableStatus.toLowerCase() == 'close';
                                final cardColor = isClosed
                                    ? const Color(0xFF422020)
                                    : const Color(0xFF204220);
                                final icon = isClosed
                                    ? Icons.lock_outline
                                    : Icons.lock_open_outlined;

                                return InkWell(
                                  onTap: () {
                                    if (isClosed) {
                                      _showClosedTableDialog(
                                        table['tables'] as String,
                                      );
                                    } else {
                                      _showCalculatorDialog(table);
                                    }
                                  },
                                  child: Container(
                                    decoration: BoxDecoration(
                                      borderRadius: BorderRadius.circular(16),
                                      gradient: isClosed
                                          ? const LinearGradient(
                                              colors: [
                                                Color(0xFF422020),
                                                Color(0xFF282828),
                                              ],
                                              begin: Alignment.topLeft,
                                              end: Alignment.bottomRight,
                                            )
                                          : const LinearGradient(
                                              colors: [
                                                Color(0xFF204220),
                                                Color(0xFF132B13),
                                              ],
                                              begin: Alignment.topLeft,
                                              end: Alignment.bottomRight,
                                            ),
                                      boxShadow: [
                                        BoxShadow(
                                          color:
                                              (isClosed
                                                      ? const Color(0xFF422020)
                                                      : const Color(0xFF204220))
                                                  .withOpacity(0.4),
                                          spreadRadius: 2,
                                          blurRadius: 10,
                                          offset: const Offset(0, 4),
                                        ),
                                      ],
                                    ),
                                    child: Column(
                                      mainAxisAlignment:
                                          MainAxisAlignment.center,
                                      children: [
                                        Icon(
                                          icon,
                                          color: Colors.white,
                                          size: 40,
                                        ),
                                        const SizedBox(height: 8),
                                        Text(
                                          table['tables'] ?? 'N/A',
                                          style: const TextStyle(
                                            fontSize: 20,
                                            fontWeight: FontWeight.bold,
                                            color: Colors.white,
                                            fontFamily: 'Raleway',
                                          ),
                                          textAlign: TextAlign.center,
                                        ),
                                        const SizedBox(height: 4),
                                        Text(
                                          isClosed ? 'Closed' : 'Open Now',
                                          style: const TextStyle(
                                            fontSize: 16,
                                            color: Colors.white70,
                                            fontFamily: 'Raleway',
                                          ),
                                          textAlign: TextAlign.center,
                                        ),
                                      ],
                                    ),
                                  ),
                                );
                              },
                            ),
                    ),
                  ],
                ),
              ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _fetchMasterTables,
        backgroundColor: const Color(0xFF75E5E2),
        foregroundColor: const Color(0xFF0D1D20),
        child: const Icon(Icons.refresh),
      ),
    );
  }
}
