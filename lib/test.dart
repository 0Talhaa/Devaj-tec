// // ignore_for_file: unused_local_variable, unused_element, use_build_context_synchronously

// import 'dart:convert';
// import 'package:flutter/material.dart';
// import 'package:flutter/services.dart';
// import 'package:mssql_connection/mssql_connection.dart';
// import 'package:start_app/database_halper.dart';
// import 'package:sql_conn/sql_conn.dart';
// import 'package:start_app/bill_screen.dart';
// import 'package:intl/intl.dart';

// final now = DateTime.now();
// final formattedDate = DateFormat('yyyy-MM-dd HH:mm:ss').format(now);

// class OrderScreen extends StatefulWidget {
//   final int tableId;
//   final String tableName;
//   final String waiterName;
//   final int customerCount;
//   final int? selectedTiltId;
//   final String? tabUniqueId; // agar edit karna hai to ye pass hoga

//   OrderScreen({
//     required this.waiterName,
//     required this.tableId,
//     required this.tableName,
//     required this.customerCount,
//     required this.selectedTiltId,
//     required this.tabUniqueId,
//   });

//   @override
//   _OrderScreenState createState() => _OrderScreenState();
// }

// class _OrderScreenState extends State<OrderScreen>
//     with SingleTickerProviderStateMixin {
//   late MssqlConnection _mssql;
//   bool _isMssqlReady = false;
//   bool _isLoading = true;

//   Map<String, List<Map<String, dynamic>>> _categoryItems = {};
//   List<Map<String, dynamic>> _categories = [];
//   String? _selectedCategory;

//   String _currentUser = "Admin";
//   String _deviceNo = "POS01";
//   int _isPrintKot = 1;

//   Map<String, dynamic>? _connectionDetails;
//   late TabController _tabController;

//   List<Map<String, dynamic>> _currentOrder = []; // ✅ final hata diya
//   double _totalBill = 0.0;
//   double _totalTax = 0.0;
//   double _totalDiscount = 0.0;

//   int? _finalTiltId;
//   String? _finalTiltName;

//   @override
//   void initState() {
//     super.initState();
//     _initConnectionAndLoadData();
//     _loadConnectionDetails();
//     _loadTiltFromLocal();

//     if (widget.tabUniqueId != null) {
//       // ✅ Edit mode
//       _fetchExistingOrder(widget.tabUniqueId!);
//     } else {
//       // ✅ New order
//       _generateNewTabUniqueId();
//     }
//     _fetchMenuData();
//   }

//   @override
//   void dispose() {
//     _tabController.dispose();
//     super.dispose();
//   }

//   Future<void> _loadConnectionDetails() async {
//     Map<String, dynamic>? connDetails =
//         await DatabaseHelper.instance.getConnectionDetails();

//     setState(() {
//       _currentUser = connDetails?['user'] ?? 'Admin';
//       _deviceNo = connDetails?['deviceName'] ?? 'POS01';
//       _isPrintKot = connDetails?['isPrintKot'] ?? 1;
//     });
//   }

//   Future<void> _initConnectionAndLoadData() async {
//     await _setupSqlConn();
//     await _loadData();
//   }

//   Future<void> _loadTiltFromLocal() async {
//     final savedDetails = await DatabaseHelper.instance.getConnectionDetails();
//     setState(() {
//       _finalTiltId = int.tryParse(savedDetails?['tiltId'] ?? '0') ?? 0;
//       _finalTiltName = savedDetails?['tiltName'] ?? '';
//     });
//   }

//   // ------------------ ORDER FETCH (EDIT MODE) ------------------
//   Future<void> _fetchExistingOrder(String tabUniqueId) async {
//     try {
//       final conn = await DatabaseHelper.instance.getConnectionDetails();

//       final query = """
//         select distinct 
//           d.itemid as itemId, 
//           d.item_name as itemName, 
//           d.qty as itemQuantity,
//           d.Comments as comments, 
//           i.sale_price as itemPrice,
//           (isnull(d.Qty,0) * isnull(i.sale_price,0)) as itemTotal,
//           d.id as orderDetailId, 
//           d.tax as tax
//         from order_detail d
//         inner join dine_in_order m on d.order_key = m.order_key
//         inner join itempos i on i.id = d.itemid
//         where m.tab_unique_id = '$tabUniqueId'
//       """;

//       final result = await SqlConn.readData(query);
//       final decoded = jsonDecode(result) as List<dynamic>;

//       setState(() {
//         _currentOrder = decoded.map((row) {
//           final qty = int.tryParse(row["itemQuantity"].toString()) ?? 0;
//           final price = double.tryParse(row["itemPrice"].toString()) ?? 0.0;
//           return {
//             "id": row["itemId"], // ✅ uniform keys
//             "item_name": row["itemName"],
//             "sale_price": price,
//             "quantity": qty,
//             "Comments": row["comments"] ?? "",
//             "tax_percent": double.tryParse(row["tax"].toString()) ?? 0.0,
//             "discount_percent": 0.0,
//           };
//         }).toList();
//         _calculateTotalBill();
//       });
//     } catch (e) {
//       print("❌ Error fetching existing order: $e");
//     } finally {
//       await SqlConn.disconnect();
//     }
//   }

//   // ------------------ TOTAL BILL CALCULATION ------------------
//   void _calculateTotalBill() {
//     double total = 0.0;
//     double totalTaxAmount = 0.0;
//     double totalDiscountAmount = 0.0;

//     for (var item in _currentOrder) {
//       final double itemPrice = (item['sale_price'] ?? 0).toDouble();
//       final int quantity = (item['quantity'] ?? 0).toInt();
//       final double tax = (item['tax_percent'] ?? 0).toDouble();
//       final double discount = (item['discount_percent'] ?? 0).toDouble();

//       final double subtotal = itemPrice * quantity;
//       final double taxAmount = subtotal * (tax / 100);
//       final double discountAmount = subtotal * (discount / 100);

//       total += subtotal + taxAmount - discountAmount;
//       totalTaxAmount += taxAmount;
//       totalDiscountAmount += discountAmount;
//     }

//     setState(() {
//       _totalBill = total;
//       _totalTax = totalTaxAmount;
//       _totalDiscount = totalDiscountAmount;
//     });
//   }
// }
