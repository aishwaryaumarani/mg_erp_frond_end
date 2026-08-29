import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'api_service.dart';

/// Holds the logged-in session (JWT + role + company_id + name) and
/// persists it across app restarts. Mirrors ApiService's singleton style
/// (see api_service.dart) rather than pulling in a state-management
/// package -- nothing else in this app uses one (provider sits in
/// pubspec.yaml unused).
///
/// Roles mirror backend/app/models/auth.py: super_admin (no companyId,
/// manages Companies), company_admin (manages their own company's
/// Users), user (plain ERP user).
class AuthService extends ChangeNotifier {
  static final AuthService instance = AuthService._();
  AuthService._();

  static const _kToken = 'auth_token';
  static const _kRole = 'auth_role';
  static const _kCompanyId = 'auth_company_id';
  static const _kFullName = 'auth_full_name';

  String? token;
  String? role;
  int? companyId;
  String? fullName;

  bool get isLoggedIn => token != null;
  bool get isSuperAdmin => role == 'super_admin';
  bool get isCompanyAdmin => role == 'company_admin';

  Future<void> loadSession() async {
    final prefs = await SharedPreferences.getInstance();
    token = prefs.getString(_kToken);
    role = prefs.getString(_kRole);
    companyId = prefs.getInt(_kCompanyId);
    fullName = prefs.getString(_kFullName);
  }

  Future<void> login(String email, String password) async {
    final data = await ApiService.instance.create('/api/auth/login', {
      'email': email,
      'password': password,
    });

    token = data['access_token'] as String;
    role = data['role'] as String;
    companyId = data['company_id'] as int?;
    fullName = data['full_name'] as String;

    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_kToken, token!);
    await prefs.setString(_kRole, role!);
    if (companyId != null) {
      await prefs.setInt(_kCompanyId, companyId!);
    } else {
      await prefs.remove(_kCompanyId);
    }
    await prefs.setString(_kFullName, fullName!);

    notifyListeners();
  }

  Future<void> logout() async {
    token = null;
    role = null;
    companyId = null;
    fullName = null;

    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_kToken);
    await prefs.remove(_kRole);
    await prefs.remove(_kCompanyId);
    await prefs.remove(_kFullName);

    notifyListeners();
  }
}
