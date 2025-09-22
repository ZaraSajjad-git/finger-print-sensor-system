import 'package:flutter/material.dart';
import 'screens/login_screen.dart';
import 'screens/finger_print_authentication_screen.dart';

void main() {
  runApp(const FingerPrintApp());
}

class FingerPrintApp extends StatelessWidget {
  const FingerPrintApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      home: const LoginScreen(),
      routes: {
        '/login': (context) => const LoginScreen(),
        '/dashboard': (context) => const FingerPrintAuthenticationScreen(),
      },
    );
  }
}
