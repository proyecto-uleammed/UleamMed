import 'package:flutter/material.dart';
import 'screens/home_screen.dart';
import 'theme/app_theme.dart';

void main() {
  runApp(const UleamMedApp());
}

class UleamMedApp extends StatelessWidget {
  const UleamMedApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'UleamMed',
      debugShowCheckedModeBanner: false,
      theme: buildAppTheme(),
      home: const HomeScreen(),
    );
  }
}
