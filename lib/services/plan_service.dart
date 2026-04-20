import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:halaph/models/destination.dart';
import 'package:halaph/models/plan.dart';
import 'package:halaph/services/auth_service.dart';
import 'package:halaph/services/firebase_service.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';

class PlanService {
  static const String _localPlansKey = 'local_travel_plans';
  static List<TravelPlan> _cachedPlans = [];

  static List<TravelPlan> get plans => _cachedPlans;

  static Future<void> initialize() async {
    await loadPlans();
  }

  static Stream<List<TravelPlan>> plansStream() {
    if (FirebaseService.currentUserId == null) return Stream.value([]);

    return FirebaseFirestore.instance
        .collection('plans')
        .where('createdBy', isEqualTo: FirebaseService.currentUserId)
        .snapshots()
        .map((snapshot) {
      return snapshot.docs
          .map((doc) => TravelPlan.fromJson(doc.data()))
          .toList();
    });
  }

  static Future<List<TravelPlan>> loadPlans() async {
    final prefs = await SharedPreferences.getInstance();
    final localPlans = prefs.getStringList(_localPlansKey) ?? const [];

    if (localPlans.isNotEmpty) {
      _cachedPlans = localPlans
          .map((raw) => TravelPlan.fromJson(jsonDecode(raw) as Map<String, dynamic>))
          .toList();
      return _cachedPlans;
    }

    if (!AuthService.isLoggedIn || FirebaseService.currentUserId == null) {
      _cachedPlans = _getSamplePlans();
      await _persistLocalPlans();
      return _cachedPlans;
    }

    try {
      final snapshot = await FirebaseFirestore.instance
          .collection('plans')
          .where('createdBy', isEqualTo: FirebaseService.currentUserId)
          .get();

      if (snapshot.docs.isEmpty) {
        _cachedPlans = _getSamplePlans();
        for (final plan in _cachedPlans) {
          await FirebaseFirestore.instance
              .collection('plans')
              .doc(plan.id)
              .set(plan.toJson());
        }
      } else {
        _cachedPlans = snapshot.docs
            .map((doc) => TravelPlan.fromJson(doc.data()))
            .toList();
      }
    } catch (e) {
      print('Error loading plans: $e');
      _cachedPlans = _getSamplePlans();
    }

    await _persistLocalPlans();

    return _cachedPlans;
  }

  static List<TravelPlan> _getSamplePlans() {
    return [
      TravelPlan(
        id: 'sample_1',
        title: 'Manila Weekend Getaway',
        startDate: DateTime.now().add(const Duration(days: 7)),
        endDate: DateTime.now().add(const Duration(days: 9)),
        createdBy: 'demo',
        participantIds: [],
        itinerary: [
          DayItinerary(
            date: DateTime.now().add(const Duration(days: 7)),
            items: [
              ItineraryItem(
                id: 'item_1',
                destination: Destination(
                  id: 'manila_1',
                  name: 'Intramuros',
                  description: 'Historic walled city in Manila',
                  location: 'Manila, Philippines',
                  imageUrl:
                      'https://images.unsplash.com/photo-15168893845-c5ad698dfc3e?w=800',
                  coordinates: const LatLng(14.5995, 120.9842),
                  category: DestinationCategory.landmark,
                  rating: 4.6,
                  budget: BudgetInfo(minCost: 0, maxCost: 200, currency: 'PHP'),
                ),
                startTime: const TimeOfDay(hour: 9, minute: 0),
                endTime: const TimeOfDay(hour: 11, minute: 0),
                dayNumber: 1,
                notes: 'Start early to avoid crowds',
              ),
            ],
          ),
        ],
        isShared: false,
        reminderEnabled: true,
        reminderMinutesBefore: 45,
      ),
      TravelPlan(
        id: 'sample_2',
        title: 'Boracay Beach Trip',
        startDate: DateTime.now().add(const Duration(days: 14)),
        endDate: DateTime.now().add(const Duration(days: 17)),
        createdBy: 'demo',
        participantIds: [],
        itinerary: [
          DayItinerary(
            date: DateTime.now().add(const Duration(days: 14)),
            items: [
              ItineraryItem(
                id: 'item_2',
                destination: Destination(
                  id: 'boracay_1',
                  name: 'White Beach',
                  description: 'Famous white sand beach in Boracay',
                  location: 'Boracay, Aklan',
                  imageUrl:
                      'https://images.unsplash.com/photo-1520200122962-40bd9afbaef7?w=800',
                  coordinates: const LatLng(11.9684, 121.9213),
                  category: DestinationCategory.activities,
                  rating: 4.8,
                  budget:
                      BudgetInfo(minCost: 2000, maxCost: 8000, currency: 'PHP'),
                ),
                startTime: const TimeOfDay(hour: 10, minute: 0),
                endTime: const TimeOfDay(hour: 12, minute: 0),
                dayNumber: 1,
                notes: 'Book accommodation in advance',
              ),
            ],
          ),
        ],
        isShared: false,
        reminderEnabled: true,
        reminderMinutesBefore: 60,
      ),
    ];
  }

  static List<TravelPlan> get userPlans {
    if (!AuthService.isLoggedIn) return _cachedPlans;
    return _cachedPlans
        .where((p) => p.createdBy == FirebaseService.currentUserId)
        .toList();
  }

  static List<TravelPlan> get upcomingPlans {
    final now = DateTime.now();
    return _cachedPlans.where((p) => p.startDate.isAfter(now)).toList();
  }

  static List<TravelPlan> get activePlans {
    final now = DateTime.now();
    return _cachedPlans
        .where((p) => p.startDate.isBefore(now) && p.endDate.isAfter(now))
        .toList();
  }

  static List<TravelPlan> get completedPlans {
    final now = DateTime.now();
    return _cachedPlans.where((p) => p.endDate.isBefore(now)).toList();
  }

  static TravelPlan? getPlanById(String id) {
    try {
      return _cachedPlans.firstWhere((p) => p.id == id);
    } catch (e) {
      return null;
    }
  }

  static Future<TravelPlan> createPlan({
    required String title,
    required DateTime startDate,
    required DateTime endDate,
    required List<Destination> destinations,
    String? createdBy,
    List<DayItinerary>? customItinerary,
    String? bannerImage,
    List<String> sharedWith = const [],
    bool reminderEnabled = true,
    int reminderMinutesBefore = 30,
  }) async {
    final userId = createdBy ?? AuthService.currentUserId ?? 'anonymous';
    final shareCode = sharedWith.isEmpty ? null : _generateShareCode(title);

    final List<DayItinerary> dayItineraries = customItinerary ??
        createDayItineraries(
          startDate,
          endDate,
          destinations,
        );

    final plan = TravelPlan(
      id: FirebaseFirestore.instance.collection('plans').doc().id,
      title: title,
      startDate: startDate,
      endDate: endDate,
      participantIds: [userId],
      createdBy: userId,
      itinerary: dayItineraries,
      isShared: sharedWith.isNotEmpty,
      bannerImage: bannerImage,
      shareCode: shareCode,
      sharedWith: sharedWith,
      reminderEnabled: reminderEnabled,
      reminderMinutesBefore: reminderMinutesBefore,
    );

    if (FirebaseService.currentUserId != null) {
      try {
        await FirebaseFirestore.instance
            .collection('plans')
            .doc(plan.id)
            .set(plan.toJson());
      } catch (_) {}
    }

    _cachedPlans.insert(0, plan);
    await _persistLocalPlans();

    return plan;
  }

  static Future<void> updatePlan(TravelPlan plan) async {
    final index = _cachedPlans.indexWhere((p) => p.id == plan.id);

    if (FirebaseService.currentUserId != null) {
      try {
        await FirebaseFirestore.instance
            .collection('plans')
            .doc(plan.id)
            .update(plan.toJson());
      } catch (_) {}
    }

    if (index != -1) {
      _cachedPlans[index] = plan;
    }
    await _persistLocalPlans();
  }

  static Future<void> deletePlan(String planId) async {
    if (FirebaseService.currentUserId != null) {
      try {
        await FirebaseFirestore.instance.collection('plans').doc(planId).delete();
      } catch (_) {}
    }
    _cachedPlans.removeWhere((p) => p.id == planId);
    await _persistLocalPlans();
  }

  static Future<void> addDestinationToPlan(
      String planId, Destination destination,
      {String? notes}) async {
    final plan = getPlanById(planId);
    if (plan == null) return;

    final newItem = ItineraryItem(
      id: 'item_${DateTime.now().millisecondsSinceEpoch}',
      destination: destination,
      startTime: const TimeOfDay(hour: 9, minute: 0),
      endTime: const TimeOfDay(hour: 10, minute: 0),
      dayNumber: plan.itinerary.isEmpty ? 1 : plan.itinerary.length + 1,
      notes: notes ?? 'Visit ${destination.name}',
    );

    final updatedItinerary = List<DayItinerary>.from(plan.itinerary);
    if (updatedItinerary.isEmpty) {
      updatedItinerary
          .add(DayItinerary(date: plan.startDate, items: [newItem]));
    } else {
      final lastDay = updatedItinerary.last;
      updatedItinerary[updatedItinerary.length - 1] = DayItinerary(
        date: lastDay.date,
        items: [...lastDay.items, newItem],
      );
    }

    final updatedPlan = TravelPlan(
      id: plan.id,
      title: plan.title,
      startDate: plan.startDate,
      endDate: plan.endDate,
      participantIds: plan.participantIds,
      createdBy: plan.createdBy,
      itinerary: updatedItinerary,
      isShared: plan.isShared,
      bannerImage: plan.bannerImage,
      shareCode: plan.shareCode,
      sharedWith: plan.sharedWith,
      reminderEnabled: plan.reminderEnabled,
      reminderMinutesBefore: plan.reminderMinutesBefore,
    );

    await updatePlan(updatedPlan);
  }

  static Future<TravelPlan?> sharePlan(String planId, List<String> recipients) async {
    final plan = getPlanById(planId);
    if (plan == null) return null;

    final normalizedRecipients = recipients
        .map((recipient) => recipient.trim())
        .where((recipient) => recipient.isNotEmpty)
        .toSet()
        .toList()
      ..sort();

    final updatedPlan = TravelPlan(
      id: plan.id,
      title: plan.title,
      startDate: plan.startDate,
      endDate: plan.endDate,
      participantIds: plan.participantIds,
      createdBy: plan.createdBy,
      itinerary: plan.itinerary,
      isShared: normalizedRecipients.isNotEmpty,
      bannerImage: plan.bannerImage,
      shareCode: normalizedRecipients.isNotEmpty
          ? (plan.shareCode ?? _generateShareCode(plan.title))
          : null,
      sharedWith: normalizedRecipients,
      reminderEnabled: plan.reminderEnabled,
      reminderMinutesBefore: plan.reminderMinutesBefore,
    );

    await updatePlan(updatedPlan);
    return updatedPlan;
  }

  static String buildShareMessage(TravelPlan plan) {
    final recipientLabel = plan.sharedWith.isEmpty
        ? 'your travel group'
        : plan.sharedWith.join(', ');
    final shareCode = plan.shareCode ?? _generateShareCode(plan.title);
    return 'TripLine PH plan "${plan.title}"\n'
        'Dates: ${plan.formattedDateRange}\n'
        'Shared with: $recipientLabel\n'
        'Share code: $shareCode';
  }

  static List<DayItinerary> createDayItineraries(
    DateTime startDate,
    DateTime endDate,
    List<Destination> destinations,
  ) {
    final List<DayItinerary> dayItineraries = [];
    final totalDays = endDate.difference(startDate).inDays + 1;

    if (totalDays <= 0 || destinations.isEmpty) return dayItineraries;

    for (int day = 0; day < totalDays; day++) {
      final currentDate = startDate.add(Duration(days: day));
      final List<ItineraryItem> dayItems = [];

      final destinationsPerDay = (destinations.length / totalDays).ceil();
      final startIndex = day * destinationsPerDay;
      final endIndex =
          (startIndex + destinationsPerDay).clamp(0, destinations.length);

      for (int i = startIndex; i < endIndex; i++) {
        final destination = destinations[i];
        final startHour = 9 + (i % 4) * 2;
        final endHour = 11 + (i % 4) * 2;

        final item = ItineraryItem(
          id: 'item_${DateTime.now().millisecondsSinceEpoch}_${day}_$i',
          destination: destination,
          startTime: TimeOfDay(hour: startHour, minute: 0),
          endTime: TimeOfDay(hour: endHour, minute: 0),
          dayNumber: day + 1,
          notes: 'Visit ${destination.name}',
        );
        dayItems.add(item);
      }

      if (dayItems.isNotEmpty) {
        dayItineraries.add(DayItinerary(date: currentDate, items: dayItems));
      }
    }

    return dayItineraries;
  }

  static Future<void> _persistLocalPlans() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(
      _localPlansKey,
      _cachedPlans.map((plan) => jsonEncode(plan.toJson())).toList(),
    );
  }

  static String _generateShareCode(String title) {
    final cleanTitle = title.replaceAll(RegExp(r'[^A-Za-z0-9]'), '').toUpperCase();
    final prefix = cleanTitle.isEmpty ? 'TRIP' : cleanTitle;
    final suffix = DateTime.now()
        .millisecondsSinceEpoch
        .toRadixString(36)
        .toUpperCase();
    return '${prefix.substring(0, prefix.length.clamp(0, 4)).padRight(4, 'X')}${suffix.substring(suffix.length - 4)}';
  }
}
