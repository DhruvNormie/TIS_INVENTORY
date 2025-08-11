// lib/services/transaction_service.dart

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class TransactionService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
Future<void> createTransaction({
  required bool isReturnable,
  required String remark,
  String? reason,
  required Map<String, int> items,
}) async {
  final user = FirebaseAuth.instance.currentUser!;
  final email = user.email ?? '';
  final uid = user.uid;

  final batchWrite = _firestore.batch();
  final txRef = _firestore.collection('transactions').doc();

  // 1. Create transaction document
  batchWrite.set(txRef, {
    'userId': uid,
    'userEmail': email,
    'status': 'active',
    'type': isReturnable ? 'returnable' : 'non_returnable',
    'remark': remark,
    'reason': reason,
    'items': items.entries
        .map((e) => {'itemId': e.key, 'quantity': e.value})
        .toList(),
    'timestamp': FieldValue.serverTimestamp(),
  });

  // 2. Deduct stock FIFO for each item
  for (var entry in items.entries) {
    String itemId = entry.key;
    int qtyNeeded = entry.value;

    // Query batches ordered by oldest first
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
    // Batch completely used up, delete it
    batchWrite.delete(batchDoc.reference);
  } else {
    // Partial deduction
    batchWrite.update(batchDoc.reference, {
      'quantity': FieldValue.increment(-deductQty),
    });
  }

  qtyNeeded -= deductQty;
}

    // If still quantity needed after all batches processed
    if (qtyNeeded > 0) {
      throw Exception("Not enough stock available for item $itemId");
    }

    // Update totalQuantity on the parent item doc
    final itemRef = _firestore.collection('items').doc(itemId);
    batchWrite.update(itemRef, {
      'totalQuantity': FieldValue.increment(-entry.value),
    });
  }

  // 3. Commit all updates atomically
  await batchWrite.commit();
}

}
