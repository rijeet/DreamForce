import 'package:flutter/services.dart';

abstract final class DeviceSettings {
  static const _channel = MethodChannel('dream_force/device_settings');
  static Future<void> openUsageAccessSettings() =>
      _channel.invokeMethod<void>('openUsageAccessSettings');
  static Future<void> openNotificationSettings() =>
      _channel.invokeMethod<void>('openNotificationSettings');

  static Future<bool> hasUsageAccess() async =>
      await _channel.invokeMethod<bool>('hasUsageAccess') ?? false;

  static Future<ScreenTimeSummary> getTodayScreenTime() async {
    final result = await _channel.invokeMapMethod<String, dynamic>(
      'getTodayScreenTime',
    );
    final data = result ?? const <String, dynamic>{};
    final apps = (data['apps'] as List<dynamic>? ?? const [])
        .whereType<Map<dynamic, dynamic>>()
        .map(
          (app) => ScreenTimeApp(
            packageName: app['packageName'] as String? ?? 'Unknown app',
            duration: Duration(milliseconds: app['durationMillis'] as int? ?? 0),
          ),
        )
        .toList(growable: false);
    return ScreenTimeSummary(
      hasPermission: data['hasPermission'] as bool? ?? false,
      total: Duration(milliseconds: data['totalMillis'] as int? ?? 0),
      apps: apps,
    );
  }
}

class ScreenTimeSummary {
  const ScreenTimeSummary({
    required this.hasPermission,
    required this.total,
    required this.apps,
  });
  final bool hasPermission;
  final Duration total;
  final List<ScreenTimeApp> apps;
}

class ScreenTimeApp {
  const ScreenTimeApp({required this.packageName, required this.duration});
  final String packageName;
  final Duration duration;
}
