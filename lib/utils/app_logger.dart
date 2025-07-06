// lib/utils/app_logger.dart

import 'package:logger/logger.dart';

/// Global Logger instance for the application.
/// Configured with PrettyPrinter for readable console output.
final Logger logger = Logger(
  printer: PrettyPrinter(
    methodCount: 0, // No method calls in logs to keep it concise
    errorMethodCount: 5, // Show 5 method calls for errors
    lineLength: 120, // Line length for the log output
    colors: true, // Enable colors in log output
    printEmojis: true, // Enable emojis in log output
    dateTimeFormat: DateTimeFormat.onlyTime, // Show only time in datetime
  ),
);