// lib/laptop_list_screen.dart

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class LaptopListScreen extends StatelessWidget {
  final User user;
  const LaptopListScreen({Key? key, required this.user}) : super(key: key);

  // TODO: Use the same adminEmails list if you want admins to delete laptops.
  static const List<String> adminEmails = [
    'admin1@example.com',
    'admin2@example.com',
    'dhruv.joshi@theinnovationstory.com'
  ];
  bool get isAdmin => adminEmails.contains(user.email);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('Laptops (${user.email})')),
      body: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
        stream: FirebaseFirestore.instance.collection('laptops').snapshots(),
        builder: (context, snapshot) {
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }
          final docs = snapshot.data!.docs;
          if (docs.isEmpty) {
            return const Center(child: Text('No laptops found'));
          }
          return ListView.builder(
            itemCount: docs.length,
            itemBuilder: (context, idx) {
              final doc = docs[idx];
              final data = doc.data();
              return Card(
                margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                child: ListTile(
                  title: Text(data['title'] ?? ''),
                  subtitle: Text(
                    'Available: ${data['availableQuantity']} / ${data['totalQuantity']}',
                  ),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // Borrow Laptop
                      IconButton(
                        icon: const Icon(Icons.remove_circle_outline),
                        onPressed:
                            () => _borrowLaptop(
                              context,
                              doc.id,
                              data['availableQuantity'] as int,
                            ),
                      ),

                      // Return Laptop
                      IconButton(
                        icon: const Icon(Icons.add_circle_outline),
                        onPressed:
                            () => _returnLaptop(
                              context,
                              doc.id,
                              data['availableQuantity'] as int,
                              data['totalQuantity'] as int,
                            ),
                      ),

                      // Delete laptop (admin only)
                      if (isAdmin)
                        IconButton(
                          icon: const Icon(Icons.delete_forever),
                          onPressed:
                              () =>
                                  FirebaseFirestore.instance
                                      .collection('laptops')
                                      .doc(doc.id)
                                      .delete(),
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

  // ------------- Borrow Laptop Logic -------------
  void _borrowLaptop(BuildContext context, String laptopId, int available) {
    if (available <= 0) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Out of stock')));
      return;
    }
    final nameController = TextEditingController();
    showDialog(
      context: context,
      builder:
          (_) => AlertDialog(
            title: const Text('Borrow Laptop'),
            content: TextField(
              controller: nameController,
              decoration: const InputDecoration(labelText: 'Your name'),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Cancel'),
              ),
              ElevatedButton(
                onPressed: () async {
                  final name = nameController.text.trim();
                  if (name.isEmpty) return;
                  final currentUser = FirebaseAuth.instance.currentUser;
                  final email = currentUser?.email ?? 'unknown@example.com';

                  final lapRef = FirebaseFirestore.instance
                      .collection('laptops')
                      .doc(laptopId);
                  final txRef =
                      FirebaseFirestore.instance
                          .collection('laptopTransactions')
                          .doc();

                  await FirebaseFirestore.instance.runTransaction((tx) async {
                    final snapshot = await tx.get(lapRef);
                    final curr = snapshot['availableQuantity'] as int;
                    tx.update(lapRef, {'availableQuantity': curr - 1});
                    tx.set(txRef, {
                      'laptopId': laptopId,
                      'borrowerName': name,
                      'borrowerEmail': email,
                      'borrowDate': FieldValue.serverTimestamp(),
                      'returnDate': null,
                    });
                  });
                  Navigator.pop(context);
                },
                child: const Text('Confirm'),
              ),
            ],
          ),
    );
  }

  // ------------- Return Laptop Logic -------------
  void _returnLaptop(
    BuildContext context,
    String laptopId,
    int available,
    int total,
  ) {
    if (available >= total) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Nothing to return')));
      return;
    }
    showDialog(
      context: context,
      builder: (context) {
        return FutureBuilder<QuerySnapshot<Map<String, dynamic>>>(
          future:
              FirebaseFirestore.instance
                  .collection('laptopTransactions')
                  .where('laptopId', isEqualTo: laptopId)
                  .where('returnDate', isNull: true)
                  .get(),
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const AlertDialog(
                content: SizedBox(
                  height: 100,
                  child: Center(child: CircularProgressIndicator()),
                ),
              );
            }
            final docs = snapshot.data?.docs;
            if (docs == null || docs.isEmpty) {
              WidgetsBinding.instance.addPostFrameCallback((_) {
                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('No active borrowers')),
                );
              });
              return const SizedBox.shrink();
            }
            return SimpleDialog(
              title: const Text('Select borrower to return'),
              children:
                  docs.map((doc) {
                    final data = doc.data();
                    return SimpleDialogOption(
                      child: Text(data['borrowerName'] ?? 'Unknown'),
                      onPressed: () async {
                        final txDocRef = doc.reference;
                        final lapRef = FirebaseFirestore.instance
                            .collection('laptops')
                            .doc(laptopId);
                        await FirebaseFirestore.instance.runTransaction((
                          tx,
                        ) async {
                          final lapSnap = await tx.get(lapRef);
                          final curr = lapSnap['availableQuantity'] as int;
                          tx.update(lapRef, {'availableQuantity': curr + 1});
                          tx.update(txDocRef, {
                            'returnDate': FieldValue.serverTimestamp(),
                          });
                        });
                        Navigator.pop(context);
                      },
                    );
                  }).toList(),
            );
          },
        );
      },
    );
  }
}
