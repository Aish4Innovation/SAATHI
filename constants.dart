import 'package:flutter/foundation.dart' show kIsWeb;

class AppConfig {
  static const String _emulatorUrl = 'http://10.0.2.2:3000';
  static const String _webUrl = 'http://localhost:3000';

  static String get apiUrl {
    if (kIsWeb) {
      return _webUrl;
    } else {
      // For mobile emulators (Android/iOS)
      return _emulatorUrl;
    }
  }
}