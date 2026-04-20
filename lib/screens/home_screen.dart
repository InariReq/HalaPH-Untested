import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:halaph/models/plan.dart';
import 'package:halaph/services/destination_service.dart';
import 'package:halaph/services/plan_service.dart';
import 'package:halaph/services/travel_cost_service.dart';
import 'package:halaph/models/destination.dart';
import 'package:halaph/screens/explore_details_screen.dart';
import 'package:cached_network_image/cached_network_image.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  List<Destination> _trendingDestinations = [];
  bool _isLoading = false;
  Map<String, List<TravelCostEstimate>> _travelCosts = {};
  TravelPlan? _nextPlan;

  @override
  void initState() {
    super.initState();
    _loadTrendingDestinations();
    _loadNextPlan();
  }

  
  Future<void> _loadTrendingDestinations() async {
    setState(() {
      _isLoading = true;
      _trendingDestinations = []; // Clear cache first
    });
    
    try {
      print('=== HOME SCREEN: Loading trending destinations ===');
      final destinations = await DestinationService.getTrendingDestinations();
      print('Home screen loaded ${destinations.length} trending destinations');
      
      // Debug: Check if we got any real data
      if (destinations.isEmpty) {
        print('❌ NO DESTINATIONS RETURNED');
      } else {
        print('✅ Got ${destinations.length} destinations');
        for (var dest in destinations.take(3)) {
          print('- ${dest.name} (${dest.category}) - ID: ${dest.id ?? "NULL_ID"}');
        }
        
        // Debug: Check if destinations have valid IDs
        bool hasValidIds = destinations.every((dest) => dest.id.isNotEmpty);
        print('All destinations have valid IDs: $hasValidIds');
      }
      
      setState(() {
        _trendingDestinations = destinations;
        _isLoading = false;
      });
      _loadTravelCosts(destinations);
    } catch (e) {
      print('Error loading trending destinations: $e');
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _loadNextPlan() async {
    final plans = await PlanService.loadPlans();
    final now = DateTime.now();
    plans.sort((a, b) => a.startDate.compareTo(b.startDate));
    final nextPlan = plans.where((plan) => !plan.endDate.isBefore(now)).cast<TravelPlan?>().firstWhere(
          (plan) => plan != null,
          orElse: () => null,
        );
    if (!mounted) return;
    setState(() => _nextPlan = nextPlan);
  }

  Future<void> _loadTravelCosts(List<Destination> destinations) async {
    for (final destination in destinations) {
      if (destination.coordinates != null) {
        try {
          final costs = await TravelCostService.getTravelCostEstimates(destination.coordinates!);
          if (mounted) {
            setState(() {
              _travelCosts[destination.id] = costs;
            });
          }
        } catch (e) {
          print('Error loading travel costs for ${destination.name}: $e');
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FA),
      body: SafeArea(
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildHeader(context),
              const SizedBox(height: 24),
              _buildCurrentPlan(context),
              const SizedBox(height: 24),
              _buildTrendingSection(context),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeader(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'TripLine PH',
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: Colors.grey[800],
                  ),
                ),
                const SizedBox(height: 4),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Where every trip finds its line',
                      style: TextStyle(
                        fontSize: 16,
                        color: Colors.grey,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        const Text(
                          'Discover Philippines',
                          style: TextStyle(
                            fontSize: 15,
                            color: Colors.grey,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Icon(
                          Icons.location_on,
                          size: 20,
                          color: Colors.grey[600],
                        ),
                      ],
                    ),
                  ],
                ),
              ],
            ),
          ),
          CircleAvatar(
            radius: 20,
            backgroundColor: Colors.blue[100],
            child: Icon(
              Icons.person,
              color: Colors.blue[600],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCurrentPlan(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 20),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.coffee,
                color: Colors.brown[600],
                size: 24,
              ),
              const SizedBox(width: 8),
              const Text(
                'Next Up',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: Colors.black87,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            _nextPlan?.title ?? 'No current plans',
            style: TextStyle(
              fontSize: 16,
              color: Colors.grey[700],
              fontWeight: FontWeight.w600,
            ),
          ),
          if (_nextPlan != null) ...[
            const SizedBox(height: 6),
            Text(
              '${_nextPlan!.formattedDateRange} • ${_nextPlan!.totalDays} days',
              style: TextStyle(
                fontSize: 13,
                color: Colors.grey[600],
              ),
            ),
          ],
          const SizedBox(height: 12),
          Container(
            decoration: BoxDecoration(
              color: Colors.blue[50],
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.blue[200]!),
            ),
            child: Material(
              color: Colors.transparent,
              child: InkWell(
                onTap: () {
                  if (_nextPlan != null) {
                    GoRouter.of(context)
                        .push('/plan-details?planId=${_nextPlan!.id}');
                  } else {
                    GoRouter.of(context).push('/create-plan');
                  }
                },
                borderRadius: BorderRadius.circular(8),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  child: Text(
                    _nextPlan != null ? 'Open Plan' : 'Create Plan',
                    style: TextStyle(
                      fontSize: 14,
                      color: Colors.blue[600],
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTrendingSection(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Trending Destinations',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: Colors.black87,
                ),
              ),
              Text(
                'See All',
                style: TextStyle(
                  fontSize: 14,
                  color: Colors.blue[600],
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        // Real trending destinations
        _isLoading 
            ? const Center(
                child: Padding(
                  padding: EdgeInsets.symmetric(vertical: 40),
                  child: CircularProgressIndicator(),
                ),
              )
            : _trendingDestinations.isEmpty
                ? Container(
                    margin: const EdgeInsets.symmetric(horizontal: 20),
                    height: 200,
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.grey[300]!),
                    ),
                    child: const Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.trending_up, size: 48, color: Colors.grey),
                          SizedBox(height: 8),
                          Text(
                            'No trending destinations available',
                            style: TextStyle(color: Colors.grey),
                          ),
                        ],
                      ),
                    ),
                  )
                : Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    child: Column(
                      children: _trendingDestinations.map((destination) {
                        return _buildTrendingCard(destination);
                      }).toList(),
                    ),
                  ),
      ],
    );
  }


  Widget _buildFallbackImage(DestinationCategory category) {
    Color startColor, endColor;

    switch (category) {
      case DestinationCategory.park:
        startColor = const Color(0xFF81C784);
        endColor = const Color(0xFF4CAF50);
        break;
      case DestinationCategory.landmark:
        startColor = const Color(0xFF64B5F6);
        endColor = const Color(0xFF2196F3);
        break;
      case DestinationCategory.food:
        startColor = const Color(0xFFFFB74D);
        endColor = const Color(0xFFFF9800);
        break;
      case DestinationCategory.activities:
        startColor = const Color(0xFFBA68C8);
        endColor = const Color(0xFF9C27B0);
        break;
      case DestinationCategory.museum:
        startColor = const Color(0xFFF06292);
        endColor = const Color(0xFFE91E63);
        break;
      case DestinationCategory.market:
        startColor = const Color(0xFF4DB6AC);
        endColor = const Color(0xFF009688);
        break;
      default:
        startColor = const Color(0xFF90A4AE);
        endColor = const Color(0xFF607D8B);
    }

    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [startColor, endColor],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.image, size: 48, color: Colors.white),
            SizedBox(height: 8),
            Text(
              'No Photo Available',
              style: TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w600),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTrendingCard(Destination destination) {
    return Container(
      margin: const EdgeInsets.only(bottom: 20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.08),
            blurRadius: 20,
            offset: const Offset(0, 4),
          ),
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Image with overlay
            Stack(
              children: [
                Container(
                  width: double.infinity,
                  height: 200,
                  child: ClipRRect(
                    borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
                    child: destination.imageUrl.isNotEmpty && destination.imageUrl.startsWith('http')
                        ? CachedNetworkImage(
                            imageUrl: destination.imageUrl,
                            fit: BoxFit.cover,
                            width: double.infinity,
                            height: 200,
                            placeholder: (context, url) => Container(
                              color: Colors.grey[100],
                              child: Center(
                                child: CircularProgressIndicator(
                                  color: Colors.blue[600],
                                ),
                              ),
                            ),
                            errorWidget: (context, url, error) {
                              print('CachedNetworkImage error for ${destination.name}: $error');
                              return _buildFallbackImage(destination.category);
                            },
                          )
                        : _buildFallbackImage(destination.category),
                  ),
                ),
                // Text overlay at bottom
                Positioned(
                  bottom: 0,
                  left: 0,
                  right: 0,
                  child: Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      borderRadius: const BorderRadius.only(
                        bottomLeft: Radius.circular(0),
                        bottomRight: Radius.circular(0),
                      ),
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          Colors.transparent,
                          Colors.black.withOpacity(0.7),
                        ],
                      ),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          destination.name,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          destination.location,
                          style: const TextStyle(
                            color: Colors.white70,
                            fontSize: 13,
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                ),
                // Heart icon overlay
                Positioned(
                  top: 12,
                  right: 12,
                  child: Container(
                    width: 32,
                    height: 32,
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.9),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: const Icon(
                      Icons.favorite_border,
                      color: Colors.red,
                      size: 18,
                    ),
                  ),
                ),
              ],
            ),
            // Content section
            Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Description
                  Text(
                    destination.description,
                    style: TextStyle(
                      fontSize: 13,
                      color: Colors.grey[600],
                      height: 1.3,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 16),
                  // Explore More button
                  GestureDetector(
                    onTap: () {
                      print('=== HOME SCREEN TAP: ${destination.name} - ID: ${destination.id} ===');
                      ExploreDetailsScreen.showAsBottomSheet(
                        context,
                        destinationId: destination.id,
                        source: 'home',
                        destination: destination,
                      );
                    },
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      decoration: BoxDecoration(
                        color: Colors.blue[600],
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: const Text(
                        'Explore More',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
