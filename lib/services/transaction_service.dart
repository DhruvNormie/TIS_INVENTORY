import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class TransactionService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  /// Step 1 - Create transaction as pending
   Future<void> createTransactionPending({
  required bool isReturnable,
  required String remark,
  String? reason,
  required Map<String, int> items,
}) async {
  final user = FirebaseAuth.instance.currentUser!;
final email = user.email ?? '';
final uid=user.uid;
// Get team from user profile by email
final query = await _firestore
    .collection('users')
    .where('email', isEqualTo: email)
    .limit(1)
    .get();

String team = '';
//String branch = '';

if (query.docs.isNotEmpty) {
  final data = query.docs.first.data();
  team = data['team'] ?? '';
 // branch = data['branch'] ?? '';
}

  await _firestore.collection('transactions').add({
    'userId': uid,
    'userEmail': email,
    'team': team, // <-- store team
    'status': 'pending',
    'type': isReturnable ? 'returnable' : 'non_returnable',
    'remark': remark,
    'reason': reason,
    'items': items.entries
        .map((e) => {'itemId': e.key, 'quantity': e.value})
        .toList(),
    'timestamp': FieldValue.serverTimestamp(),
  });
}

  /// Step 2 - Approve transaction and deduct stock
  Future<void> approveTransaction(String transactionId) async {
    final txDoc = await _firestore.collection('transactions').doc(transactionId).get();
    if (!txDoc.exists) throw Exception("Transaction not found");

    final data = txDoc.data()!;
    final items = (data['items'] as List)
        .map((e) => Map<String, dynamic>.from(e))
        .toList();

    final batchWrite = _firestore.batch();

    // Deduct stock FIFO
    for (var entry in items) {
      String itemId = entry['itemId'];
      int qtyNeeded = entry['quantity'];

      final batchesSnapshot = await _firestore
          .collection('items')
          .doc(itemId)
          .collection('batches')
          .orderBy('createdAt')
          .get();

      for (var batchDoc in batchesSnapshot.docs) {
        if (qtyNeeded <= 0) break;

        int batchQty = batchDoc['quantity'];
        if (batchQty <= 0) continue;

        int deductQty = qtyNeeded > batchQty ? batchQty : qtyNeeded;

        if (batchQty == deductQty) {
          batchWrite.delete(batchDoc.reference);
        } else {
          batchWrite.update(batchDoc.reference, {
            'quantity': FieldValue.increment(-deductQty),
          });
        }

        qtyNeeded -= deductQty;
      }

      if (qtyNeeded > 0) {
        throw Exception("Not enough stock available for item $itemId");
      }

      final itemRef = _firestore.collection('items').doc(itemId);
      batchWrite.update(itemRef, {
        'totalQuantity': FieldValue.increment(-entry['quantity']),
      });
    }

    // Update transaction status
    batchWrite.update(txDoc.reference, {'status': 'active'});

    await batchWrite.commit();
  }

  /// Step 3 - Reject transaction
  Future<void> rejectTransaction(String transactionId) async {
    await _firestore.collection('transactions').doc(transactionId).update({
      'status': 'rejected',
    });
  }
}
