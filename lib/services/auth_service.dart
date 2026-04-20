import 'package:firebase_auth/firebase_auth.dart' as firebase_auth;
import 'package:halaph/services/firebase_service.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';

class AuthService {
  static const String _accountsKey = 'local_accounts';
  static firebase_auth.User? _currentUser;
  static String? _token;
  static String? _inviteCode;
  static String? _userName;
  static String? _localUserId;
  static String? _localEmail;

  static firebase_auth.User? get currentUser => _currentUser;
  static bool get isLoggedIn => _currentUser != null || _localUserId != null;
  static String? get token => _token;
  static String? get inviteCode => _inviteCode;
  static String? get userName => _userName;
  static String? get currentEmail => _currentUser?.email ?? _localEmail;
  static String? get currentUserId => _currentUser?.uid ?? _localUserId;

  static Future<void> initialize() async {
    try {
      await FirebaseService.initialize();
    } catch (_) {}

    final prefs = await SharedPreferences.getInstance();
    _currentUser = firebase_auth.FirebaseAuth.instance.currentUser;
    _localUserId = prefs.getString('local_user_id');
    _localEmail = prefs.getString('user_email');
    _userName = prefs.getString('user_name');
    _inviteCode = prefs.getString('user_invite_code');

    if (_currentUser != null) {
      await _loadUserData();
    } else if (_localUserId != null) {
      _token = _localUserId;
    }
  }

  static Future<void> _loadUserData() async {
    if (_currentUser == null) return;

    try {
      final userData = await FirebaseService.getUserData(_currentUser!.uid);
      if (userData != null) {
        _inviteCode = userData['inviteCode'] as String?;
        _userName = userData['name'] as String?;
      }
    } catch (e) {
      print('Error loading user data: $e');
    }
  }

  static Future<bool> login(String email, String password) async {
    try {
      await FirebaseService.signInWithEmail(email, password);
      _currentUser = firebase_auth.FirebaseAuth.instance.currentUser;

      if (_currentUser != null) {
        _token = _currentUser!.uid;
        _localUserId = _currentUser!.uid;
        _localEmail = _currentUser!.email;
        await _loadUserData();
        await _saveLocalAuth();
        return true;
      }
    } catch (_) {}

    final prefs = await SharedPreferences.getInstance();
    final accounts = _getStoredAccounts(prefs);

    for (final account in accounts) {
      if (account['email'] == email.trim() && account['password'] == password) {
        _currentUser = null;
        _localUserId = account['id'] as String;
        _localEmail = account['email'] as String;
        _userName = account['name'] as String;
        _inviteCode = account['inviteCode'] as String;
        _token = _localUserId;
        await _saveLocalAuth();
        return true;
      }
    }

    throw Exception('Invalid email or password');
  }

  static Future<bool> register(
      String name, String email, String password) async {
    try {
      await FirebaseService.signUpWithEmail(name, email, password);
      _currentUser = firebase_auth.FirebaseAuth.instance.currentUser;

      if (_currentUser != null) {
        _token = _currentUser!.uid;
        _localUserId = _currentUser!.uid;
        _localEmail = _currentUser!.email;
        _userName = name;
        _inviteCode = await FirebaseService.getInviteCode();
        await _saveLocalAuth();
        return true;
      }
    } catch (_) {}

    final prefs = await SharedPreferences.getInstance();
    final accounts = _getStoredAccounts(prefs);
    final normalizedEmail = email.trim().toLowerCase();

    if (accounts.any((account) => account['email'] == normalizedEmail)) {
      throw Exception('An account already exists with this email');
    }

    final localId = 'local_${DateTime.now().millisecondsSinceEpoch}';
    final generatedInviteCode = _generateLocalInviteCode(name, localId);

    accounts.add({
      'id': localId,
      'name': name.trim(),
      'email': normalizedEmail,
      'password': password,
      'inviteCode': generatedInviteCode,
      'createdAt': DateTime.now().toIso8601String(),
    });

    await prefs.setString(_accountsKey, jsonEncode(accounts));

    _currentUser = null;
    _localUserId = localId;
    _localEmail = normalizedEmail;
    _token = localId;
    _userName = name.trim();
    _inviteCode = generatedInviteCode;
    await _saveLocalAuth();
    return true;
  }

  static Future<void> _saveLocalAuth() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('local_user_id', currentUserId ?? '');
      await prefs.setString('firebase_uid', _currentUser?.uid ?? '');
      await prefs.setString('user_email', currentEmail ?? '');
      await prefs.setString('user_name', _userName ?? '');
      await prefs.setString('user_invite_code', _inviteCode ?? '');
    } catch (e) {
      print('Error saving local auth: $e');
    }
  }

  static Future<void> logout() async {
    try {
      await FirebaseService.signOut();
    } catch (_) {}
    _currentUser = null;
    _token = null;
    _inviteCode = null;
    _userName = null;
    _localUserId = null;
    _localEmail = null;

    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('firebase_uid');
    await prefs.remove('local_user_id');
    await prefs.remove('user_email');
    await prefs.remove('user_name');
    await prefs.remove('user_invite_code');
  }

  static Future<void> updateProfile({String? name, String? avatarUrl}) async {
    if (!isLoggedIn) return;

    if (_currentUser != null) {
      await FirebaseService.updateUserProfile(name: name, avatarUrl: avatarUrl);
    }

    if (name != null) {
      _userName = name;
    }

    if (_localUserId != null) {
      final prefs = await SharedPreferences.getInstance();
      final accounts = _getStoredAccounts(prefs);
      final index = accounts.indexWhere((account) => account['id'] == _localUserId);
      if (index != -1) {
        accounts[index]['name'] = _userName;
        await prefs.setString(_accountsKey, jsonEncode(accounts));
      }
      await _saveLocalAuth();
    }
  }

  static Future<bool> changePassword(
      String currentPassword, String newPassword) async {
    if (_currentUser == null) return false;

    try {
      final cred = firebase_auth.EmailAuthProvider.credential(
        email: _currentUser!.email!,
        password: currentPassword,
      );

      await _currentUser!.reauthenticateWithCredential(cred);
      await _currentUser!.updatePassword(newPassword);
      return true;
    } catch (e) {
      throw Exception('Failed to change password: $e');
    }
  }

  static Future<bool> checkAuthState() async {
    _currentUser = firebase_auth.FirebaseAuth.instance.currentUser;
    if (_currentUser != null) {
      _token = _currentUser!.uid;
      await _loadUserData();
      return true;
    }

    final prefs = await SharedPreferences.getInstance();
    _localUserId = prefs.getString('local_user_id');
    _localEmail = prefs.getString('user_email');
    _userName = prefs.getString('user_name');
    _inviteCode = prefs.getString('user_invite_code');
    _token = _localUserId;
    return _localUserId != null && _localUserId!.isNotEmpty;
  }

  static List<Map<String, dynamic>> _getStoredAccounts(SharedPreferences prefs) {
    final raw = prefs.getString(_accountsKey);
    if (raw == null || raw.isEmpty) {
      return <Map<String, dynamic>>[];
    }

    final decoded = jsonDecode(raw) as List<dynamic>;
    return decoded.map((item) => Map<String, dynamic>.from(item)).toList();
  }

  static String _generateLocalInviteCode(String name, String id) {
    final prefix = name.replaceAll(RegExp(r'[^A-Za-z]'), '').toUpperCase();
    final shortPrefix = (prefix.isEmpty ? 'TRIP' : prefix).padRight(4, 'X');
    final suffix = id.hashCode.abs().toRadixString(36).toUpperCase().padLeft(6, '0');
    return '${shortPrefix.substring(0, 4)}${suffix.substring(0, 6)}';
  }
}

class User {
  final String id;
  final String email;
  final String name;
  final String? avatarUrl;
  final DateTime createdAt;

  User({
    required this.id,
    required this.email,
    required this.name,
    this.avatarUrl,
    required this.createdAt,
  });

  factory User.fromJson(Map<String, dynamic> json) {
    return User(
      id: json['id'],
      email: json['email'],
      name: json['name'],
      avatarUrl: json['avatarUrl'],
      createdAt: DateTime.parse(json['createdAt']),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'email': email,
      'name': name,
      'avatarUrl': avatarUrl,
      'createdAt': createdAt.toIso8601String(),
    };
  }

  User copyWith({
    String? name,
    String? avatarUrl,
  }) {
    return User(
      id: id,
      email: email,
      name: name ?? this.name,
      avatarUrl: avatarUrl ?? this.avatarUrl,
      createdAt: createdAt,
    );
  }
}
