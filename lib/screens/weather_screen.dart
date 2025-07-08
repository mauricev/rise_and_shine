// lib/screens/weather_screen.dart

import 'dart:async';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:rise_and_shine/managers/city_list_manager.dart';
import 'package:rise_and_shine/managers/unit_system_manager.dart';
import 'package:rise_and_shine/managers/weather_manager.dart';
import 'package:rise_and_shine/models/city.dart';
import 'package:rise_and_shine/models/city_live_info.dart';
import 'package:rise_and_shine/models/hourly_forecast.dart';
import 'package:rise_and_shine/models/daily_forecast.dart';
import 'package:rise_and_shine/models/city_weather_data.dart';
import 'package:rise_and_shine/models/weather_alert.dart';
import 'package:rise_and_shine/providers/app_managers_provider.dart';
import 'package:rise_and_shine/consts/consts_ui.dart';
import 'package:rise_and_shine/consts/consts_app.dart';
import 'package:rise_and_shine/utils/app_logger.dart';
import 'package:rise_and_shine/utils/weather_icons.dart';
import 'package:rise_and_shine/screens/city_selection_screen.dart';


class WeatherScreen extends StatefulWidget {
  const WeatherScreen({super.key});

  @override
  State<WeatherScreen> createState() => _WeatherScreenState();
}

class _WeatherScreenState extends State<WeatherScreen> {
  late CityListManager _cityListManager;
  late UnitSystemManager _unitSystemManager;
  late WeatherManager _weatherManager;

  bool _showAddedConfirmation = false;
  Timer? _addedConfirmationTimer;

  @override
  void initState() {
    super.initState();
    logger.d('WeatherScreen: initState called.');
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final appManagers = AppManagers.of(context);
    _cityListManager = appManagers.cityListManager;
    _unitSystemManager = appManagers.unitSystemManager;
    _weatherManager = appManagers.weatherManager;
    logger.d('WeatherScreen: didChangeDependencies called. Managers accessed.');
  }

  void _addCityToSavedList(City city) {
    if (!_cityListManager.isCitySaved(city)) {
      _cityListManager.addCityToSavedList(city);
      setState(() {
        _showAddedConfirmation = true;
      });
      _addedConfirmationTimer?.cancel(); // Cancel any existing timer
      _addedConfirmationTimer = Timer(const Duration(seconds: 3), () {
        if (mounted) {
          setState(() {
            _showAddedConfirmation = false;
          });
        }
      });
      logger.d('WeatherScreen: City ${city.name} added to saved list. Showing confirmation.');
    } else {
      logger.d('WeatherScreen: City ${city.name} already saved. No action.');
    }
  }

  void _showOptionsDialog() {
    logger.d('WeatherScreen: Showing options dialog.');
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return ListenableBuilder(
          listenable: _unitSystemManager,
          builder: (context, child) {
            return AlertDialog(
              title: const Text(kOptionsDialogTitle),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text(kChooseUnitsLabel),
                  ToggleButtons(
                    isSelected: [
                      !_unitSystemManager.isMetricUnits, // Imperial
                      _unitSystemManager.isMetricUnits, // Metric
                    ],
                    onPressed: (int index) {
                      if (index == 0 && _unitSystemManager.isMetricUnits) {
                        // Toggling to Imperial
                        _unitSystemManager.toggleUnitSystem();
                        logger.d('WeatherScreen: Toggled to Imperial units.');
                      } else if (index == 1 && !_unitSystemManager.isMetricUnits) {
                        // Toggling to Metric
                        _unitSystemManager.toggleUnitSystem();
                        logger.d('WeatherScreen: Toggled to Metric units.');
                      }
                    },
                    borderRadius: BorderRadius.circular(8.0),
                    selectedColor: Colors.white,
                    fillColor: Colors.blueAccent,
                    color: Colors.blueGrey,
                    children: const <Widget>[
                      Padding(
                        padding: EdgeInsets.symmetric(horizontal: 16.0),
                        child: Text(kImperialUnitsLabel),
                      ),
                      Padding(
                        padding: EdgeInsets.symmetric(horizontal: 16.0),
                        child: Text('Metric'),
                      ),
                    ],
                  ),
                ],
              ),
              actions: <Widget>[
                TextButton(
                  onPressed: () {
                    Navigator.of(context).pop();
                    logger.d('WeatherScreen: Options dialog closed.');
                  },
                  child: const Text(kCloseButton),
                ),
              ],
            );
          },
        );
      },
    );
  }

  @override
  void dispose() {
    logger.d('WeatherScreen: dispose called. Cancelling timers.');
    _addedConfirmationTimer?.cancel();
    super.dispose();
  }

  AppBar _buildAppBar(City? selectedCity) {
    return AppBar(
      title: const Text(kWeatherScreenTitle),
      centerTitle: true,
      actions: const <Widget>[
        // Options and Cities buttons are now at the bottom of the screen
      ],
    );
  }

  Widget _buildCityName(String cityName) {
    return Text(
      cityName,
      style: const TextStyle(
        fontSize: 32,
        fontWeight: FontWeight.bold,
        color: Colors.white,
        shadows: [
          Shadow(
            blurRadius: 10.0,
            color: Colors.black54,
            offset: Offset(2.0, 2.0),
          ),
        ],
      ),
      textAlign: TextAlign.center,
    );
  }

  Widget _buildLocalTime(String formattedLocalTime) {
    return Text(
      formattedLocalTime,
      style: const TextStyle(
        fontSize: 16,
        color: Colors.white70,
        shadows: [
          Shadow(
            blurRadius: 5.0,
            color: Colors.black45,
            offset: Offset(1.0, 1.0),
          ),
        ],
      ),
    );
  }

  Widget _buildWeatherStatus(CityLiveInfo liveInfo) {
    final bool isMetric = _unitSystemManager.isMetricUnits;
    if (liveInfo.isLoading) {
      return const CircularProgressIndicator(color: Colors.white);
    } else if (liveInfo.error != null) {
      return Text(
        // Fix: Removed unnecessary braces
        '$kWeatherError ${liveInfo.error}',
        style: const TextStyle(color: Colors.red, fontSize: 16),
        textAlign: TextAlign.center,
      );
    } else {
      return Column(
        children: [
          Text(
            '${liveInfo.temperatureCelsius!.toStringAsFixed(0)}°${isMetric ? 'C' : 'F'}',
            style: const TextStyle(
              fontSize: 64,
              fontWeight: FontWeight.bold,
              color: Colors.white,
              shadows: [
                Shadow(
                  blurRadius: 10.0,
                  color: Colors.black54,
                  offset: Offset(3.0, 3.0),
                ),
              ],
            ),
          ),
          if (liveInfo.weatherIconCode != null)
            Text(
              getWeatherEmoji(liveInfo.weatherIconCode!),
              style: const TextStyle(fontSize: 80),
            ),
          Text(
            liveInfo.description ?? 'N/A',
            style: const TextStyle(
              fontSize: 20,
              color: Colors.white,
              shadows: [
                Shadow(
                  blurRadius: 5.0,
                  color: Colors.black45,
                  offset: Offset(1.0, 1.0),
                ),
              ],
            ),
            textAlign: TextAlign.center,
          ),
        ],
      );
    }
  }

  Widget _buildAddCityButton(City selectedCity, CityListManager manager) {
    final Size buttonSize = const Size(60, 30);
    if (!manager.isCitySaved(selectedCity)) {
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
    return const SizedBox.shrink(); // Return empty widget if city is saved and confirmation is not shown
  }

  Widget _buildHourlyForecastCardItem(HourlyForecast forecast, bool isMetric) {
    String tempUnit = isMetric ? 'C' : 'F';
    String speedUnit = isMetric ? 'm/s' : 'mph';

    // Define a standard height for a single line of dynamic text (PoP or Wind)
    // This helps in reserving consistent space.
    const double dynamicTextLineHeight = 16.0;

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 4.0),
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(12.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center, // Center content vertically within the card
          children: [
            // 1. Time (closer to the top)
            Text(DateFormat('h a').format(forecast.time.toLocal()), style: const TextStyle(fontSize: 14)),
            const SizedBox(height: 2), // Small space after time

            // 2. Condition Icon
            Text(getWeatherEmoji(forecast.iconCode), style: const TextStyle(fontSize: 32)),

            // 3. Fixed-height section for PoP and Wind (ensures vertical alignment)
            SizedBox(
              height: 2 * dynamicTextLineHeight, // Space for two potential lines
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center, // Center PoP/Wind vertically within this block
                children: [
                  // Rain Probability (PoP) - Row 2 if present
                  if (forecast.pop != null && forecast.pop! > 0)
                    Text(
                      '${(forecast.pop! * 100).toStringAsFixed(0)}% Pop',
                      style: const TextStyle(fontSize: 10, color: Colors.blue, fontWeight: FontWeight.bold),
                      textAlign: TextAlign.center, // Ensure text is centered
                    )
                  else
                    const SizedBox(height: dynamicTextLineHeight), // Reserve space if not present

                  // Wind Speed - Row 2 or 3 if present
                  if (forecast.windSpeed != null && forecast.windSpeed! >= _weatherManager.getWindSpeedThreshold())
                    Text(
                      '${forecast.windSpeed!.toStringAsFixed(0)} $speedUnit',
                      style: const TextStyle(fontSize: 10, color: Colors.grey, fontWeight: FontWeight.bold),
                      textAlign: TextAlign.center, // Ensure text is centered
                    )
                  else
                    const SizedBox(height: dynamicTextLineHeight), // Reserve space if not present
                ],
              ),
            ),

            // Space between dynamic block and temperature
            const SizedBox(height: 4),

            // 4. Temperature (always at the same vertical position across all cards)
            Text('${forecast.temperatureCelsius.toStringAsFixed(0)}°$tempUnit',
                style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
          ],
        ),
      ),
    );
  }

  Widget _buildDailyForecastRowItem(DailyForecast forecast, bool isMetric) {
    String tempUnit = isMetric ? 'C' : 'F';

    return Container(
      padding: const EdgeInsets.symmetric(vertical: 8.0, horizontal: 16.0),
      decoration: BoxDecoration(
        border: Border(bottom: BorderSide(color: Colors.grey[300]!, width: 0.5)),
      ),
      child: SizedBox( // Use SizedBox to define the overall space for the Stack
        width: double.infinity, // Takes full available width
        height: 50, // Fixed height for the row to ensure consistent spacing
        child: LayoutBuilder( // LayoutBuilder correctly wraps the Stack to get its constraints
          builder: (context, constraints) {
            // Calculate the horizontal center, then shift left by kIconWidth
            final double horizontalCenter = (constraints.maxWidth / 2) - kIconWidth;

            return Stack(
              alignment: Alignment.centerLeft, // Vertically centers and left-aligns unpositioned children
              children: [
                // 1. Date/Day (Left-aligned by default due to Stack alignment)
                Text(
                  DateFormat('EEE, MMM d').format(forecast.time.toLocal()),
                  style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w500),
                ),

                // 2. Icon Group (Positioned: left edge at calculated center)
                Positioned(
                  left: horizontalCenter, // Set the left edge of this widget to the calculated center
                  child: Row(
                    mainAxisSize: MainAxisSize.min, // Make the Row only as wide as its children
                    crossAxisAlignment: CrossAxisAlignment.center, // Vertically center items within this Row
                    children: [
                      // Condition Icon (Weather Emoji)
                      // Wrapped in SizedBox with fixed width and Align.centerLeft for consistent vertical alignment
                      SizedBox(
                        width: kIconWidth, // Allocate a fixed width for the icon using the constant
                        child: Align(
                          alignment: Alignment.centerLeft, // Align the emoji to the left within its SizedBox
                          child: Text(getWeatherEmoji(forecast.iconCode), style: const TextStyle(fontSize: 28)),
                        ),
                      ),

                      // Probability of Precipitation (PoP)
                      if (forecast.pop != null && forecast.pop! > 0)
                        Padding(
                          padding: const EdgeInsets.only(left: 4.0), // Small space after icon
                          child: Text(
                            '${(forecast.pop! * 100).toStringAsFixed(0)}%',
                            style: const TextStyle(fontSize: 12, color: Colors.blue),
                          ),
                        ),
                      // Wind Icon (No Value)
                      if (forecast.windSpeed != null && forecast.windSpeed! >= _weatherManager.getWindSpeedThreshold())
                        Padding(
                          padding: const EdgeInsets.only(left: 4.0), // Small space after PoP or icon
                          child: Icon(Icons.air, size: 16, color: Colors.white70),
                        ),
                    ],
                  ),
                ),

                // 3. Min/Max Temperature (Right-aligned)
                Align(
                  alignment: Alignment.centerRight,
                  child: Text(
                    '${forecast.minTemperatureCelsius.toStringAsFixed(0)}°$tempUnit / ${forecast.maxTemperatureCelsius.toStringAsFixed(0)}°$tempUnit',
                    style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }

  // Removed unused methods _buildCitiesButton and _buildOptionsButton
  // as they are no longer referenced after moving buttons to the bottom bar.


  Widget _buildLoadingCitiesState() {
    return const Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          CircularProgressIndicator(),
          SizedBox(height: 16),
          Text(kLoadingCities, style: TextStyle(fontSize: 18, color: Colors.grey)),
        ],
      ),
    );
  }

  Widget _buildErrorFetchingCitiesState(String error, CityListManager manager) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.error_outline, color: Colors.red, size: 40),
            const SizedBox(height: 10),
            Text(
              '$kErrorFetchingCities $error',
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 16, color: Colors.red),
            ),
            const SizedBox(height: 20),
            ElevatedButton.icon(
              icon: const Icon(Icons.refresh),
              label: const Text(kRetryFetchCities),
              onPressed: () async {
                logger.d('WeatherScreen: Retrying fetch cities on error.');
                await _cityListManager.initialized;
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildNoCitySelectedState(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Text(
              kNoCitySelected,
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 18, color: Colors.grey),
            ),
            const SizedBox(height: 20),
            ElevatedButton.icon(
              icon: const Icon(Icons.location_city),
              label: const Text(kSelectACity),
              onPressed: () {
                logger.d('WeatherScreen: Navigating to CitySelectionScreen from no city state.');
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => const CitySelectionScreen()),
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDetailText(String label, String value, {Color? valueColor}) {
    return RichText(
      text: TextSpan(
        style: const TextStyle(fontSize: 16, color: Colors.white),
        children: [
          TextSpan(
            text: '$label ',
            style: const TextStyle(fontWeight: FontWeight.w400, color: Colors.white70),
          ),
          TextSpan(
            text: value,
            style: TextStyle(fontWeight: FontWeight.bold, color: valueColor ?? Colors.white),
          ),
        ],
      ),
    );
  }

  Widget _buildWeatherDetailsText(CityLiveInfo liveInfo) {
    final bool isMetric = _unitSystemManager.isMetricUnits;
    String speedUnit = isMetric ? 'm/s' : 'mph';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildDetailText(
          kFeelsLike,
          '${liveInfo.feelsLike!.toStringAsFixed(0)}°${isMetric ? 'C' : 'F'}',
        ),
        _buildDetailText(
          kHumidity,
          '${liveInfo.humidity!}%',
        ),
        _buildDetailText(
          kWind,
          '${liveInfo.windSpeed!.toStringAsFixed(1)} $speedUnit ${liveInfo.windDirection}',
        ),
        if (liveInfo.uvIndex != null)
          _buildDetailText(
            kUVIndex,
            liveInfo.uvIndex!.toStringAsFixed(0),
            valueColor: getUvIndexColor(liveInfo.uvIndex!),
          ),
      ],
    );
  }

  Widget _buildWeatherAlerts(List<WeatherAlert> alerts) {
    if (alerts.isEmpty) {
      return const SizedBox.shrink();
    }

    return Padding(
      padding: const EdgeInsets.only(top: 16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            kWeatherAlertsHeading,
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Colors.amberAccent,
              shadows: [
                Shadow(
                  blurRadius: 5.0,
                  color: Colors.black54,
                  offset: Offset(1.0, 1.0),
                ),
              ],
            ),
          ),
          const SizedBox(height: 8),
          Container(
            decoration: BoxDecoration(
              color: Colors.red.withAlpha( (255 * 0.2).round() ),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.red, width: 1),
            ),
            padding: const EdgeInsets.all(12.0),
            child: ListView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: alerts.length,
              itemBuilder: (context, index) {
                final alert = alerts[index];
                return Padding(
                  padding: const EdgeInsets.symmetric(vertical: 4.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        alert.event,
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                          color: Colors.white,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        alert.description,
                        style: const TextStyle(fontSize: 14, color: Colors.white70),
                      ),
                      const SizedBox(height: 4),
                      _buildDetailText(kAlertSourceLabel, alert.senderName, valueColor: Colors.white),
                      _buildDetailText(kAlertSeverityLabel, alert.severity ?? kAlertNotAvailable,
                          valueColor: getSeverityColor(alert.severity)),
                      _buildDetailText(kAlertUrgencyLabel, alert.urgency ?? kAlertNotAvailable,
                          valueColor: Colors.white),
                      Text(
                        '${DateFormat('MMM d, h:mm a').format(alert.startTime.toLocal())} - ${DateFormat('MMM d, h:mm a').format(alert.endTime.toLocal())}',
                        style: const TextStyle(fontSize: 12, color: Colors.white54),
                      ),
                      if (index < alerts.length - 1)
                        const Divider(color: Colors.white30, height: 16),
                    ],
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  // New method to build the fixed bottom buttons
  Widget _buildFixedBottomButtons(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
      // Fix: Changed deprecated withOpacity to withAlpha
      color: Colors.blue.withAlpha((255 * 0.8).round()), // Semi-transparent background for the button row
      child: SafeArea( // Ensure buttons respect the bottom safe area (e.g., iPhone home indicator)
        top: false, // Don't apply top padding from safe area
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceAround, // Distribute space between buttons
          children: [
            Expanded(
              child: ElevatedButton.icon(
                onPressed: _showOptionsDialog,
                icon: const Icon(Icons.settings),
                label: const Text(kOptionsButton),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.blueAccent, // Button background color
                  foregroundColor: Colors.white, // Button text/icon color
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                ),
              ),
            ),
            const SizedBox(width: 16), // Space between the two buttons
            Expanded(
              child: ElevatedButton.icon(
                onPressed: () {
                  logger.d('WeatherScreen: Navigating to CitySelectionScreen from bottom bar.');
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (context) => const CitySelectionScreen()),
                  );
                },
                icon: const Icon(Icons.location_city),
                label: const Text(kCitiesButton),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.blueAccent,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: _cityListManager, // Listen to city list changes
      builder: (context, _) {
        final City? selectedCity = _cityListManager.selectedCity;
        final String? cityListError = _cityListManager.searchCitiesError; // This also captures init errors

        return Scaffold(
          appBar: _buildAppBar(selectedCity),
          body: Container(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [Colors.blue, Colors.lightBlueAccent],
              ),
            ),
            child: Column( // Main Column to hold scrollable content and fixed bottom buttons
              children: [
                Expanded( // This Expanded widget contains the scrollable weather content
                  child: SafeArea( // SafeArea for the scrollable weather content
                    bottom: false, // Prevents double-padding if the bottom bar also has SafeArea
                    child: FutureBuilder<void>( // Use FutureBuilder to await manager initialization
                      future: _cityListManager.initialized,
                      builder: (context, managerInitSnapshot) { // Fix: Corrected typo 'managerInitInitSnapshot'
                        if (managerInitSnapshot.connectionState == ConnectionState.waiting) {
                          return _buildLoadingCitiesState();
                        } else if (managerInitSnapshot.hasError) {
                          // If manager initialization itself failed
                          return _buildErrorFetchingCitiesState(managerInitSnapshot.error.toString(), _cityListManager);
                        } else if (cityListError != null) {
                          // If manager initialized but encountered a search/location error later
                          return _buildErrorFetchingCitiesState(cityListError, _cityListManager);
                        } else if (selectedCity == null) {
                          return _buildNoCitySelectedState(context);
                        } else {
                          // Main weather display logic, now safely inside an initialized manager context
                          return StreamBuilder<Map<int, CityWeatherData>>(
                            stream: _weatherManager.weatherDataStream,
                            initialData: _weatherManager.getWeatherForCity(selectedCity) != null
                                ? {selectedCity.hashCode: _weatherManager.getWeatherForCity(selectedCity)!}
                                : {},
                            builder: (context, snapshot) {
                              final CityWeatherData? cityWeatherData = snapshot.data?[selectedCity.hashCode];
                              final bool isMetric = _unitSystemManager.isMetricUnits;

                              if (cityWeatherData == null || cityWeatherData.liveInfo.isLoading) {
                                return Center(
                                  child: Column(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      const CircularProgressIndicator(color: Colors.white),
                                      const SizedBox(height: 16),
                                      Text(
                                        cityWeatherData == null
                                            ? kLoadingCities // Initial load
                                            : kLoadingWeatherForecast, // Refreshing
                                        style: const TextStyle(fontSize: 18, color: Colors.white70),
                                      ),
                                    ],
                                  ),
                                );
                              }

                              if (cityWeatherData.liveInfo.error != null) {
                                return Center(
                                  child: Padding(
                                    padding: const EdgeInsets.all(20.0),
                                    child: Column(
                                      mainAxisAlignment: MainAxisAlignment.center,
                                      children: [
                                        const Icon(Icons.cloud_off, color: Colors.white, size: 40),
                                        const SizedBox(height: 10),
                                        Text(
                                          // Fix: Removed unnecessary braces
                                          '$kWeatherError ${cityWeatherData.liveInfo.error}',
                                          textAlign: TextAlign.center,
                                          style: const TextStyle(fontSize: 16, color: Colors.white),
                                        ),
                                        const SizedBox(height: 20),
                                        ElevatedButton.icon(
                                          icon: const Icon(Icons.refresh),
                                          label: const Text(kRetryFetchCities),
                                          onPressed: () {
                                            _weatherManager.fetchWeatherForCities([selectedCity]);
                                          },
                                        ),
                                      ],
                                    ),
                                  ),
                                );
                              }

                              // Display weather data
                              return SingleChildScrollView(
                                child: Padding(
                                  padding: const EdgeInsets.all(16.0),
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.center,
                                    children: [
                                      // NEW: Wrap the Stack to ensure it takes full available width
                                      SizedBox(
                                        width: double.infinity,
                                        child: Stack(
                                          alignment: Alignment.center,
                                          children: [
                                            Column(
                                              children: [
                                                _buildCityName(selectedCity.name),
                                                _buildLocalTime(cityWeatherData.liveInfo.formattedLocalTime),
                                                const SizedBox(height: 20),
                                                _buildWeatherStatus(cityWeatherData.liveInfo),
                                              ],
                                            ),
                                            // Positioned at top-right of this now expanded Stack
                                            Positioned(
                                              top: 0, // Reverted to 0
                                              right: 0, // Reverted to 0
                                              child: _buildAddCityButton(selectedCity, _cityListManager),
                                            ),
                                          ],
                                        ),
                                      ),
                                      const SizedBox(height: 20),
                                      _buildWeatherDetailsText(cityWeatherData.liveInfo),
                                      const SizedBox(height: 20),
                                      _buildWeatherAlerts(cityWeatherData.alerts),
                                      const SizedBox(height: 20),
                                      // Hourly Forecast
                                      if (cityWeatherData.hourlyForecasts.isNotEmpty) ...[
                                        const Align(
                                          alignment: Alignment.centerLeft,
                                          child: Text(
                                            kHourlyForecastHeading,
                                            style: TextStyle(
                                              fontSize: 20,
                                              fontWeight: FontWeight.bold,
                                              color: Colors.white,
                                              shadows: [
                                                Shadow(
                                                  blurRadius: 5.0,
                                                  color: Colors.black45,
                                                  offset: Offset(1.0, 1.0),
                                                ),
                                              ],
                                            ),
                                          ),
                                        ),
                                        const SizedBox(height: 10),
                                        SizedBox(
                                          height: 175, // Increased height from 160 to 175
                                          child: ListView.builder(
                                            scrollDirection: Axis.horizontal,
                                            itemCount: cityWeatherData.hourlyForecasts.length,
                                            itemBuilder: (context, index) {
                                              return _buildHourlyForecastCardItem(
                                                  cityWeatherData.hourlyForecasts[index], isMetric);
                                            },
                                          ),
                                        ),
                                      ],
                                      const SizedBox(height: 20),
                                      // Daily Forecast
                                      if (cityWeatherData.dailyForecasts.isNotEmpty) ...[
                                        const Align(
                                          alignment: Alignment.centerLeft,
                                          child: Text(
                                            kDailyForecastHeading,
                                            style: TextStyle(
                                              fontSize: 20,
                                              fontWeight: FontWeight.bold,
                                              color: Colors.white,
                                              shadows: [
                                                Shadow(
                                                  blurRadius: 5.0,
                                                  color: Colors.black45,
                                                  offset: Offset(1.0, 1.0),
                                                ),
                                              ],
                                            ),
                                          ),
                                        ),
                                        const SizedBox(height: 10),
                                        ListView.builder(
                                          shrinkWrap: true,
                                          physics: const NeverScrollableScrollPhysics(),
                                          itemCount: cityWeatherData.dailyForecasts.length,
                                          itemBuilder: (context, index) {
                                            return _buildDailyForecastRowItem(
                                                cityWeatherData.dailyForecasts[index], isMetric);
                                          },
                                        ),
                                      ],
                                    ],
                                  ),
                                ),
                              );
                            },
                          );
                        }
                      },
                    ),
                  ),
                ),
                // Fixed bottom buttons are placed here, outside the Expanded and SingleChildScrollView
                _buildFixedBottomButtons(context),
              ],
            ),
          ),
        );
      },
    );
  }
}

Color getUvIndexColor(double uvIndex) {
  if (uvIndex < 3) return Colors.greenAccent;
  if (uvIndex < 6) return Colors.yellowAccent;
  if (uvIndex < 8) return Colors.orangeAccent;
  if (uvIndex < 11) return Colors.redAccent;
  return Colors.purpleAccent;
}

Color getSeverityColor(String? severity) {
  switch (severity?.toLowerCase()) {
    case 'extreme':
      return Colors.deepPurpleAccent;
    case 'severe':
      return Colors.redAccent;
    case 'moderate':
      return Colors.orangeAccent;
    case 'minor':
      return Colors.yellowAccent;
    case 'unknown':
    default:
      return Colors.grey;
  }
}