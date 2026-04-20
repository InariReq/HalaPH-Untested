import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';

class GoogleMapsApiService {
  static const String _baseUrl = 'https://maps.googleapis.com/maps/api';
  static String _apiKey = 'AIzaSyC9f8Z0u-wQ5A_ePeJxbuQcGdoMQXvAovA';

  static void setApiKey(String key) {
    _apiKey = key;
  }

  static bool get isConfigured => _apiKey.isNotEmpty;

  static void _logMissingApiKey() {
    print(
        'Google Maps API key is not configured. Pass --dart-define=MAPS_API_KEY=your_key_here.');
  }

  // Geocoding API - Convert address to coordinates
  static Future<LatLng?> geocodeAddress(String address) async {
    if (!isConfigured) {
      _logMissingApiKey();
      return null;
    }

    print('=== GOOGLE GEOCODING API ===');
    print('Geocoding address: "$address"');

    final params = {
      'address': address,
      'key': _apiKey,
    };

    final uri =
        Uri.https('maps.googleapis.com', '/maps/api/geocode/json', params);

    try {
      final response = await http.get(uri);
      print('Geocoding response status: ${response.statusCode}');

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        print('Geocoding API status: ${data['status']}');

        if (data['status'] == 'OK' && data['results'].isNotEmpty) {
          final location = data['results'][0]['geometry']['location'];
          final coordinates = LatLng(location['lat'], location['lng']);
          print(
              'Geocoded "$address" to: ${coordinates.latitude}, ${coordinates.longitude}');
          return coordinates;
        } else {
          print(
              'Geocoding failed: ${data['status']} - ${data['error_message'] ?? 'No error message'}');
        }
      }
    } catch (e) {
      print('Geocoding API error: $e');
    }

    return null;
  }

  // Reverse Geocoding API - Convert coordinates to address
  static Future<String?> reverseGeocode(LatLng coordinates) async {
    if (!isConfigured) {
      _logMissingApiKey();
      return null;
    }

    print('=== GOOGLE REVERSE GEOCODING API ===');
    print(
        'Reverse geocoding: ${coordinates.latitude}, ${coordinates.longitude}');

    final params = {
      'latlng': '${coordinates.latitude},${coordinates.longitude}',
      'key': _apiKey,
    };

    final uri =
        Uri.https('maps.googleapis.com', '/maps/api/geocode/json', params);

    try {
      final response = await http.get(uri);

      if (response.statusCode == 200) {
        final data = json.decode(response.body);

        if (data['status'] == 'OK' && data['results'].isNotEmpty) {
          final address = data['results'][0]['formatted_address'];
          print('Reverse geocoded to: "$address"');
          return address;
        }
      }
    } catch (e) {
      print('Reverse geocoding error: $e');
    }

    return null;
  }

  // Directions API - Get real directions between two points
  static Future<GoogleDirectionsResponse?> getDirections({
    required LatLng origin,
    required LatLng destination,
    String? travelMode = 'driving', // driving, walking, bicycling, transit
    String? departureTime,
  }) async {
    if (!isConfigured) {
      _logMissingApiKey();
      return null;
    }

    print('=== GOOGLE DIRECTIONS API ===');
    print(
        'Getting directions from ${origin.latitude},${origin.longitude} to ${destination.latitude},${destination.longitude}');
    print('Travel mode: $travelMode');

    final params = {
      'origin': '${origin.latitude},${origin.longitude}',
      'destination': '${destination.latitude},${destination.longitude}',
      'mode': travelMode ?? 'driving',
      'key': _apiKey,
    };

    // Add departure time for transit mode
    if (travelMode == 'transit' && departureTime != null) {
      params['departure_time'] = departureTime;
    }

    final uri =
        Uri.https('maps.googleapis.com', '/maps/api/directions/json', params);

    try {
      final response = await http.get(uri);
      print('Directions API response status: ${response.statusCode}');

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        print('Directions API status: ${data['status']}');

        if (data['status'] == 'OK' && data['routes'].isNotEmpty) {
          final directionsResponse = GoogleDirectionsResponse.fromJson(data);
          print(
              'Found ${directionsResponse.routes.length} routes with ${directionsResponse.routes.first.legs.length} legs');
          return directionsResponse;
        } else {
          print(
              'Directions API failed: ${data['status']} - ${data['error_message'] ?? 'No error message'}');
        }
      }
    } catch (e) {
      print('Directions API error: $e');
    }

    return null;
  }

  // Get multiple travel modes for the same route
  static Future<List<GoogleDirectionsResponse>> getAllDirectionsModes({
    required LatLng origin,
    required LatLng destination,
  }) async {
    if (!isConfigured) {
      _logMissingApiKey();
      return [];
    }

    final List<GoogleDirectionsResponse> allRoutes = [];

    // Add current time for transit departure
    final now = DateTime.now().millisecondsSinceEpoch ~/ 1000;

    final travelModes = [
      {'mode': 'walking', 'departure_time': null},
      {'mode': 'driving', 'departure_time': null},
      {'mode': 'transit', 'departure_time': now.toString()},
    ];

    for (final modeConfig in travelModes) {
      try {
        print('Trying ${modeConfig['mode']} mode...');
        final directions = await getDirections(
          origin: origin,
          destination: destination,
          travelMode: modeConfig['mode'] as String,
          departureTime: modeConfig['departure_time'],
        );

        if (directions != null) {
          allRoutes.add(directions);
          print('Successfully got ${modeConfig['mode']} directions');
        } else {
          print('No directions returned for ${modeConfig['mode']} mode');
        }
      } catch (e) {
        print('Error getting ${modeConfig['mode']} directions: $e');
      }
    }

    print(
        'Got directions for ${allRoutes.length} travel modes out of ${travelModes.length} requested');
    return allRoutes;
  }

  // Places Text Search API - Find places by name/query (Philippines only)
  static Future<List<GooglePlace>> searchPlaces({
    required String query,
    LatLng? location,
    double radius = 50000, // 50km radius for wider coverage
  }) async {
    if (!isConfigured) {
      _logMissingApiKey();
      return [];
    }

    // Always add Philippines to ensure Philippines-only results
    if (!query.toLowerCase().contains('philippines')) {
      query = '$query Philippines';
    }

    print('=== GOOGLE PLACES TEXT SEARCH (PHILIPPINES ONLY) ===');
    print('Searching for: "$query"');

    // Default to Philippines center if no location provided
    final searchLocation = location ?? const LatLng(12.8797, 121.7740);
    print(
        'Near location: ${searchLocation.latitude},${searchLocation.longitude}');

    final params = {
      'query': query,
      'key': _apiKey,
      'location': '${searchLocation.latitude},${searchLocation.longitude}',
      'radius': radius.toString(),
    };

    final uri = Uri.https(
        'maps.googleapis.com', '/maps/api/place/textsearch/json', params);
    print('Google Places API URL: $uri');

    try {
      final response = await http.get(uri);
      print('Places search response status: ${response.statusCode}');

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        print('Places search status: ${data['status']}');

        if (data['status'] == 'OK') {
          var places = (data['results'] as List)
              .map((place) => GooglePlace.fromJson(place))
              .toList();

          // Filter to ensure only Philippines results
          places = places
              .where((place) => _isInPhilippines(place.location))
              .toList();

          print('Found ${places.length} Philippines places for "$query"');

          // Print first few results for debugging
          for (int i = 0; i < places.length && i < 3; i++) {
            final place = places[i];
            print(
                '  ${i + 1}. ${place.name} at ${place.location.latitude},${place.location.longitude}');
          }

          return places;
        } else {
          print(
              'Places search failed: ${data['status']} - ${data['error_message'] ?? 'No error message'}');
        }
      }
    } catch (e) {
      print('Places search error: $e');
    }

    return [];
  }

  // Check if coordinates are within Philippines bounds
  static bool _isInPhilippines(LatLng location) {
    // Philippines bounding box
    const double minLat = 4.5; // Mindanao south
    const double maxLat = 21.0; // Luzon north
    const double minLng = 116.0; // Palawan west
    const double maxLng = 127.0; // Batanes east

    return location.latitude >= minLat &&
        location.latitude <= maxLat &&
        location.longitude >= minLng &&
        location.longitude <= maxLng;
  }

  // Places API - Find places near a location
  static Future<List<GooglePlace>> findNearbyPlaces({
    required LatLng location,
    required String placeType,
    double radius = 1000, // meters
  }) async {
    if (!isConfigured) {
      _logMissingApiKey();
      return [];
    }

    print('=== GOOGLE PLACES NEARBY SEARCH ===');
    print(
        'Finding $placeType near ${location.latitude},${location.longitude} within ${radius}m');

    final params = {
      'location': '${location.latitude},${location.longitude}',
      'radius': radius.toString(),
      'type': placeType,
      'key': _apiKey,
    };

    final uri = Uri.https(
        'maps.googleapis.com', '/maps/api/place/nearbysearch/json', params);

    try {
      final response = await http.get(uri);

      if (response.statusCode == 200) {
        final data = json.decode(response.body);

        if (data['status'] == 'OK') {
          final places = (data['results'] as List)
              .map((place) => GooglePlace.fromJson(place))
              .toList();
          print('Found ${places.length} nearby $placeType places');
          return places;
        }
      }
    } catch (e) {
      print('Nearby places error: $e');
    }

    return [];
  }

  // Places Photos API - Get photo URL from photo reference
  static String getPhotoUrl(String photoReference,
      {int maxWidth = 400, int maxHeight = 400}) {
    if (!isConfigured) {
      _logMissingApiKey();
      return '';
    }

    print('=== GOOGLE PLACES PHOTO API ===');
    print('Getting photo for reference: $photoReference');

    final params = {
      'maxwidth': maxWidth.toString(),
      'maxheight': maxHeight.toString(),
      'photo_reference': photoReference,
      'key': _apiKey,
    };

    final uri =
        Uri.https('maps.googleapis.com', '/maps/api/place/photo', params);
    print('Generated photo URL: $uri');
    return uri.toString();
  }

  // Place Details API - Get detailed information about a place
  static Future<GooglePlaceDetails?> getPlaceDetails(String placeId) async {
    if (!isConfigured) {
      _logMissingApiKey();
      return null;
    }

    print('=== GOOGLE PLACE DETAILS API ===');
    print('Getting details for place ID: $placeId');

    final params = {
      'place_id': placeId,
      'fields':
          'name,formatted_address,formatted_phone_number,rating,reviews,photos,types,editorial_summary,website',
      'key': _apiKey,
    };

    final uri = Uri.https(
        'maps.googleapis.com', '/maps/api/place/details/json', params);

    try {
      final response = await http.get(uri);
      print('Place details response status: ${response.statusCode}');

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        print('Place details status: ${data['status']}');

        if (data['status'] == 'OK' && data['result'] != null) {
          final placeDetails = GooglePlaceDetails.fromJson(data['result']);
          print('Successfully got details for ${placeDetails.name}');
          return placeDetails;
        } else {
          print(
              'Place details failed: ${data['status']} - ${data['error_message'] ?? 'No error message'}');
        }
      }
    } catch (e) {
      print('Place details API error: $e');
    }

    return null;
  }
}

// Models for Google API responses

class GoogleDirectionsResponse {
  final List<GoogleRoute> routes;
  final List<GoogleGeocodedWaypoint> geocodedWaypoints;
  final String status;

  GoogleDirectionsResponse({
    required this.routes,
    required this.geocodedWaypoints,
    required this.status,
  });

  factory GoogleDirectionsResponse.fromJson(Map<String, dynamic> json) {
    return GoogleDirectionsResponse(
      routes: (json['routes'] as List)
          .map((route) => GoogleRoute.fromJson(route))
          .toList(),
      geocodedWaypoints: (json['geocoded_waypoints'] as List)
          .map((waypoint) => GoogleGeocodedWaypoint.fromJson(waypoint))
          .toList(),
      status: json['status'],
    );
  }
}

class GoogleRoute {
  final List<GoogleLeg> legs;
  final String overviewPolyline;
  final List<String> warnings;
  final GoogleBounds bounds;

  GoogleRoute({
    required this.legs,
    required this.overviewPolyline,
    required this.warnings,
    required this.bounds,
  });

  factory GoogleRoute.fromJson(Map<String, dynamic> json) {
    return GoogleRoute(
      legs:
          (json['legs'] as List).map((leg) => GoogleLeg.fromJson(leg)).toList(),
      overviewPolyline: json['overview_polyline']['points'],
      warnings: List<String>.from(json['warnings'] ?? []),
      bounds: GoogleBounds.fromJson(json['bounds']),
    );
  }

  Duration get totalDuration {
    int totalSeconds = 0;
    for (final leg in legs) {
      totalSeconds += leg.duration.value;
    }
    return Duration(seconds: totalSeconds);
  }

  double get totalDistance {
    double totalMeters = 0;
    for (final leg in legs) {
      totalMeters += leg.distance.value;
    }
    return totalMeters / 1000; // Convert to km
  }
}

class GoogleLeg {
  final List<GoogleStep> steps;
  final GoogleDistance distance;
  final GoogleDuration duration;
  final String startAddress;
  final String endAddress;
  final LatLng startLocation;
  final LatLng endLocation;

  GoogleLeg({
    required this.steps,
    required this.distance,
    required this.duration,
    required this.startAddress,
    required this.endAddress,
    required this.startLocation,
    required this.endLocation,
  });

  factory GoogleLeg.fromJson(Map<String, dynamic> json) {
    return GoogleLeg(
      steps: (json['steps'] as List)
          .map((step) => GoogleStep.fromJson(step))
          .toList(),
      distance: GoogleDistance.fromJson(json['distance']),
      duration: GoogleDuration.fromJson(json['duration']),
      startAddress: json['start_address'],
      endAddress: json['end_address'],
      startLocation: LatLng(
        json['start_location']['lat'],
        json['start_location']['lng'],
      ),
      endLocation: LatLng(
        json['end_location']['lat'],
        json['end_location']['lng'],
      ),
    );
  }
}

class GoogleStep {
  final GoogleDistance distance;
  final GoogleDuration duration;
  final LatLng startLocation;
  final LatLng endLocation;
  final String htmlInstructions;
  final String maneuver;
  final String travelMode;

  GoogleStep({
    required this.distance,
    required this.duration,
    required this.startLocation,
    required this.endLocation,
    required this.htmlInstructions,
    required this.maneuver,
    required this.travelMode,
  });

  factory GoogleStep.fromJson(Map<String, dynamic> json) {
    return GoogleStep(
      distance: GoogleDistance.fromJson(json['distance']),
      duration: GoogleDuration.fromJson(json['duration']),
      startLocation: LatLng(
        json['start_location']['lat'],
        json['start_location']['lng'],
      ),
      endLocation: LatLng(
        json['end_location']['lat'],
        json['end_location']['lng'],
      ),
      htmlInstructions: json['html_instructions'],
      maneuver: json['maneuver'] ?? '',
      travelMode: json['travel_mode'] ?? '',
    );
  }
}

class GoogleDistance {
  final String text;
  final double value;

  GoogleDistance({required this.text, required this.value});

  factory GoogleDistance.fromJson(Map<String, dynamic> json) {
    return GoogleDistance(
      text: json['text'],
      value: json['value'].toDouble(),
    );
  }
}

class GoogleDuration {
  final String text;
  final int value;

  GoogleDuration({required this.text, required this.value});

  factory GoogleDuration.fromJson(Map<String, dynamic> json) {
    return GoogleDuration(
      text: json['text'],
      value: json['value'],
    );
  }
}

class GoogleBounds {
  final LatLng northeast;
  final LatLng southwest;

  GoogleBounds({required this.northeast, required this.southwest});

  factory GoogleBounds.fromJson(Map<String, dynamic> json) {
    return GoogleBounds(
      northeast: LatLng(
        json['northeast']['lat'],
        json['northeast']['lng'],
      ),
      southwest: LatLng(
        json['southwest']['lat'],
        json['southwest']['lng'],
      ),
    );
  }
}

class GoogleGeocodedWaypoint {
  final String geocoderStatus;
  final String placeId;
  final List<String> types;

  GoogleGeocodedWaypoint({
    required this.geocoderStatus,
    required this.placeId,
    required this.types,
  });

  factory GoogleGeocodedWaypoint.fromJson(Map<String, dynamic> json) {
    return GoogleGeocodedWaypoint(
      geocoderStatus: json['geocoder_status'],
      placeId: json['place_id'],
      types: List<String>.from(json['types'] ?? []),
    );
  }
}

class GooglePlace {
  final String placeId;
  final String name;
  final LatLng location;
  final String vicinity;
  final List<String> types;
  final double rating;
  final List<GooglePlacePhoto> photos;

  GooglePlace({
    required this.placeId,
    required this.name,
    required this.location,
    required this.vicinity,
    required this.types,
    required this.rating,
    required this.photos,
  });

  factory GooglePlace.fromJson(Map<String, dynamic> json) {
    return GooglePlace(
      placeId: json['place_id'],
      name: json['name'],
      location: LatLng(
        json['geometry']['location']['lat'],
        json['geometry']['location']['lng'],
      ),
      vicinity: json['vicinity'] ?? '',
      types: List<String>.from(json['types'] ?? []),
      rating: (json['rating'] as num?)?.toDouble() ?? 0.0,
      photos: (json['photos'] as List?)
              ?.map((photo) => GooglePlacePhoto.fromJson(photo))
              .toList() ??
          [],
    );
  }
}

class GooglePlacePhoto {
  final String photoReference;
  final int height;
  final int width;

  GooglePlacePhoto({
    required this.photoReference,
    required this.height,
    required this.width,
  });

  factory GooglePlacePhoto.fromJson(Map<String, dynamic> json) {
    return GooglePlacePhoto(
      photoReference: json['photo_reference'],
      height: json['height'] ?? 400,
      width: json['width'] ?? 400,
    );
  }
}

class GooglePlaceDetails {
  final String name;
  final String formattedAddress;
  final String? formattedPhoneNumber;
  final double rating;
  final List<String> types;
  final List<GooglePlacePhoto> photos;
  final String? editorialSummary;
  final String? website;

  GooglePlaceDetails({
    required this.name,
    required this.formattedAddress,
    this.formattedPhoneNumber,
    required this.rating,
    required this.types,
    required this.photos,
    this.editorialSummary,
    this.website,
  });

  factory GooglePlaceDetails.fromJson(Map<String, dynamic> json) {
    return GooglePlaceDetails(
      name: json['name'] ?? '',
      formattedAddress: json['formatted_address'] ?? '',
      formattedPhoneNumber: json['formatted_phone_number'],
      rating: (json['rating'] as num?)?.toDouble() ?? 0.0,
      types: List<String>.from(json['types'] ?? []),
      photos: (json['photos'] as List?)
              ?.map((photo) => GooglePlacePhoto.fromJson(photo))
              .toList() ??
          [],
      editorialSummary: json['editorial_summary']?['overview'],
      website: json['website'],
    );
  }
}
