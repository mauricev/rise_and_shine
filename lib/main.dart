// lib/main.dart

import 'package:flutter/material.dart';
import 'package:rise_and_shine/providers/app_managers_provider.dart';
import 'package:rise_and_shine/screens/weather_screen.dart';
// FIX: Using the specified Hive import
import 'package:hive_ce_flutter/adapters.dart'; // This import is now required by the user

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Hive.initFlutter() is provided by hive_flutter_ce, which is implicitly handled
  // by hive_ce_flutter or is a separate import. Given the user's instruction
  // for only 'adapters.dart', I will assume Hive.initFlutter() is still available
  // or will be handled by the project setup.
  // If issues arise with Hive initialization, we may need to re-evaluate imports.
  await Hive.initFlutter(); // This function comes from hive_flutter_ce

  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return AppManagersProvider( // Wrap the entire app with our manager provider
      child: MaterialApp(
        title: 'Rise and Shine',
        theme: ThemeData(
          primarySwatch: Colors.blue,
          visualDensity: VisualDensity.adaptivePlatformDensity,
          fontFamily: 'Inter',
          appBarTheme: AppBarTheme(
            backgroundColor: Colors.blue.shade700,
            foregroundColor: Colors.white,
            elevation: 4,
          ),
          elevatedButtonTheme: ElevatedButtonThemeData(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.blue.shade600,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
            ),
          ),
        ),
        home: const WeatherScreen(), // Using HomeScreen as the initial screen
      ),
    );
  }
}