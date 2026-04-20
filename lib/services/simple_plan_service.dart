import 'package:flutter/material.dart';
import 'package:halaph/models/plan.dart';
import 'package:halaph/models/destination.dart';

class SimplePlanService {
  static final List<TravelPlan> _plans = [];
  static int _planIdCounter = 1;

  // Get all user plans
  static List<TravelPlan> getUserPlans() {
    return _plans.where((plan) => plan.createdBy == 'current_user').toList();
  }

  // Create a new travel plan
  static TravelPlan createPlan({
    required String title,
    required DateTime startDate,
    required DateTime endDate,
    required List<Destination> destinations,
    String createdBy = 'current_user',
    String? bannerImage,
    List<DayItinerary>? customItinerary,
  }) {
    // Create itinerary items distributed across days
    final List<DayItinerary> dayItineraries = createDayItineraries(
      startDate,
      endDate,
      destinations,
    );

    final planId = 'plan$_planIdCounter';
    final plan = TravelPlan(
      id: planId,
      title: title,
      startDate: startDate,
      endDate: endDate,
      participantIds: [createdBy],
      createdBy: createdBy,
      itinerary: customItinerary ?? dayItineraries,
      isShared: false,
      bannerImage: bannerImage,
    );
    
    _plans.add(plan);
    _planIdCounter++;
    return plan;
  }

  // Simple add destination method
  static bool addDestinationToPlan(String planId, Destination destination, {DateTime? customDate, TimeOfDay? customTime}) {
    try {
      final planIndex = _plans.indexWhere((plan) => plan.id == planId);
      if (planIndex == -1) return false;

      final plan = _plans[planIndex];
      
      // Create new item
      final newItem = ItineraryItem(
        id: 'item_${DateTime.now().millisecondsSinceEpoch}',
        destination: destination,
        startTime: customTime ?? const TimeOfDay(hour: 9, minute: 0),
        endTime: customTime != null ? TimeOfDay(hour: (customTime.hour + 1) % 24, minute: customTime.minute) : const TimeOfDay(hour: 10, minute: 0),
        dayNumber: 1,
        notes: 'Visit ${destination.name}',
      );

      // Add to first day or create new day
      final updatedItinerary = List<DayItinerary>.from(plan.itinerary);
      if (updatedItinerary.isEmpty) {
        updatedItinerary.add(DayItinerary(
          date: customDate ?? DateTime.now(),
          items: [newItem],
        ));
      } else {
        final firstDay = updatedItinerary[0];
        final updatedItems = List<ItineraryItem>.from(firstDay.items);
        updatedItems.add(newItem);
        updatedItinerary[0] = DayItinerary(
          date: firstDay.date,
          items: updatedItems,
        );
      }

      // Update plan
      _plans[planIndex] = TravelPlan(
        id: plan.id,
        title: plan.title,
        startDate: plan.startDate,
        endDate: plan.endDate,
        participantIds: plan.participantIds,
        createdBy: plan.createdBy,
        itinerary: updatedItinerary,
        isShared: plan.isShared,
        bannerImage: plan.bannerImage,
      );

      return true;
    } catch (e) {
      return false;
    }
  }

  // Get plan by ID
  static TravelPlan? getPlanById(String id) {
    try {
      return _plans.firstWhere((plan) => plan.id == id);
    } catch (e) {
      return null;
    }
  }

  // Delete a plan
  static bool deletePlan(String id) {
    try {
      _plans.removeWhere((plan) => plan.id == id);
      return true;
    } catch (e) {
      return false;
    }
  }

  // Update a plan (accepts TravelPlan object)
  static bool updatePlanObject(TravelPlan updatedPlan) {
    try {
      final index = _plans.indexWhere((plan) => plan.id == updatedPlan.id);
      if (index != -1) {
        _plans[index] = updatedPlan;
        return true;
      }
      return false;
    } catch (e) {
      return false;
    }
  }

  // Get all plans
  static List<TravelPlan> getAllPlans() {
    return List.from(_plans);
  }

  // Create day itineraries from destinations
  static List<DayItinerary> createDayItineraries(
    DateTime startDate,
    DateTime endDate,
    List<Destination> destinations,
  ) {
    final List<DayItinerary> dayItineraries = [];
    final totalDays = endDate.difference(startDate).inDays + 1;
    
    // Distribute destinations across days
    for (int day = 0; day < totalDays; day++) {
      final currentDate = startDate.add(Duration(days: day));
      final List<ItineraryItem> dayItems = [];
      
      // Add destinations for this day
      final destinationsPerDay = (destinations.length / totalDays).ceil();
      final startIndex = day * destinationsPerDay;
      final endIndex = (startIndex + destinationsPerDay).clamp(0, destinations.length);
      
      for (int i = startIndex; i < endIndex; i++) {
        final destination = destinations[i];
        final startHour = 9 + (i % 4) * 2;
        final endHour = 11 + (i % 4) * 2;
        final item = ItineraryItem(
          id: 'item_${_planIdCounter}_${day}_$i',
          destination: destination,
          startTime: TimeOfDay(hour: startHour, minute: 0),
          endTime: TimeOfDay(hour: endHour, minute: 0),
          dayNumber: day + 1,
          notes: 'Visit ${destination.name}',
        );
        dayItems.add(item);
      }
      
      if (dayItems.isNotEmpty) {
        dayItineraries.add(DayItinerary(
          date: currentDate,
          items: dayItems,
        ));
      }
    }
    
    return dayItineraries;
  }

  // Save plan with complete itinerary data (for compatibility with create_plan_screen.dart)
  static TravelPlan savePlan({
    required String title,
    required DateTime startDate,
    required DateTime endDate,
    required Map<int, List<Destination>> itinerary,
    String createdBy = 'current_user',
    String? bannerImage,
  }) {
    // Validation
    if (title.trim().isEmpty) {
      throw ArgumentError('Plan title cannot be empty');
    }
    if (endDate.isBefore(startDate)) {
      throw ArgumentError('End date must be after start date');
    }
    
    // Convert itinerary map to destinations list
    final allDestinations = <Destination>[];
    for (final dayDestinations in itinerary.values) {
      allDestinations.addAll(dayDestinations);
    }
    
    if (allDestinations.isEmpty) {
      throw ArgumentError('Plan must have at least one destination');
    }
    
    // Create plan using the streamlined createPlan method
    return createPlan(
      title: title,
      startDate: startDate,
      endDate: endDate,
      destinations: allDestinations,
      createdBy: createdBy,
      bannerImage: bannerImage,
    );
  }

  // Update existing plan with new data (for compatibility with plan_details_screen.dart)
  static bool updatePlan({
    required String planId,
    String? title,
    DateTime? startDate,
    DateTime? endDate,
    Map<int, List<Destination>>? itinerary,
    String? bannerImage,
  }) {
    try {
      final planIndex = _plans.indexWhere((plan) => plan.id == planId);
      if (planIndex == -1) return false;
      
      final existingPlan = _plans[planIndex];
      
      // Convert itinerary if provided
      List<DayItinerary>? updatedItinerary;
      if (itinerary != null) {
        final allDestinations = <Destination>[];
        for (final dayDestinations in itinerary.values) {
          allDestinations.addAll(dayDestinations);
        }
        updatedItinerary = createDayItineraries(
          startDate ?? existingPlan.startDate,
          endDate ?? existingPlan.endDate,
          allDestinations,
        );
      } else {
        // If no new itinerary provided, keep existing but update structure
        updatedItinerary = existingPlan.itinerary;
      }
      
      final updatedPlan = TravelPlan(
        id: existingPlan.id,
        title: title ?? existingPlan.title,
        startDate: startDate ?? existingPlan.startDate,
        endDate: endDate ?? existingPlan.endDate,
        participantIds: existingPlan.participantIds,
        createdBy: existingPlan.createdBy,
        itinerary: updatedItinerary,
        isShared: existingPlan.isShared,
        bannerImage: bannerImage ?? existingPlan.bannerImage,
      );
      
      _plans[planIndex] = updatedPlan;
      return true;
    } catch (e) {
      return false;
    }
  }

  // Clear all plans (for testing/cleanup)
  static void clearAllPlans() {
    _plans.clear();
    _planIdCounter = 1;
  }

  // Check if plans should be cleared (for development/testing)
  static bool shouldClearPlans() {
    // You can customize this logic based on your needs
    return _plans.isNotEmpty && _plans.every((plan) => 
      plan.title.contains('Sample') || plan.title.contains('Quick')
    );
  }

  // Create sample plans for testing (call this explicitly when needed)
  static void createSamplePlans() {
    // Clear existing plans before creating sample ones
    _plans.clear();
    
    // Sample destinations
    final destinations = [
      Destination(
        id: 'manila_bay',
        name: 'Manila Bay',
        location: 'Manila',
        category: DestinationCategory.landmark,
        imageUrl: 'https://picsum.photos/seed/manilabay/400/300',
        description: 'Famous bay known for beautiful sunsets',
        rating: 4.5,
        budget: BudgetInfo(minCost: 100, maxCost: 500),
      ),
      Destination(
        id: 'intramuros',
        name: 'Intramuros',
        location: 'Manila',
        category: DestinationCategory.landmark,
        imageUrl: 'https://picsum.photos/seed/intramuros/400/300',
        description: 'Historic walled city',
        rating: 4.7,
        budget: BudgetInfo(minCost: 200, maxCost: 800),
      ),
    ];
    
    // Create sample plan
    createPlan(
      title: 'Manila Heritage Tour',
      startDate: DateTime.now(),
      endDate: DateTime.now().add(Duration(days: 2)),
      destinations: destinations,
    );
    
    // Create a second simple plan for testing
    final simpleDestinations = [
      Destination(
        id: 'rizal_park',
        name: 'Rizal Park',
        location: 'Manila',
        category: DestinationCategory.park,
        imageUrl: 'https://picsum.photos/seed/rizalpark/400/300',
        description: 'National park in the heart of Manila',
        rating: 4.3,
        budget: BudgetInfo(minCost: 50, maxCost: 200),
      ),
    ];
    
    createPlan(
      title: 'Quick Manila Tour',
      startDate: DateTime.now(),
      endDate: DateTime.now().add(Duration(days: 1)),
      destinations: simpleDestinations,
    );
  }
}
