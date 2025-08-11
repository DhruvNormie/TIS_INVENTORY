// lib/screens/borrow_laptop_page.dart

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class BorrowLaptopPage extends StatefulWidget {
  const BorrowLaptopPage({Key? key}) : super(key: key);

  @override
  _BorrowLaptopPageState createState() => _BorrowLaptopPageState();
}

class _BorrowLaptopPageState extends State<BorrowLaptopPage> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  Future<void> _borrowLaptop(String laptopDocId, String laptopName) async {
    final user = _auth.currentUser;
    if (user == null) {
      // Optionally navigate to login
      return;
    }
    final userId = user.uid;
    final userEmail = user.email ?? 'unknown@example.com';
    final now = Timestamp.now();

    await _firestore.collection('laptop_transactions').add({
      'itemType': 'laptop',
      'itemId': laptopDocId,
      'itemName': laptopName,
      'userId': userId,
      'userEmail': userEmail,
      'borrowTime': now,
      'status': 'active',
    });

    if (!mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text('You borrowed $laptopName')));
  }

  @override
  Widget build(BuildContext context) {
    // Theme Colors
    const Color backgroundColor = Color(0xFFF4F6FD); // Light grey
    const Color primaryColor = Color.fromARGB(255, 0, 183, 255); // Blue
    // const Color iconColor = Color(0xFF3949AB); // Indigo 600
    const Color textColor = Color(0xFF212121); // Dark grey
    const Color accentColor = Color(0xFF00ACC1); // Teal

    return Scaffold(
      backgroundColor: backgroundColor,
      appBar: AppBar(
        backgroundColor: primaryColor,
        centerTitle: true,
        elevation: 4,
        title: const Text(
          'Borrow a Laptop',
          style: TextStyle(fontSize: 20, fontWeight: FontWeight.w600),
        ),
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: StreamBuilder<QuerySnapshot>(
            // First stream: all active laptop borrows
            stream:
                _firestore
                    .collection('laptop_transactions')
                    .where('status', isEqualTo: 'active')
                    .snapshots(),
            builder: (context, txSnapshot) {
              if (txSnapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              }
              if (txSnapshot.hasError) {
                return Center(
                  child: Text(
                    'Error: ${txSnapshot.error}',
                    style: TextStyle(color: textColor),
                  ),
                );
              }

              // Build set of borrowed laptop IDs
              final activeDocs = txSnapshot.data?.docs ?? [];
              final borrowedIds = <String>{};
              for (var doc in activeDocs) {
                final id = doc['itemId'] as String;
                borrowedIds.add(id);
              }

              // Second stream: all laptops
              return StreamBuilder<QuerySnapshot>(
                stream:
                    _firestore
                        .collection('laptops')
                        .orderBy('createdAt')
                        .snapshots(),
                builder: (context, laptopSnapshot) {
                  if (laptopSnapshot.connectionState ==
                      ConnectionState.waiting) {
                    return const Center(child: CircularProgressIndicator());
                  }
                  if (laptopSnapshot.hasError) {
                    return Center(
                      child: Text(
                        'Error: ${laptopSnapshot.error}',
                        style: TextStyle(color: textColor),
                      ),
                    );
                  }

                  final laptopDocs = laptopSnapshot.data?.docs ?? [];
                  if (laptopDocs.isEmpty) {
                    return Center(
                      child: Text(
                        'No laptops available.',
                        style: TextStyle(color: textColor, fontSize: 16),
                      ),
                    );
                  }

                  return ListView.builder(
                    itemCount: laptopDocs.length,
                    itemBuilder: (context, index) {
                      final doc = laptopDocs[index];
                      final laptopId = doc.id;
                      final laptopName = doc['name'] as String;
                      final isBorrowed = borrowedIds.contains(laptopId);

                      return Card(
                        color: Colors.white,
                        elevation: 1,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        margin: const EdgeInsets.symmetric(
                          vertical: 6,
                          horizontal: 0,
                        ),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 12,
                          ),
                          child: Row(
                            children: [
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      laptopName,
                                      style: TextStyle(
                                        fontSize: 16,
                                        fontWeight: FontWeight.w600,
                                        color: textColor,
                                      ),
                                    ),
                                    const SizedBox(height: 4),
                                    if (isBorrowed)
                                      Text(
                                        'Currently borrowed',
                                        style: TextStyle(
                                          fontSize: 14,
                                          color: Colors.redAccent,
                                        ),
                                      )
                                    else
                                      Text(
                                        'Available',
                                        style: TextStyle(
                                          fontSize: 14,
                                          color: Colors.green.shade700,
                                        ),
                                      ),
                                  ],
                                ),
                              ),
                              ElevatedButton(
                                style: ElevatedButton.styleFrom(
                                  backgroundColor:
                                      isBorrowed
                                          ? Colors.grey.shade400
                                          : accentColor,
                                  foregroundColor: Colors.white,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  elevation: isBorrowed ? 0 : 2,
                                ),
                                onPressed:
                                    isBorrowed
                                        ? null
                                        : () =>
                                            _borrowLaptop(laptopId, laptopName),
                                child: Text(
                                  isBorrowed ? 'Unavailable' : 'Borrow',
                                  style: const TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  );
                },
              );
            },
          ),
        ),
      ),
    );
  }
}
