import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:provider/provider.dart';
import 'package:tis_inventory/screens/admin_home.dart';
import 'package:tis_inventory/services/migrations.dart';
import 'services/auth_service.dart';
import 'widgets/auth_gate.dart';
import 'firebase_options.dart';

import 'package:firebase_auth/firebase_auth.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
 await validateItemAndBatch("dhruv","FRC Mechanical","Dadar",2);
  await FirebaseAuth.instance.setPersistence(Persistence.LOCAL);
  runApp(const InventoryApp());
}

class InventoryApp extends StatelessWidget {
  const InventoryApp({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => AuthService()),
        StreamProvider(
          create: (context) => context.read<AuthService>().authStateChanges,
          initialData: null,
        ),
      ],
      child: MaterialApp(
        title: 'Inventory App',
        theme: ThemeData(primarySwatch: Colors.blue),
        home: const AuthGate(),
        debugShowCheckedModeBanner: false,
        builder: (context, child) {
          return Container(
            color: const Color.fromARGB(
              255,
              28,
              0,
              27,
            ), // 🔳 Background color for the whole app
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 500),
                child: child ?? const SizedBox(),
              ),
            ),
          );
        },
      ),
    );
  }
}

// import 'package:flutter/material.dart';

// void main() {
//   runApp(
//     MaterialApp(
//       home: Scaffold(
//         appBar: AppBar(title: Text('No Firebase')),
//         body: Center(child: Text('App runs without Firebase')),
//       ),
//     ),
//   );
// }
