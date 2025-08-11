import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';

class LaptopTransactionsPage extends StatelessWidget {
  const LaptopTransactionsPage({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    const Color backgroundColor = Color(0xFFF4F6FD);
    const Color primaryColor = Color.fromARGB(255, 0, 183, 255);
    const Color textColor = Color(0xFF212121);
    const Color cardColor = Colors.white;
    const Color iconColor = Color(0xFF3949AB);
    // const Color accentColor = Color(0xFF00ACC1);

    final Stream<QuerySnapshot> transactionsStream =
        FirebaseFirestore.instance
            .collection('laptop_transactions')
            .snapshots();

    return Scaffold(
      backgroundColor: backgroundColor,
      appBar: AppBar(
        backgroundColor: primaryColor,
        centerTitle: true,
        title: const Text('Laptop Transactions'),
        elevation: 4,
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: transactionsStream,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return Center(child: Text('Error: ${snapshot.error}'));
          }

          final docs = snapshot.data?.docs ?? [];
          if (docs.isEmpty) {
            return const Center(child: Text('No laptop transactions found.'));
          }

          final List<Map<String, dynamic>> items =
              docs.map((doc) {
                final data = doc.data() as Map<String, dynamic>;
                final String status = (data['status'] ?? 'active').toString();
                final Timestamp? ts = data['borrowTime'] as Timestamp?;
                return {'doc': doc, 'status': status, 'timestamp': ts};
              }).toList();

          items.sort((a, b) {
            final statusA = a['status'].toString();
            final statusB = b['status'].toString();
            if (statusA == 'returned' && statusB != 'returned') return 1;
            if (statusA != 'returned' && statusB == 'returned') return -1;
            final tsA = a['timestamp'] as Timestamp?;
            final tsB = b['timestamp'] as Timestamp?;
            if (tsA == null || tsB == null) return 0;
            return tsA.compareTo(tsB);
          });

          return ListView.builder(
            padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
            itemCount: items.length,
            itemBuilder: (context, index) {
              final doc = items[index]['doc'] as QueryDocumentSnapshot;
              final data = doc.data() as Map<String, dynamic>;

              final userName = (data['userName'] ?? '').toString();
              final userEmail = (data['userEmail'] ?? '').toString();
              final status = (data['status'] ?? 'active').toString();
              final ts = data['borrowTime'] as Timestamp?;
              final reqTs = data['returnRequestedAt'] as Timestamp?;
              final apprTs = data['returnApprovedAt'] as Timestamp?;
              final itemName =
                  (data['itemName'] ?? 'Unknown Laptop').toString();

              final String date =
                  ts != null
                      ? DateFormat(
                        'dd-MM-yy HH:mm',
                      ).format(ts.toDate().toLocal())
                      : 'Unknown';

              final String? reqDate =
                  reqTs != null
                      ? DateFormat(
                        'dd-MM-yy HH:mm',
                      ).format(reqTs.toDate().toLocal())
                      : null;

              final String? apprDate =
                  apprTs != null
                      ? DateFormat(
                        'dd-MM-yy HH:mm',
                      ).format(apprTs.toDate().toLocal())
                      : null;

              final bool isReturned = status == 'returned';
              final bool isOverdue =
                  ts != null &&
                  !isReturned &&
                  DateTime.now().difference(ts.toDate().toLocal()) >
                      const Duration(hours: 24);

              return Opacity(
                opacity: status == 'pending_return' ? 0.6 : 1.0,
                child: Card(
                  color: cardColor,
                  elevation: 2,
                  margin: const EdgeInsets.symmetric(vertical: 8),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(14),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // ─ Title
                        Text(
                          userName.isNotEmpty
                              ? 'Laptop by $userName'
                              : 'Laptop by $userEmail',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: isOverdue ? Colors.red : textColor,
                          ),
                        ),
                        const SizedBox(height: 4),

                        // ─ Email
                        Text(
                          'Email: $userEmail',
                          style: const TextStyle(fontSize: 14),
                        ),

                        // ─ Borrow Date
                        const SizedBox(height: 4),
                        Text(
                          'Date: $date',
                          style: TextStyle(
                            fontSize: 14,
                            color: isOverdue ? Colors.red : textColor,
                          ),
                        ),

                        // ─ Return Requested
                        if (reqDate != null)
                          Padding(
                            padding: const EdgeInsets.only(top: 4),
                            child: Text(
                              'Return requested: $reqDate',
                              style: const TextStyle(
                                fontSize: 14,
                                color: Colors.orange,
                              ),
                            ),
                          ),

                        // ─ Return Approved
                        if (status == 'returned' && apprDate != null)
                          Padding(
                            padding: const EdgeInsets.only(top: 4),
                            child: Text(
                              'Return approved: $apprDate',
                              style: const TextStyle(
                                fontSize: 14,
                                color: Colors.green,
                              ),
                            ),
                          ),

                        const Divider(height: 20),

                        // ─ Laptop item name
                        ListTile(
                          contentPadding: EdgeInsets.zero,
                          leading: const Icon(
                            Icons.laptop_mac,
                            color: iconColor,
                          ),
                          title: Text(
                            itemName,
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                            ),
                          ),
                          trailing: const SizedBox.shrink(), // No quantity
                        ),
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
