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
///
/// [modules] are the departments this login may open (backend/app/core/
/// permissions.py). main.dart builds the sidebar from them, so a user
/// granted only "sales" sees only the Sales group. They are a mirror of
/// the server's answer, never the authority: every endpoint re-checks,
/// so a stale cached list can hide a menu but can never unlock data.
class AuthService extends ChangeNotifier {
  static final AuthService instance = AuthService._();
  AuthService._();

  static const _kToken = 'auth_token';
  static const _kRole = 'auth_role';
  static const _kCompanyId = 'auth_company_id';
  static const _kFullName = 'auth_full_name';
  static const _kModules = 'auth_modules';

  String? token;
  String? role;
  int? companyId;
  String? fullName;
  List<String> modules = const [];

  bool get isLoggedIn => token != null;
  bool get isSuperAdmin => role == 'super_admin';
  bool get isCompanyAdmin => role == 'company_admin';

  /// True when this login may open [module] (e.g. 'sales'). Admins are
  /// never department-gated -- the backend says the same, and the login
  /// response already sends them the full list.
  bool can(String module) => isSuperAdmin || isCompanyAdmin || modules.contains(module);

  Future<void> loadSession() async {
    final prefs = await SharedPreferences.getInstance();
    token = prefs.getString(_kToken);
    role = prefs.getString(_kRole);
    companyId = prefs.getInt(_kCompanyId);
    fullName = prefs.getString(_kFullName);
    modules = prefs.getStringList(_kModules) ?? const [];
  }

  /// Re-reads the session's departments from the server. Called on app
  /// start so permissions an admin changed while the user was signed in
  /// reshape the menu without forcing them to sign out and back in --
  /// the JWT deliberately carries no module list.
  Future<void> refreshPermissions() async {
    if (!isLoggedIn) return;
    try {
      final me = await ApiService.instance.getOne('/api/auth/me');
      modules = (me['modules'] as List<dynamic>).cast<String>();
      role = me['role'] as String;
      await (await SharedPreferences.getInstance()).setStringList(_kModules, modules);
      notifyListeners();
    } catch (_) {
      // Offline or a dead token -- keep the cached menu. A dead token is
      // already handled by ApiService, which logs the user out on 401.
    }
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
    modules = ((data['modules'] as List<dynamic>?) ?? const []).cast<String>();

    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_kToken, token!);
    await prefs.setString(_kRole, role!);
    if (companyId != null) {
      await prefs.setInt(_kCompanyId, companyId!);
    } else {
      await prefs.remove(_kCompanyId);
    }
    await prefs.setString(_kFullName, fullName!);
    await prefs.setStringList(_kModules, modules);

    notifyListeners();
  }

  Future<void> logout() async {
    token = null;
    role = null;
    companyId = null;
    fullName = null;
    modules = const [];

    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_kToken);
    await prefs.remove(_kRole);
    await prefs.remove(_kCompanyId);
    await prefs.remove(_kFullName);
    await prefs.remove(_kModules);

    notifyListeners();
  }
}
