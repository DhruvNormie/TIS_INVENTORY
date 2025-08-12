import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:tis_inventory/widgets/auth_gate.dart';
import '../../services/transaction_service.dart';


class ManagerHome extends StatelessWidget {
  ManagerHome({Key? key}) : super(key: key);

  final TransactionService _transactionService = TransactionService();

  /// Fetches manager's team by email
  Future<Map<String, String>> _getManagerInfo() async {
    final email = FirebaseAuth.instance.currentUser?.email;
    if (email == null) return {'team': '', 'branch': ''};

    final query = await FirebaseFirestore.instance
        .collection('users')
        .where('email', isEqualTo: email)
        .limit(1)
        .get();

    if (query.docs.isEmpty) return {'team': '', 'branch': ''};

    final data = query.docs.first.data();
    return {
      'team': data['team'] ?? '',
      'branch': data['branch'] ?? '',
    };
  }

  /// Logout function
  Future<void> _logout(BuildContext context) async {
    await FirebaseAuth.instance.signOut();
    Navigator.pushAndRemoveUntil(
      context,
      MaterialPageRoute(builder: (context) => const AuthGate()),
      (route) => false,
    );
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<Map<String, String>>(
      future: _getManagerInfo(),
      builder: (context, managerSnapshot) {
        if (managerSnapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }
        if (!managerSnapshot.hasData || managerSnapshot.data!['team']!.isEmpty) {
          return const Scaffold(
            body: Center(child: Text('No team assigned to this manager')),
          );
        }

        final team = managerSnapshot.data!['team']!;

        return Scaffold(
          appBar: AppBar(
            title: const Text('Manager Dashboard'),
            actions: [
              IconButton(
                icon: const Icon(Icons.logout),
                onPressed: () => _logout(context),
              ),
            ],
          ),
          body: StreamBuilder<QuerySnapshot>(
            stream: FirebaseFirestore.instance
                .collection('transactions')
                .where('status', isEqualTo: 'pending')
                .where('team', isEqualTo: team)
                .snapshots(),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              }
              if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                return const Center(child: Text('No pending orders for your team & branch'));
              }

              final orders = snapshot.data!.docs;

              return ListView.builder(
                itemCount: orders.length,
                itemBuilder: (context, index) {
                  final doc = orders[index];
                  final data = doc.data() as Map<String, dynamic>;

                  return Card(
                    margin: const EdgeInsets.all(8),
                    child: ListTile(
                      title: Text('Order ID: ${doc.id}'),
                      subtitle: Text('Remark: ${data['remark'] ?? ''}'),
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          IconButton(
                            icon: const Icon(Icons.check, color: Colors.green),
                            onPressed: () => _transactionService.approveTransaction(doc.id),
                          ),
                          IconButton(
                            icon: const Icon(Icons.close, color: Colors.red),
                            onPressed: () => _transactionService.rejectTransaction(doc.id),
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
      },
    );
  }
}
