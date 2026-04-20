import 'package:flutter/material.dart';
import 'package:halaph/models/destination.dart';

class TravelPlan {
  final String id;
  final String title;
  final DateTime startDate;
  final DateTime endDate;
  final List<String> participantIds;
  final String createdBy;
  final List<DayItinerary> itinerary;
  final bool isShared;
  final String? bannerImage;
  final String? shareCode;
  final List<String> sharedWith;
  final bool reminderEnabled;
  final int reminderMinutesBefore;

  TravelPlan({
    required this.id,
    required this.title,
    required this.startDate,
    required this.endDate,
    required this.participantIds,
    required this.createdBy,
    this.itinerary = const [],
    this.isShared = false,
    this.bannerImage,
    this.shareCode,
    this.sharedWith = const [],
    this.reminderEnabled = true,
    this.reminderMinutesBefore = 30,
  });

  factory TravelPlan.fromJson(Map<String, dynamic> json) {
    return TravelPlan(
      id: json['id'],
      title: json['title'],
      startDate: DateTime.parse(json['startDate']),
      endDate: DateTime.parse(json['endDate']),
      participantIds: List<String>.from(json['participantIds'] ?? []),
      createdBy: json['createdBy'],
      itinerary: (json['itinerary'] as List?)
          ?.map((e) => DayItinerary.fromJson(e))
          .toList() ?? [],
      isShared: json['isShared'] ?? false,
      bannerImage: json['bannerImage'],
      shareCode: json['shareCode'],
      sharedWith: List<String>.from(json['sharedWith'] ?? []),
      reminderEnabled: json['reminderEnabled'] ?? true,
      reminderMinutesBefore: json['reminderMinutesBefore'] ?? 30,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'title': title,
      'startDate': startDate.toIso8601String(),
      'endDate': endDate.toIso8601String(),
      'participantIds': participantIds,
      'createdBy': createdBy,
      'itinerary': itinerary.map((e) => e.toJson()).toList(),
      'isShared': isShared,
      'bannerImage': bannerImage,
      'shareCode': shareCode,
      'sharedWith': sharedWith,
      'reminderEnabled': reminderEnabled,
      'reminderMinutesBefore': reminderMinutesBefore,
    };
  }

  String get formattedDateRange {
    final start = '${startDate.month}/${startDate.day}/${startDate.year}';
    final end = '${endDate.month}/${endDate.day}/${endDate.year}';
    return '$start - $end';
  }

  int get totalDays => endDate.difference(startDate).inDays + 1;

  ItineraryItem? get firstItineraryItem {
    for (final day in itinerary) {
      if (day.items.isNotEmpty) {
        return day.items.first;
      }
    }
    return null;
  }

  DateTime? get nextReminderDateTime {
    if (!reminderEnabled) return null;
    final firstItem = firstItineraryItem;
    if (firstItem == null) return null;

    final eventTime = DateTime(
      startDate.year,
      startDate.month,
      startDate.day,
      firstItem.startTime.hour,
      firstItem.startTime.minute,
    );

    return eventTime.subtract(Duration(minutes: reminderMinutesBefore));
  }
}

class DayItinerary {
  final DateTime date;
  final List<ItineraryItem> items;

  DayItinerary({
    required this.date,
    this.items = const [],
  });

  factory DayItinerary.fromJson(Map<String, dynamic> json) {
    return DayItinerary(
      date: DateTime.parse(json['date']),
      items: (json['items'] as List?)
          ?.map((e) => ItineraryItem.fromJson(e))
          .toList() ?? [],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'date': date.toIso8601String(),
      'items': items.map((e) => e.toJson()).toList(),
    };
  }

  String get formattedDate => '${date.month}/${date.day}';
  String get dayName => 'Day ${items.isNotEmpty ? items.first.dayNumber : 1}';
}

class ItineraryItem {
  final String id;
  final Destination destination;
  final TimeOfDay startTime;
  final TimeOfDay endTime;
  final String notes;
  final int dayNumber;
  final List<String> transportOptions;

  ItineraryItem({
    required this.id,
    required this.destination,
    required this.startTime,
    required this.endTime,
    this.notes = '',
    required this.dayNumber,
    this.transportOptions = const [],
  });

  factory ItineraryItem.fromJson(Map<String, dynamic> json) {
    return ItineraryItem(
      id: json['id'],
      destination: Destination.fromJson(json['destination']),
      startTime: TimeOfDay(
        hour: json['startHour'] ?? 0,
        minute: json['startMinute'] ?? 0,
      ),
      endTime: TimeOfDay(
        hour: json['endHour'] ?? 0,
        minute: json['endMinute'] ?? 0,
      ),
      notes: json['notes'] ?? '',
      dayNumber: json['dayNumber'] ?? 1,
      transportOptions: List<String>.from(json['transportOptions'] ?? []),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'destination': destination.toJson(),
      'startHour': startTime.hour,
      'startMinute': startTime.minute,
      'endHour': endTime.hour,
      'endMinute': endTime.minute,
      'notes': notes,
      'dayNumber': dayNumber,
      'transportOptions': transportOptions,
    };
  }

  String get formattedStartTime => '${startTime.hour.toString().padLeft(2, '0')}:${startTime.minute.toString().padLeft(2, '0')}';
}
