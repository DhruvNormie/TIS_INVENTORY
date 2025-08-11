import 'package:flutter/widgets.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../firebase_options.dart'; // Adjust path if needed

Future<void> validateItemAndBatch(String name, String team, String branch, int expectedBatchCount) async {
  final query = await FirebaseFirestore.instance.collection('items')
    .where('name', isEqualTo: name)
    .where('teamname', isEqualTo: team)
    .where('branch', isEqualTo: branch)
    .get();

  if (query.docs.length > 1) {
    print('Validation failed: Duplicate items found!');
  } else if (query.docs.isEmpty) {
    print('Validation failed: Item not found!');
  } else {
    final itemDoc = query.docs.first;
    final batchesSnapshot = await itemDoc.reference.collection('batches').get();
    print('Batch count: ${batchesSnapshot.docs.length}');
    if (batchesSnapshot.docs.length != expectedBatchCount) {
      print('Validation failed: Expected $expectedBatchCount batches but found ${batchesSnapshot.docs.length}');
    } else {
      print('Validation passed: No duplicates and correct number of batches.');
    }
  }
}
