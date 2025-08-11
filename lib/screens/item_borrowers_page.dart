import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';

/// Shows all users who currently have borrowed this item
class ItemBorrowersPage extends StatelessWidget {
  final String itemId;
  final String itemName;
  const ItemBorrowersPage({
    Key? key,
    required this.itemId,
    required this.itemName,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('Borrowers of $itemName')),
      body: StreamBuilder<QuerySnapshot>(
        stream:
            FirebaseFirestore.instance
                .collection('transactions')
                .where('type', isEqualTo: 'returnable')
                .where('status', whereIn: ['active', 'pending_return'])
                .orderBy('timestamp', descending: true)
                .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return Center(child: Text('Error: ${snapshot.error}'));
          }
          final docs =
              snapshot.data!.docs.where((doc) {
                final items = List<Map<String, dynamic>>.from(
                  (doc.data() as Map<String, dynamic>)['items'] ?? [],
                );
                return items.any(
                  (e) => e['itemId'] == itemId && (e['quantity'] as int) > 0,
                );
              }).toList();
          if (docs.isEmpty) {
            return Center(child: Text('No active borrowings for this item.'));
          }
          return ListView(
            children:
                docs.map((doc) {
                  final data = doc.data() as Map<String, dynamic>;
                  final userName = data['userName'] as String? ?? 'Unknown';
                  final email = data['userEmail'] as String? ?? '';
                  final ts = data['timestamp'] as Timestamp?;
                  final date =
                      ts != null
                          ? DateFormat(
                            'dd-MM-yy HH:mm',
                          ).format(ts.toDate().toLocal())
                          : 'Unknown';
                  final qty =
                      (List<Map<String, dynamic>>.from(
                            data['items'] ?? [],
                          ).firstWhere((e) => e['itemId'] == itemId)['quantity']
                          as int?);
                  return ListTile(
                    title: Text('$userName ($email)'),
                    subtitle: Text('Borrowed on: $date'),
                    trailing: Text('Qty: $qty'),
                  );
                }).toList(),
          );
        },
      ),
    );
  }
}
