import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class RoleService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  /// Fetches the user role ('admin' or 'user') from 'users' collection
 Future<String?> getRole(String uid) async {
  final usersRef = FirebaseFirestore.instance.collection('users');

  // Try UID doc
  var doc = await usersRef.doc(uid).get();
  if (!doc.exists) {
    // Fall back to email doc
    final email = FirebaseAuth.instance.currentUser?.email;
    if (email != null) {
      doc = await usersRef.doc(email).get();
    }
  }

  return doc.data()?['role'] as String?;
}

}
