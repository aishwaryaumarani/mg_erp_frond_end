/// Backend base URL.
///
/// - Web / desktop / iOS simulator running against a locally-started
///   backend: keep "http://127.0.0.1:8000".
/// - Android emulator talking to a backend on your host machine:
///   use "http://10.0.2.2:8000" instead (10.0.2.2 is the emulator's
///   alias for the host's localhost).
/// - A real device or a deployed backend: put the machine's LAN IP or
///   the deployed URL here, e.g. "http://192.168.1.20:8000" or
///   "https://mini-erp-api.example.com".
///
/// Override at build/run time without editing this file:
///   flutter run --dart-define=API_BASE_URL=http://10.0.2.2:8000
class ApiConfig {
  static const String baseUrl = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: 'http://127.0.0.1:8000',
  );
}
