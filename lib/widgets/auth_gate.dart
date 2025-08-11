import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../services/role_service.dart';
import '../../screens/sign_in_page.dart';
import '../../screens/admin_home.dart';
import '../../screens/user_home.dart';

class AuthGate extends StatelessWidget {
  const AuthGate({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final user = context.watch<User?>();
    print(user);
    if (user == null) {
      return const SignInPage();
      
    }return FutureBuilder<String?>(
  future: RoleService().getRole(user.uid),
  builder: (context, snapshot) {
    if (snapshot.connectionState == ConnectionState.waiting) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }
    if (snapshot.hasError) {
      return const Scaffold(
        body: Center(child: Text('Error loading role')),
      );
    }
    final role = snapshot.data ?? '';
    if (role == 'admin') {
      return const AdminHome();
    }  else {
      return const UserHome();
    }
  },
);

  }
}
