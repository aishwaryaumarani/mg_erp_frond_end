import 'dart:convert';
import 'package:http/http.dart' as http;
import '../config/api_config.dart';
import 'auth_service.dart';

/// Thrown when the backend returns a non-2xx response. Carries the
/// backend's `detail` message (FastAPI/HTTPException convention) so
/// screens can show a useful error instead of a generic one.
class ApiException implements Exception {
  final int statusCode;
  final String message;
  ApiException(this.statusCode, this.message);

  @override
  String toString() => message;
}

/// Thin wrapper around the Mini ERP REST API. Every master module
/// (Products, Categories, Brands, Units, Taxes, Price Lists,
/// Customers, Suppliers) is CRUD over a resource path, so this one
/// class covers all of Phase 1. Later phases (Sales/Purchase/
/// Inventory/Accounts) can add their own resource-specific methods
/// here following the same pattern.
class ApiService {
  static final ApiService instance = ApiService._();
  ApiService._();

  Uri _uri(String path, [Map<String, dynamic>? query]) {
    final cleanQuery = <String, String>{};
    query?.forEach((k, v) {
      if (v != null && v.toString().isNotEmpty) cleanQuery[k] = v.toString();
    });
    return Uri.parse('${ApiConfig.baseUrl}$path').replace(
      queryParameters: cleanQuery.isEmpty ? null : cleanQuery,
    );
  }

  /// Every authenticated endpoint requires this (see backend/app/core/
  /// security.py's get_current_user) -- login itself doesn't need it,
  /// but sending a null-less header there is harmless since there's no
  /// token yet.
  Map<String, String> _headers() {
    final headers = {'Content-Type': 'application/json'};
    final token = AuthService.instance.token;
    if (token != null) headers['Authorization'] = 'Bearer $token';
    return headers;
  }

  dynamic _decode(http.Response res) {
    if (res.statusCode >= 200 && res.statusCode < 300) {
      if (res.body.isEmpty) return null;
      return jsonDecode(res.body);
    }
    String message = 'Request failed (${res.statusCode})';
    try {
      final body = jsonDecode(res.body);
      if (body is Map && body['detail'] != null) {
        message = body['detail'].toString();
      }
    } catch (_) {
      // response wasn't JSON -- fall back to the generic message
    }
    if (res.statusCode == 401) {
      // Expired/invalid token -- bounce back to the login screen instead
      // of leaving every screen stuck on a dead error.
      AuthService.instance.logout();
    }
    throw ApiException(res.statusCode, message);
  }

  Future<List<dynamic>> list(String path, {Map<String, dynamic>? query}) async {
    final res = await http.get(_uri(path, query), headers: _headers());
    final data = _decode(res);
    return (data as List<dynamic>?) ?? [];
  }

  Future<Map<String, dynamic>> getOne(String path) async {
    final res = await http.get(_uri(path), headers: _headers());
    return _decode(res) as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> create(String path, Map<String, dynamic> body) async {
    final res = await http.post(
      _uri(path),
      headers: _headers(),
      body: jsonEncode(body),
    );
    return _decode(res) as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> update(String path, Map<String, dynamic> body) async {
    final res = await http.put(
      _uri(path),
      headers: _headers(),
      body: jsonEncode(body),
    );
    return _decode(res) as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> patch(String path, Map<String, dynamic> body) async {
    final res = await http.patch(
      _uri(path),
      headers: _headers(),
      body: jsonEncode(body),
    );
    return _decode(res) as Map<String, dynamic>;
  }

  Future<void> delete(String path) async {
    final res = await http.delete(_uri(path), headers: _headers());
    _decode(res);
  }
}
