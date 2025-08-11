import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'admin_home.dart';

class PendingAccountsPage extends StatelessWidget {
  const PendingAccountsPage({Key? key}) : super(key: key);
  Future<void> _approveAccount(String email, BuildContext context) async {
    try {
      final docRef = FirebaseFirestore.instance
          .collection('pending_users')
          .doc(email);
      final docSnapshot = await docRef.get();

      if (!docSnapshot.exists) {
        if (!context.mounted) return;
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('User not found.')));
        return;
      }

      final userData = docSnapshot.data()!;
      final password = userData['password'];

      try {
        await FirebaseAuth.instance.createUserWithEmailAndPassword(
          email: email,
          password: password,
        );
      } on FirebaseAuthException catch (e) {
        if (e.code != 'email-already-in-use') throw e;
      }
      userData.remove('password');
      userData['status'] = 'approved';

      await FirebaseFirestore.instance
          .collection('users')
          .doc(email)
          .set(userData);
      await docRef.delete();

      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Account approved and Firebase user created.'),
        ),
      );
    } catch (e) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Error approving account: $e')));
    }
  }

  Future<void> _rejectAccount(String email, BuildContext context) async {
    try {
      await FirebaseFirestore.instance
          .collection('pending_users')
          .doc(email)
          .delete();

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Account rejected and removed.')),
      );
    } catch (e) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Error rejecting account: $e')));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Pending Account Approvals'),
        backgroundColor: const Color.fromARGB(255, 0, 183, 255),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () {
            Navigator.pushReplacement(
              context,
              MaterialPageRoute(builder: (context) => const AdminHome()),
            );
          },
        ),
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream:
            FirebaseFirestore.instance
                .collection('pending_users')
                .orderBy('createdAt', descending: true)
                .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
            return const Center(child: Text('No pending account requests.'));
          }

          final pendingUsers = snapshot.data!.docs;

          return ListView.builder(
            itemCount: pendingUsers.length,
            itemBuilder: (context, index) {
              final user = pendingUsers[index];
              final email = user['email'];
              final role = user['role'];
              final timestamp =
                  user['createdAt']?.toDate()?.toString().split('.')[0] ??
                  'Unknown';

              return Card(
                margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                child: ListTile(
                  leading: const Icon(Icons.person_outline, color: Colors.teal),
                  title: Text(email),
                  subtitle: Text('Role: $role\nRequested: $timestamp'),
                  isThreeLine: true,
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      IconButton(
                        icon: const Icon(
                          Icons.check_circle,
                          color: Colors.green,
                        ),
                        tooltip: 'Approve',
                        onPressed: () => _approveAccount(email, context),
                      ),
                      IconButton(
                        icon: const Icon(Icons.cancel, color: Colors.red),
                        tooltip: 'Reject',
                        onPressed: () => _rejectAccount(email, context),
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
