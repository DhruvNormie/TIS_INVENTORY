import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'dart:convert';

class MyBorrowingsPage extends StatefulWidget {
  const MyBorrowingsPage({Key? key}) : super(key: key);

  @override
  _MyBorrowingsPageState createState() => _MyBorrowingsPageState();
}

class _MyBorrowingsPageState extends State<MyBorrowingsPage> {
  final String uid = FirebaseAuth.instance.currentUser!.uid;
  final Map<String, TextEditingController> _reasonControllers = {};
  final Map<String, String> _itemNames = {};

  final Map<String, Map<String, TextEditingController>> _returnQtyControllers =
      {};

  // @override
  // void dispose() {
  //   for (var controller in _reasonControllers.values) {
  //     controller.dispose();
  //   }
  //   super.dispose();
  // }
  @override
  void dispose() {
    for (var map in _returnQtyControllers.values) {
      for (var controller in map.values) {
        controller.dispose();
      }
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    const Color backgroundColor = Color(0xFFF4F6FD);
    const Color primaryColor = Color.fromARGB(255, 0, 183, 255);
    const Color textColor = Color(0xFF212121);
    const Color accentColor = Color(0xFF00ACC1);
    const Color warningColor = Colors.orange;
    const Color errorColor = Colors.red;
    const Color successColor = Colors.green;

    InputDecoration _decor(String label) {
      return InputDecoration(
        labelText: label,
        filled: true,
        fillColor: Colors.white,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 14,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide.none,
        ),
      );
    }

    return Scaffold(
      backgroundColor: backgroundColor,
      appBar: AppBar(
        backgroundColor: primaryColor,
        title: const Text('My Borrowings'),
        centerTitle: true,
        elevation: 4,
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream:
            FirebaseFirestore.instance
                .collection('transactions')
                .where('type', isEqualTo: 'returnable')
                .where('userId', isEqualTo: uid)
                .orderBy('timestamp', descending: true)
                .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return Center(
              child: Text('Error loading borrowings: ${snapshot.error}'),
            );
          }

          final docs = snapshot.data?.docs ?? [];
          if (docs.isEmpty) {
            return const Center(child: Text('No borrowings found.'));
          }

          return ListView.builder(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            itemCount: docs.length,
            itemBuilder: (context, idx) {
              final doc = docs[idx];
              final data = doc.data() as Map<String, dynamic>;
              final txId = doc.id;
              final status = data['status'] as String? ?? 'active';

              final Timestamp? ts = data['timestamp'] as Timestamp?;
              final date =
                  ts != null
                      ? DateFormat(
                        'dd-MM-yy HH:mm',
                      ).format(ts.toDate().toLocal())
                      : 'Unknown';

              final Timestamp? reqTs = data['returnRequestedAt'] as Timestamp?;
              final String? reqDate =
                  reqTs != null
                      ? DateFormat(
                        'dd-MM-yy HH:mm',
                      ).format(reqTs.toDate().toLocal())
                      : null;

              final Timestamp? apprTs = data['returnApprovedAt'] as Timestamp?;
              final String? apprDate =
                  apprTs != null
                      ? DateFormat(
                        'dd-MM-yy HH:mm',
                      ).format(apprTs.toDate().toLocal())
                      : null;

              // Always show the original items
              List<Map<String, dynamic>> items =
                  List<Map<String, dynamic>>.from(data['items'] ?? []);

              _reasonControllers.putIfAbsent(
                txId,
                () => TextEditingController(),
              );

              return Opacity(
                opacity: status == 'pending_return' ? 0.6 : 1.0,
                child: Card(
                  color:
                      status == 'pending_return'
                          ? Colors.grey[200]
                          : Colors.white,
                  elevation: 2,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  margin: const EdgeInsets.symmetric(vertical: 8),
                  child: Padding(
                    padding: const EdgeInsets.all(14),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Borrowed on: $date',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color:
                                status == 'pending_return'
                                    ? errorColor
                                    : textColor,
                          ),
                        ),
                        if (reqDate != null)
                          Padding(
                            padding: const EdgeInsets.only(top: 4),
                            child: Text(
                              'Return requested: $reqDate',
                              style: const TextStyle(color: warningColor),
                            ),
                          ),
                        if (status == 'returned' && apprDate != null)
                          Padding(
                            padding: const EdgeInsets.only(top: 4),
                            child: Text(
                              'Return approved: $apprDate',
                              style: const TextStyle(color: successColor),
                            ),
                          ),
                        const Divider(height: 20),

                        ...items.map((entry) {
                          final itemId = entry['itemId'] as String;
                          final borrowedQty =
                              (entry['quantity'] ?? entry['requestedQty'])
                                  as int;
                          _returnQtyControllers.putIfAbsent(txId, () => {});
                          _returnQtyControllers[txId]!.putIfAbsent(
                            itemId,
                            () => TextEditingController(),
                          );
                          // Check if return request exists and fetch corresponding return qty
                          int? requestedReturnQty;
                          if (status == 'pending_return' &&
                              data['returnRequest']?['items'] != null) {
                            final returnList = List<Map<String, dynamic>>.from(
                              data['returnRequest']['items'],
                            );
                            final matching = returnList.firstWhere(
                              (e) => e['itemId'] == itemId,
                              orElse: () => {},
                            );
                            requestedReturnQty =
                                matching['requestedQty'] as int?;
                          }

                          // ... rest of FutureBuilder code remains unchanged ...
                          return FutureBuilder<DocumentSnapshot>(
                            future:
                                FirebaseFirestore.instance
                                    .collection('items')
                                    .doc(itemId)
                                    .get(),
                            builder: (context, snapItem) {
                              // ... all loading/error handling as before ...

                              if (!snapItem.hasData ||
                                  !snapItem.data!.exists ||
                                  snapItem.data!.data() == null) {
                                return ListTile(
                                  title: const Text('Unknown item'),
                                  trailing: Text(
                                    status == 'pending_return' &&
                                            requestedReturnQty != null
                                        ? 'Returning: $requestedReturnQty'
                                        : 'Qty: $borrowedQty',
                                  ),
                                );
                              }

                              final itemData =
                                  snapItem.data!.data()!
                                      as Map<String, dynamic>;
                              final name =
                                  itemData['name'] as String? ?? 'Unnamed';

                              _itemNames[itemId] = name;

                              return Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  ListTile(
                                    title: Text(
                                      name,
                                      style: const TextStyle(
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                    trailing: Text(
                                      status == 'pending_return' &&
                                              requestedReturnQty != null
                                          ? 'Returning: $requestedReturnQty'
                                          : 'Qty: $borrowedQty',
                                    ),
                                  ),
                                  if (status == 'active')
                                    Padding(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 16,
                                        vertical: 4,
                                      ),
                                      child: TextField(
                                        controller:
                                            _returnQtyControllers[txId]![itemId],
                                        keyboardType: TextInputType.number,
                                        decoration: InputDecoration(
                                          labelText:
                                              'Return Qty (max $borrowedQty)',
                                          filled: true,
                                          fillColor: Colors.white,
                                          border: OutlineInputBorder(
                                            borderRadius: BorderRadius.circular(
                                              12,
                                            ),
                                            borderSide: BorderSide.none,
                                          ),
                                        ),
                                      ),
                                    ),
                                ],
                              );
                            },
                          );
                        }),

                        const SizedBox(height: 12),

                        if (status == 'active') ...[
                          TextField(
                            controller: _reasonControllers[txId],
                            decoration: _decor('Return Note*'),
                          ),
                          const SizedBox(height: 8),
                          SizedBox(
                            width: double.infinity,
                            height: 45,
                            child: ElevatedButton.icon(
                              icon: const Icon(Icons.reply),
                              label: const Text('Request Return'),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: accentColor,
                                foregroundColor: Colors.white,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                              ),
                              onPressed: () async {
                                final reason =
                                    _reasonControllers[txId]!.text.trim();
                                if (reason.isEmpty) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(
                                      content: Text(
                                        'Return reason is required',
                                      ),
                                    ),
                                  );
                                  return;
                                }

                                final returnItems = <Map<String, dynamic>>[];
                                final itemControllers =
                                    _returnQtyControllers[txId]!;

                                bool hasValidQty = false;

                                for (var entry in data['items']) {
                                  final itemId = entry['itemId'] as String;
                                  final borrowedQty = entry['quantity'] as int;
                                  final controller = itemControllers[itemId];
                                  final input =
                                      int.tryParse(controller?.text ?? '0') ??
                                      0;

                                  if (input > 0) {
                                    hasValidQty = true;
                                    if (input > borrowedQty) {
                                      ScaffoldMessenger.of(
                                        context,
                                      ).showSnackBar(
                                        SnackBar(
                                          content: Text(
                                            'Return quantity for item "${_itemNames[itemId] ?? itemId}" exceeds borrowed amount',
                                          ),
                                        ),
                                      );
                                      return;
                                    }
                                    returnItems.add({
                                      'itemId': itemId,
                                      'requestedQty': input,
                                    });
                                  }
                                }

                                if (!hasValidQty) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(
                                      content: Text(
                                        'Select at least one item with return quantity',
                                      ),
                                    ),
                                  );
                                  return;
                                }

                                debugPrint(
                                  "Submitting return for: ${jsonEncode(returnItems)}",
                                );

                                await FirebaseFirestore.instance
                                    .collection('transactions')
                                    .doc(txId)
                                    .update({
                                      'status': 'pending_return',
                                      'returnReason': reason,
                                      'returnRequestedAt':
                                          FieldValue.serverTimestamp(),
                                      'returnRequest': {'items': returnItems},
                                    });

                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                    content: Text('Return requested'),
                                  ),
                                );
                              },
                            ),
                          ),
                        ],
                      ],
                    ),
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
