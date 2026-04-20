import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:halaph/services/firebase_service.dart';
import 'package:halaph/services/auth_service.dart';

class FriendService {
  static List<Friend> _friends = [];
  static List<FriendRequest> _requests = [];

  static List<Friend> get friends => _friends;
  static List<FriendRequest> get pendingRequests => _requests;
  static int get pendingRequestsCount => _requests.length;

  static Future<void> initialize() async {
    if (AuthService.isLoggedIn) {
      await _loadFriends();
      await _loadRequests();
    }
  }

  static Stream<List<Friend>> friendsStream() {
    if (FirebaseService.currentUserId == null) return Stream.value([]);

    return FirebaseFirestore.instance
        .collection('friends')
        .where('userId', isEqualTo: FirebaseService.currentUserId)
        .where('status', isEqualTo: 'friend')
        .snapshots()
        .map((snapshot) {
      return snapshot.docs.map((doc) => Friend.fromJson(doc.data())).toList();
    });
  }

  static Stream<List<FriendRequest>> requestsStream() {
    if (FirebaseService.currentUserId == null) return Stream.value([]);

    return FirebaseFirestore.instance
        .collection('friend_requests')
        .where('toUserId', isEqualTo: FirebaseService.currentUserId)
        .where('status', isEqualTo: 'pending')
        .snapshots()
        .map((snapshot) {
      return snapshot.docs
          .map((doc) => FriendRequest.fromJson(doc.data()))
          .toList();
    });
  }

  static Future<void> _loadFriends() async {
    if (FirebaseService.currentUserId == null) return;

    try {
      final snapshot = await FirebaseFirestore.instance
          .collection('friends')
          .where('userId', isEqualTo: FirebaseService.currentUserId)
          .where('status', isEqualTo: 'friend')
          .get();

      _friends =
          snapshot.docs.map((doc) => Friend.fromJson(doc.data())).toList();
    } catch (e) {
      print('Error loading friends: $e');
    }
  }

  static Future<void> _loadRequests() async {
    if (FirebaseService.currentUserId == null) return;

    try {
      final snapshot = await FirebaseFirestore.instance
          .collection('friend_requests')
          .where('toUserId', isEqualTo: FirebaseService.currentUserId)
          .where('status', isEqualTo: 'pending')
          .get();

      _requests = snapshot.docs
          .map((doc) => FriendRequest.fromJson(doc.data()))
          .toList();
    } catch (e) {
      print('Error loading requests: $e');
    }
  }

  static String? getMyInviteCode() {
    return AuthService.inviteCode;
  }

  static Future<Friend?> addFriendByCode(String inviteCode) async {
    if (!AuthService.isLoggedIn) return null;

    inviteCode = inviteCode.toUpperCase().trim();

    try {
      final snapshot = await FirebaseFirestore.instance
          .collection('users')
          .where('inviteCode', isEqualTo: inviteCode)
          .get();

      if (snapshot.docs.isEmpty) return null;

      final friendData = snapshot.docs.first.data();
      final friendId = friendData['id'] as String;

      if (friendId == FirebaseService.currentUserId) return null;

      final friend = Friend(
        id: '${FirebaseService.currentUserId}_$friendId',
        friendId: friendId,
        name: friendData['name'] ?? 'Unknown',
        avatarUrl: friendData['avatarUrl'],
        status: FriendStatus.friend,
        addedAt: DateTime.now(),
      );

      await FirebaseFirestore.instance
          .collection('friends')
          .doc(friend.id)
          .set(friend.toJson());

      _friends.add(friend);

      await FirebaseFirestore.instance.collection('friend_activities').add({
        'userId': FirebaseService.currentUserId,
        'userName': AuthService.userName,
        'type': 'friendAdded',
        'friendId': friendId,
        'friendName': friend.name,
        'message': '${AuthService.userName} added ${friend.name} as a friend',
        'createdAt': FieldValue.serverTimestamp(),
        'isRead': false,
      });

      return friend;
    } catch (e) {
      print('Error adding friend: $e');
      return null;
    }
  }

  static Future<FriendRequest> sendFriendRequest(
      String userId, String userName) async {
    if (!AuthService.isLoggedIn) throw Exception('Not logged in');

    final request = FriendRequest(
      id: '${FirebaseService.currentUserId}_$userId',
      fromUserId: FirebaseService.currentUserId!,
      fromUserName: AuthService.userName ?? 'Unknown',
      toUserId: userId,
      status: FriendRequestStatus.pending,
      createdAt: DateTime.now(),
    );

    await FirebaseFirestore.instance
        .collection('friend_requests')
        .doc(request.id)
        .set(request.toJson());

    _requests.add(request);
    return request;
  }

  static Future<void> acceptFriendRequest(String requestId) async {
    try {
      final requestIndex = _requests.indexWhere((r) => r.id == requestId);
      if (requestIndex == -1) return;

      final request = _requests[requestIndex];

      await FirebaseFirestore.instance
          .collection('friend_requests')
          .doc(requestId)
          .update({'status': 'accepted'});

      final friend = Friend(
        id: '${FirebaseService.currentUserId}_${request.fromUserId}',
        friendId: request.fromUserId,
        name: request.fromUserName,
        status: FriendStatus.friend,
        addedAt: DateTime.now(),
      );

      await FirebaseFirestore.instance
          .collection('friends')
          .doc(friend.id)
          .set(friend.toJson());

      _friends.add(friend);
      _requests.removeAt(requestIndex);
    } catch (e) {
      print('Error accepting friend request: $e');
    }
  }

  static Future<void> declineFriendRequest(String requestId) async {
    try {
      await FirebaseFirestore.instance
          .collection('friend_requests')
          .doc(requestId)
          .update({'status': 'declined'});

      _requests.removeWhere((r) => r.id == requestId);
    } catch (e) {
      print('Error declining friend request: $e');
    }
  }

  static Future<void> removeFriend(String friendId) async {
    try {
      final docId = '${FirebaseService.currentUserId}_$friendId';
      await FirebaseFirestore.instance
          .collection('friends')
          .doc(docId)
          .delete();
      _friends.removeWhere((f) => f.friendId == friendId);
    } catch (e) {
      print('Error removing friend: $e');
    }
  }

  static Future<void> blockFriend(String friendId) async {
    final index = _friends.indexWhere((f) => f.friendId == friendId);
    if (index != -1) {
      _friends[index] = _friends[index].copyWith(status: FriendStatus.blocked);
      await FirebaseFirestore.instance
          .collection('friends')
          .doc('${FirebaseService.currentUserId}_$friendId')
          .update({'status': 'blocked'});
    }
  }

  static Future<void> unblockFriend(String friendId) async {
    final index = _friends.indexWhere((f) => f.friendId == friendId);
    if (index != -1) {
      _friends[index] = _friends[index].copyWith(status: FriendStatus.friend);
      await FirebaseFirestore.instance
          .collection('friends')
          .doc('${FirebaseService.currentUserId}_$friendId')
          .update({'status': 'friend'});
    }
  }

  static bool isFriend(String userId) {
    return _friends
        .any((f) => f.friendId == userId && f.status == FriendStatus.friend);
  }

  static List<Friend> get friendsOnline =>
      _friends.where((f) => f.isOnline).toList();
}

enum FriendStatus { friend, blocked, pending }

class Friend {
  final String id;
  final String friendId;
  final String name;
  final String? avatarUrl;
  final FriendStatus status;
  final bool isOnline;
  final DateTime? lastSeen;
  final DateTime addedAt;

  Friend({
    required this.id,
    required this.friendId,
    required this.name,
    this.avatarUrl,
    this.status = FriendStatus.friend,
    this.isOnline = false,
    this.lastSeen,
    required this.addedAt,
  });

  factory Friend.fromJson(Map<String, dynamic> json) {
    return Friend(
      id: json['id'],
      friendId: json['friendId'],
      name: json['name'],
      avatarUrl: json['avatarUrl'],
      status: FriendStatus.values.firstWhere((s) => s.name == json['status'],
          orElse: () => FriendStatus.friend),
      isOnline: json['isOnline'] ?? false,
      lastSeen: json['lastSeen'] != null
          ? (json['lastSeen'] is Timestamp
              ? (json['lastSeen'] as Timestamp).toDate()
              : DateTime.parse(json['lastSeen']))
          : null,
      addedAt: json['addedAt'] is Timestamp
          ? (json['addedAt'] as Timestamp).toDate()
          : DateTime.parse(json['addedAt']),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'friendId': friendId,
      'userId': FirebaseService.currentUserId,
      'name': name,
      'avatarUrl': avatarUrl,
      'status': status.name,
      'isOnline': isOnline,
      'lastSeen': lastSeen?.toIso8601String(),
      'addedAt': addedAt.toIso8601String(),
    };
  }

  Friend copyWith({
    String? name,
    String? avatarUrl,
    FriendStatus? status,
    bool? isOnline,
    DateTime? lastSeen,
  }) {
    return Friend(
      id: id,
      friendId: friendId,
      name: name ?? this.name,
      avatarUrl: avatarUrl ?? this.avatarUrl,
      status: status ?? this.status,
      isOnline: isOnline ?? this.isOnline,
      lastSeen: lastSeen ?? this.lastSeen,
      addedAt: addedAt,
    );
  }
}

enum FriendRequestStatus { pending, accepted, declined }

class FriendRequest {
  final String id;
  final String fromUserId;
  final String fromUserName;
  final String toUserId;
  final FriendRequestStatus status;
  final DateTime createdAt;

  FriendRequest({
    required this.id,
    required this.fromUserId,
    required this.fromUserName,
    required this.toUserId,
    this.status = FriendRequestStatus.pending,
    required this.createdAt,
  });

  factory FriendRequest.fromJson(Map<String, dynamic> json) {
    return FriendRequest(
      id: json['id'],
      fromUserId: json['fromUserId'],
      fromUserName: json['fromUserName'],
      toUserId: json['toUserId'],
      status: FriendRequestStatus.values.firstWhere(
          (s) => s.name == json['status'],
          orElse: () => FriendRequestStatus.pending),
      createdAt: json['createdAt'] is Timestamp
          ? (json['createdAt'] as Timestamp).toDate()
          : DateTime.parse(json['createdAt']),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'fromUserId': fromUserId,
      'fromUserName': fromUserName,
      'toUserId': toUserId,
      'status': status.name,
      'createdAt': createdAt.toIso8601String(),
    };
  }
}

class FriendActivity {
  final String id;
  final String userId;
  final String userName;
  final FriendActivityType type;
  final String? planId;
  final String? planName;
  final String message;
  final DateTime createdAt;
  final bool isRead;

  FriendActivity({
    required this.id,
    required this.userId,
    required this.userName,
    required this.type,
    this.planId,
    this.planName,
    required this.message,
    required this.createdAt,
    this.isRead = false,
  });

  factory FriendActivity.fromJson(Map<String, dynamic> json) {
    return FriendActivity(
      id: json['id'] ?? '',
      userId: json['userId'],
      userName: json['userName'],
      type: FriendActivityType.values.firstWhere((t) => t.name == json['type']),
      planId: json['planId'],
      planName: json['planName'],
      message: json['message'],
      createdAt: json['createdAt'] is Timestamp
          ? (json['createdAt'] as Timestamp).toDate()
          : DateTime.parse(json['createdAt']),
      isRead: json['isRead'] ?? false,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'userId': userId,
      'userName': userName,
      'type': type.name,
      'planId': planId,
      'planName': planName,
      'message': message,
      'createdAt': createdAt.toIso8601String(),
      'isRead': isRead,
    };
  }

  FriendActivity markAsRead() {
    return FriendActivity(
      id: id,
      userId: userId,
      userName: userName,
      type: type,
      planId: planId,
      planName: planName,
      message: message,
      createdAt: createdAt,
      isRead: true,
    );
  }
}

enum FriendActivityType {
  planCreated,
  planUpdated,
  planJoined,
  friendAdded,
  tripStarted,
  tripCompleted,
}
