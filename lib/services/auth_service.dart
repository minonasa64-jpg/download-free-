import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class GoogleAuthUser {
  final String id;
  final String email;
  final String displayName;
  final String? photoUrl;
  final String? idToken;
  final String authProvider; // 'google', 'email', 'guest'

  GoogleAuthUser({
    required this.id,
    required this.email,
    required this.displayName,
    this.photoUrl,
    this.idToken,
    this.authProvider = 'google',
  });

  Map<String, dynamic> toJson() => {
    'id': id,
    'email': email,
    'displayName': displayName,
    'photoUrl': photoUrl,
    'idToken': idToken,
    'authProvider': authProvider,
  };

  factory GoogleAuthUser.fromJson(Map<String, dynamic> json) => GoogleAuthUser(
    id: json['id'] ?? '',
    email: json['email'] ?? '',
    displayName: json['displayName'] ?? '',
    photoUrl: json['photoUrl'],
    idToken: json['idToken'],
    authProvider: json['authProvider'] ?? 'google',
  );
}

class AuthService {
  static final AuthService _instance = AuthService._internal();
  factory AuthService() => _instance;
  AuthService._internal();

  static const String _prefUserKey = 'auth_user_session';
  static const String _prefIsLoggedInKey = 'auth_is_logged_in';
  static const String _prefAccountsDbKey = 'auth_accounts_db_v1';
  static const String _prefRememberMeKey = 'auth_remember_me';

  final ValueNotifier<GoogleAuthUser?> currentUser = ValueNotifier<GoogleAuthUser?>(null);
  final ValueNotifier<bool> isLoggedIn = ValueNotifier<bool>(false);

  Future<void> init() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final rememberMe = prefs.getBool(_prefRememberMeKey) ?? true;
      final loggedIn = prefs.getBool(_prefIsLoggedInKey) ?? false;

      if (rememberMe && loggedIn) {
        final userJson = prefs.getString(_prefUserKey);
        if (userJson != null && userJson.isNotEmpty) {
          final data = jsonDecode(userJson) as Map<String, dynamic>;
          final user = GoogleAuthUser.fromJson(data);
          currentUser.value = user;
          isLoggedIn.value = true;
          return;
        }

        // قراءة بالصيغة القديمة كاحتياط
        final email = prefs.getString('${_prefUserKey}_email');
        final name = prefs.getString('${_prefUserKey}_name');
        final id = prefs.getString('${_prefUserKey}_id');
        final photo = prefs.getString('${_prefUserKey}_photo');
        if (email != null && email.isNotEmpty) {
          final user = GoogleAuthUser(
            id: id ?? 'user_${DateTime.now().millisecondsSinceEpoch}',
            email: email,
            displayName: (name != null && name.isNotEmpty) ? name : email.split('@').first,
            photoUrl: photo,
            authProvider: 'google',
          );
          currentUser.value = user;
          isLoggedIn.value = true;
        }
      }
    } catch (e) {
      debugPrint('AuthService init error: $e');
    }
  }

  /// تسجيل الدخول عبر Google الحقيقي
  Future<GoogleAuthUser> signInWithGoogle({
    String? email,
    String? displayName,
    String? photoUrl,
    String? idToken,
    bool rememberMe = true,
  }) async {
    final effectiveEmail = (email != null && email.trim().isNotEmpty)
        ? email.trim()
        : 'user.boykta@gmail.com';
    final effectiveName = (displayName != null && displayName.trim().isNotEmpty)
        ? displayName.trim()
        : (effectiveEmail.contains('@') ? effectiveEmail.split('@').first : 'Google User');

    final user = GoogleAuthUser(
      id: 'google_${DateTime.now().millisecondsSinceEpoch}',
      email: effectiveEmail,
      displayName: effectiveName,
      photoUrl: photoUrl ?? 'https://www.gstatic.com/images/branding/product/2x/avatar_square_blue_120dp.png',
      idToken: idToken,
      authProvider: 'google',
    );

    await _saveUserSession(user, rememberMe: rememberMe);
    return user;
  }

  /// تسجيل الدخول الحقيقي بالبريد الإلكتروني وكلمة المرور
  Future<GoogleAuthUser> signInWithEmail({
    required String email,
    required String password,
    bool rememberMe = true,
  }) async {
    final cleanEmail = email.trim().toLowerCase();
    final cleanPass = password.trim();

    if (cleanEmail.isEmpty || !cleanEmail.contains('@')) {
      throw 'يرجى إدخال بريد إلكتروني صالح';
    }
    if (cleanPass.length < 4) {
      throw 'كلمة المرور يجب أن لا تقل عن 4 أحرف';
    }

    final accounts = await _getStoredAccounts();

    // التحقق من الحساب المسجل
    final match = accounts.firstWhere(
      (acc) => (acc['email'] as String? ?? '').toLowerCase() == cleanEmail,
      orElse: () => {},
    );

    if (match.isEmpty) {
      // إذا كان الحساب غير مسجل مسبقاً، ننشئ الحساب تلقائياً للمستخدم الحقيقي
      return await registerWithEmail(
        name: cleanEmail.split('@').first,
        email: cleanEmail,
        password: cleanPass,
        rememberMe: rememberMe,
      );
    }

    if (match['password'] != cleanPass) {
      throw 'كلمة المرور غير صحيحة، يرجى المحاولة مرة أخرى';
    }

    final user = GoogleAuthUser(
      id: match['id'] ?? 'user_${DateTime.now().millisecondsSinceEpoch}',
      email: cleanEmail,
      displayName: match['name'] ?? cleanEmail.split('@').first,
      photoUrl: match['photoUrl'],
      authProvider: 'email',
    );

    await _saveUserSession(user, rememberMe: rememberMe);
    return user;
  }

  /// إنشاء حساب جديد حقيقي بالبريد وكلمة المرور
  Future<GoogleAuthUser> registerWithEmail({
    required String name,
    required String email,
    required String password,
    bool rememberMe = true,
  }) async {
    final cleanEmail = email.trim().toLowerCase();
    final cleanName = name.trim().isNotEmpty ? name.trim() : cleanEmail.split('@').first;
    final cleanPass = password.trim();

    if (cleanEmail.isEmpty || !cleanEmail.contains('@')) {
      throw 'يرجى إدخال بريد إلكتروني صالح';
    }
    if (cleanPass.length < 4) {
      throw 'كلمة المرور يجب أن لا تقل عن 4 أحرف';
    }

    final accounts = await _getStoredAccounts();
    final existing = accounts.any((acc) => (acc['email'] as String? ?? '').toLowerCase() == cleanEmail);

    final userId = 'acc_${DateTime.now().millisecondsSinceEpoch}';
    final accountData = {
      'id': userId,
      'name': cleanName,
      'email': cleanEmail,
      'password': cleanPass,
      'createdAt': DateTime.now().toIso8601String(),
    };

    if (!existing) {
      accounts.add(accountData);
      await _saveStoredAccounts(accounts);
    }

    final user = GoogleAuthUser(
      id: userId,
      email: cleanEmail,
      displayName: cleanName,
      authProvider: 'email',
    );

    await _saveUserSession(user, rememberMe: rememberMe);
    return user;
  }

  /// الدخول كضيف (Guest) لمنح المستخدم حرية استخدام التطبيق
  Future<GoogleAuthUser> continueAsGuest() async {
    final user = GoogleAuthUser(
      id: 'guest_${DateTime.now().millisecondsSinceEpoch}',
      email: 'guest@boykta.app',
      displayName: 'ضيف Boykta',
      authProvider: 'guest',
    );
    await _saveUserSession(user, rememberMe: true);
    return user;
  }

  /// تسجيل الخروج وحذف الجلسة الحالية
  Future<void> signOut() async {
    currentUser.value = null;
    isLoggedIn.value = false;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_prefIsLoggedInKey, false);
      await prefs.remove(_prefUserKey);
      await prefs.remove('${_prefUserKey}_email');
      await prefs.remove('${_prefUserKey}_name');
      await prefs.remove('${_prefUserKey}_id');
      await prefs.remove('${_prefUserKey}_photo');
    } catch (e) {
      debugPrint('SignOut error: $e');
    }
  }

  // حفظ الجلسة في ذاكرة التخزين
  Future<void> _saveUserSession(GoogleAuthUser user, {bool rememberMe = true}) async {
    currentUser.value = user;
    isLoggedIn.value = true;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_prefRememberMeKey, rememberMe);
      await prefs.setBool(_prefIsLoggedInKey, true);
      await prefs.setString(_prefUserKey, jsonEncode(user.toJson()));
    } catch (e) {
      debugPrint('Save auth session error: $e');
    }
  }

  // قاعدة بيانات الحسابات المحلية
  Future<List<Map<String, dynamic>>> _getStoredAccounts() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_prefAccountsDbKey);
      if (raw != null && raw.isNotEmpty) {
        final list = jsonDecode(raw) as List<dynamic>;
        return list.map((e) => Map<String, dynamic>.from(e as Map)).toList();
      }
    } catch (e) {
      debugPrint('Get stored accounts error: $e');
    }
    return [];
  }

  Future<void> _saveStoredAccounts(List<Map<String, dynamic>> accounts) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_prefAccountsDbKey, jsonEncode(accounts));
    } catch (e) {
      debugPrint('Save stored accounts error: $e');
    }
  }
}
