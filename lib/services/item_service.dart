import 'package:cloud_firestore/cloud_firestore.dart';

/// Service for CRUD operations on inventory items
class ItemService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  /// Adds a new item document to 'items' collection
  Future<void> addItem({
    required String name,
    required String teamname, // was: sku
    required String location, // was: category
    required double price,
    required int quantity,
  }) async {
    await _firestore.collection('items').add({
      'name': name,
      'teamname': teamname,
      'location': location,
      'price': price,
      'quantity': quantity,
      'createdAt': Timestamp.now(), // Server-side timestamp
    });
  }

  // TODO: Implement updateItem, deleteItem, etc.
}
