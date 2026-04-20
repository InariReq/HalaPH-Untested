import 'dart:math';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:halaph/models/destination.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:geolocator/geolocator.dart';
import 'package:halaph/services/google_maps_api_service.dart';
import 'package:halaph/services/firebase_service.dart';

class DestinationService {
  // Get current city based on location
  static String getCurrentCity(LatLng location) {
    // Major Philippines cities with their approximate coordinates
    final cities = {
      'Manila': LatLng(14.5995, 120.9842),
      'Quezon City': LatLng(14.6760, 121.0437),
      'Cebu City': LatLng(10.3157, 123.8854),
      'Davao City': LatLng(7.0731, 125.6128),
      'Makati': LatLng(14.5547, 121.0244),
      'Pasig': LatLng(14.5764, 121.0851),
      'Taguig': LatLng(14.5176, 121.0515),
      'Pasay': LatLng(14.5375, 121.0014),
      'Mandaluyong': LatLng(14.5794, 121.0359),
      'San Juan': LatLng(14.6018, 121.0366),
      'Caloocan': LatLng(14.6507, 120.9663),
      'Las Piñas': LatLng(14.4378, 120.9762),
      'Muntinlupa': LatLng(14.4090, 121.0258),
      'Parañaque': LatLng(14.4793, 121.0199),
      'Marikina': LatLng(14.6528, 121.1064),
      'Valenzuela': LatLng(14.6908, 120.9838),
      'Iloilo City': LatLng(10.7158, 122.5639),
      'Baguio City': LatLng(16.4023, 120.5960),
      'Bacolod City': LatLng(10.6718, 122.9510),
      'Cagayan de Oro': LatLng(8.4542, 124.6319),
      'General Santos': LatLng(6.1164, 125.1716),
      'Zamboanga City': LatLng(6.9214, 122.0790),
      'Angeles City': LatLng(15.1474, 120.5896),
      'Batangas City': LatLng(13.7567, 121.0584),
      'Lipa City': LatLng(13.9401, 121.1615),
      'Tuguegarao': LatLng(17.6147, 121.7310),
      'Legazpi': LatLng(13.1392, 123.7438),
      'Lucena': LatLng(13.9340, 121.6162),
      'Puerto Princesa': LatLng(9.8467, 118.7333),
    };

    String closestCity = 'Quezon City'; // Default to largest city
    double minDistance = double.infinity;

    cities.forEach((cityName, cityLocation) {
      double distance = _calculateDistance(location, cityLocation);
      if (distance < minDistance) {
        minDistance = distance;
        closestCity = cityName;
      }
    });

    print(
        'Detected city: $closestCity (distance: ${minDistance.toStringAsFixed(2)} km)');
    return closestCity;
  }

  // Calculate distance between two coordinates
  static double _calculateDistance(LatLng point1, LatLng point2) {
    const double earthRadius = 6371; // Earth's radius in kilometers

    double lat1Rad = point1.latitude * (3.14159265359 / 180);
    double lat2Rad = point2.latitude * (3.14159265359 / 180);
    double deltaLatRad =
        (point2.latitude - point1.latitude) * (3.14159265359 / 180);
    double deltaLngRad =
        (point2.longitude - point1.longitude) * (3.14159265359 / 180);

    double a = sin(deltaLatRad / 2) * sin(deltaLatRad / 2) +
        cos(lat1Rad) *
            cos(lat2Rad) *
            sin(deltaLngRad / 2) *
            sin(deltaLngRad / 2);
    double c = 2 * asin(sqrt(a).clamp(0.0, 1.0));

    return earthRadius * c;
  }

  // Philippines bounding box for validation
  static const double _phMinLat = 4.5;
  static const double _phMaxLat = 21.0;
  static const double _phMinLng = 116.0;
  static const double _phMaxLng = 127.0;

  static bool _isInPhilippines(LatLng location) {
    return location.latitude >= _phMinLat &&
        location.latitude <= _phMaxLat &&
        location.longitude >= _phMinLng &&
        location.longitude <= _phMaxLng;
  }

  // Get current location
  static Future<LatLng> getCurrentLocation() async {
    print('=== DESTINATION SERVICE CALLED ===');
    try {
      print('=== GETTING CURRENT LOCATION ===');

      // Check if location services are enabled
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        print(
            'Location services are disabled - using default Philippines location');
        return _getDefaultPhilippinesLocation();
      }

      // Check location permissions
      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        print('Location permissions denied - requesting...');
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          print(
              'Location permissions still denied - using default Philippines location');
          return _getDefaultPhilippinesLocation();
        }
      }

      if (permission == LocationPermission.deniedForever) {
        print(
            'Location permissions permanently denied - using default Philippines location');
        return _getDefaultPhilippinesLocation();
      }

      // Get current position
      print('✅ Getting GPS position...');
      final Position position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
        timeLimit: const Duration(seconds: 10),
      );

      final userLocation = LatLng(position.latitude, position.longitude);
      print('✅ Current location: ${position.latitude}, ${position.longitude}');

      // Validate location is in Philippines, otherwise use default
      if (!_isInPhilippines(userLocation)) {
        print(
            '⚠️ Location outside Philippines - using default Philippines location');
        return _getDefaultPhilippinesLocation();
      }

      return userLocation;
    } catch (e) {
      print('Error getting location: $e - using default Philippines location');
      return _getDefaultPhilippinesLocation();
    }
  }

  static LatLng _getDefaultPhilippinesLocation() {
    return const LatLng(12.8797, 121.7740); // Default to Philippines
  }

  // Get all destinations - using hardcoded data for now
  static Future<List<Destination>> getDestinations() async {
    // Return hardcoded Philippines destinations
    return [
      Destination(
        id: '1',
        name: 'Intramuros',
        description: 'Historic walled city in Manila',
        location: 'Manila, Philippines',
        imageUrl:
            'https://images.unsplash.com/photo-15168893845-c5ad698dfc3e?ixlib=rb-4.0.3&ixid=MnXHtFYYlgI',
        coordinates: const LatLng(14.5995, 120.9842),
        category: DestinationCategory.landmark,
        rating: 4.6,
        budget: BudgetInfo(minCost: 0, maxCost: 200, currency: 'PHP'),
      ),
      Destination(
        id: '2',
        name: 'Boracay',
        description: 'White sand beach destination',
        location: 'Aklan, Philippines',
        imageUrl:
            'https://images.unsplash.com/photo-1520200122962-40bd9afbaef7?ixlib=rb-4.0.3&ixid=MnXHtFYYlgI',
        coordinates: const LatLng(13.2529, 123.7851),
        category: DestinationCategory.activities,
        rating: 4.8,
        budget: BudgetInfo(minCost: 1000, maxCost: 5000, currency: 'PHP'),
      ),
      Destination(
        id: '3',
        name: 'Palawan',
        description: 'Ultimate island paradise',
        location: 'Palawan, Philippines',
        imageUrl:
            'https://images.unsplash.com/photo-1518477328608-e5e3b35a0db?ixlib=rb-4.0.3&ixid=MnXHtFYYlgI',
        coordinates: const LatLng(9.8391, 118.7355),
        category: DestinationCategory.activities,
        rating: 4.9,
        budget: BudgetInfo(minCost: 2000, maxCost: 8000, currency: 'PHP'),
      ),
    ];
  }

  // Get destination by ID
  static Future<Destination?> getDestination(String id) async {
    // Find in hardcoded list
    final destinations = await getDestinations();
    try {
      return destinations.firstWhere((dest) => dest.id == id);
    } catch (e) {
      return null;
    }
  }

  // Search destinations
  static Future<List<Destination>> searchDestinations(String? query) async {
    try {
      final destinations = await getDestinations();

      if (query != null && query.isNotEmpty) {
        final searchQuery = query.toLowerCase();
        return destinations.where((dest) {
          return dest.name.toLowerCase().contains(searchQuery) ||
              dest.description.toLowerCase().contains(searchQuery) ||
              dest.category.name.toLowerCase().contains(searchQuery);
        }).toList();
      } else {
        return destinations;
      }
    } catch (e) {
      // If API fails, return empty list
      print('Search failed completely: $e');
      return [];
    }
  }

  static Future<List<Destination>> getTrendingDestinations() async {
    print('\n=== APP CALLED getTrendingDestinations ===');
    try {
      // Check if Google Maps API is configured
      if (!GoogleMapsApiService.isConfigured) {
        print('Google Maps API key not configured - using fallback data');
        return _getFallbackDestinations();
      }

      print('=== GETTING TRENDING DESTINATIONS FROM GOOGLE PLACES ===');

      // Get current location for nearby search
      final currentLocation = await getCurrentLocation();
      print('=== LOCATION DEBUG ===');
      print(
          'Searching from location: ${currentLocation.latitude}, ${currentLocation.longitude}');

      // Detect current city
      final currentCity = getCurrentCity(currentLocation);
      print('=== CITY DETECTION ===');
      print('Current city detected as: $currentCity');

      // Search for trending places in the current city
      final trendingQueries = [
        'tourist attractions in $currentCity',
        'popular restaurants in $currentCity',
        'shopping malls in $currentCity',
        'parks in $currentCity',
        'museums in $currentCity'
      ];

      print('=== SEARCH QUERIES ===');
      for (String query in trendingQueries) {
        print('Query: $query');
      }

      List<Destination> allTrendingPlaces = [];

      for (String query in trendingQueries) {
        try {
          final places = await GoogleMapsApiService.searchPlaces(
              query: query, location: currentLocation);
          print('Found ${places.length} places for query: "$query"');

          // Take top 2 from each category to get variety
          final convertedPlaces = await Future.wait(places
              .map((place) => _convertGooglePlaceToDestination(place))
              .take(2));
          allTrendingPlaces.addAll(convertedPlaces);
        } catch (e) {
          print('Error searching for "$query": $e');
        }
      }

      // Sort by rating and take top 6
      allTrendingPlaces.sort((a, b) => b.rating.compareTo(a.rating));
      final topPlaces = allTrendingPlaces.take(6).toList();

      if (topPlaces.isNotEmpty) {
        print(
            'Returning ${topPlaces.length} trending places from Google Places');
        return topPlaces;
      } else {
        print('No Google Places results, returning fallback data');
        return _getFallbackDestinations();
      }
    } catch (e) {
      print('Google Places trending failed: $e');
      print('Returning fallback data');
      return _getFallbackDestinations();
    }
  }

  static List<Destination> _getFallbackDestinations() {
    return [
      Destination(
        id: 'fallback_1',
        name: 'Intramuros',
        description:
            'Historic walled city in Manila - the oldest district and historic center of Manila',
        location: 'Manila, Philippines',
        imageUrl:
            'https://images.unsplash.com/photo-15168893845-c5ad698dfc3e?ixlib=rb-4.0.3',
        coordinates: const LatLng(14.5995, 120.9842),
        category: DestinationCategory.landmark,
        rating: 4.6,
        budget: BudgetInfo(minCost: 0, maxCost: 500, currency: 'PHP'),
      ),
      Destination(
        id: 'fallback_2',
        name: 'Boracay',
        description:
            'World-famous white sand beach destination with crystal clear waters',
        location: 'Aklan, Philippines',
        imageUrl:
            'https://images.unsplash.com/photo-1520200122962-40bd9afbaef7?ixlib=rb-4.0.3',
        coordinates: const LatLng(11.9684, 121.9213),
        category: DestinationCategory.activities,
        rating: 4.8,
        budget: BudgetInfo(minCost: 2000, maxCost: 8000, currency: 'PHP'),
      ),
      Destination(
        id: 'fallback_3',
        name: 'Palawan',
        description:
            'Ultimate island paradise with stunning lagoons and pristine beaches',
        location: 'Palawan, Philippines',
        imageUrl:
            'https://images.unsplash.com/photo-1518509562904-e7ef99cdcc86?ixlib=rb-4.0.3',
        coordinates: const LatLng(9.8391, 118.7355),
        category: DestinationCategory.activities,
        rating: 4.9,
        budget: BudgetInfo(minCost: 3000, maxCost: 10000, currency: 'PHP'),
      ),
      Destination(
        id: 'fallback_4',
        name: 'Chocolate Hills',
        description:
            'Unique geological formation in Bohol - over 1,000 cone-shaped hills',
        location: 'Bohol, Philippines',
        imageUrl:
            'https://images.unsplash.com/photo-1548786811-dd6e453ccca7?ixlib=rb-4.0.3',
        coordinates: const LatLng(9.8180, 124.1435),
        category: DestinationCategory.landmark,
        rating: 4.5,
        budget: BudgetInfo(minCost: 500, maxCost: 2000, currency: 'PHP'),
      ),
      Destination(
        id: 'fallback_5',
        name: 'Taal Volcano',
        description:
            'One of the world\'s smallest active volcanoes with a crater lake',
        location: 'Batangas, Philippines',
        imageUrl:
            'https://images.unsplash.com/photo-1587620962725-abab7fe55159?ixlib=rb-4.0.3',
        coordinates: const LatLng(14.0022, 120.9978),
        category: DestinationCategory.landmark,
        rating: 4.7,
        budget: BudgetInfo(minCost: 300, maxCost: 1500, currency: 'PHP'),
      ),
      Destination(
        id: 'fallback_6',
        name: 'Banaue Rice Terraces',
        description: 'Ancient mountainous terraces - wonder of the world',
        location: 'Ifugao, Philippines',
        imageUrl:
            'https://images.unsplash.com/photo-1601806459988-c735a9a95879?ixlib=rb-4.0.3',
        coordinates: const LatLng(16.9117, 121.0597),
        category: DestinationCategory.landmark,
        rating: 4.6,
        budget: BudgetInfo(minCost: 1000, maxCost: 4000, currency: 'PHP'),
      ),
    ];
  }

  static DestinationCategory _parseCategory(List<String> types) {
    // Check for shopping/retail first (highest priority for places like SM)
    if (types.contains('shopping_mall') ||
        types.contains('market') ||
        types.contains('store') ||
        types.contains('supermarket')) {
      return DestinationCategory.market;
    }
    // Then check for food/restaurant
    else if (types.contains('restaurant') ||
        types.contains('food') ||
        types.contains('cafe') ||
        types.contains('bakery')) {
      return DestinationCategory.food;
    }
    // Then check for parks
    else if (types.contains('park') || types.contains('natural_feature')) {
      return DestinationCategory.park;
    }
    // Then check for museums
    else if (types.contains('museum') || types.contains('art_gallery')) {
      return DestinationCategory.museum;
    }
    // Then check for activities/entertainment
    else if (types.contains('amusement_park') ||
        types.contains('zoo') ||
        types.contains('aquarium') ||
        types.contains('stadium') ||
        types.contains('entertainment')) {
      return DestinationCategory.activities;
    }
    // Finally check for landmarks (lowest priority)
    else if (types.contains('landmark') ||
        types.contains('tourist_attraction') ||
        types.contains('historic_site')) {
      return DestinationCategory.landmark;
    }
    // Default to landmark if nothing matches
    return DestinationCategory.landmark;
  }

  static String getCategoryName(DestinationCategory category) {
    switch (category) {
      case DestinationCategory.park:
        return 'Parks';
      case DestinationCategory.landmark:
        return 'Landmarks';
      case DestinationCategory.food:
        return 'Food';
      case DestinationCategory.activities:
        return 'Activities';
      case DestinationCategory.museum:
        return 'Museums';
      case DestinationCategory.market:
        return 'Markets';
    }
  }

  static Future<Destination?> getDestinationById(String id) async {
    try {
      // Try to get real destination data from API
      // For now, return hardcoded destination data
      return await getDestination(id);
    } catch (e) {
      print('API get destination failed: $e');
      return null;
    }
  }

  static Future<Destination> _convertGooglePlaceToDestination(
      GooglePlace place) async {
    print('=== CONVERTING GOOGLE PLACE ===');
    print('Place name: ${place.name}');
    print('Place ID: ${place.placeId}');
    print('Number of photos: ${place.photos.length}');

    // Get detailed place information including address and description
    String description = place.vicinity;
    String location = place.vicinity;

    try {
      final placeDetails =
          await GoogleMapsApiService.getPlaceDetails(place.placeId);
      if (placeDetails != null) {
        print('Got detailed information for ${place.name}');

        // Use formatted address if available
        if (placeDetails.formattedAddress.isNotEmpty) {
          location = placeDetails.formattedAddress;
        }

        // Use editorial summary if available, otherwise generate description
        if (placeDetails.editorialSummary != null &&
            placeDetails.editorialSummary!.isNotEmpty) {
          description = placeDetails.editorialSummary!;
        } else {
          // Generate a description based on place type and name
          description =
              _generateDescription(place.name, _parseCategory(place.types));
        }

        print('Final location: $location');
        print('Final description: $description');
      }
    } catch (e) {
      print('Error getting place details: $e');
      // Fallback to generated description
      description =
          _generateDescription(place.name, _parseCategory(place.types));
    }

    // Get real photo from Google Places if available, otherwise use category placeholder
    String imageUrl;
    if (place.photos.isNotEmpty) {
      // Use the first photo from Google Places
      final photoReference = place.photos.first.photoReference;
      print('Using photo reference: $photoReference');

      imageUrl = GoogleMapsApiService.getPhotoUrl(
        photoReference,
        maxWidth: 800,
        maxHeight: 600,
      );
      print('Using Google Places photo for ${place.name}: $imageUrl');
    } else {
      // Fallback to category-based placeholder
      imageUrl = _getCategoryImage(_parseCategory(place.types));
      print(
          'No photos available for ${place.name}, using category placeholder: $imageUrl');
    }

    return Destination(
      id: place.placeId,
      name: place.name,
      description: description,
      location: location,
      imageUrl: imageUrl,
      coordinates: place.location,
      category: _parseCategory(place.types),
      rating: place.rating,
      budget: BudgetInfo(minCost: 0, maxCost: 0, currency: 'PHP'),
    );
  }

  // Generate descriptive text based on place name and category
  static String _generateDescription(
      String name, DestinationCategory category) {
    switch (category) {
      case DestinationCategory.park:
        return 'A beautiful $name perfect for relaxation, outdoor activities, and enjoying nature. Great for families and nature lovers.';
      case DestinationCategory.landmark:
        return 'An iconic $name and must-see historical attraction. Perfect for learning about local culture and taking memorable photos.';
      case DestinationCategory.food:
        return 'A popular dining destination at $name. Known for delicious cuisine and great atmosphere for meals with friends and family.';
      case DestinationCategory.activities:
        return 'An exciting $name offering fun activities and adventures. Perfect for thrill-seekers and creating unforgettable memories.';
      case DestinationCategory.museum:
        return 'A fascinating $name showcasing art, history, and culture. Ideal for learning and exploration with educational exhibits.';
      case DestinationCategory.market:
        return 'A vibrant $name offering local products, crafts, and authentic shopping experiences. Great for finding unique souvenirs.';
    }
  }

  static String _getCategoryImage(DestinationCategory category) {
    switch (category) {
      case DestinationCategory.park:
        return 'https://images.unsplash.com/photo-1506905925346-21bda4d32df4?ixlib=rb-4.0.3&ixid=MnXHtFYYlgI';
      case DestinationCategory.landmark:
        return 'https://images.unsplash.com/photo-15168893845-c5ad698dfc3e?ixlib=rb-4.0.3&ixid=MnXHtFYYlgI';
      case DestinationCategory.food:
        return 'https://images.unsplash.com/photo-1565299624946-b28f40a0ae38?ixlib=rb-4.0.3&ixid=MnXHtFYYlgI';
      case DestinationCategory.activities:
        return 'https://images.unsplash.com/photo-1520200122962-40bd9afbaef7?ixlib=rb-4.0.3&ixid=MnXHtFYYlgI';
      case DestinationCategory.museum:
        return 'https://images.unsplash.com/photo-1541961017774-22349e4a1262?ixlib=rb-4.0.3&ixid=MnXHtFYYlgI';
      case DestinationCategory.market:
        return 'https://images.unsplash.com/photo-1516448483748-2aa0cf52309a?ixlib=rb-4.0.3&ixid=MnXHtFYYlgI';
      default:
        return 'https://images.unsplash.com/photo-1518477328608-e5e3b35a0db?ixlib=rb-4.0.3&ixid=MnXHtFYYlgI';
    }
  }

  // NEW: Search real places using Google Places API
  static Future<List<Destination>> searchRealPlaces({
    required String query,
    LatLng? location,
    DestinationCategory? category,
  }) async {
    try {
      // Get current location if none provided
      final searchLocation = location ?? await getCurrentLocation();
      print(
          'Using location: ${searchLocation.latitude}, ${searchLocation.longitude}');

      // Build search query based on category
      String searchQuery = query.isNotEmpty ? query : 'tourist attractions';

      if (category != null) {
        switch (category) {
          case DestinationCategory.food:
            searchQuery = query.isNotEmpty ? query : 'restaurants';
            break;
          case DestinationCategory.park:
            searchQuery = query.isNotEmpty ? query : 'parks';
            break;
          case DestinationCategory.museum:
            searchQuery = query.isNotEmpty ? query : 'museums';
            break;
          case DestinationCategory.market:
            searchQuery = query.isNotEmpty ? query : 'shopping malls';
            break;
          case DestinationCategory.activities:
            searchQuery = query.isNotEmpty ? query : 'activities';
            break;
          case DestinationCategory.landmark:
            searchQuery = query.isNotEmpty ? query : 'landmarks';
            break;
        }
      }

      // Add Philippines to get local results but don't force Manila
      searchQuery = '$searchQuery Philippines';

      print('Using text search with query: "$searchQuery"');
      final googlePlaces = await GoogleMapsApiService.searchPlaces(
          query: searchQuery, location: searchLocation);
      final realPlaces = await Future.wait(
          googlePlaces.map((place) => _convertGooglePlaceToDestination(place)));
      return realPlaces;
    } catch (e) {
      print('Error searching real places: $e');
      // Return empty list if all methods fail
      return [];
    }
  }

  // NEW: Get autocomplete suggestions
  static Future<List<String>> getAutocompleteSuggestions(String input,
      {LatLng? location}) async {
    try {
      // Use Google Maps API for autocomplete (simplified version)
      return [];
      // TODO: Implement proper autocomplete using GoogleMapsApiService
    } catch (e) {
      print('Error getting autocomplete: $e');
      return [];
    }
  }

  // Enhanced search that prioritizes Google Places API
  static Future<List<Destination>> searchDestinationsEnhanced({
    String? query,
    DestinationCategory? category,
  }) async {
    print('\n=== APP CALLED searchDestinationsEnhanced ===');
    try {
      // Check if Google Maps API is configured
      if (!GoogleMapsApiService.isConfigured) {
        print('Google Maps API key not configured - using fallback data');
        return _getFilteredFallbackDestinations(
            query: query, category: category);
      }

      print('=== ENHANCED SEARCH: query="$query", category=$category ===');

      // Get current location for location-based search
      final currentLocation = await getCurrentLocation();

      // Use category-specific search query if category is selected but no search query
      String searchQuery;
      if (query?.isNotEmpty == true) {
        searchQuery = query!;
      } else if (category != null) {
        searchQuery = _getCategoryQuery(category);
        print('Using category-specific query: "$searchQuery"');
      } else {
        searchQuery = 'tourist attractions Philippines';
      }

      final googlePlaces = await GoogleMapsApiService.searchPlaces(
          query: searchQuery, location: currentLocation);
      final realPlaces = await Future.wait(
          googlePlaces.map((place) => _convertGooglePlaceToDestination(place)));
      print('Google Places returned ${realPlaces.length} results');

      // Filter by category if specified
      if (category != null && realPlaces.isNotEmpty) {
        final filtered =
            realPlaces.where((dest) => dest.category == category).toList();
        print('Filtered to ${filtered.length} results for category $category');
        return filtered;
      }

      if (realPlaces.isNotEmpty) {
        print('Returning ${realPlaces.length} Google Places results');
        return realPlaces;
      }

      print('Google Places returned no results - using fallback');
      return _getFilteredFallbackDestinations(query: query, category: category);
    } catch (e) {
      print('Enhanced search failed: $e');
      return _getFilteredFallbackDestinations(query: query, category: category);
    }
  }

  static List<Destination> _getFilteredFallbackDestinations(
      {String? query, DestinationCategory? category}) {
    var destinations = _getFallbackDestinations();

    // Filter by category
    if (category != null) {
      destinations = destinations.where((d) => d.category == category).toList();
    }

    // Filter by query
    if (query != null && query.isNotEmpty) {
      final searchTerm = query.toLowerCase();
      destinations = destinations
          .where((d) =>
              d.name.toLowerCase().contains(searchTerm) ||
              d.description.toLowerCase().contains(searchTerm) ||
              d.location.toLowerCase().contains(searchTerm))
          .toList();
    }

    return destinations;
  }

  // Helper method to convert category to search query
  static String _getCategoryQuery(DestinationCategory category) {
    switch (category) {
      case DestinationCategory.food:
        return 'restaurants';
      case DestinationCategory.park:
        return 'parks';
      case DestinationCategory.museum:
        return 'museums';
      case DestinationCategory.market:
        return 'shopping malls';
      case DestinationCategory.activities:
        return 'activities';
      case DestinationCategory.landmark:
        return 'tourist attractions';
    }
  }

  // Helper method for original search logic
  static Future<List<Destination>> _searchOriginalDestinations({
    String? query,
    DestinationCategory? category,
  }) async {
    try {
      final destinations = await getDestinations();

      return destinations.where((destination) {
        // Filter by query
        if (query != null && query.isNotEmpty) {
          final searchTerm = query.toLowerCase();
          final matchesName =
              destination.name.toLowerCase().contains(searchTerm);
          final matchesLocation =
              destination.location.toLowerCase().contains(searchTerm);
          final matchesDescription =
              destination.description.toLowerCase().contains(searchTerm);

          if (!matchesName && !matchesLocation && !matchesDescription) {
            return false;
          }
        }

        // Filter by category
        if (category != null && destination.category != category) {
          return false;
        }

        return true;
      }).toList();
    } catch (e) {
      return [];
    }
  }

  // Firestore-based favorites
  static Future<List<Destination>> getFavorites() async {
    if (FirebaseService.currentUserId == null) return [];

    try {
      final snapshot = await FirebaseFirestore.instance
          .collection('favorites')
          .where('userId', isEqualTo: FirebaseService.currentUserId)
          .get();

      return snapshot.docs.map((doc) {
        final data = doc.data();
        return Destination.fromJson(data['destination']);
      }).toList();
    } catch (e) {
      print('Error getting favorites: $e');
      return [];
    }
  }

  static Future<void> addToFavorites(Destination destination) async {
    if (FirebaseService.currentUserId == null) return;

    try {
      await FirebaseFirestore.instance.collection('favorites').add({
        'userId': FirebaseService.currentUserId,
        'destinationId': destination.id,
        'destination': destination.toJson(),
        'createdAt': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      print('Error adding to favorites: $e');
    }
  }

  static Future<void> removeFromFavorites(String destinationId) async {
    if (FirebaseService.currentUserId == null) return;

    try {
      final snapshot = await FirebaseFirestore.instance
          .collection('favorites')
          .where('userId', isEqualTo: FirebaseService.currentUserId)
          .where('destinationId', isEqualTo: destinationId)
          .get();

      for (final doc in snapshot.docs) {
        await doc.reference.delete();
      }
    } catch (e) {
      print('Error removing from favorites: $e');
    }
  }

  static Future<bool> isFavorite(String destinationId) async {
    if (FirebaseService.currentUserId == null) return false;

    try {
      final snapshot = await FirebaseFirestore.instance
          .collection('favorites')
          .where('userId', isEqualTo: FirebaseService.currentUserId)
          .where('destinationId', isEqualTo: destinationId)
          .get();

      return snapshot.docs.isNotEmpty;
    } catch (e) {
      return false;
    }
  }

  // Firestore-based recently viewed
  static Future<List<Destination>> getRecentlyViewed() async {
    if (FirebaseService.currentUserId == null) return [];

    try {
      final snapshot = await FirebaseFirestore.instance
          .collection('recently_viewed')
          .where('userId', isEqualTo: FirebaseService.currentUserId)
          .orderBy('viewedAt', descending: true)
          .limit(10)
          .get();

      return snapshot.docs.map((doc) {
        final data = doc.data();
        return Destination.fromJson(data['destination']);
      }).toList();
    } catch (e) {
      print('Error getting recently viewed: $e');
      return [];
    }
  }

  static Future<void> addToRecentlyViewed(Destination destination) async {
    if (FirebaseService.currentUserId == null) return;

    try {
      // Check if already exists and remove
      final existing = await FirebaseFirestore.instance
          .collection('recently_viewed')
          .where('userId', isEqualTo: FirebaseService.currentUserId)
          .where('destinationId', isEqualTo: destination.id)
          .get();

      for (final doc in existing.docs) {
        await doc.reference.delete();
      }

      // Add new
      await FirebaseFirestore.instance.collection('recently_viewed').add({
        'userId': FirebaseService.currentUserId,
        'destinationId': destination.id,
        'destination': destination.toJson(),
        'viewedAt': FieldValue.serverTimestamp(),
      });

      // Keep only last 20
      final all = await FirebaseFirestore.instance
          .collection('recently_viewed')
          .where('userId', isEqualTo: FirebaseService.currentUserId)
          .orderBy('viewedAt', descending: false)
          .get();

      if (all.docs.length > 20) {
        for (int i = 0; i < all.docs.length - 20; i++) {
          await all.docs[i].reference.delete();
        }
      }
    } catch (e) {
      print('Error adding to recently viewed: $e');
    }
  }
}
