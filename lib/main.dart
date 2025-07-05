// lib/main.dart

import 'package:flutter/material.dart';
import 'package:hive_ce_flutter/adapters.dart';
import 'package:path_provider/path_provider.dart';
import 'package:rise_and_shine/providers/app_managers_provider.dart';
import 'package:rise_and_shine/screens/weather_screen.dart';
import 'package:logger/logger.dart';

// No need to import .g.dart files if not using generated TypeAdapters
// import 'package:rise_and_shine/models/city.g.dart';
// import 'package:rise_and_shine/models/city_live_info.g.dart';
// import 'package:rise_and_shine/models/hourly_forecast.g.dart';
// import 'package:rise_and_shine/models/daily_forecast.g.dart';


final Logger _logger = Logger(
  printer: PrettyPrinter(
    methodCount: 0,
    errorMethodCount: 5,
    lineLength: 120,
    colors: true,
    printEmojis: true,
    dateTimeFormat: DateTimeFormat.onlyTime,
  ),
);

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize Hive
  try {
    final appDocumentDir = await getApplicationDocumentsDirectory();
    await Hive.initFlutter(appDocumentDir.path);
    _logger.d('Hive initialized at: ${appDocumentDir.path}');

    // FIX: TEMPORARY DEBUGGING STEP: Clear the Hive box on every startup
    // This will delete any old, potentially corrupted data.
    // REMOVE THIS LINE AFTER DEBUGGING IS COMPLETE.
    //await Hive.deleteBoxFromDisk('savedCitiesBox');
    //_logger.d('Hive box "savedCitiesBox" cleared for debugging.');


    // We are not using generated TypeAdapters, so no registerAdapter calls here.
    // If you were using them, they would be here:
    // Hive.registerAdapter(CityAdapter());
    // Hive.registerAdapter(CityLiveInfoAdapter());
    // Hive.registerAdapter(HourlyForecastAdapter());
    // Hive.registerAdapter(DailyForecastAdapter());

  } catch (e) {
    _logger.e('Error initializing Hive or registering adapters: $e');
    // Depending on severity, you might want to show an error screen or exit
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