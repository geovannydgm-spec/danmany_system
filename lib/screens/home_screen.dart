import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'user_screen.dart';
import 'admin_screen.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final User? user = FirebaseAuth.instance.currentUser;
    final bool esAdministrador = user?.email == 'geovanny.dgm@gmail.com';

    if (!esAdministrador) {
      return const UserScreen(role: 'maestro');
    } else {
      return const AdminScreen();
    }
  }
}