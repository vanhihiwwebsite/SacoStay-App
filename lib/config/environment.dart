import 'dart:io';

import 'package:flutter/foundation.dart';

/// API URLs — mirror Angular `environment*.ts`.
class Environment {
  Environment._();

  static const productionApiUrl = 'https://api.sacostay.id.vn/api';
  static const productionHubUrl = 'https://api.sacostay.id.vn/chatHub';

  static const devApiHost = '5219';
  static const devHubPath = '/chatHub';

  /// `false` = local dev API; `true` = production (default for emulator without local BE).
  static bool useProduction = true;

  static String get environmentName => useProduction ? 'production' : 'development';

  static String get apiUrl {
    if (useProduction) return productionApiUrl;
    if (!kIsWeb && Platform.isAndroid) {
      return 'http://10.0.2.2:$devApiHost/api';
    }
    return 'http://localhost:$devApiHost/api';
  }

  static String get chatHubUrl {
    if (useProduction) return productionHubUrl;
    if (!kIsWeb && Platform.isAndroid) {
      return 'http://10.0.2.2:$devApiHost$devHubPath';
    }
    return 'http://localhost:$devApiHost$devHubPath';
  }
}
