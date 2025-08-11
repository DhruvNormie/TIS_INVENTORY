import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class ReturnRequestsPage extends StatelessWidget {
  const ReturnRequestsPage({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Return Requests')),
      body: StreamBuilder<QuerySnapshot>(
        stream:
            FirebaseFirestore.instance
                .collection('transactions')
                .where('type', isEqualTo: 'returnable')
                .where('status', isEqualTo: 'pending_return')
                .orderBy('returnRequestedAt', descending: true)
                .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return Center(child: Text('Error: ${snapshot.error}'));
          }

          final docs = snapshot.data?.docs ?? [];
          if (docs.isEmpty) {
            return const Center(child: Text('No pending return requests.'));
          }

          return ListView.builder(
            itemCount: docs.length,
            itemBuilder: (context, index) {
              final doc = docs[index];
              final data = doc.data() as Map<String, dynamic>;
              final txId = doc.id;
              final userName = data['userName'] ?? 'Unknown';
              final userId = data['userId'] ?? '';
              final returnReason = data['returnReason'] ?? '';

              final List<Map<String, dynamic>> originalItems =
                  List<Map<String, dynamic>>.from(data['items'] ?? []);

              final List<Map<String, dynamic>> returnItems =
                  List<Map<String, dynamic>>.from(
                    data['returnRequest']?['items'] ?? [],
                  );

              return Card(
                margin: const EdgeInsets.all(8),
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'User: $userName',
                        style: Theme.of(context).textTheme.bodyLarge,
                      ),
                      const SizedBox(height: 4),
                      Text('Reason: $returnReason'),
                      const Divider(),

                      // Display return items
                      ...returnItems.map((e) {
                        final id = e['itemId'] as String;
                        final qty = e['requestedQty'] as int;
                        return FutureBuilder<DocumentSnapshot>(
                          future:
                              FirebaseFirestore.instance
                                  .collection('items')
                                  .doc(id)
                                  .get(),
                          builder: (context, snapItem) {
                            if (snapItem.connectionState ==
                                ConnectionState.waiting) {
                              return const ListTile(
                                title: Text('Loading item...'),
                              );
                            }
                            if (snapItem.hasError) {
                              return ListTile(
                                title: Text(
                                  'Error loading item: ${snapItem.error}',
                                ),
                                trailing: Text('Qty: $qty'),
                              );
                            }
                            if (!snapItem.hasData || !snapItem.data!.exists) {
                              return ListTile(
                                title: const Text('Item not found'),
                                trailing: Text('Qty: $qty'),
                              );
                            }
                            final name =
                                snapItem.data!.get('name') ?? 'Unnamed';
                            return ListTile(
                              title: Text(name),
                              trailing: Text('Returning: $qty'),
                            );
                          },
                        );
                      }).toList(),

                      const SizedBox(height: 8),

                      // Action buttons
                      Row(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          TextButton(
                            onPressed: () async {
                              await FirebaseFirestore.instance
                                  .collection('transactions')
                                  .doc(txId)
                                  .update({'status': 'active'});
                            },
                            child: const Text('Reject'),
                          ),
                          const SizedBox(width: 8),
                          ElevatedButton(
                            onPressed: () async {
                              final batch = FirebaseFirestore.instance.batch();
                              final txRef = FirebaseFirestore.instance
                                  .collection('transactions')
                                  .doc(txId);

                              // Step 1: Mark as returned
                              batch.update(txRef, {
                                'status': 'returned',
                                'returnApprovedAt':
                                    FieldValue.serverTimestamp(),
                              });

                              // Step 2: Increment stock of returned items
                              for (var item in returnItems) {
                                final itemRef = FirebaseFirestore.instance
                                    .collection('items')
                                    .doc(item['itemId']);
                                batch.update(itemRef, {
                                  'quantity': FieldValue.increment(
                                    item['requestedQty'] as int,
                                  ),
                                });
                              }

                              await batch.commit();

                              // Step 3: Create new transaction for remaining items
                              final Map<String, int> returnedMap = {
                                for (var item in returnItems)
                                  item['itemId']: item['requestedQty'] as int,
                              };

                              final List<Map<String, dynamic>> remainingItems =
                                  [];

                              for (var origItem in originalItems) {
                                final id = origItem['itemId'];
                                final borrowedQty = origItem['quantity'];
                                final returnedQty = returnedMap[id] ?? 0;
                                final remainingQty = borrowedQty - returnedQty;

                                if (remainingQty > 0) {
                                  remainingItems.add({
                                    'itemId': id,
                                    'quantity': remainingQty,
                                  });
                                }
                              }

                              debugPrint('Remaining items: $remainingItems');

                              if (remainingItems.isNotEmpty) {
                                await FirebaseFirestore.instance
                                    .collection('transactions')
                                    .add({
                                      'userId': userId,
                                      'userName': userName,
                                      'items': remainingItems,
                                      'type': 'returnable',
                                      'status': 'active',
                                      'timestamp': FieldValue.serverTimestamp(),
                                      'note':
                                          '[Auto-generated from partial return]',
                                    });
                              }

                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text('Partial return approved'),
                                ),
                              );
                            },
                            child: const Text('Approve'),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }
}
