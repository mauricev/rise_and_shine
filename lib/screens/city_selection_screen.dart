// lib/screens/city_selection_screen.dart

import 'package:flutter/material.dart';
import 'package:rise_and_shine/managers/city_list_manager.dart';
import 'package:rise_and_shine/models/city.dart';
import 'package:rise_and_shine/models/city_display_data.dart';
import 'package:rise_and_shine/providers/app_managers_provider.dart';
import 'package:rise_and_shine/consts/consts_ui.dart';
import 'package:rise_and_shine/utils/app_logger.dart'; // Import global logger
import 'package:rise_and_shine/utils/weather_icons.dart'; // NEW: Import global weather icon utility


class CitySelectionScreen extends StatefulWidget {
  const CitySelectionScreen({super.key});

  @override
  State<CitySelectionScreen> createState() => _CitySelectionScreenState();
}

class _CitySelectionScreenState extends State<CitySelectionScreen> {
  final TextEditingController _searchController = TextEditingController();
  List<City> _searchResults = [];
  bool _showSearchResults = false;

  late CityListManager _cityListManager;

  @override
  void initState() {
    super.initState();
    logger.d('CitySelectionScreen: initState called.');
    _searchController.addListener(_onSearchChanged);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _cityListManager = context.cityListManager;
    logger.d('CitySelectionScreen: didChangeDependencies called. Manager initialized.');
  }

  void _onSearchChanged() {
    final String query = _searchController.text;
    if (query.isEmpty) {
      setState(() {
        _showSearchResults = false;
        _searchResults = [];
      });
      logger.d('CitySelectionScreen: Search query is empty, hiding search results.');
    } else {
      logger.d('CitySelectionScreen: Search query changed to: "$query"');
      _cityListManager.searchCities(query).then((results) {
        if (mounted) {
          setState(() {
            _searchResults = results;
            _showSearchResults = true;
          });
          logger.d('CitySelectionScreen: Search results updated. Count: ${results.length}');
        }
      }).catchError((e) {
        logger.e('CitySelectionScreen: Error searching cities: $e');
        if (mounted) {
          setState(() {
            _searchResults = [];
            _showSearchResults = true;
          });
        }
      });
    }
  }

  void _selectCityAndNavigate(City city) {
    logger.d('CitySelectionScreen: _selectCityAndNavigate called for: ${city.name}');
    _cityListManager.selectCity(city);
    Navigator.of(context).pop();
  }

  void _removeCity(City city) {
    logger.d('CitySelectionScreen: Attempting to remove city: ${city.name}');
    _cityListManager.removeCity(city);
  }

  @override
  void dispose() {
    logger.d('CitySelectionScreen: dispose called.');
    _searchController.removeListener(_onSearchChanged);
    _searchController.dispose();
    super.dispose();
  }

  AppBar _buildAppBar() {
    return AppBar(
      title: const Text(kCitySelectionScreenTitle),
      centerTitle: true,
    );
  }

  Widget _buildSearchField() {
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: TextField(
        controller: _searchController,
        decoration: InputDecoration(
          labelText: kSearchCityPlaceholder,
          hintText: kSearchCityHint,
          prefixIcon: const Icon(Icons.search),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12.0),
          ),
          filled: true,
          fillColor: Colors.grey[100],
        ),
      ),
    );
  }

  Widget _buildCityList(List<CityDisplayData> cities, bool isSavedList) {
    if (cities.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Text(
            isSavedList ? kNoSavedCities : kNoSearchResults,
            style: const TextStyle(fontSize: 16, color: Colors.grey),
            textAlign: TextAlign.center,
          ),
        ),
      );
    }

    return ListView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: cities.length,
      itemBuilder: (context, index) {
        final CityDisplayData cityDisplayData = cities[index];
        final City city = cityDisplayData.city;
        final bool isSelected = city == _cityListManager.selectedCity;

        return Dismissible(
          key: ValueKey(city.name + city.country),
          direction: DismissDirection.endToStart,
          confirmDismiss: (direction) async {
            if (direction == DismissDirection.endToStart) {
              if (cityDisplayData.isSaved) {
                return Future.value(true);
              } else {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Only saved cities can be removed by swiping.')),
                );
                return Future.value(false);
              }
            }
            return Future.value(false);
          },
          onDismissed: (direction) {
            if (direction == DismissDirection.endToStart) {
              _removeCity(city);
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text('${city.name} dismissed')),
              );
            }
          },
          background: Container(
            color: Colors.red,
            alignment: Alignment.centerRight,
            padding: const EdgeInsets.symmetric(horizontal: 20.0),
            child: const Icon(Icons.delete, color: Colors.white),
          ),
          child: Card(
            margin: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
            elevation: 4,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            child: ListTile(
              contentPadding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
              title: Text(
                city.name,
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 18,
                  color: isSelected ? Colors.blueAccent : Colors.black87,
                ),
              ),
              subtitle: Text(
                city.state != null ? '${city.state}, ${city.country}' : city.country,
                style: const TextStyle(fontSize: 14, color: Colors.grey),
              ),
              trailing: Row( // NEW: Use a Row to hold both icon and temperature
                mainAxisSize: MainAxisSize.min, // Ensure row only takes minimum space
                children: [
                  if (cityDisplayData.liveInfo.isLoading)
                    const SizedBox(
                        width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))
                  else if (cityDisplayData.liveInfo.error != null)
                    const Icon(Icons.error, color: Colors.red)
                  else if (cityDisplayData.liveInfo.weatherIconCode != null) // NEW: Display icon if available
                      Text(
                        getWeatherEmoji(cityDisplayData.liveInfo.weatherIconCode!), // Use global function
                        style: const TextStyle(fontSize: 24), // Adjust icon size
                      ),
                  const SizedBox(width: 8), // Spacing between icon and temperature
                  Text(
                    cityDisplayData.liveInfo.temperatureCelsius != null
                        ? '${cityDisplayData.liveInfo.temperatureCelsius!.toStringAsFixed(0)}°C'
                        : kLoadingWeatherForecast,
                    style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                ],
              ),
              onTap: () => _selectCityAndNavigate(city),
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    logger.d('CitySelectionScreen: build called.');
    return Scaffold(
      appBar: _buildAppBar(),
      body: Column(
        children: [
          _buildSearchField(),
          if (_cityListManager.isSearchingCities)
            const Padding(
              padding: EdgeInsets.all(8.0),
              child: CircularProgressIndicator(),
            )
          else if (_searchController.text.isNotEmpty && _searchResults.isEmpty && _cityListManager.searchCitiesError == null)
            const Padding(
              padding: EdgeInsets.all(8.0),
              child: Text(kNoSearchResults),
            )
          else if (_cityListManager.searchCitiesError != null)
              Padding(
                padding: const EdgeInsets.all(8.0),
                child: Text(
                  'Search Error: ${_cityListManager.searchCitiesError}',
                  style: const TextStyle(color: Colors.red),
                ),
              )
            else if (_showSearchResults)
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Padding(
                        padding: EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
                        child: Text(
                          kFoundCitiesHeading,
                          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                        ),
                      ),
                      Expanded(
                        child: ListView.builder(
                          itemCount: _searchResults.length,
                          itemBuilder: (context, index) {
                            final City city = _searchResults[index];
                            return Card(
                              margin: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 4.0),
                              elevation: 2,
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                              child: ListTile(
                                title: Text(city.name),
                                subtitle: Text(city.state != null ? '${city.state}, ${city.country}' : city.country),
                                onTap: () => _selectCityAndNavigate(city),
                              ),
                            );
                          },
                        ),
                      ),
                    ],
                  ),
                )
              else
                Expanded(
                  child: ListenableBuilder(
                    listenable: _cityListManager,
                    builder: (context, child) {
                      final List<CityDisplayData> savedCities = _cityListManager.allCitiesDisplayData
                          .where((data) => data.isSaved)
                          .toList();
                      final CityDisplayData? currentUnsavedCity = _cityListManager.allCitiesDisplayData
                          .firstWhereOrNull((data) => !data.isSaved && data.city == _cityListManager.selectedCity);

                      List<CityDisplayData> displayCities = [];
                      if (currentUnsavedCity != null) {
                        displayCities.add(currentUnsavedCity);
                      }
                      displayCities.addAll(savedCities);

                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          if (displayCities.isNotEmpty)
                            const Padding(
                              padding: EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
                              child: Text(
                                kSavedCitiesHeading,
                                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                              ),
                            ),
                          Expanded(
                            child: _buildCityList(displayCities, true),
                          ),
                        ],
                      );
                    },
                  ),
                ),
        ],
      ),
    );
  }
}