// Widget _buildDesktopLayout() {
//     return Row(
//       children: [
//         Expanded(
//           flex: 3,
//           child: Container(
//             color: Colors.grey.shade900,
//             padding: const EdgeInsets.all(16),
//             child: _buildOrderListWithDetails(),
//           ),
//         ),
//         Expanded(
//           flex: 2,
//           child: Padding(
//             padding: const EdgeInsets.all(8.0),
//             child: _selectedCategory != null && _categoryItems[_selectedCategory] != null
//                 ? GridView.builder(
//                     gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
//                       crossAxisCount: 2,
//                       crossAxisSpacing: 8.0,
//                       mainAxisSpacing: 8.0,
//                       childAspectRatio: 0.7,
//                     ),
//                     itemCount: _categoryItems[_selectedCategory]?.length ?? 0,
//                     itemBuilder: (context, index) {
//                       final items = _categoryItems[_selectedCategory] ?? [];
//                       final item = items[index];
//                       return Card(
//                         child: InkWell(
//                           onTap: () => _addItemToOrder(item),
//                           onLongPress: () => _showCommentDialog(OrderItem.fromMap(item)),
//                           child: Padding(
//                             padding: const EdgeInsets.all(8.0),
//                             child: Column(
//                               mainAxisAlignment: MainAxisAlignment.center,
//                               children: [
//                                 const Icon(
//                                   Icons.local_dining,
//                                   color: Color(0xFF75E5E2),
//                                   size: 40,
//                                 ),
//                                 const SizedBox(height: 8),
//                                 Text(
//                                   item['item_name'],
//                                   textAlign: TextAlign.center,
//                                   style: const TextStyle(
//                                     color: Colors.white,
//                                     fontSize: 16,
//                                     fontWeight: FontWeight.bold,
//                                     fontFamily: 'Raleway',
//                                   ),
//                                 ),
//                                 const SizedBox(height: 4),
//                                 Text(
//                                   ' ${item['sale_price'].toStringAsFixed(2)}',
//                                   style: const TextStyle(
//                                     color: Colors.white70,
//                                     fontSize: 14,
//                                     fontFamily: 'Raleway',
//                                   ),
//                                 ),
//                                 const SizedBox(height: 4),
//                                 Row(
//                                   mainAxisAlignment: MainAxisAlignment.center,
//                                   children: [
//                                     const Text(
//                                       'Tax:',
//                                       style: TextStyle(
//                                         color: Colors.white70,
//                                         fontSize: 12,
//                                         fontFamily: 'Raleway',
//                                       ),
//                                     ),
//                                     Text(
//                                       ' ${(OrderConstants.taxRate * 100).toStringAsFixed(1)}%',
//                                       style: const TextStyle(
//                                         color: Colors.lightGreen,
//                                         fontSize: 12,
//                                         fontWeight: FontWeight.bold,
//                                         fontFamily: 'Raleway',
//                                       ),
//                                     ),
//                                     const Text(
//                                       ' | ',
//                                       style: TextStyle(
//                                         color: Colors.white70,
//                                         fontSize: 12,
//                                         fontFamily: 'Raleway',
//                                       ),
//                                     ),
//                                     const Text(
//                                       'Disc:',
//                                       style: TextStyle(
//                                         color: Colors.white70,
//                                         fontSize: 12,
//                                         fontFamily: 'Raleway',
//                                       ),
//                                     ),
//                                     Text(
//                                       ' ${(OrderConstants.discountRate * 100).toStringAsFixed(1)}%',
//                                       style: const TextStyle(
//                                         color: Colors.orange,
//                                         fontSize: 12,
//                                         fontWeight: FontWeight.bold,
//                                         fontFamily: 'Raleway',
//                                       ),
//                                     ),
//                                   ],
//                                 ),
//                               ],
//                             ),
//                           ),
//                         ),
//                       );
//                     },
//                   )
//                 : const Center(
//                     child: Text(
//                       'No items available',
//                       style: TextStyle(color: Colors.white70, fontFamily: 'Raleway'),
//                     ),
//                   ),
//           ),
//         ),
//       ],
//     );
//   }
