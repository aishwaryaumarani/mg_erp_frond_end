/// Backend base URL.
///
/// - A real device on the same Wi-Fi as the dev machine (and web/desktop
///   too): the machine's LAN IP, e.g. "http://192.168.1.26:8000". The
///   backend must be started with --host 0.0.0.0 to accept it.
/// - Android emulator talking to a backend on your host machine:
///   use "http://10.0.2.2:8000" instead (10.0.2.2 is the emulator's
///   alias for the host's localhost).
/// - A deployed backend: put the deployed URL here, e.g.
///   "https://mg-chemicals-api.example.com".
///
/// Override at build/run time without editing this file:
///   flutter run --dart-define=API_BASE_URL=http://10.0.2.2:8000
class ApiConfig {
  static const String baseUrl = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: 'http://127.0.0.1:8000',
  );
}
