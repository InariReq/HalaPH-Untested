import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart' as firebase_auth;
import 'package:cloud_firestore/cloud_firestore.dart';

class FirebaseService {
  static final firebase_auth.FirebaseAuth _auth =
      firebase_auth.FirebaseAuth.instance;
  static final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  static CollectionReference get usersCollection =>
      _firestore.collection('users');
  static CollectionReference get plansCollection =>
      _firestore.collection('plans');
  static CollectionReference get friendsCollection =>
      _firestore.collection('friends');
  static CollectionReference get collaborativePlansCollection =>
      _firestore.collection('collaborative_plans');
  static CollectionReference get destinationsCollection =>
      _firestore.collection('destinations');

  static firebase_auth.User? get currentUser => _auth.currentUser;
  static String? get currentUserId => _auth.currentUser?.uid;

  static Future<void> initialize() async {
    await Firebase.initializeApp();
  }

  static Future<bool> signInWithEmail(String email, String password) async {
    try {
      final credential = await _auth.signInWithEmailAndPassword(
        email: email,
        password: password,
      );
      if (credential.user != null) {
        await _syncUserToFirestore(credential.user!);
        return true;
      }
      return false;
    } on firebase_auth.FirebaseAuthException catch (e) {
      throw _handleAuthError(e);
    }
  }

  static Future<bool> signUpWithEmail(
      String name, String email, String password) async {
    try {
      final credential = await _auth.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );

      if (credential.user != null) {
        await credential.user!.updateDisplayName(name);
        await _createUserDocument(credential.user!, name);
        return true;
      }
      return false;
    } on firebase_auth.FirebaseAuthException catch (e) {
      throw _handleAuthError(e);
    }
  }

  static Future<void> _createUserDocument(
      firebase_auth.User user, String name) async {
    final inviteCode = _generateInviteCode(user.uid, name);

    await usersCollection.doc(user.uid).set({
      'id': user.uid,
      'email': user.email,
      'name': name,
      'inviteCode': inviteCode,
      'createdAt': FieldValue.serverTimestamp(),
      'lastSeen': FieldValue.serverTimestamp(),
      'isOnline': true,
    });
  }

  static Future<void> _syncUserToFirestore(firebase_auth.User user) async {
    await usersCollection.doc(user.uid).update({
      'lastSeen': FieldValue.serverTimestamp(),
      'isOnline': true,
    });
  }

  static String _generateInviteCode(String userId, String userName) {
    final timestamp = DateTime.now().millisecondsSinceEpoch;
    final hash =
        '${userId}_$timestamp'.hashCode.abs().toRadixString(36).toUpperCase();
    final shortName = userName
        .replaceAll(RegExp(r'[^a-zA-Z]'), '')
        .substring(0, userName.length.clamp(0, 4))
        .toUpperCase();
    return 'TRI$shortName$hash'.substring(0, 10).padLeft(10, 'X');
  }

  static Future<void> signOut() async {
    if (currentUserId != null) {
      await usersCollection.doc(currentUserId).update({
        'isOnline': false,
        'lastSeen': FieldValue.serverTimestamp(),
      });
    }
    await _auth.signOut();
  }

  static String _handleAuthError(firebase_auth.FirebaseAuthException e) {
    switch (e.code) {
      case 'user-not-found':
        return 'No account found with this email';
      case 'wrong-password':
        return 'Incorrect password';
      case 'email-already-in-use':
        return 'An account already exists with this email';
      case 'weak-password':
        return 'Password should be at least 6 characters';
      case 'invalid-email':
        return 'Invalid email format';
      default:
        return 'Authentication failed: ${e.message}';
    }
  }

  static Future<Map<String, dynamic>?> getUserData(String userId) async {
    final doc = await usersCollection.doc(userId).get();
    return doc.exists ? doc.data() as Map<String, dynamic> : null;
  }

  static Future<void> updateUserProfile(
      {String? name, String? avatarUrl}) async {
    if (currentUserId == null) return;

    final updates = <String, dynamic>{};
    if (name != null) {
      updates['name'] = name;
      await currentUser!.updateDisplayName(name);
    }
    if (avatarUrl != null) {
      updates['avatarUrl'] = avatarUrl;
    }

    if (updates.isNotEmpty) {
      await usersCollection.doc(currentUserId).update(updates);
    }
  }

  static Future<String?> getInviteCode() async {
    if (currentUserId == null) return null;
    final doc = await usersCollection.doc(currentUserId).get();
    return doc.exists ? doc.get('inviteCode') as String? : null;
  }
}
