import 'package:flutter/services.dart';

class AppInfo {
  const AppInfo({required this.label, this.iconBytes});

  final String label;
  final Uint8List? iconBytes;
}

abstract final class AppInfoService {
  static const _channel = MethodChannel('dream_force/device_settings');
  static final Map<String, AppInfo> _cache = {};
  static final Map<String, Future<AppInfo>> _inFlight = {};

  static Future<AppInfo> getAppInfo(
    String packageName, {
    String? fallbackLabel,
  }) {
    final cached = _cache[packageName];
    if (cached != null) return Future.value(cached);
    final existing = _inFlight[packageName];
    if (existing != null) return existing;

    final request = _load(packageName, fallbackLabel);
    _inFlight[packageName] = request;
    return request.whenComplete(() => _inFlight.remove(packageName));
  }

  static Future<AppInfo> _load(
    String packageName,
    String? fallbackLabel,
  ) async {
    try {
      final result = await _channel.invokeMapMethod<String, dynamic>(
        'getAppInfo',
        {'packageName': packageName},
      );
      final bytes = result?['iconPng'];
      final info = AppInfo(
        label: result?['label'] as String? ?? fallbackLabel ?? packageName,
        iconBytes: bytes is Uint8List ? bytes : null,
      );
      _cache[packageName] = info;
      return info;
    } catch (_) {
      final info = AppInfo(label: fallbackLabel ?? packageName);
      _cache[packageName] = info;
      return info;
    }
  }
}
