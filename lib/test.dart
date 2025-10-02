// // --- Corrected Code Block in running_orders_page.dart ---

// Expanded(
//   flex: 3,
//   child: Row(
//     mainAxisAlignment: MainAxisAlignment.center,
//     children: [
//       ElevatedButton(
//         onPressed: () {
//           // 💡 FIX APPLIED HERE: order['order_no'] ko .toString() mein convert kiya gaya hai.
//           final dynamic orderNo = order['order_no'];
//           final String orderNoString = orderNo.toString(); 

//           Navigator.push(
//             context,
//             MaterialPageRoute(
//               // ✅ Corrected Line: Order number ko String ki tarah pass kiya ja raha hai.
//               builder: (_) => CashBillScreen(orderNo: orderNoString),
//             ),
//           );
//         },
//         // ... rest of CASH button style
//         // ...
//       ),
//       // ... rest of CREDIT button
//     ],
//   ),
// ),