// lib/services/search_cities_service.dart

import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:rise_and_shine/models/city.dart';
import 'package:flutter/foundation.dart'; // For kDebugMode
import 'package:logger/logger.dart'; // Import the logger plugin

class SearchCitiesService {
  static const String _apiKey = 'c2c0d08e8d8f459b881ebe54afbd838f';
  static const String _baseUrl = 'https://api.opencagedata.com/geocode/v1/json';

  // Instantiate the logger
  final Logger _logger = Logger(
    printer: PrettyPrinter(
      methodCount: 0, // No method calls to be displayed
      errorMethodCount: 5, // Number of method calls if stacktrace is provided
      lineLength: 120, // Width of the output
      colors: true, // Colorful log messages
      printEmojis: true, // Print emojis for log messages
      printTime: true, // Should each log message contain a timestamp
    ),
  );

  Future<List<City>> searchCities(String query) async {
    if (query.isEmpty) {
      if (kDebugMode) {
        _logger.d('SearchCitiesService: Query is empty, returning empty list.');
      }
      return [];
    }

    final Uri uri = Uri.parse('$_baseUrl?q=$query&key=$_apiKey');

    if (kDebugMode) {
      _logger.d('SearchCitiesService: Fetching cities from: $uri');
    }

    final http.Response response = await http.get(uri);

    if (kDebugMode) {
      _logger.d('SearchCitiesService: Response status code: ${response.statusCode}');
      _logger.d('SearchCitiesService: Response body: ${response.body}'); // IMPORTANT: Full raw response
    }

    if (response.statusCode == 200) {
      final Map<String, dynamic> data = jsonDecode(response.body) as Map<String, dynamic>;
      final List<dynamic> results = data['results'] as List<dynamic>;
      final List<City> cities = [];

      final String lowerCaseQuery = query.toLowerCase();

      for (final dynamic item in results) {
        final Map<String, dynamic> result = item as Map<String, dynamic>;

        final Map<String, dynamic>? components = result['components'] as Map<String, dynamic>?;
        final Map<String, dynamic>? geometry = result['geometry'] as Map<String, dynamic>?;

        // --- Debugging: Print raw components and geometry before any filtering ---
        if (kDebugMode) {
          _logger.d('--- Processing result: "${result['formatted']}" ---');
          _logger.d('  Raw _type: ${components?['_type']}');
          _logger.d('  Raw _category: ${components?['_category']}');
          _logger.d('  Raw city: ${components?['city']}');
          _logger.d('  Raw town: ${components?['town']}');
          _logger.d('  Raw village: ${components?['village']}');
          _logger.d('  Raw suburb: ${components?['suburb']}');
          _logger.d('  Raw hamlet: ${components?['hamlet']}');
          _logger.d('  Raw city_district: ${components?['city_district']}');
          _logger.d('  Raw borough: ${components?['borough']}');
          _logger.d('  Raw _normalized_city: ${components?['_normalized_city']}');
          _logger.d('  Raw geometry.lat: ${geometry?['lat']}');
          _logger.d('  Raw geometry.lng: ${geometry?['lng']}');
        }
        // --- End Debugging ---


        if (components == null || geometry == null) {
          if (kDebugMode) {
            _logger.d('SearchCitiesService: Skipping result "${result['formatted']}" because components or geometry map is missing.');
          }
          continue;
        }

        late double latitude;
        late double longitude;

        final dynamic rawLat = geometry['lat'];
        final dynamic rawLng = geometry['lng'];

        if (rawLat is num && rawLng is num) {
          latitude = rawLat.toDouble();
          longitude = rawLng.toDouble();
        } else {
          if (kDebugMode) {
            _logger.d('SearchCitiesService: Skipping result "${result['formatted']}" because lat (${rawLat.runtimeType}) or lng (${rawLng.runtimeType}) is not a number. Raw values: lat=$rawLat, lng=$rawLng');
          }
          continue;
        }

        final String? type = components['_type'] as String?;
        final List<String> acceptedTypes = [
          'city', 'town', 'village', 'suburb', 'hamlet', 'city_district', 'borough', 'neighbourhood'
        ];

        if (type == null || !acceptedTypes.contains(type)) {
          if (kDebugMode) {
            _logger.d('SearchCitiesService: Skipping result "${result['formatted']}" because _type is "$type" (not in accepted list: ${acceptedTypes.join(', ')}).');
          }
          continue;
        }

        final String? cityComponent = components['city'] as String?;
        final String? townComponent = components['town'] as String?;
        final String? villageComponent = components['village'] as String?;
        final String? suburbComponent = components['suburb'] as String?;
        final String? hamletComponent = components['hamlet'] as String?;
        final String? cityDistrictComponent = components['city_district'] as String?;
        final String? boroughComponent = components['borough'] as String?;
        final String? normalizedCityComponent = components['_normalized_city'] as String?;

        String? displayNameCandidate;
        if (cityComponent != null && cityComponent.isNotEmpty) {
          displayNameCandidate = cityComponent;
        } else if (townComponent != null && townComponent.isNotEmpty) {
          displayNameCandidate = townComponent;
        } else if (villageComponent != null && villageComponent.isNotEmpty) {
          displayNameCandidate = villageComponent;
        } else if (suburbComponent != null && suburbComponent.isNotEmpty) {
          displayNameCandidate = suburbComponent;
        } else if (hamletComponent != null && hamletComponent.isNotEmpty) {
          displayNameCandidate = hamletComponent;
        } else if (cityDistrictComponent != null && cityDistrictComponent.isNotEmpty) {
          displayNameCandidate = cityDistrictComponent;
        } else if (boroughComponent != null && boroughComponent.isNotEmpty) {
          displayNameCandidate = boroughComponent;
        } else {
          // Fallback to formatted if no specific component name is found, but type is accepted
          displayNameCandidate = result['formatted'] as String?;
        }

        bool nameMatchesQuery = false;
        // FIX: Reverted to .contains() for broader matching as requested
        if (displayNameCandidate != null && displayNameCandidate.toLowerCase().contains(lowerCaseQuery)) {
          nameMatchesQuery = true;
        } else if (normalizedCityComponent != null && normalizedCityComponent.toLowerCase().contains(lowerCaseQuery)) {
          nameMatchesQuery = true;
        }

        if (!nameMatchesQuery) {
          if (kDebugMode) {
            _logger.d('SearchCitiesService: Skipping result "${result['formatted']}" because its determined display name ("$displayNameCandidate") and normalized city ("$normalizedCityComponent") do not contain the query "$query".');
          }
          continue;
        }

        final String displayName = displayNameCandidate ?? normalizedCityComponent ?? (result['formatted'] as String? ?? 'Unknown City');

        final String country = components['country'] as String? ?? 'Unknown Country';
        final String? state = components['state'] as String?;

        cities.add(
          City(
            name: displayName,
            country: country,
            state: state,
            latitude: latitude,
            longitude: longitude,
            timezoneOffsetSeconds: (result['annotations']?['timezone']?['offset_sec'] as num?)?.toInt() ?? 0,
          ),
        );
      }
      if (kDebugMode) {
        _logger.d('SearchCitiesService: Found ${cities.length} filtered cities.');
        for (var city in cities) {
          _logger.d('  - Added city: ${city.name}, ${city.country} (Lat: ${city.latitude}, Lon: ${city.longitude})');
        }
      }
      return cities;
    } else {
      final Map<String, dynamic> errorData = jsonDecode(response.body) as Map<String, dynamic>;
      final String errorMessage = errorData['message'] as String? ?? 'Unknown error';
      if (kDebugMode) {
        _logger.e('SearchCitiesService: Error response: ${response.statusCode}, Message: $errorMessage', error: errorData);
      }
      throw Exception('Failed to search for cities: $errorMessage (Status: ${response.statusCode})');
    }
  }
}