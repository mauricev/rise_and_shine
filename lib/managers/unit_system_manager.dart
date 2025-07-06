// lib/managers/unit_system_manager.dart

import 'package:flutter/foundation.dart';
import 'package:hive_ce_flutter/hive_flutter.dart';
import 'package:rise_and_shine/utils/app_logger.dart';
import 'dart:async'; // FIX: Added missing import for Completer


class UnitSystemManager extends ChangeNotifier {
  static const String _unitBoxName = 'appSettingsBox';
  static const String _isMetricKey = 'isMetricUnits';
  late Box _unitBox;

  bool _isMetricUnits = false; // Default to English (false means English)

  bool get isMetricUnits => _isMetricUnits;

  final Completer<void> _initCompleter = Completer<void>();
  Future<void> get initialized => _initCompleter.future;

  UnitSystemManager() {
    _initialize();
  }

  Future<void> _initialize() async {
    try {
      if (!Hive.isBoxOpen(_unitBoxName)) {
        _unitBox = await Hive.openBox(_unitBoxName);
        logger.d('UnitSystemManager: Hive box "$_unitBoxName" opened.');
      } else {
        _unitBox = Hive.box(_unitBoxName);
        logger.d('UnitSystemManager: Hive box "$_unitBoxName" already open.');
      }

      _isMetricUnits = _unitBox.get(_isMetricKey, defaultValue: false) as bool;
      logger.d('UnitSystemManager: Initial unit system loaded: ${_isMetricUnits ? "Metric" : "English"}');
      _initCompleter.complete();
    } catch (e) {
      logger.e('UnitSystemManager: Error initializing Hive or loading unit preference: $e', error: e);
      _initCompleter.completeError(e);
    }
  }

  Future<void> toggleUnitSystem() async {
    _isMetricUnits = !_isMetricUnits;
    await _unitBox.put(_isMetricKey, _isMetricUnits);
    logger.d('UnitSystemManager: Unit system toggled to: ${_isMetricUnits ? "Metric" : "English"}');
    notifyListeners();
  }

  @override
  void dispose() {
    logger.d('UnitSystemManager: dispose called. Closing unit box.');
    _unitBox.close();
    super.dispose();
  }
}