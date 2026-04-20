import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:halaph/models/destination.dart';
import 'package:halaph/services/auth_service.dart';
import 'package:halaph/services/firebase_service.dart';

class CollaborativePlanService {
  static List<CollaborativePlan> _plans = [];

  static List<CollaborativePlan> get plans => _plans;

  static Future<void> initialize() async {
    if (AuthService.isLoggedIn) {
      await _loadPlans();
    }
  }

  static Stream<List<CollaborativePlan>> plansStream() {
    if (FirebaseService.currentUserId == null) return Stream.value([]);

    return FirebaseFirestore.instance
        .collection('collaborative_plans')
        .where('collaborators', arrayContains: {
          'userId': FirebaseService.currentUserId,
        })
        .snapshots()
        .map((snapshot) {
          return snapshot.docs
              .map((doc) => CollaborativePlan.fromJson(doc.data()))
              .toList();
        });
  }

  static Future<void> _loadPlans() async {
    if (FirebaseService.currentUserId == null) return;

    try {
      final snapshot = await FirebaseFirestore.instance
          .collection('collaborative_plans')
          .where('collaborators', arrayContains: {
        'userId': FirebaseService.currentUserId,
      }).get();

      _plans = snapshot.docs
          .map((doc) => CollaborativePlan.fromJson(doc.data()))
          .toList();
    } catch (e) {
      print('Error loading collaborative plans: $e');
    }
  }

  static List<CollaborativePlan> get myCollaborativePlans {
    final userId = FirebaseService.currentUserId;
    if (userId == null) return [];

    return _plans.where((p) {
      if (p.ownerId == userId) return true;
      return p.collaborators
          .any((c) => c.userId == userId && c.role != CollaboratorRole.viewer);
    }).toList();
  }

  static Future<CollaborativePlan> createCollaborativePlan({
    required String title,
    required String description,
    required List<Destination> destinations,
    required DateTime startDate,
    required DateTime endDate,
    required double budget,
  }) async {
    if (!AuthService.isLoggedIn) throw Exception('Not logged in');

    final userId = FirebaseService.currentUserId!;
    final planId =
        FirebaseFirestore.instance.collection('collaborative_plans').doc().id;

    final plan = CollaborativePlan(
      id: planId,
      title: title,
      description: description,
      ownerId: userId,
      ownerName: AuthService.userName ?? 'Unknown',
      destinations: destinations
          .asMap()
          .entries
          .map((e) => PlanDestination(
                destination: e.value,
                order: e.key + 1,
              ))
          .toList(),
      startDate: startDate,
      endDate: endDate,
      budget: budget,
      collaborators: [
        Collaborator(
          userId: userId,
          userName: AuthService.userName ?? 'Unknown',
          role: CollaboratorRole.owner,
          status: CollaboratorStatus.accepted,
          addedAt: DateTime.now(),
        ),
      ],
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
    );

    await FirebaseFirestore.instance
        .collection('collaborative_plans')
        .doc(planId)
        .set(plan.toJson());

    _plans.insert(0, plan);

    await _addActivity('planCreated', planId: planId, planName: title);

    return plan;
  }

  static Future<CollaborativePlan?> inviteCollaborator({
    required String planId,
    required String friendId,
    required String friendName,
    CollaboratorRole role = CollaboratorRole.editor,
  }) async {
    try {
      final planIndex = _plans.indexWhere((p) => p.id == planId);
      if (planIndex == -1) {
        final doc = await FirebaseFirestore.instance
            .collection('collaborative_plans')
            .doc(planId)
            .get();
        if (!doc.exists) return null;
      }

      final plan = _plans.length > planIndex ? _plans[planIndex] : null;

      if (plan != null && plan.collaborators.any((c) => c.userId == friendId)) {
        return plan;
      }

      final newCollaborators = plan != null
          ? List<Collaborator>.from(plan.collaborators)
          : <Collaborator>[];

      newCollaborators.add(Collaborator(
        userId: friendId,
        userName: friendName,
        role: role,
        status: CollaboratorStatus.pending,
        addedAt: DateTime.now(),
      ));

      final updates = {
        'collaborators': newCollaborators.map((c) => c.toJson()).toList(),
        'updatedAt': FieldValue.serverTimestamp(),
      };

      await FirebaseFirestore.instance
          .collection('collaborative_plans')
          .doc(planId)
          .update(updates);

      final updatedPlan = CollaborativePlan(
        id: planId,
        title: plan?.title ?? '',
        description: plan?.description ?? '',
        ownerId: plan?.ownerId ?? '',
        ownerName: plan?.ownerName ?? '',
        destinations: plan?.destinations ?? [],
        startDate: plan?.startDate ?? DateTime.now(),
        endDate: plan?.endDate ?? DateTime.now(),
        budget: plan?.budget ?? 0,
        collaborators: newCollaborators,
        comments: plan?.comments ?? [],
        imageUrl: plan?.imageUrl,
        isPublic: plan?.isPublic ?? false,
        createdAt: plan?.createdAt ?? DateTime.now(),
        updatedAt: DateTime.now(),
      );

      if (planIndex != -1) {
        _plans[planIndex] = updatedPlan;
      }

      return updatedPlan;
    } catch (e) {
      print('Error inviting collaborator: $e');
      return null;
    }
  }

  static Future<void> respondToInvitation({
    required String planId,
    required bool accept,
  }) async {
    final planIndex = _plans.indexWhere((p) => p.id == planId);
    if (planIndex == -1) return;

    final userId = FirebaseService.currentUserId;
    final plan = _plans[planIndex];
    final collabIndex =
        plan.collaborators.indexWhere((c) => c.userId == userId);
    if (collabIndex == -1) return;

    final newCollaborators = List<Collaborator>.from(plan.collaborators);
    final current = newCollaborators[collabIndex];
    newCollaborators[collabIndex] = Collaborator(
      userId: current.userId,
      userName: current.userName,
      avatarUrl: current.avatarUrl,
      role: current.role,
      status:
          accept ? CollaboratorStatus.accepted : CollaboratorStatus.declined,
      addedAt: current.addedAt,
    );

    final updates = {
      'collaborators': newCollaborators.map((c) => c.toJson()).toList(),
      'updatedAt': FieldValue.serverTimestamp(),
    };

    await FirebaseFirestore.instance
        .collection('collaborative_plans')
        .doc(planId)
        .update(updates);

    _plans[planIndex] = CollaborativePlan(
      id: plan.id,
      title: plan.title,
      description: plan.description,
      ownerId: plan.ownerId,
      ownerName: plan.ownerName,
      destinations: plan.destinations,
      startDate: plan.startDate,
      endDate: plan.endDate,
      budget: plan.budget,
      collaborators: newCollaborators,
      comments: plan.comments,
      imageUrl: plan.imageUrl,
      isPublic: plan.isPublic,
      createdAt: plan.createdAt,
      updatedAt: DateTime.now(),
    );

    if (accept) {
      await _addActivity('planJoined', planId: planId, planName: plan.title);
    }
  }

  static Future<void> removeCollaborator({
    required String planId,
    required String collaboratorId,
  }) async {
    final planIndex = _plans.indexWhere((p) => p.id == planId);
    if (planIndex == -1) return;

    final plan = _plans[planIndex];
    final newCollaborators =
        plan.collaborators.where((c) => c.userId != collaboratorId).toList();

    final updates = {
      'collaborators': newCollaborators.map((c) => c.toJson()).toList(),
      'updatedAt': FieldValue.serverTimestamp(),
    };

    await FirebaseFirestore.instance
        .collection('collaborative_plans')
        .doc(planId)
        .update(updates);

    _plans[planIndex] = CollaborativePlan(
      id: plan.id,
      title: plan.title,
      description: plan.description,
      ownerId: plan.ownerId,
      ownerName: plan.ownerName,
      destinations: plan.destinations,
      startDate: plan.startDate,
      endDate: plan.endDate,
      budget: plan.budget,
      collaborators: newCollaborators,
      comments: plan.comments,
      imageUrl: plan.imageUrl,
      isPublic: plan.isPublic,
      createdAt: plan.createdAt,
      updatedAt: DateTime.now(),
    );
  }

  static Future<void> addDestinationToPlan({
    required String planId,
    required Destination destination,
    String? notes,
  }) async {
    final planIndex = _plans.indexWhere((p) => p.id == planId);
    if (planIndex == -1) return;

    final plan = _plans[planIndex];
    final userId = FirebaseService.currentUserId;

    final newDestinations = List<PlanDestination>.from(plan.destinations);
    newDestinations.add(PlanDestination(
      destination: destination,
      order: newDestinations.length + 1,
      notes: notes,
      addedBy: userId,
    ));

    final updates = {
      'destinations': newDestinations.map((d) => d.toJson()).toList(),
      'updatedAt': FieldValue.serverTimestamp(),
    };

    await FirebaseFirestore.instance
        .collection('collaborative_plans')
        .doc(planId)
        .update(updates);

    _plans[planIndex] = CollaborativePlan(
      id: plan.id,
      title: plan.title,
      description: plan.description,
      ownerId: plan.ownerId,
      ownerName: plan.ownerName,
      destinations: newDestinations,
      startDate: plan.startDate,
      endDate: plan.endDate,
      budget: plan.budget,
      collaborators: plan.collaborators,
      comments: plan.comments,
      imageUrl: plan.imageUrl,
      isPublic: plan.isPublic,
      createdAt: plan.createdAt,
      updatedAt: DateTime.now(),
    );
  }

  static Future<void> addComment({
    required String planId,
    required String message,
  }) async {
    final planIndex = _plans.indexWhere((p) => p.id == planId);
    if (planIndex == -1) return;

    final userId = FirebaseService.currentUserId!;
    final plan = _plans[planIndex];

    final newComment = Comment(
      id: '${planId}_${DateTime.now().millisecondsSinceEpoch}',
      userId: userId,
      userName: AuthService.userName ?? 'Unknown',
      message: message,
      createdAt: DateTime.now(),
    );

    final newComments = List<Comment>.from(plan.comments)..add(newComment);

    final updates = {
      'comments': newComments.map((c) => c.toJson()).toList(),
      'updatedAt': FieldValue.serverTimestamp(),
    };

    await FirebaseFirestore.instance
        .collection('collaborative_plans')
        .doc(planId)
        .update(updates);

    _plans[planIndex] = CollaborativePlan(
      id: plan.id,
      title: plan.title,
      description: plan.description,
      ownerId: plan.ownerId,
      ownerName: plan.ownerName,
      destinations: plan.destinations,
      startDate: plan.startDate,
      endDate: plan.endDate,
      budget: plan.budget,
      collaborators: plan.collaborators,
      comments: newComments,
      imageUrl: plan.imageUrl,
      isPublic: plan.isPublic,
      createdAt: plan.createdAt,
      updatedAt: DateTime.now(),
    );
  }

  static CollaborativePlan? getPlanById(String id) {
    try {
      return _plans.firstWhere((p) => p.id == id);
    } catch (e) {
      return null;
    }
  }

  static Future<void> _addActivity(String type,
      {String? planId, String? planName}) async {
    if (FirebaseService.currentUserId == null) return;

    await FirebaseFirestore.instance.collection('friend_activities').add({
      'userId': FirebaseService.currentUserId,
      'userName': AuthService.userName,
      'type': type,
      'planId': planId,
      'planName': planName,
      'message': '${AuthService.userName} created a new trip: $planName',
      'createdAt': FieldValue.serverTimestamp(),
      'isRead': false,
    });
  }
}

enum CollaboratorRole { owner, editor, viewer }

enum CollaboratorStatus { pending, accepted, declined, removed }

class Collaborator {
  final String userId;
  final String userName;
  final String? avatarUrl;
  final CollaboratorRole role;
  final CollaboratorStatus status;
  final DateTime addedAt;

  Collaborator({
    required this.userId,
    required this.userName,
    this.avatarUrl,
    this.role = CollaboratorRole.viewer,
    this.status = CollaboratorStatus.pending,
    required this.addedAt,
  });

  factory Collaborator.fromJson(Map<String, dynamic> json) {
    return Collaborator(
      userId: json['userId'],
      userName: json['userName'],
      avatarUrl: json['avatarUrl'],
      role: CollaboratorRole.values.firstWhere((r) => r.name == json['role'],
          orElse: () => CollaboratorRole.viewer),
      status: CollaboratorStatus.values.firstWhere(
          (s) => s.name == json['status'],
          orElse: () => CollaboratorStatus.pending),
      addedAt: json['addedAt'] is Timestamp
          ? (json['addedAt'] as Timestamp).toDate()
          : DateTime.parse(json['addedAt']),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'userId': userId,
      'userName': userName,
      'avatarUrl': avatarUrl,
      'role': role.name,
      'status': status.name,
      'addedAt': addedAt.toIso8601String(),
    };
  }
}

class PlanDestination {
  final Destination destination;
  final int order;
  final String? notes;
  final String? addedBy;

  PlanDestination({
    required this.destination,
    required this.order,
    this.notes,
    this.addedBy,
  });

  factory PlanDestination.fromJson(Map<String, dynamic> json) {
    return PlanDestination(
      destination: Destination.fromJson(json['destination']),
      order: json['order'],
      notes: json['notes'],
      addedBy: json['addedBy'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'destination': destination.toJson(),
      'order': order,
      'notes': notes,
      'addedBy': addedBy,
    };
  }
}

class Comment {
  final String id;
  final String userId;
  final String userName;
  final String message;
  final DateTime createdAt;

  Comment({
    required this.id,
    required this.userId,
    required this.userName,
    required this.message,
    required this.createdAt,
  });

  factory Comment.fromJson(Map<String, dynamic> json) {
    return Comment(
      id: json['id'],
      userId: json['userId'],
      userName: json['userName'],
      message: json['message'],
      createdAt: json['createdAt'] is Timestamp
          ? (json['createdAt'] as Timestamp).toDate()
          : DateTime.parse(json['createdAt']),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'userId': userId,
      'userName': userName,
      'message': message,
      'createdAt': createdAt.toIso8601String(),
    };
  }
}

class CollaborativePlan {
  final String id;
  final String title;
  final String description;
  final String ownerId;
  final String ownerName;
  final List<PlanDestination> destinations;
  final DateTime startDate;
  final DateTime endDate;
  final double budget;
  final List<Collaborator> collaborators;
  final List<Comment> comments;
  final String? imageUrl;
  final bool isPublic;
  final DateTime createdAt;
  final DateTime updatedAt;

  CollaborativePlan({
    required this.id,
    required this.title,
    required this.description,
    required this.ownerId,
    required this.ownerName,
    required this.destinations,
    required this.startDate,
    required this.endDate,
    required this.budget,
    required this.collaborators,
    this.comments = const [],
    this.imageUrl,
    this.isPublic = false,
    required this.createdAt,
    required this.updatedAt,
  });

  factory CollaborativePlan.fromJson(Map<String, dynamic> json) {
    return CollaborativePlan(
      id: json['id'],
      title: json['title'],
      description: json['description'],
      ownerId: json['ownerId'],
      ownerName: json['ownerName'],
      destinations: (json['destinations'] as List?)
              ?.map((d) => PlanDestination.fromJson(d))
              .toList() ??
          [],
      startDate: json['startDate'] is Timestamp
          ? (json['startDate'] as Timestamp).toDate()
          : DateTime.parse(json['startDate']),
      endDate: json['endDate'] is Timestamp
          ? (json['endDate'] as Timestamp).toDate()
          : DateTime.parse(json['endDate']),
      budget: json['budget']?.toDouble() ?? 0,
      collaborators: (json['collaborators'] as List?)
              ?.map((c) => Collaborator.fromJson(c))
              .toList() ??
          [],
      comments: (json['comments'] as List?)
              ?.map((c) => Comment.fromJson(c))
              .toList() ??
          [],
      imageUrl: json['imageUrl'],
      isPublic: json['isPublic'] ?? false,
      createdAt: json['createdAt'] is Timestamp
          ? (json['createdAt'] as Timestamp).toDate()
          : DateTime.parse(json['createdAt']),
      updatedAt: json['updatedAt'] is Timestamp
          ? (json['updatedAt'] as Timestamp).toDate()
          : DateTime.parse(json['updatedAt']),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'title': title,
      'description': description,
      'ownerId': ownerId,
      'ownerName': ownerName,
      'destinations': destinations.map((d) => d.toJson()).toList(),
      'startDate': startDate.toIso8601String(),
      'endDate': endDate.toIso8601String(),
      'budget': budget,
      'collaborators': collaborators.map((c) => c.toJson()).toList(),
      'comments': comments.map((c) => c.toJson()).toList(),
      'imageUrl': imageUrl,
      'isPublic': isPublic,
      'createdAt': createdAt.toIso8601String(),
      'updatedAt': updatedAt.toIso8601String(),
    };
  }

  bool get canEdit {
    final userId = FirebaseService.currentUserId;
    if (userId == ownerId) return true;
    try {
      final collab = collaborators.firstWhere((c) => c.userId == userId);
      return collab.role == CollaboratorRole.editor ||
          collab.role == CollaboratorRole.owner;
    } catch (e) {
      return false;
    }
  }

  bool get canInvite => FirebaseService.currentUserId == ownerId;

  bool get canDelete => FirebaseService.currentUserId == ownerId;

  int get daysUntilStart => startDate.difference(DateTime.now()).inDays;

  double get totalSpent {
    double total = 0;
    for (final dest in destinations) {
      total += dest.destination.budget.maxCost;
    }
    return total;
  }

  double get budgetRemaining => budget - totalSpent;
}
