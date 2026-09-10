import 'dart:convert';
import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:http/http.dart' as http;
import '../config/api_config.dart';
import 'auth_service.dart';

/// Thrown when the backend returns a non-2xx response. Carries the
/// backend's `detail` message (FastAPI/HTTPException convention) so
/// screens can show a useful error instead of a generic one.
class ApiException implements Exception {
  final int statusCode;
  final String message;

  /// The parsed `detail` from the response, when the server sent a
  /// structured error. GST failures use {error, message, retryable}, and
  /// the UI branches on that code -- "already generated" is handled very
  /// differently from "the portal is down".
  final dynamic detail;

  ApiException(this.statusCode, this.message, {this.detail});

  /// The machine-readable code, when there is one.
  String? get code => detail is Map ? '${(detail as Map)['error']}' : null;

  @override
  String toString() => message;
}

/// Thin wrapper around the MG Chemicals REST API. Every master module
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
    dynamic detail;
    try {
      final body = jsonDecode(res.body);
      if (body is Map && body['detail'] != null) {
        detail = body['detail'];
        // A structured error carries its own human-readable message;
        // anything else is stringified as before.
        message = detail is Map && detail['message'] != null
            ? '${detail['message']}'
            : detail.toString();
      }
    } catch (_) {
      // response wasn't JSON -- fall back to the generic message
    }
    if (res.statusCode == 401) {
      // Expired/invalid token -- bounce back to the login screen instead
      // of leaving every screen stuck on a dead error.
      AuthService.instance.logout();
    }
    throw ApiException(res.statusCode, message, detail: detail);
  }

  Future<List<dynamic>> list(String path, {Map<String, dynamic>? query}) async {
    final res = await http.get(_uri(path, query), headers: _headers());
    final data = _decode(res);
    return (data as List<dynamic>?) ?? [];
  }

  /// [query] is optional so single-object endpoints that take filters --
  /// the reports, which return one {rows, summary} object for a date
  /// range -- can use this too.
  Future<Map<String, dynamic>> getOne(String path, {Map<String, dynamic>? query}) async {
    final res = await http.get(_uri(path, query), headers: _headers());
    return _decode(res) as Map<String, dynamic>;
  }

  /// Raw bytes rather than JSON -- used for the company logo, which the
  /// server returns as an image.
  Future<Uint8List> getBytes(String path) async {
    final res = await http.get(_uri(path), headers: _headers());
    if (res.statusCode >= 400) {
      throw ApiException(res.statusCode, 'Could not load $path');
    }
    return res.bodyBytes;
  }

  /// Downloads a generated file (Excel/PDF export) and hands the browser
  /// or the OS a Save dialog.
  ///
  /// It cannot be a plain link: every export endpoint is behind the same
  /// Bearer token as the rest of the API, and a link carries no header.
  /// So the bytes are fetched here and saved through file_picker, which
  /// triggers a normal download on web and a save dialog everywhere else.
  ///
  /// The filename comes off the server's Content-Disposition where it is
  /// readable -- it is the name the report gave itself -- and falls back
  /// to [fallbackName], because a cross-origin browser only exposes that
  /// header when the server says it may (the backend does; a proxy in
  /// front of it might not).
  Future<void> download(
    String path, {
    Map<String, dynamic>? query,
    required String fallbackName,
    required String mimeType,
  }) async {
    final res = await http.get(_uri(path, query), headers: _headers());
    if (res.statusCode >= 400) {
      _decode(res); // throws ApiException carrying the server's message
    }
    final disposition = res.headers['content-disposition'] ?? '';
    final match = RegExp(r'filename="?([^";]+)"?').firstMatch(disposition);
    await FilePicker.saveFile(
      fileName: match?.group(1) ?? fallbackName,
      bytes: res.bodyBytes,
      mimeType: mimeType,
    );
  }

  /// Multipart upload -- used to send a supplier's invoice PDF to
  /// /api/purchase-invoices/import/preview. Bytes rather than a file path,
  /// because on web there is no path to give.
  Future<Map<String, dynamic>> uploadFile(
    String path,
    List<int> bytes,
    String filename,
  ) async {
    final request = http.MultipartRequest('POST', _uri(path))
      ..headers.addAll(_headers()..remove('Content-Type'))
      ..files.add(http.MultipartFile.fromBytes('file', bytes, filename: filename));
    final streamed = await request.send();
    final res = await http.Response.fromStream(streamed);
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
