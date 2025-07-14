// lib/main.dart

import 'package:flutter/material.dart';
import 'package:hive_ce_flutter/hive_flutter.dart';
import 'package:path_provider/path_provider.dart';
import 'package:rise_and_shine/providers/app_managers_provider.dart';
import 'package:rise_and_shine/screens/weather_screen.dart';
// REMOVED: import 'package:logger/logger.dart'; // No longer needed here
import 'package:rise_and_shine/utils/app_logger.dart'; // NEW: Import the global logger


// REMOVED: final Logger _logger = Logger(...); // No longer declared here

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize Hive
  try {
    final appDocumentDir = await getApplicationDocumentsDirectory();
    await Hive.initFlutter(appDocumentDir.path);
    //logger.d('Hive initialized at: ${appDocumentDir.path}'); // Use global logger

    // REMOVED: await Hive.deleteBoxFromDisk('savedCitiesBox'); // This temporary line is now removed.
    // _logger.d('Hive box "savedCitiesBox" cleared for debugging.'); // This log is also removed.

  } catch (e) {
    logger.e('Error initializing Hive: $e'); // Use global logger
  }

  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return AppManagersProvider(
      child: MaterialApp(
        title: 'Rise & Shine Weather',
        theme: ThemeData(
          primarySwatch: Colors.blue,
          visualDensity: VisualDensity.adaptivePlatformDensity,
          appBarTheme: const AppBarTheme(
            backgroundColor: Colors.white,
            foregroundColor: Colors.black,
            elevation: 1,
          ),
        ),
        home: const WeatherScreen(),
      ),
    );
  }
}