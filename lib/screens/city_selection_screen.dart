// lib/screens/city_selection_screen.dart

import 'package:flutter/material.dart';
import 'package:rise_and_shine/models/city.dart';
import 'package:rise_and_shine/providers/app_managers_provider.dart'; // For accessing managers
import 'package:rise_and_shine/managers/city_list_manager.dart'; // Import CityListManager
import 'dart:async'; // For Timer

class CitySelectionScreen extends StatefulWidget {
  const CitySelectionScreen({super.key});

  @override
  // FIX: Changed to public class name by removing the underscore
  CitySelectionScreenState createState() => CitySelectionScreenState();
}

// FIX: Changed to public class name by removing the underscore
class CitySelectionScreenState extends State<CitySelectionScreen> {
  late CityListManager _cityListManager; // Reference to CityListManager

  final TextEditingController _searchController = TextEditingController();
  List<City> _searchResults = [];
  bool _isLoading = false;
  String? _errorMessage;

  Timer? _debounceTimer; // Debounce timer for search input

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
  }

  @override
  void dispose() {
    _searchController.removeListener(_onSearchChanged);
    _searchController.dispose();
    _debounceTimer?.cancel(); // Cancel the timer to prevent memory leaks
    super.dispose();
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
        setState(() {
          _searchResults = []; // Clear results if search bar is empty
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
      _searchResults = []; // Clear previous results immediately on new search
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
      _searchResults = []; // Clear search results after selection
    });
    Navigator.of(context).pop(); // Navigate back to WeatherScreen
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Select a City'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: <Widget>[
            // Search Input Field
            TextField(
              controller: _searchController,
              decoration: InputDecoration(
                labelText: 'Search for a city',
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
                    setState(() {
                      _searchResults = [];
                      _errorMessage = null;
                    });
                  },
                ),
              ),
            ),
            // Error Message Display
            if (_errorMessage != null)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 8.0),
                child: Text(
                  _errorMessage!,
                  style: const TextStyle(color: Colors.red),
                ),
              ),
            // Search Results List
            Expanded(
              child: _searchResults.isEmpty && !_isLoading && _errorMessage == null
                  ? const Center(child: Text('Start typing to search for cities'))
                  : ListView.builder(
                itemCount: _searchResults.length,
                itemBuilder: (context, index) {
                  final city = _searchResults[index];
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
                      subtitle: Text(
                        '${city.state != null ? '${city.state}, ' : ''}${city.country}',
                        style: const TextStyle(fontSize: 14.0),
                      ),
                      onTap: () => _onCitySelected(city), // Call the city selection handler
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}