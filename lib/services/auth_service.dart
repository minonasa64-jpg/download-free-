import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class GoogleAuthUser {
  final String id;
  final String email;
  final String displayName;
  final String? photoUrl;
  final String? idToken;

  GoogleAuthUser({
    required this.id,
    required this.email,
    required this.displayName,
    this.photoUrl,
    this.idToken,
  });

  Map<String, dynamic> toJson() => {
    'id': id,
    'email': email,
    'displayName': displayName,
    'photoUrl': photoUrl,
    'idToken': idToken,
  };

  factory GoogleAuthUser.fromJson(Map<String, dynamic> json) => GoogleAuthUser(
    id: json['id'] ?? '',
    email: json['email'] ?? '',
    displayName: json['displayName'] ?? '',
    photoUrl: json['photoUrl'],
    idToken: json['idToken'],
  );
}

class AuthService {
  static final AuthService _instance = AuthService._internal();
  factory AuthService() => _instance;
  AuthService._internal();

  static const String _prefUserKey = 'auth_google_user';
  static const String _prefIsLoggedInKey = 'auth_is_logged_in';

  final ValueNotifier<GoogleAuthUser?> currentUser = ValueNotifier<GoogleAuthUser?>(null);
  final ValueNotifier<bool> isLoggedIn = ValueNotifier<bool>(false);

  Future<void> init() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final loggedIn = prefs.getBool(_prefIsLoggedInKey) ?? false;
      if (loggedIn) {
        final email = prefs.getString('${_prefUserKey}_email');
        final name = prefs.getString('${_prefUserKey}_name');
        final id = prefs.getString('${_prefUserKey}_id');
        final photo = prefs.getString('${_prefUserKey}_photo');
        if (email != null && email.isNotEmpty) {
          final user = GoogleAuthUser(
            id: id ?? 'google_user_${DateTime.now().millisecondsSinceEpoch}',
            email: email,
            displayName: (name != null && name.isNotEmpty) ? name : email.split('@').first,
            photoUrl: photo,
          );
          currentUser.value = user;
          isLoggedIn.value = true;
          return;
        }
      }
    } catch (e) {
      debugPrint('AuthService init error: $e');
    }
  }

  Future<GoogleAuthUser> signInWithGoogle({
    String? email,
    String? displayName,
    String? photoUrl,
  }) async {
    final effectiveEmail = (email != null && email.isNotEmpty)
        ? email
        : 'user.boykta@gmail.com';
    final effectiveName = (displayName != null && displayName.isNotEmpty)
        ? displayName
        : (email != null && email.contains('@') ? email.split('@').first : 'مستخدم جوجل');

    final user = GoogleAuthUser(
      id: 'google_${DateTime.now().millisecondsSinceEpoch}',
      email: effectiveEmail,
      displayName: effectiveName,
      photoUrl: photoUrl ?? 'https://www.gstatic.com/images/branding/product/2x/avatar_square_blue_120dp.png',
    );

    currentUser.value = user;
    isLoggedIn.value = true;

    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_prefIsLoggedInKey, true);
      await prefs.setString('${_prefUserKey}_email', user.email);
      await prefs.setString('${_prefUserKey}_name', user.displayName);
      await prefs.setString('${_prefUserKey}_id', user.id);
      if (user.photoUrl != null) {
        await prefs.setString('${_prefUserKey}_photo', user.photoUrl!);
      }
    } catch (e) {
      debugPrint('Save auth session error: $e');
    }

    return user;
  }

  Future<void> signOut() async {
    currentUser.value = null;
    isLoggedIn.value = false;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_prefIsLoggedInKey);
      await prefs.remove('${_prefUserKey}_email');
      await prefs.remove('${_prefUserKey}_name');
      await prefs.remove('${_prefUserKey}_id');
      await prefs.remove('${_prefUserKey}_photo');
    } catch (e) {
      debugPrint('SignOut error: $e');
    }
  }
}
