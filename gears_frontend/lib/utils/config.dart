import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:device_info_plus/device_info_plus.dart';

const int flaskPort = 5001;
const String pcLanIp = "10.181.116.8";

String? _cachedBaseUrl;

String get baseUrl => _cachedBaseUrl ?? "http://10.0.2.2:$flaskPort";

Future<void> initBaseUrl() async {
  // 🌐 WEB
  if (kIsWeb) {
    _cachedBaseUrl = "http://localhost:$flaskPort";
    return;
  }

  // 📱 ANDROID
  if (defaultTargetPlatform == TargetPlatform.android) {
    final androidInfo = await DeviceInfoPlugin().androidInfo;
    final bool isEmulator = !androidInfo.isPhysicalDevice;

    if (isEmulator) {
      _cachedBaseUrl = "http://10.0.2.2:$flaskPort";
    } else {
      _cachedBaseUrl = "http://$pcLanIp:$flaskPort";
    }

    print("[CONFIG] Using baseUrl: $_cachedBaseUrl");
    return;
  }

  // 🍎 iOS Simulator
  if (defaultTargetPlatform == TargetPlatform.iOS) {
    _cachedBaseUrl = "http://127.0.0.1:$flaskPort";
    return;
  }

  // 🖥 Desktop fallback
  _cachedBaseUrl = "http://localhost:$flaskPort";
}

Future<bool> checkFlaskConnection() async {
  try {
    final uri = Uri.parse("$baseUrl/test-supabase");
    final client = HttpClient();
    client.connectionTimeout = const Duration(seconds: 5);
    final request = await client.getUrl(uri);
    final response = await request.close();
    client.close();
    return response.statusCode == 200;
  } catch (e) {
    print("[CONFIG] Flask connection check failed: $e");
    return false;
  }
}