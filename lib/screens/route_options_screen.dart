import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:halaph/services/destination_service.dart';
import 'package:halaph/services/budget_routing_service.dart';
import 'package:halaph/services/google_maps_api_service.dart';
import 'package:halaph/models/destination.dart';

class TransportModeInfo {
  final String name;
  final IconData icon;
  final Color color;

  TransportModeInfo({
    required this.name,
    required this.icon,
    required this.color,
  });
}

class RouteOptionsScreen extends StatefulWidget {
  final String destinationId;
  final String destinationName;
  final Destination? destination;

  const RouteOptionsScreen({
    super.key,
    required this.destinationId,
    required this.destinationName,
    this.destination,
  });

  @override
  State<RouteOptionsScreen> createState() => _RouteOptionsScreenState();
}

class _RouteOptionsScreenState extends State<RouteOptionsScreen> {
  LatLng? _currentLocation;
  LatLng? _destinationLocation;
  bool _isLoading = true;
  Set<Marker> _markers = {};
  Set<Polyline> _polylines = {};
  GoogleMapController? _mapController;
  List<BudgetRoute> _budgetRoutes = [];
  BudgetRoute? _selectedRoute;
  // Removed unused fields - now using Google Directions API

  
  @override
  void initState() {
    super.initState();
    _loadRouteData();
  }

  @override
  void dispose() {
    _mapController?.dispose();
    super.dispose();
  }

  Future<void> _loadRouteData() async {
    print('=== ROUTE OPTIONS SCREEN: _loadRouteData() CALLED ===');
    try {
      // Get current location
      print('=== GETTING CURRENT LOCATION ===');
      final currentLoc = await DestinationService.getCurrentLocation();
      
      // Get actual destination from destination service
      LatLng destLoc;
      try {
        final destination = await DestinationService.getDestination(widget.destinationId);
        if (destination != null) {
          // Use actual coordinates from Google Places if available
          if (destination.coordinates != null) {
            destLoc = destination.coordinates!;
            print('Using actual coordinates from destination: ${destLoc.latitude}, ${destLoc.longitude}');
          } else {
            // Try to extract coordinates from destination location field
            print('No coordinates in destination, trying to extract from location field');
            destLoc = await _extractCoordinatesFromDestination(destination);
          }
        } else {
          // Fallback to geocoding the destination name
          print('Destination not found, using geocoding for: ${widget.destinationName}');
          destLoc = await _geocodeDestination(widget.destinationName);
        }
      } catch (e) {
        print('Error getting destination, using geocoding: $e');
        destLoc = await _geocodeDestination(widget.destinationName);
      }
      
      // Calculate routes using Google Directions API with walking and transit modes
      print('=== CALLING GOOGLE DIRECTIONS API ===');
      print('Origin: ${currentLoc.latitude}, ${currentLoc.longitude}');
      print('Destination: ${destLoc.latitude}, ${destLoc.longitude}');
      
      final googleRoutes = await GoogleMapsApiService.getAllDirectionsModes(
        origin: currentLoc,
        destination: destLoc,
      );
      
      print('Google returned ${googleRoutes.length} routes');
      
      // Convert Google routes to BudgetRoute format for UI compatibility
      final routes = <BudgetRoute>[];
      for (var directions in googleRoutes) {
        if (directions.routes.isNotEmpty) {
          final budgetRoute = _convertGoogleRouteToBudgetRoute(directions);
          routes.add(budgetRoute);
        }
      }
      
      print('Converted ${routes.length} routes to BudgetRoute format');
      for (var route in routes) {
        print('BudgetRoute: ${route.mode}, distance: ${route.distance}km, cost: ₱${route.cost}');
      }
      
      // Show all routes - no filtering for now
      final allRoutes = routes;
      
      print('Showing ${allRoutes.length} routes (all modes)');
      
      setState(() {
        _currentLocation = currentLoc;
        _destinationLocation = destLoc;
        _budgetRoutes = allRoutes;
        _selectedRoute = allRoutes.isNotEmpty ? allRoutes.first : null;
        _isLoading = false;
        
        // Create markers
        _markers = {
          Marker(
            markerId: const MarkerId('current'),
            position: currentLoc,
            infoWindow: const InfoWindow(title: 'You'),
            icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueBlue),
          ),
          Marker(
            markerId: const MarkerId('destination'),
            position: destLoc,
            infoWindow: InfoWindow(title: widget.destinationName),
            icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueRed),
          ),
        };
        
        // Create polylines from selected route - show different colors for each transport mode
        if (_selectedRoute != null && _selectedRoute!.polyline.isNotEmpty) {
          final Set<Polyline> routePolylines = {};
          
          // Create single polyline for the route
          routePolylines.add(
            Polyline(
              polylineId: PolylineId('route_${_selectedRoute!.mode}'),
              points: _selectedRoute!.polyline,
              color: _getTransportModeInfo(_selectedRoute!.mode).color,
              width: 4,
              patterns: _selectedRoute!.mode == TravelMode.walking 
                  ? [PatternItem.dash(10), PatternItem.gap(5)]
                  : [],
            ),
          );
            
          
          _polylines = routePolylines;
          print('Created ${routePolylines.length} polylines for route');
        }
      });
    } catch (e) {
      print('Error loading route data: $e');
      setState(() => _isLoading = false);
    }
  }

  void _onMapCreated(GoogleMapController controller) {
    _mapController = controller;
    // Auto-zoom to fit both markers
    if (_currentLocation != null && _destinationLocation != null) {
      final bounds = LatLngBounds(
        southwest: LatLng(
          _currentLocation!.latitude < _destinationLocation!.latitude 
              ? _currentLocation!.latitude 
              : _destinationLocation!.latitude,
          _currentLocation!.longitude < _destinationLocation!.longitude 
              ? _currentLocation!.longitude 
              : _destinationLocation!.longitude,
        ),
        northeast: LatLng(
          _currentLocation!.latitude > _destinationLocation!.latitude 
              ? _currentLocation!.latitude 
              : _destinationLocation!.latitude,
          _currentLocation!.longitude > _destinationLocation!.longitude 
              ? _currentLocation!.longitude 
              : _destinationLocation!.longitude,
        ),
      );
      
      // Add padding to ensure markers are visible
      final padding = 0.02; // 2% padding
      final paddedBounds = LatLngBounds(
        southwest: LatLng(
          bounds.southwest.latitude - padding,
          bounds.southwest.longitude - padding,
        ),
        northeast: LatLng(
          bounds.northeast.latitude + padding,
          bounds.northeast.longitude + padding,
        ),
      );
      
      controller.animateCamera(CameraUpdate.newLatLngBounds(paddedBounds, 100));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        surfaceTintColor: Colors.transparent,
        leading: IconButton(
          icon: const Icon(Icons.close, color: Colors.black),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          'Route Options',
          style: TextStyle(
            color: Colors.black,
            fontSize: 18,
            fontWeight: FontWeight.w600,
          ),
        ),
        actions: [
          IconButton(
            icon: Icon(Icons.info_outline, color: Colors.grey[600]),
            onPressed: () {
              // Show info dialog
            },
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                // Your Journey Section
                _buildYourJourneySection(),
                // Available Transport Section
                _buildAvailableTransportSection(),
                // Start Navigation Button
                _buildStartNavigationButton(),
              ],
            ),
    );
  }

  Widget _buildYourJourneySection() {
    return Container(
      margin: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Your Journey',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                  color: Colors.black,
                ),
              ),
              Text(
                'Updated 1m ago',
                style: TextStyle(
                  fontSize: 14,
                  color: Colors.grey[600],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          // Map Container
          Container(
            height: 200,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.1),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: GoogleMap(
                onMapCreated: _onMapCreated,
                initialCameraPosition: CameraPosition(
                  target: _currentLocation!,
                  zoom: 14,
                ),
                markers: _markers,
                polylines: _polylines,
                zoomControlsEnabled: false,
                scrollGesturesEnabled: false,
                tiltGesturesEnabled: false,
                rotateGesturesEnabled: false,
              ),
            ),
          ),
          const SizedBox(height: 8),
          // Distance Info
          if (_selectedRoute != null)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: Colors.grey[100],
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                '${_selectedRoute!.distance.toStringAsFixed(1)} km total',
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                  color: Colors.black87,
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildAvailableTransportSection() {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Available Transport',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                    color: Colors.black,
                  ),
                ),
                Text(
                  '${_budgetRoutes.length} Options Found',
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.grey[600],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            // Transport Options List
            Expanded(
              child: ListView.builder(
                itemCount: _budgetRoutes.length,
                itemBuilder: (context, index) {
                  final route = _budgetRoutes[index];
                  final isSelected = _selectedRoute?.id == route.id;
                  final modeInfo = _getTransportModeInfo(route.mode);
                  
                  return Container(
                    margin: const EdgeInsets.only(bottom: 12),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: isSelected ? modeInfo.color : Colors.grey[300]!,
                        width: isSelected ? 2 : 1,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.05),
                          blurRadius: 4,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: Material(
                      color: Colors.transparent,
                      child: InkWell(
                        onTap: () => _selectRoute(route),
                        borderRadius: BorderRadius.circular(12),
                        child: Padding(
                          padding: const EdgeInsets.all(16),
                          child: Row(
                            children: [
                              // Icon
                              Container(
                                width: 40,
                                height: 40,
                                decoration: BoxDecoration(
                                  color: modeInfo.color.withOpacity(0.1),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Icon(
                                  modeInfo.icon,
                                  color: modeInfo.color,
                                  size: 24,
                                ),
                              ),
                              const SizedBox(width: 12),
                              // Transport Info
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      modeInfo.name,
                                      style: const TextStyle(
                                        fontSize: 16,
                                        fontWeight: FontWeight.w600,
                                        color: Colors.black,
                                      ),
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      _getTransportDetails(route),
                                      style: TextStyle(
                                        fontSize: 14,
                                        color: Colors.grey[600],
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              // Time and Price
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.end,
                                children: [
                                  Text(
                                    '${route.duration.inMinutes} min',
                                    style: const TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.w600,
                                      color: Colors.black,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    route.cost == 0.0 ? 'Free' : '₱${route.cost.toStringAsFixed(2)}',
                                    style: TextStyle(
                                      fontSize: 14,
                                      fontWeight: FontWeight.w500,
                                      color: route.cost == 0.0 ? Colors.green : Colors.black87,
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ),
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

  String _getTransportDetails(BudgetRoute route) {
    switch (route.mode) {
      case TravelMode.walking:
        return '${route.distance.toStringAsFixed(1)} km • Free';
      case TravelMode.jeepney:
        return '${route.distance.toStringAsFixed(1)} km • ₱${route.cost.toStringAsFixed(0)}';
      case TravelMode.bus:
        return '${route.distance.toStringAsFixed(1)} km • ₱${route.cost.toStringAsFixed(0)}';
      case TravelMode.train:
        return '${route.distance.toStringAsFixed(1)} km • ₱${route.cost.toStringAsFixed(0)}';
      case TravelMode.driving:
        return '${route.distance.toStringAsFixed(1)} km • ₱${route.cost.toStringAsFixed(0)}';
    }
  }

  
  void _selectRoute(BudgetRoute route) {
    setState(() {
      _selectedRoute = route;
      _polylines = route.polyline.isNotEmpty 
          ? {
              Polyline(
                polylineId: PolylineId('selected_${route.mode}'),
                points: route.polyline,
                color: _getTransportModeInfo(route.mode).color,
                width: 6,
                patterns: route.mode == TravelMode.walking 
                    ? [PatternItem.dash(10), PatternItem.gap(5)]
                    : [],
              ),
            }
          : {};
    });
  }

  Future<LatLng> _extractCoordinatesFromDestination(Destination destination) async {
    // Try to parse coordinates from destination location field if it contains them
    final location = destination.location.toLowerCase();
    
    // Check if location contains coordinates (like "14.1234, 123.5678")
    final coordPattern = RegExp(r'(\d+\.?\d*)\s*,\s*(\d+\.?\d*)');
    final match = coordPattern.firstMatch(location);
    
    if (match != null) {
      try {
        final lat = double.parse(match.group(1)!);
        final lng = double.parse(match.group(2)!);
        print('Extracted coordinates from destination: $lat, $lng');
        return LatLng(lat, lng);
      } catch (e) {
        print('Error parsing coordinates: $e');
      }
    }
    
    // If no coordinates in location field, try geocoding the name
    return await _geocodeDestination(destination.name);
  }

  Future<LatLng> _geocodeDestination(String destinationName) async {
    print('=== GOOGLE LOCATION SEARCH ===');
    print('Finding location for: $destinationName');
    
    try {
      // First try Google Geocoding API
      final coordinates = await GoogleMapsApiService.geocodeAddress(destinationName);
      
      if (coordinates != null) {
        print('Google Geocoded "$destinationName" to: ${coordinates.latitude}, ${coordinates.longitude}');
        return coordinates;
      } else {
        print('Google Geocoding failed, trying Places Text Search...');
        
        // Try Google Places Text Search as fallback
        final currentLocation = await DestinationService.getCurrentLocation();
        final places = await GoogleMapsApiService.searchPlaces(
          query: destinationName,
          location: currentLocation,
        );
        
        if (places.isNotEmpty) {
          final place = places.first;
          print('Google Places found "${place.name}" at: ${place.location.latitude}, ${place.location.longitude}');
          return place.location;
        } else {
          print('Google Places also failed, using hardcoded fallback');
          return await _getFallbackCoordinates(destinationName);
        }
      }
    } catch (e) {
      print('Google location search error: $e, using fallback');
      return await _getFallbackCoordinates(destinationName);
    }
  }

  Future<LatLng> _getFallbackCoordinates(String destinationName) async {
    print('Using fallback coordinates for: $destinationName');
    
    // Simple heuristic for major Philippine cities
    final name = destinationName.toLowerCase();
    if (name.contains('cebu')) return const LatLng(10.3157, 123.8854);
    if (name.contains('davao')) return const LatLng(7.0731, 125.6128);
    if (name.contains('makati')) return const LatLng(14.5547, 121.0244);
    if (name.contains('quezon')) return const LatLng(14.6760, 121.0437);
    if (name.contains('pasig')) return const LatLng(14.5764, 121.0851);
    if (name.contains('taguig')) return const LatLng(14.5176, 121.0515);
    if (name.contains('pasay')) return const LatLng(14.5375, 121.0014);
    if (name.contains('mandaluyong')) return const LatLng(14.5794, 121.0359);
    if (name.contains('san juan')) return const LatLng(14.6018, 121.0366);
    if (name.contains('caloocan')) return const LatLng(14.6507, 120.9663);
    if (name.contains('las piñas')) return const LatLng(14.4378, 120.9762);
    if (name.contains('muntinlupa')) return const LatLng(14.4090, 121.0258);
    if (name.contains('parañaque')) return const LatLng(14.4793, 121.0199);
    if (name.contains('marikina')) return const LatLng(14.6528, 121.1064);
    if (name.contains('valenzuela')) return const LatLng(14.6908, 120.9838);
    if (name.contains('iloilo')) return const LatLng(10.7158, 122.5639);
    if (name.contains('baguio')) return const LatLng(16.4023, 120.5960);
    if (name.contains('bacolod')) return const LatLng(10.6718, 122.9510);
    if (name.contains('cagayan')) return const LatLng(8.4542, 124.6319);
    
    // Default to Manila
    print('Using Manila as default location');
    return const LatLng(14.5995, 120.9842);
  }

  TransportModeInfo _getTransportModeInfo(TravelMode mode) {
    switch (mode) {
      case TravelMode.walking:
        return TransportModeInfo(
          name: 'Walk',
          icon: Icons.directions_walk,
          color: Colors.green,
        );
      case TravelMode.jeepney:
        return TransportModeInfo(
          name: 'Jeepney',
          icon: Icons.directions_bus,
          color: Colors.orange,
        );
      case TravelMode.bus:
        return TransportModeInfo(
          name: 'Bus',
          icon: Icons.directions_bus,
          color: Colors.blue,
        );
      case TravelMode.train:
        return TransportModeInfo(
          name: 'Train',
          icon: Icons.train,
          color: Colors.purple,
        );
      case TravelMode.driving:
        return TransportModeInfo(
          name: 'Car',
          icon: Icons.directions_car,
          color: Colors.red,
        );
    }
  }

Widget _buildStartNavigationButton() {
    return Container(
      padding: const EdgeInsets.all(16),
      child: SizedBox(
        width: double.infinity,
        child: ElevatedButton(
          onPressed: () {
            // Start navigation logic
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Starting navigation...')),
            );
          },
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.blue,
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(vertical: 16),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            elevation: 0,
          ),
          child: const Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.navigation, size: 20),
              SizedBox(width: 8),
              Text(
                'Start Navigation',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // Convert Google Directions to BudgetRoute format for UI compatibility
  BudgetRoute _convertGoogleRouteToBudgetRoute(GoogleDirectionsResponse googleDirections) {
    if (googleDirections.routes.isEmpty) {
      return BudgetRoute(
        id: 'error',
        mode: TravelMode.driving,
        start: _currentLocation ?? const LatLng(0, 0),
        end: _destinationLocation ?? const LatLng(0, 0),
        duration: const Duration(minutes: 0),
        distance: 0.0,
        cost: 0.0,
        instructions: ['No route found'],
        polyline: [],
        summary: 'No route',
        tips: [],
      );
    }

    final route = googleDirections.routes.first;
    final totalDistance = route.totalDistance * 1000; // Convert km back to meters
    final totalDuration = Duration(seconds: route.totalDuration.inSeconds);
    
    // Determine travel mode from the route
    TravelMode mode = TravelMode.driving;
    
    // Debug: Check what travel modes are in the steps
    print('DEBUG: Checking travel modes in route steps...');
    for (var leg in route.legs) {
      for (var step in leg.steps) {
        print('DEBUG: Step travelMode: "${step.travelMode}"');
      }
    }
    
    if (route.legs.any((leg) => leg.steps.any((step) => step.travelMode.contains('transit')))) {
      mode = TravelMode.jeepney; // Use jeepney as default for transit
      print('DEBUG: Detected transit mode, setting to jeepney');
    } else if (route.legs.any((leg) => leg.steps.any((step) => step.travelMode.contains('walking')))) {
      mode = TravelMode.walking;
      print('DEBUG: Detected walking mode');
    } else {
      print('DEBUG: Defaulting to driving mode');
    }

    return BudgetRoute(
      id: 'google_${mode.name}_${DateTime.now().millisecondsSinceEpoch}',
      mode: mode,
      start: _currentLocation ?? const LatLng(0, 0),
      end: _destinationLocation ?? const LatLng(0, 0),
      duration: totalDuration,
      distance: totalDistance / 1000, // Convert meters to km
      cost: _estimateFare(mode, totalDistance),
      instructions: route.legs.expand((leg) => leg.steps.map((step) => step.htmlInstructions)).toList(),
      polyline: _decodePolyline(route.overviewPolyline),
      summary: route.legs.map((leg) => leg.startAddress).join(' → '),
      tips: _getTravelTips(mode),
    );
  }

  // Estimate fare based on travel mode and distance
  double _estimateFare(TravelMode mode, double distanceInMeters) {
    switch (mode) {
      case TravelMode.driving:
        return 50.0 + (distanceInMeters / 1000) * 15; // Base + per km
      case TravelMode.walking:
        return 0.0;
      case TravelMode.jeepney:
        return 12.0 + (distanceInMeters / 1000) * 8; // Minimum fare + per km
      case TravelMode.bus:
        return 25.0 + (distanceInMeters / 1000) * 12;
      case TravelMode.train:
        return 20.0 + (distanceInMeters / 1000) * 10;
    }
  }

  // Get travel tips based on mode
  List<String> _getTravelTips(TravelMode mode) {
    switch (mode) {
      case TravelMode.walking:
        return ['Stay hydrated', 'Use pedestrian crossings', 'Be aware of surroundings'];
      case TravelMode.jeepney:
        return ['Have small bills ready', 'Signal driver to stop', 'Be prepared for crowded conditions'];
      case TravelMode.bus:
        return ['Check schedule online', 'Have exact fare ready', 'Use beep card for convenience'];
      case TravelMode.train:
        return ['Avoid rush hours', 'Keep ticket handy', 'Mind the gap between train and platform'];
      case TravelMode.driving:
        return ['Consider traffic conditions', 'Check parking availability', 'Use navigation apps for real-time updates'];
    }
  }

  // Decode polyline string to coordinates
  List<LatLng> _decodePolyline(String encodedString) {
    List<LatLng> polyline = [];
    int index = 0;
    int len = encodedString.length;
    int lat = 0;
    int lng = 0;

    while (index < len) {
      int shift = 0;
      int result = 0;
      int byteValue;
      do {
        byteValue = encodedString.codeUnitAt(index++) - 63;
        result |= (byteValue & 0x1f) << shift;
        shift += 5;
      } while (byteValue >= 0x20);
      int dlat = ((result & 1) != 0 ? ~(result >> 1) : (result >> 1));
      lat += dlat;
      shift = 0;
      result = 0;
      do {
        byteValue = encodedString.codeUnitAt(index++) - 63;
        result |= (byteValue & 0x1f) << shift;
        shift += 5;
      } while (byteValue >= 0x20);
      int dlng = ((result & 1) != 0 ? ~(result >> 1) : (result >> 1));
      lng += dlng;
      polyline.add(LatLng(lat / 1E5, lng / 1E5));
    }
    return polyline;
  }

  }

enum TransportType { walk, jeepney, bus, lrt, mrt }

class TransportOption {
  final TransportType type;
  final String name;
  final String time;
  final String? distance;
  final String? frequency;
  final String price;
  final IconData icon;
  final Color color;
  bool isSelected;

  TransportOption({
    required this.type,
    required this.name,
    required this.time,
    this.distance,
    this.frequency,
    required this.price,
    required this.icon,
    required this.color,
    this.isSelected = false,
  });
}
