// lib/screens/city_selection_screen.dart

import 'package:flutter/material.dart';
import 'package:rise_and_shine/models/city.dart';
import 'package:rise_and_shine/providers/app_managers_provider.dart'; // For accessing managers
import 'package:rise_and_shine/managers/city_list_manager.dart'; // Import CityListManager
import 'package:rise_and_shine/consts/consts_ui.dart'; // Import UI constants
import 'package:rise_and_shine/models/city_display_data.dart'; // Import CityDisplayData
import 'package:rise_and_shine/models/city_live_info.dart'; // Import CityLiveInfo
import 'dart:async'; // For Timer

class CitySelectionScreen extends StatefulWidget {
  const CitySelectionScreen({super.key});

  @override
  CitySelectionScreenState createState() => CitySelectionScreenState();
}

class CitySelectionScreenState extends State<CitySelectionScreen> {
  // Explicitly type the manager reference
  late CityListManager _cityListManager;

  // Explicitly type controllers and focus nodes
  final TextEditingController _searchController = TextEditingController();
  final FocusNode _searchFocusNode = FocusNode();
  // Explicitly type the list of search results
  List<City> _searchResults = <City>[];
  // Explicitly type boolean flags
  bool _isLoading = false;
  // Explicitly type nullable String for error messages
  String? _errorMessage;
  bool _isSearchFocused = false;

  // Explicitly type the Timer
  Timer? _debounceTimer;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Access CityListManager from AppManagersProvider
    _cityListManager = AppManagersProvider.of(context).cityListManager;
  }

  @override
  void initState() {
    super.initState();
    _searchController.addListener(_onSearchChanged);
    // Add listener to FocusNode
    _searchFocusNode.addListener(_onFocusChanged);
  }

  @override
  void dispose() {
    _searchController.removeListener(_onSearchChanged);
    _searchController.dispose();
    _debounceTimer?.cancel(); // Cancel the timer to prevent memory leaks
    // Dispose FocusNode and remove listener
    _searchFocusNode.removeListener(_onFocusChanged);
    _searchFocusNode.dispose();
    super.dispose();
  }

  // Listener for focus changes on the search bar
  void _onFocusChanged() {
    setState(() {
      _isSearchFocused = _searchFocusNode.hasFocus;
      // If focus is lost and search text is empty, clear results
      if (!_isSearchFocused && _searchController.text.isEmpty) {
        _searchResults = <City>[];
        _errorMessage = null;
      }
    });
  }

  // Debounce logic for search input
  void _onSearchChanged() {
    if (_debounceTimer?.isActive ?? false) {
      _debounceTimer!.cancel(); // Cancel previous timer
    }
    _debounceTimer = Timer(const Duration(milliseconds: 500), () {
      // Only trigger search if the text is not empty
      if (_searchController.text.isNotEmpty) {
        _searchCities(_searchController.text);
      } else {
        // If text becomes empty, clear search results, but don't change focus state
        setState(() {
          _searchResults = <City>[];
          _errorMessage = null;
        });
      }
    });
  }

  // Method to perform city search using CityListManager
  Future<void> _searchCities(String query) async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
      _searchResults = <City>[]; // Clear previous results immediately on new search
    });

    try {
      // Call searchCities on the CityListManager instance
      final List<City> cities = await _cityListManager.searchCities(query);
      setState(() {
        _searchResults = cities;
        _isLoading = false;
      });
    } catch (e) {
      // Handle errors during city search
      debugPrint('CitySelectionScreen: Error in searchCities: $e');
      setState(() {
        _errorMessage = 'Failed to load cities: ${e.toString()}';
        _isLoading = false;
      });
    }
  }

  // Method to set the selected city in CityListManager and navigate back
  void _onCitySelected(City city) {
    _cityListManager.selectCity(city); // Set the selected city in the manager
    setState(() {
      _searchController.clear(); // Clear search text field
      _searchResults = <City>[]; // Clear search results after selection
      _searchFocusNode.unfocus(); // Unfocus the search bar
    });
    Navigator.of(context).pop(); // Navigate back to WeatherScreen
  }

  // Helper function to build the search bar
  Widget _buildSearchBar() {
    return TextField(
      controller: _searchController,
      focusNode: _searchFocusNode,
      decoration: InputDecoration(
        labelText: kSearchForACity,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10.0),
        ),
        suffixIcon: _isLoading
            ? const Padding(
          padding: EdgeInsets.all(8.0),
          child: CircularProgressIndicator(strokeWidth: 2),
        )
            : IconButton(
          icon: const Icon(Icons.clear),
          onPressed: () {
            _searchController.clear();
            _searchFocusNode.unfocus(); // Unfocus when cleared
            setState(() {
              _searchResults = <City>[];
              _errorMessage = null;
            });
          },
        ),
      ),
    );
  }

  // Helper function to build the error message display
  Widget _buildErrorMessage() {
    if (_errorMessage != null) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 8.0),
        child: Text(
          _errorMessage!,
          style: const TextStyle(color: Colors.red),
        ),
      );
    }
    return const SizedBox.shrink();
  }

  // Helper function to build the list of cities (now accepts CityDisplayData)
  Widget _buildCityList(List<CityDisplayData> citiesToDisplay, {required bool showWeatherDetails}) {
    return Scrollbar(
      thumbVisibility: true, // Always show the scrollbar thumb
      thickness: 10.0, // FIX: Made the scrollbar wider
      child: ListView.builder(
        itemCount: citiesToDisplay.length,
        itemBuilder: (BuildContext context, int index) {
          final CityDisplayData cityDisplayData = citiesToDisplay[index];
          final City city = cityDisplayData.city;
          final CityLiveInfo liveInfo = cityDisplayData.liveInfo;

          return Card(
            margin: const EdgeInsets.symmetric(vertical: 8.0),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10.0),
            ),
            elevation: 3,
            child: ListTile(
              contentPadding: const EdgeInsets.all(16.0),
              title: Text(
                city.name,
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 18.0,
                ),
              ),
              subtitle: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(
                    '${city.state != null ? '${city.state}, ' : ''}${city.country}',
                    style: const TextStyle(fontSize: 14.0),
                  ),
                  // Conditionally display weather details based on showWeatherDetails flag
                  if (showWeatherDetails) ...<Widget>[
                    const SizedBox(height: 4),
                    if (liveInfo.isLoading)
                      const Text('Loading weather...', style: TextStyle(fontSize: 12, color: Colors.grey))
                    else if (liveInfo.error != null)
                      Text('Weather error: ${liveInfo.error}', style: const TextStyle(fontSize: 12, color: Colors.red))
                    else if (liveInfo.temperatureCelsius != null && liveInfo.condition != null)
                        Text(
                          '${liveInfo.formattedLocalTime} | ${liveInfo.temperatureCelsius!.toStringAsFixed(0)}°C | ${liveInfo.condition}',
                          style: const TextStyle(fontSize: 14, color: Colors.blueGrey),
                        )
                      else
                        const Text('Weather data N/A', style: TextStyle(fontSize: 12, color: Colors.grey)),
                  ],
                ],
              ),
              onTap: () => _onCitySelected(city),
            ),
          );
        },
      ),
    );
  }

  // Helper function to build the main content area based on search state
  Widget _buildMainContent() {
    return Expanded(
      child: ListenableBuilder(
        listenable: _cityListManager, // Listen to CityListManager for saved cities
        builder: (BuildContext context, Widget? child) {
          // Handle loading and error states first, as they are general UI states
          if (_isLoading) {
            return const Center(child: CircularProgressIndicator());
          } else if (_errorMessage != null) {
            return Center(child: Text(_errorMessage!));
          }

          // Case 1: Search bar is focused and empty (user is about to type)
          if (_isSearchFocused && _searchController.text.isEmpty) {
            return const Center(child: Text(kStartTypingToSearch));
          }
          // Case 2: User has typed and search results are available (even if empty results)
          else if (_searchController.text.isNotEmpty) {
            final List<CityDisplayData> searchDisplayData = _searchResults.map((City city) {
              return CityDisplayData(
                city: city,
                liveInfo: CityLiveInfo(
                  currentTimeUtc: DateTime.now().toUtc(),
                  timezoneOffsetSeconds: city.timezoneOffsetSeconds,
                  isLoading: false,
                ),
                isSaved: false,
              );
            }).toList();

            if (searchDisplayData.isNotEmpty) {
              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  const Padding(
                    padding: EdgeInsets.only(top: 16.0, bottom: 8.0, left: 8.0),
                    child: Text(
                      kFoundCitiesHeading, // "Found Cities" heading
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  Expanded(child: _buildCityList(searchDisplayData, showWeatherDetails: false)),
                ],
              );
            } else {
              // If search text is not empty but no results found
              return const Center(child: Text(kNoCitiesFound));
            }
          }
          // Case 3: No active search (search bar not focused AND text is empty)
          // Always show "Saved Cities" heading, then list or "No cities found".
          else {
            final List<CityDisplayData> savedCitiesDisplayData = _cityListManager.allCitiesDisplayData
                .where((data) => data.isSaved) // FIX: Filter to show ONLY saved cities
                .toList();

            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                const Padding(
                  padding: EdgeInsets.only(top: 16.0, bottom: 8.0, left: 8.0),
                  child: Text(
                    kSavedCitiesHeading, // "Saved Cities" heading
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                Expanded(
                  child: savedCitiesDisplayData.isNotEmpty
                      ? _buildCityList(savedCitiesDisplayData, showWeatherDetails: true)
                      : const Center(child: Text(kNoCitiesFound)), // Show this if no saved cities
                ),
              ],
            );
          }
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(kSelectACity), // Using constant for app bar title
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: <Widget>[
            _buildSearchBar(), // Use helper function
            _buildErrorMessage(), // Use helper function
            _buildMainContent(), // Use helper function
          ],
        ),
      ),
    );
  }
}
