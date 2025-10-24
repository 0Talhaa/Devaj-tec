// if (searchResults.isNotEmpty)
//   SizedBox(
//     height: 200, // fixed height instead of Flexible
//     child: ListView.builder(
//       shrinkWrap: true,
//       itemCount: searchResults.length > 10 ? 10 : searchResults.length,
//       itemBuilder: (context, index) {
//         final customer = searchResults[index];
//         return ListTile(
//           title: Text(
//             customer.customerName,
//             style: const TextStyle(
//               color: Colors.white,
//               fontFamily: 'Raleway',
//             ),
//           ),
//           subtitle: Text(
//             'Cell: ${customer.cellNo}${customer.telNo.isNotEmpty ? ' | Tel: ${customer.telNo}' : ''}',
//             style: const TextStyle(
//               color: Colors.white70,
//               fontFamily: 'Raleway',
//             ),
//           ),
//           onTap: () {
//             _autoFillCustomerDetails(customer);
//             setDialogState(() {
//               searchResults = [];
//             });
//           },
//         );
//       },
//     ),
//   ),
