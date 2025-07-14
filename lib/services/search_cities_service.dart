// lib/services/search_cities_service.dart

import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:rise_and_shine/models/city.dart';
import 'package:flutter/foundation.dart';

import '../api_keys/api_keys.dart';
import '../utils/app_logger.dart';

class SearchCitiesService {
  static const String _baseUrl = 'https://api.opencagedata.com/geocode/v1/json';

  Future<List<City>> searchCities(String query) async {
    if (query.isEmpty) {
      if (kDebugMode) {
        logger.d('SearchCitiesService: Query is empty, returning empty list.');
      }
      return [];
    }

    final Uri uri = Uri.parse('$_baseUrl?q=$query&key=${ApiKeys.openCageKey}');

    if (kDebugMode) {
      logger.d('SearchCitiesService: Fetching cities from: $uri');
    }

    final http.Response response = await http.get(uri);

    //if (kDebugMode) {
      //logger.d('SearchCitiesService: Response status code: ${response.statusCode}');
      //logger.d('SearchCitiesService: Response body: ${response.body}');
    //}

    if (response.statusCode == 200) {
      final Map<String, dynamic> data = jsonDecode(response.body) as Map<String, dynamic>;
      final List<dynamic> results = data['results'] as List<dynamic>;
      final List<City> cities = [];

      final String lowerCaseQuery = query.toLowerCase();

      for (final dynamic item in results) {
        final Map<String, dynamic> result = item as Map<String, dynamic>;

        final Map<String, dynamic>? components = result['components'] as Map<String, dynamic>?;
        final Map<String, dynamic>? geometry = result['geometry'] as Map<String, dynamic>?;

        if (kDebugMode) {
          logger.d('--- Processing result: "${result['formatted']}" ---');
          logger.d('  Raw _type: ${components?['_type']}');
          logger.d('  Raw _category: ${components?['_category']}');
          logger.d('  Raw city: ${components?['city']}');
          logger.d('  Raw town: ${components?['town']}');
          logger.d('  Raw village: ${components?['village']}');
          logger.d('  Raw suburb: ${components?['suburb']}');
          logger.d('  Raw hamlet: ${components?['hamlet']}');
          logger.d('  Raw city_district: ${components?['city_district']}');
          logger.d('  Raw borough: ${components?['borough']}');
          logger.d('  Raw _normalized_city: ${components?['_normalized_city']}');
          logger.d('  Raw geometry.lat: ${geometry?['lat']}');
          logger.d('  Raw geometry.lng: ${geometry?['lng']}');
        }

        if (components == null || geometry == null) {
          if (kDebugMode) {
            logger.d('SearchCitiesService: Skipping result "${result['formatted']}" because components or geometry map is missing.');
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
            logger.d('SearchCitiesService: Skipping result "${result['formatted']}" because lat (${rawLat.runtimeType}) or lng (${rawLng.runtimeType}) is not a number. Raw values: lat=$rawLat, lng=$rawLng');
          }
          continue;
        }

        final String? type = components['_type'] as String?;
        final List<String> acceptedTypes = [
          'city', 'town', 'village', 'suburb', 'hamlet', 'city_district', 'borough', 'neighbourhood'
        ];

        if (type == null || !acceptedTypes.contains(type)) {
          if (kDebugMode) {
            logger.d('SearchCitiesService: Skipping result "${result['formatted']}" because _type is "$type" (not in accepted list: ${acceptedTypes.join(', ')}).');
          }
          continue;
        }

        // CONSOLIDATED: Use the new helper function
        final String? displayNameCandidate = _getDisplayNameCandidate(components, result);

        bool nameMatchesQuery = false;
        if (displayNameCandidate != null && displayNameCandidate.toLowerCase().contains(lowerCaseQuery)) {
          nameMatchesQuery = true;
        } else if (components['_normalized_city'] != null && (components['_normalized_city'] as String).toLowerCase().contains(lowerCaseQuery)) {
          nameMatchesQuery = true;
        }

        if (!nameMatchesQuery) {
          if (kDebugMode) {
            logger.d('SearchCitiesService: Skipping result "${result['formatted']}" because its determined display name ("$displayNameCandidate") and normalized city ("${components['_normalized_city']}") do not contain the query "$query".');
          }
          continue;
        }

        final String displayName = displayNameCandidate ?? (components['_normalized_city'] as String? ?? (result['formatted'] as String? ?? 'Unknown City'));

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
        logger.d('SearchCitiesService: Found ${cities.length} filtered cities.');
        for (var city in cities) {
          logger.d('  - Added city: ${city.name}, ${city.country} (Lat: ${city.latitude}, Lon: ${city.longitude})');
        }
      }
      return cities;
    } else {
      final Map<String, dynamic> errorData = jsonDecode(response.body) as Map<String, dynamic>;
      final String errorMessage = errorData['message'] as String? ?? 'Unknown error';
      if (kDebugMode) {
        logger.e('SearchCitiesService: Error response: ${response.statusCode}, Message: $errorMessage', error: errorData);
      }
      throw Exception('Failed to search for cities: $errorMessage (Status: ${response.statusCode})');
    }
  }

  // NEW: Helper function to determine the most appropriate display name from components
  String? _getDisplayNameCandidate(Map<String, dynamic> components, Map<String, dynamic> result) {
    const List<String> preferredKeys = [
      'city', 'town', 'village', 'suburb', 'hamlet', 'city_district', 'borough'
    ];

    for (final String key in preferredKeys) {
      final String? componentValue = components[key] as String?;
      if (componentValue != null && componentValue.isNotEmpty) {
        return componentValue;
      }
    }

    // Fallback to formatted if no specific component name is found
    return result['formatted'] as String?;
  }
}