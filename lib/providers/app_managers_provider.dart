// lib/providers/app_managers_provider.dart

import 'package:flutter/material.dart';
import 'package:rise_and_shine/managers/city_list_manager.dart';

class AppManagersProvider extends StatefulWidget {
  final Widget child;

  const AppManagersProvider({super.key, required this.child});

  static AppManagersProviderState of(BuildContext context) {
    final AppManagersProviderState? result =
    context.findAncestorStateOfType<AppManagersProviderState>();
    if (result != null) {
      return result;
    }
    throw FlutterError('AppManagersProvider not found in context. '
        'Wrap your widget tree with AppManagersProvider.');
  }

  @override
  AppManagersProviderState createState() => AppManagersProviderState();
}

class AppManagersProviderState extends State<AppManagersProvider> {
  late final CityListManager cityListManager;

  @override
  void initState() {
    super.initState();
    // Removed: final SearchCitiesService searchCitiesService = SearchCitiesService();
    // SearchCitiesService is now instantiated within CityListManager
    cityListManager = CityListManager(); // No parameters needed here anymore
  }

  @override
  void dispose() {
    cityListManager.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return _AppManagersInheritedWidget(
      cityListManager: cityListManager,
      child: widget.child,
    );
  }
}

class _AppManagersInheritedWidget extends InheritedWidget {
  const _AppManagersInheritedWidget({
    required this.cityListManager,
    required super.child,
  });

  final CityListManager cityListManager;

  static T? _getManager<T extends Object>(BuildContext context) {
    final _AppManagersInheritedWidget? inherited =
    context.dependOnInheritedWidgetOfExactType<_AppManagersInheritedWidget>();

    if (inherited == null) {
      return null;
    }

    if (T == CityListManager) return inherited.cityListManager as T;

    return null;
  }

  @override
  bool updateShouldNotify(_AppManagersInheritedWidget oldWidget) {
    return false;
  }
}

extension BuildContextManagerExtensions on BuildContext {
  CityListManager get cityListManager => _AppManagersInheritedWidget._getManager<CityListManager>(this)!;
}