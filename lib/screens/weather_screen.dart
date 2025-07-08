// lib/screens/weather_screen.dart (Only the _buildWeatherAlertsSection method and surrounding context shown)

import 'package:flutter/material.dart';
import 'package:rise_and_shine/managers/city_list_manager.dart';
import 'package:rise_and_shine/models/city.dart';
import 'package:rise_and_shine/models/city_live_info.dart';
import 'package:rise_and_shine/models/hourly_forecast.dart';
import 'package:rise_and_shine/models/daily_forecast.dart';
import 'package:rise_and_shine/models/city_weather_data.dart';
import 'package:rise_and_shine/models/weather_alert.dart';
import 'package:rise_and_shine/providers/app_managers_provider.dart';
import 'package:rise_and_shine/screens/city_selection_screen.dart';
import 'package:rise_and_shine/consts/consts_ui.dart';
import 'package:rise_and_shine/consts/consts_app.dart';
import 'dart:async';
import 'package:intl/intl.dart';
import 'package:rise_and_shine/utils/app_logger.dart';
import 'package:rise_and_shine/utils/weather_icons.dart';
import 'package:rise_and_shine/widgets/toggle_button.dart';
import 'package:rise_and_shine/managers/weather_manager.dart';
import 'package:rise_and_shine/managers/unit_system_manager.dart';


class WeatherScreen extends StatefulWidget {
  const WeatherScreen({super.key});

  @override
  State<WeatherScreen> createState() => _WeatherScreenState();
}

class _WeatherScreenState extends State<WeatherScreen> {
  bool _showAddedConfirmation = false;
  Timer? _addedConfirmationTimer;

  late CityListManager _cityListManager;
  late UnitSystemManager _unitSystemManager;
  late WeatherManager _weatherManager;

  bool _didInitialSetup = false;
  bool _hasMeasuredDailyForecastRowHeight = false;

  final GlobalKey _dailyForecastRowKey = GlobalKey();
  double _dailyForecastRowHeight = kDailyForecastRowHeight;

  @override
  void initState() {
    super.initState();
    logger.d('WeatherScreen: initState called.');
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_didInitialSetup) {
      final appManagers = AppManagers.of(context);
      _cityListManager = appManagers.cityListManager;
      _unitSystemManager = appManagers.unitSystemManager;
      _weatherManager = appManagers.weatherManager;

      logger.d('WeatherScreen: didChangeDependencies called. Managers accessed.');

      _didInitialSetup = true;
    } else {
      logger.d('WeatherScreen: didChangeDependencies called again, initial setup already triggered.');
    }

    if (_cityListManager.selectedCity != null && !_hasMeasuredDailyForecastRowHeight) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _calculateDailyForecastRowHeight();
      });
    }
  }

  void _calculateDailyForecastRowHeight() {
    if (_dailyForecastRowKey.currentContext != null) {
      final RenderBox renderBox = _dailyForecastRowKey.currentContext!.findRenderObject() as RenderBox;
      final newHeight = renderBox.size.height;
      if (newHeight > 0 && newHeight != _dailyForecastRowHeight) {
        setState(() {
          _dailyForecastRowHeight = newHeight;
          _hasMeasuredDailyForecastRowHeight = true;
          logger.d('WeatherScreen: Calculated daily forecast row height: $_dailyForecastRowHeight');
        });
      } else if (newHeight == 0) {
        logger.w('WeatherScreen: Measured daily forecast row height is 0. Using default.');
      }
    } else {
      logger.w('WeatherScreen: _dailyForecastRowKey.currentContext is null. Cannot calculate row height.');
    }
  }

  @override
  void dispose() {
    logger.d('WeatherScreen: dispose called.');
    _addedConfirmationTimer?.cancel();
    super.dispose();
  }

  void _addCityToSavedList(City city) {
    logger.d('WeatherScreen: _addCityToSavedList called for ${city.name}.');
    _cityListManager.addCityToSavedList(city);

    setState(() {
      _showAddedConfirmation = true;
    });

    _addedConfirmationTimer?.cancel();
    _addedConfirmationTimer = Timer(const Duration(seconds: 2), () {
      if (mounted) {
        setState(() {
          _showAddedConfirmation = false;
        });
      }
    });
  }

  void _showOptionsDialog() {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        final unitSystemManager = AppManagers.of(context).unitSystemManager;
        return AlertDialog(
          title: const Text(kOptionsDialogTitle),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(kChooseUnitsLabel),
              const SizedBox(height: 16),
              ListenableBuilder(
                listenable: unitSystemManager,
                builder: (context, child) {
                  return ToggleButton(
                    initialValue: unitSystemManager.isMetricUnits,
                    onChanged: (bool newValue) {
                      unitSystemManager.toggleUnitSystem();
                      logger.d('Unit system changed to Metric: ${unitSystemManager.isMetricUnits}');
                    },
                    leftLabel: kImperialUnitsLabel,
                    rightLabel: 'Metric',
                    activeColor: Colors.blueAccent,
                    inactiveColor: Colors.green,
                    activeTextColor: Colors.white,
                    inactiveTextColor: Colors.blueGrey,
                  );
                },
              ),
            ],
          ),
          actions: <Widget>[
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
              },
              child: const Text(kCloseButton),
            ),
          ],
        );
      },
    );
  }

  AppBar _buildAppBar() {
    return AppBar(
      title: const Text(kWeatherScreenTitle),
      centerTitle: true,
      actions: const [],
    );
  }

  Widget _buildCityName(String cityName) {
    return Text(
      cityName,
      style: const TextStyle(
        fontSize: 28,
        fontWeight: FontWeight.bold,
        color: Colors.blueAccent,
      ),
      textAlign: TextAlign.center,
    );
  }

  Widget _buildLocalTime(String formattedLocalTime) {
    return Text(
      formattedLocalTime,
      style: const TextStyle(
        fontSize: 20,
        fontWeight: FontWeight.w600,
        color: Colors.black87,
      ),
      textAlign: TextAlign.center,
    );
  }

  Widget _buildWeatherStatus(CityLiveInfo liveInfo) {
    if (liveInfo.isLoading) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 6.0),
        child: Text(
          'Fetching weather…',
          style: TextStyle(
            fontSize: 14,
            fontStyle: FontStyle.italic,
            color: Colors.grey,
          ),
          textAlign: TextAlign.center,
        ),
      );
    } else if (liveInfo.error != null) {
      return Column(
        children: [
          const Icon(Icons.warning, color: Colors.orange, size: 28),
          const SizedBox(height: 3),
          Text(
            '$kWeatherError ${liveInfo.error!}',
            style: const TextStyle(color: Colors.red, fontSize: 11),
            textAlign: TextAlign.center,
          ),
        ],
      );
    } else {
      final String tempUnit = _unitSystemManager.isMetricUnits ? '°C' : '°F';
      return Column(
        children: [
          Text(
            getWeatherEmoji(liveInfo.weatherIconCode!),
            style: const TextStyle(fontSize: 50),
          ),
          const SizedBox(height: 3),
          if (liveInfo.description != null)
            Text(
              liveInfo.description!,
              style: const TextStyle(
                fontSize: 15,
                color: Colors.black,
                fontStyle: FontStyle.italic,
              ),
              textAlign: TextAlign.center,
            ),
          const SizedBox(height: 3),
          Text(
            '${liveInfo.temperatureCelsius?.toStringAsFixed(1) ?? ''}$tempUnit',
            style: const TextStyle(
              fontSize: 36,
              fontWeight: FontWeight.bold,
              color: Colors.green,
            ),
          ),
          const SizedBox(height: 8),
          _buildWeatherDetailsText(liveInfo),
          if (liveInfo.uvIndex != null)
            _buildDetailText(kUVIndex, liveInfo.uvIndex!.toStringAsFixed(0)),
        ],
      );
    }
  }

  Widget _buildAddCityButton(City selectedCity, CityListManager manager) {
    const Size buttonSize = Size(55, 28);

    final bool isCityCurrentlySavedForButton = manager.isCitySaved(selectedCity);

    if (!isCityCurrentlySavedForButton && !_showAddedConfirmation) {
      return SizedBox(
        width: buttonSize.width,
        height: buttonSize.height,
        child: Align(
          alignment: Alignment.topRight,
          child: TextButton(
            onPressed: () => _addCityToSavedList(selectedCity),
            style: TextButton.styleFrom(
              foregroundColor: Colors.blue.shade700,
              textStyle: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold),
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
              minimumSize: Size.zero,
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
            ),
            child: const Text(kAddButton),
          ),
        ),
      );
    } else if (_showAddedConfirmation) {
      return SizedBox(
        width: buttonSize.width,
        height: buttonSize.height,
        child: const Align(
          alignment: Alignment.topRight,
          child: Padding(
            padding: EdgeInsets.symmetric(horizontal: 6.0, vertical: 3.0),
            child: Text(
              kAddedConfirmation,
              style: TextStyle(
                color: Colors.green,
                fontSize: 11,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ),
      );
    }
    return SizedBox(
      width: buttonSize.width,
      height: buttonSize.height,
      child: Container(),
    );
  }

  Widget _buildHourlyForecastCardItem({
    required DateTime localForecastTime,
    required String iconCode,
    required double temperatureCelsius,
    double? pop,
    double? windSpeed,
  }) {
    final String unitSymbol = _unitSystemManager.isMetricUnits ? '°C' : '°F';
    final double windThreshold = _weatherManager.getWindSpeedThreshold();
    final bool showWindIcon = windSpeed != null && windSpeed >= windThreshold;

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 6.0, vertical: 1.0),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      elevation: 1,
      child: Container(
        width: 95,
        padding: const EdgeInsets.all(5.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              DateFormat('h a').format(localForecastTime),
              style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 1),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  getWeatherEmoji(iconCode),
                  style: const TextStyle(fontSize: 24),
                ),
                const SizedBox(width: 2),
                if (pop != null && pop > 0)
                  Text(
                    '${(pop * 100).toStringAsFixed(0)}%',
                    style: const TextStyle(fontSize: 8, color: Colors.blueGrey, fontWeight: FontWeight.bold),
                  ),
                if (pop != null && pop > 0 && showWindIcon)
                  const SizedBox(width: 2),
                if (showWindIcon)
                  const Icon(Icons.wind_power, size: 14, color: Colors.blueGrey),
              ],
            ),
            const SizedBox(height: 1),
            Text(
              '${temperatureCelsius.toStringAsFixed(0)}$unitSymbol',
              style: const TextStyle(fontSize: 13, color: Colors.green),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDailyForecastRowItem({
    Key? key,
    required DateTime localForecastDate,
    required String iconCode,
    required double minTemperatureCelsius,
    required double maxTemperatureCelsius,
    double? pop,
    double? windSpeed,
  }) {
    final String unitSymbol = _unitSystemManager.isMetricUnits ? '°C' : '°F';
    final double windThreshold = _weatherManager.getWindSpeedThreshold();
    final bool showWindIcon = windSpeed != null && windSpeed >= windThreshold;

    const double emojiVisualWidth = 26.0;
    const double gapAfterEmoji = 4.0;

    return Padding(
      key: key,
      padding: const EdgeInsets.symmetric(vertical: 5.0, horizontal: 16.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Expanded(
            flex: 2,
            child: Text(
              DateFormat('EEE, MMM d').format(localForecastDate),
              style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
            ),
          ),
          Expanded(
            flex: 2,
            child: LayoutBuilder(
              builder: (BuildContext context, BoxConstraints constraints) {
                final double availableWidth = constraints.maxWidth;
                final double supplementaryIconsStartLeft =
                    (availableWidth / 2) + (emojiVisualWidth / 2) + gapAfterEmoji;

                return Stack(
                  children: [
                    Align(
                      alignment: Alignment.center,
                      child: Text(
                        getWeatherEmoji(iconCode),
                        style: const TextStyle(fontSize: 26),
                      ),
                    ),
                    Positioned(
                      left: supplementaryIconsStartLeft,
                      top: 0,
                      bottom: 0,
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          if (pop != null && pop > 0)
                            Text(
                              '${(pop * 100).toStringAsFixed(0)}%',
                              style: const TextStyle(fontSize: 8, color: Colors.blueGrey, fontWeight: FontWeight.bold),
                            ),
                          if (pop != null && pop > 0 && showWindIcon)
                            const SizedBox(width: 2),
                          if (showWindIcon)
                            const Icon(Icons.wind_power, size: 14, color: Colors.blueGrey),
                        ],
                      ),
                    ),
                  ],
                );
              },
            ),
          ),
          Expanded(
            flex: 2,
            child: Text(
              '${minTemperatureCelsius.toStringAsFixed(0)}$unitSymbol / ${maxTemperatureCelsius.toStringAsFixed(0)}$unitSymbol',
              style: const TextStyle(fontSize: 14, color: Colors.blueGrey),
              textAlign: TextAlign.right,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildWeatherAlertsSection(List<WeatherAlert> alerts, int timezoneOffsetSeconds) {
    if (alerts.isEmpty) {
      return const SizedBox.shrink();
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Padding(
          padding: EdgeInsets.symmetric(vertical: 8.0, horizontal: 16.0),
          child: Text(
            kWeatherAlertsHeading,
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: Colors.red,
            ),
          ),
        ),
        ListView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: alerts.length,
          itemBuilder: (context, index) {
            final alert = alerts[index];
            final localStartTime = alert.startTime.add(Duration(seconds: timezoneOffsetSeconds));
            final localEndTime = alert.endTime.add(Duration(seconds: timezoneOffsetSeconds));

            return Card(
              margin: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 4.0),
              elevation: 2,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              child: Padding(
                padding: const EdgeInsets.all(12.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      alert.event,
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 15,
                        color: Colors.redAccent,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '${DateFormat('MMM d, h:mm a').format(localStartTime)} - ${DateFormat('h:mm a').format(localEndTime)}',
                      style: const TextStyle(fontSize: 12, color: Colors.grey),
                    ),
                    if (alert.severity != null || alert.urgency != null)
                      Text(
                        // FIX: Removed unnecessary braces
                        '$kAlertSeverityLabel ${alert.severity ?? kAlertNotAvailable}, $kAlertUrgencyLabel ${alert.urgency ?? kAlertNotAvailable}',
                        style: const TextStyle(fontSize: 12, color: Colors.blueGrey),
                      ),
                    const SizedBox(height: 8),
                    Text(
                      alert.description,
                      style: const TextStyle(fontSize: 13),
                    ),
                    if (alert.senderName.isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.only(top: 4.0),
                        child: Text(
                          // FIX: Removed unnecessary braces
                          '$kAlertSourceLabel ${alert.senderName}',
                          style: const TextStyle(fontSize: 10, fontStyle: FontStyle.italic, color: Colors.black54),
                        ),
                      ),
                  ],
                ),
              ),
            );
          },
        ),
        const SizedBox(height: 8),
      ],
    );
  }

  Widget _buildMainWeatherCard(CityWeatherData cityWeatherData, CityListManager cityListManager) {
    final City selectedCity = cityWeatherData.city;
    final CityLiveInfo liveInfo = cityWeatherData.liveInfo;
    final List<HourlyForecast> rawHourlyForecasts = cityWeatherData.hourlyForecasts;
    final List<DailyForecast> rawDailyForecasts = cityWeatherData.dailyForecasts;
    final List<WeatherAlert> alerts = cityWeatherData.alerts;

    final List<HourlyForecast> displayHourlyForecasts = rawHourlyForecasts.isNotEmpty
        ? rawHourlyForecasts.skip(1).take(8).toList()
        : [];

    final List<DailyForecast> displayDailyForecasts = rawDailyForecasts.isNotEmpty
        ? rawDailyForecasts.skip(1).take(8).toList()
        : [];

    logger.d('WeatherScreen: rawDailyForecasts length: ${rawDailyForecasts.length}');
    logger.d('WeatherScreen: displayDailyForecasts length (after slicing): ${displayDailyForecasts.length}');

    final DateTime now = DateTime.now().toUtc().add(Duration(seconds: selectedCity.timezoneOffsetSeconds));
    final List<Widget> weatherSections = [];

    weatherSections.add(
      Padding(
        padding: const EdgeInsets.all(6.0),
        child: Card(
          elevation: 6,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
          child: Padding(
            padding: const EdgeInsets.all(12.0),
            child: Stack(
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _buildCityName(selectedCity.name),
                    const SizedBox(height: 4),
                    const SizedBox(height: 4),
                    _buildWeatherStatus(liveInfo),
                  ],
                ),
                _buildAddCityButton(selectedCity, cityListManager),
                Positioned(
                  left: 0,
                  bottom: 0,
                  child: Padding(
                    padding: const EdgeInsets.only(left: 2.0, bottom: 2.0),
                    child: _buildLocalTime(liveInfo.formattedLocalTime),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
    weatherSections.add(const SizedBox(height: 8));

    final List<WeatherAlert> immediateAlerts = alerts.where((alert) =>
        alert.startTime.toUtc().add(Duration(seconds: selectedCity.timezoneOffsetSeconds)).isBefore(now.add(const Duration(hours: 6)))
    ).toList();

    final List<WeatherAlert> futureAlerts = alerts.where((alert) =>
        alert.startTime.toUtc().add(Duration(seconds: selectedCity.timezoneOffsetSeconds)).isAfter(now.add(const Duration(hours: 6)))
    ).toList();


    if (displayHourlyForecasts.isNotEmpty) {
      weatherSections.add(
        const Padding(
          padding: EdgeInsets.symmetric(vertical: 3.0, horizontal: 16.0),
          child: Text(
            kHourlyForecastHeading,
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: Colors.black87,
            ),
          ),
        ),
      );
      weatherSections.add(
        SizedBox(
          height: 100,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            itemCount: displayHourlyForecasts.length,
            itemBuilder: (context, index) {
              final HourlyForecast forecast = displayHourlyForecasts[index];
              final DateTime localForecastTime = forecast.time.add(
                Duration(seconds: selectedCity.timezoneOffsetSeconds),
              );
              return _buildHourlyForecastCardItem(
                localForecastTime: localForecastTime,
                iconCode: forecast.iconCode,
                temperatureCelsius: forecast.temperatureCelsius,
                pop: forecast.pop,
                windSpeed: forecast.windSpeed,
              );
            },
          ),
        ),
      );
      weatherSections.add(const SizedBox(height: 8));
    }

    if (immediateAlerts.isNotEmpty) {
      weatherSections.add(_buildWeatherAlertsSection(immediateAlerts, selectedCity.timezoneOffsetSeconds));
      weatherSections.add(const SizedBox(height: 8));
    }

    if (displayDailyForecasts.isNotEmpty) {
      weatherSections.add(
        const Padding(
          padding: EdgeInsets.symmetric(vertical: 3.0, horizontal: 16.0),
          child: Text(
            kDailyForecastHeading,
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: Colors.black87,
            ),
          ),
        ),
      );
      weatherSections.add(
        SizedBox(
          height: displayDailyForecasts.length * _dailyForecastRowHeight +
              (displayDailyForecasts.isNotEmpty ? (displayDailyForecasts.length - 1) * 1.0 : 0.0),
          child: ListView.separated(
            shrinkWrap: true,
            physics: const ClampingScrollPhysics(),
            itemCount: displayDailyForecasts.length,
            separatorBuilder: (context, index) => const Divider(
              color: Colors.grey,
              thickness: 1,
              height: 1,
              indent: 16,
              endIndent: 16,
            ),
            itemBuilder: (context, index) {
              final DailyForecast forecast = displayDailyForecasts[index];
              final DateTime localForecastDate = forecast.time.add(
                Duration(seconds: selectedCity.timezoneOffsetSeconds),
              );
              return _buildDailyForecastRowItem(
                localForecastDate: localForecastDate,
                iconCode: forecast.iconCode,
                minTemperatureCelsius: forecast.minTemperatureCelsius,
                maxTemperatureCelsius: forecast.maxTemperatureCelsius,
                pop: forecast.pop,
                windSpeed: forecast.windSpeed,
              );
            },
          ),
        ),
      );
      weatherSections.add(const SizedBox(height: 8));
    }

    if (futureAlerts.isNotEmpty) {
      weatherSections.add(_buildWeatherAlertsSection(futureAlerts, selectedCity.timezoneOffsetSeconds));
      weatherSections.add(const SizedBox(height: 8));
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: weatherSections,
    );
  }

  Widget _buildCitiesButton(BuildContext context) {
    return TextButton(
      onPressed: () {
        Navigator.of(context).push(
          MaterialPageRoute<void>(builder: (BuildContext context) => const CitySelectionScreen()),
        );
      },
      style: TextButton.styleFrom(
        foregroundColor: Colors.blue.shade700,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        side: BorderSide(color: Colors.blue.shade300),
      ),
      child: const Text(kCitiesButton, style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
    );
  }

  Widget _buildOptionsButton() {
    return TextButton(
      onPressed: _showOptionsDialog,
      style: TextButton.styleFrom(
        foregroundColor: Colors.grey.shade700,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        side: BorderSide(color: Colors.grey.shade300),
      ),
      child: const Text(kOptionsButton, style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
    );
  }

  Widget _buildLoadingCitiesState() {
    return const Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          CircularProgressIndicator(),
          SizedBox(height: 12),
          Text(kLoadingCities, style: TextStyle(fontSize: 14)),
        ],
      ),
    );
  }

  Widget _buildErrorFetchingCitiesState(String error, CityListManager manager) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(12.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.error_outline, color: Colors.red, size: 45),
            const SizedBox(height: 8),
            Text(
              '$kErrorFetchingCities $error',
              style: const TextStyle(color: Colors.red, fontSize: 14),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: () => _weatherManager.fetchWeatherForCities(manager.allCities),
              child: const Text(kRetryFetchCities, style: TextStyle(fontSize: 14)),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildNoCitySelectedState(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Text(
            kNoCitySelected,
            style: TextStyle(fontSize: 16, color: Colors.grey),
          ),
          const SizedBox(height: 16),
          ElevatedButton(
            onPressed: () {
              Navigator.of(context).push(
                MaterialPageRoute<void>(builder: (BuildContext context) => const CitySelectionScreen()),
              );
            },
            child: const Text(kSelectACity, style: TextStyle(fontSize: 16)),
          ),
        ],
      ),
    );
  }

  Widget _buildDetailText(String label, String value, {Color? valueColor}) {
    return Text(
      '$label $value',
      style: TextStyle(fontSize: 16, color: valueColor ?? Colors.blueGrey),
      textAlign: TextAlign.center,
    );
  }

  Widget _buildWeatherDetailsText(CityLiveInfo liveInfo) {
    final String tempUnit = _unitSystemManager.isMetricUnits ? '°C' : '°F';
    final String speedUnit = _unitSystemManager.isMetricUnits ? 'm/s' : 'mph';
    final double windThreshold = _weatherManager.getWindSpeedThreshold();

    final Color? windColor = (liveInfo.windSpeed != null && liveInfo.windSpeed! >= windThreshold)
        ? Colors.red
        : null;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _buildDetailText(kFeelsLike, '${liveInfo.feelsLike?.toStringAsFixed(1) ?? ''}$tempUnit'),
        _buildDetailText(kHumidity, '${liveInfo.humidity ?? ''}%'),
        _buildDetailText(kWind, '${liveInfo.windSpeed?.toStringAsFixed(1) ?? ''} $speedUnit ${liveInfo.windDirection ?? ''}', valueColor: windColor),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    logger.d('WeatherScreen: build called.');
    final City? selectedCity = AppManagers.of(context).cityListManager.selectedCity;

    final List<DailyForecast> displayDailyForecasts;
    if (selectedCity != null) {
      final CityWeatherData? cityWeatherData = AppManagers.of(context).weatherManager.getWeatherForCity(selectedCity);
      if (cityWeatherData != null && cityWeatherData.dailyForecasts.isNotEmpty) {
        displayDailyForecasts = cityWeatherData.dailyForecasts.skip(1).take(8).toList();
      } else {
        displayDailyForecasts = [];
      }
    } else {
      displayDailyForecasts = [];
    }


    return Scaffold(
      appBar: _buildAppBar(),
      body: Column(
        children: [
          Expanded(
            child: SingleChildScrollView(
              child: ListenableBuilder(
                listenable: _cityListManager,
                builder: (BuildContext context, Widget? child) {
                  final City? currentSelectedCity = _cityListManager.selectedCity;

                  if (currentSelectedCity == null) {
                    logger.d('WeatherScreen: Build method: No city selected, showing selection prompt.');
                    return _buildNoCitySelectedState(context);
                  }

                  logger.d('WeatherScreen: Build method: Selected city is ${currentSelectedCity.name}. Proceeding to StreamBuilder for weather.');
                  return StreamBuilder<Map<int, CityWeatherData>>(
                    stream: _weatherManager.weatherDataStream,
                    builder: (BuildContext context, AsyncSnapshot<Map<int, CityWeatherData>> snapshot) {
                      final CityWeatherData? cityWeatherData = snapshot.data?[currentSelectedCity.hashCode];

                      if (cityWeatherData == null || cityWeatherData.liveInfo.isLoading) {
                        logger.d('WeatherScreen: Build method: Weather data for ${currentSelectedCity.name} is null or loading. Showing progress.');
                        return _buildLoadingCitiesState();
                      } else if (cityWeatherData.liveInfo.error != null) {
                        logger.e('WeatherScreen: Build method: Weather data for ${currentSelectedCity.name} has error: ${cityWeatherData.liveInfo.error}');
                        return _buildErrorFetchingCitiesState(cityWeatherData.liveInfo.error!, _cityListManager);
                      }

                      logger.d('WeatherScreen: Build method: Displaying weather for ${currentSelectedCity.name}.');
                      return _buildMainWeatherCard(cityWeatherData, _cityListManager);
                    },
                  );
                },
              ),
            ),
          ),
          if (!_hasMeasuredDailyForecastRowHeight && displayDailyForecasts.isNotEmpty && selectedCity != null)
            Offstage(
              offstage: true,
              child: _buildDailyForecastRowItem(
                key: _dailyForecastRowKey,
                localForecastDate: displayDailyForecasts[0].time.add(Duration(seconds: selectedCity.timezoneOffsetSeconds)),
                iconCode: displayDailyForecasts[0].iconCode,
                minTemperatureCelsius: displayDailyForecasts[0].minTemperatureCelsius,
                maxTemperatureCelsius: displayDailyForecasts[0].maxTemperatureCelsius,
                pop: displayDailyForecasts[0].pop,
                windSpeed: displayDailyForecasts[0].windSpeed,
              ),
            ),
          Padding(
            padding: const EdgeInsets.only(right: 16.0, bottom: 16.0, left: 16.0),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                _buildOptionsButton(),
                _buildCitiesButton(context),
              ],
            ),
          ),
        ],
      ),
    );
  }
}