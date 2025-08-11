import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';

class NonReturnableItemsScreen extends StatefulWidget {
  @override
  _NonReturnableItemsScreenState createState() =>
      _NonReturnableItemsScreenState();
}

class _NonReturnableItemsScreenState extends State<NonReturnableItemsScreen> {
  bool isLoading = true;
  Map<String, List<Map<String, dynamic>>> groupedItems = {};

  @override
  void initState() {
    super.initState();
    fetchUserNonReturnableItems();
  }

  Future<void> fetchUserNonReturnableItems() async {
    try {
      final currentUser = FirebaseAuth.instance.currentUser;

      if (currentUser == null) {
        setState(() => isLoading = false);
        return;
      }

      final userEmail = currentUser.email?.trim();
      final querySnapshot =
          await FirebaseFirestore.instance.collection('transactions').get();

      groupedItems.clear();

      for (var doc in querySnapshot.docs) {
        final data = doc.data();
        final email = data['userEmail']?.toString().trim();
        final type = data['type']?.toString();
        final timestamp = data['timestamp'];

        if (email != userEmail || type != 'non_returnable') continue;

        final dynamic itemsField = data['items'];

        if (itemsField is List && itemsField.isNotEmpty) {
          for (var item in itemsField) {
            if (item is Map) {
              final itemMap = {
                ...Map<String, dynamic>.from(item),
                'reason': data['reason'],
                'status': data['status'],
                'timestamp': timestamp,
                'userEmail': email,
                'userId': data['userId'],
                'userName': data['userName'],
                'type': type,
              };

              final tsKey = timestamp.toString();
              if (!groupedItems.containsKey(tsKey)) {
                groupedItems[tsKey] = [];
              }
              groupedItems[tsKey]!.add(itemMap);
            }
          }
        }
      }

      setState(() => isLoading = false);
    } catch (e) {
      // print('❌ Fetch error: $e');
      setState(() => isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    const Color primaryColor = Color.fromARGB(255, 0, 183, 255);
    return Scaffold(
      appBar: AppBar(
        backgroundColor: primaryColor,
        title: const Text('Non-Returnable Items'),
        centerTitle: true,
        elevation: 4,
      ),
      body:
          isLoading
              ? const Center(child: CircularProgressIndicator())
              : groupedItems.isEmpty
              ? const Center(child: Text("No items found."))
              : ListView(
                children:
                    groupedItems.entries.map((entry) {
                      final items = entry.value;
                      final DateTime? ts =
                          items.first['timestamp']?.toDate() ?? null;
                      final formattedDate =
                          ts != null
                              ? DateFormat('dd-MM-yy HH:mm').format(ts)
                              : 'Unknown';

                      return Card(
                        margin: const EdgeInsets.symmetric(
                          vertical: 8,
                          horizontal: 16,
                        ),
                        child: Padding(
                          padding: const EdgeInsets.all(12),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Borrowed on: $formattedDate',
                                style: Theme.of(context).textTheme.bodyLarge
                                    ?.copyWith(fontWeight: FontWeight.bold),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                'Student: ${items.first['userName']}',
                                style: Theme.of(context).textTheme.bodyMedium,
                              ),
                              const SizedBox(height: 4),
                              Text(
                                'Mentor: ${items.first['userEmail']}',
                                style: Theme.of(context).textTheme.bodySmall,
                              ),
                              const Divider(),
                              ...items.map((item) {
                                final itemId = item['itemId'];
                                final qty = item['quantity'] ?? '-';
                                final reason = item['reason'] ?? '';

                                return FutureBuilder<DocumentSnapshot>(
                                  future:
                                      FirebaseFirestore.instance
                                          .collection('items')
                                          .doc(itemId)
                                          .get(),
                                  builder: (context, snapshot) {
                                    if (snapshot.connectionState ==
                                        ConnectionState.waiting) {
                                      return const ListTile(
                                        title: Text('Loading item...'),
                                      );
                                    }

                                    String itemName = 'Unknown Item';
                                    if (snapshot.hasData &&
                                        snapshot.data!.exists) {
                                      final data =
                                          snapshot.data!.data()
                                              as Map<String, dynamic>;
                                      itemName = data['name'] ?? 'Unnamed';
                                    }

                                    return ListTile(
                                      title: Text(itemName),
                                      subtitle: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Text('Quantity: $qty'),
                                          Text('Reason: $reason'),
                                        ],
                                      ),
                                    );
                                  },
                                );
                              }).toList(),
                            ],
                          ),
                        ),
                      );
                    }).toList(),
              ),
    );
  }
}
