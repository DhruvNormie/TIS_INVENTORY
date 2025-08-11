import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';

class AdjustmentListPage extends StatelessWidget {
  const AdjustmentListPage({Key? key}) : super(key: key);

  String _formatTimestamp(Timestamp ts) {
    final dt = ts.toDate();
    return DateFormat.yMMMd().add_jm().format(dt);
  }

  @override
  Widget build(BuildContext context) {
    const Color backgroundColor = Color(0xFFF4F6FD);
    const Color primaryColor = Color.fromARGB(255, 0, 183, 255);
    const Color textColor = Color(0xFF212121);
    const Color cardColor = Colors.white;
    // const Color iconColor = Color(0xFF3949AB);
    // const Color accentColor = Color(0xFF00ACC1);

    return Scaffold(
      backgroundColor: backgroundColor,
      appBar: AppBar(
        backgroundColor: primaryColor,
        title: const Text('Quantity Adjustments'),
        centerTitle: true,
        elevation: 4,
      ),
      body: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
        stream:
            FirebaseFirestore.instance
                .collection('adjustments')
                .orderBy('timestamp', descending: true)
                .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
            return const Center(child: Text('No adjustments recorded.'));
          }

          final docs = snapshot.data!.docs;
          return ListView.separated(
            padding: const EdgeInsets.all(16),
            separatorBuilder: (_, __) => const SizedBox(height: 12),
            itemCount: docs.length,
            itemBuilder: (context, index) {
              final data = docs[index].data();

              final itemName = data['itemName'] as String? ?? '—';
              final oldQty = data['oldQuantity'] as int? ?? 0;
              final newQty = data['newQuantity'] as int? ?? 0;
              final reason = data['reason'] as String? ?? '';
              final email = data['modifiedByEmail'] as String? ?? '—';
              final ts = data['timestamp'] as Timestamp?;

              return Card(
                color: cardColor,
                elevation: 2,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(14),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Item title
                      Text(
                        itemName,
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: textColor,
                        ),
                      ),
                      const SizedBox(height: 6),

                      // Quantity
                      Text(
                        'Quantity: $oldQty → $newQty',
                        style: const TextStyle(fontSize: 14),
                      ),
                      const SizedBox(height: 2),

                      // Reason
                      if (reason.isNotEmpty)
                        Text(
                          'Reason: $reason',
                          style: const TextStyle(fontSize: 14),
                        ),
                      const SizedBox(height: 2),

                      // Modified by
                      Text('By: $email', style: const TextStyle(fontSize: 14)),

                      // Timestamp
                      if (ts != null)
                        Padding(
                          padding: const EdgeInsets.only(top: 2),
                          child: Text(
                            'When: ${_formatTimestamp(ts)}',
                            style: TextStyle(
                              fontSize: 13,
                              color: textColor.withOpacity(0.7),
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
      ),
    );
  }
}
