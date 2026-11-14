import 'package:flutter/services.dart';

abstract final class DeviceSettings {
  static const _channel = MethodChannel('dream_force/device_settings');
  static Future<void> openUsageAccessSettings() =>
      _channel.invokeMethod<void>('openUsageAccessSettings');
  static Future<void> openNotificationSettings() =>
      _channel.invokeMethod<void>('openNotificationSettings');

  static Future<bool> hasUsageAccess() async =>
      await _channel.invokeMethod<bool>('hasUsageAccess') ?? false;

  static Future<String> getDeviceTimezone() async =>
      await _channel.invokeMethod<String>('getDeviceTimezone') ?? 'UTC';

  static Future<ScreenTimeSummary> getScreenTime(String period) async {
    final result = await _channel.invokeMapMethod<String, dynamic>(
      'getScreenTime',
      {'period': period},
    );
    final data = result ?? const <String, dynamic>{};
    final apps = (data['apps'] as List<dynamic>? ?? const [])
        .whereType<Map<dynamic, dynamic>>()
        .map(
          (app) => ScreenTimeApp(
            packageName: app['packageName'] as String? ?? 'Unknown app',
            duration: Duration(
              milliseconds: app['durationMillis'] as int? ?? 0,
            ),
          ),
        )
        .toList(growable: false);
    final dailyUsage = (data['dailyUsage'] as List<dynamic>? ?? const [])
        .whereType<Map<dynamic, dynamic>>()
        .map((day) {
          final dayApps = (day['apps'] as List<dynamic>? ?? const [])
              .whereType<Map<dynamic, dynamic>>()
              .map(
                (app) => ScreenTimeUsage(
                  packageName: app['packageName'] as String? ?? 'unknown',
                  appLabel:
                      app['appLabel'] as String? ??
                      app['packageName'] as String? ??
                      'Unknown app',
                  usageSeconds: app['usageSeconds'] as int? ?? 0,
                ),
              )
              .toList(growable: false);
          return ScreenTimeDay(
            localDate: day['localDate'] as String? ?? '',
            apps: dayApps,
          );
        })
        .toList(growable: false);
    final queriedAtMillis = data['queriedAtMillis'] as int?;
    return ScreenTimeSummary(
      hasPermission: data['hasPermission'] as bool? ?? false,
      total: Duration(milliseconds: data['totalMillis'] as int? ?? 0),
      apps: apps,
      dailyUsage: dailyUsage,
      timezoneId: data['timezoneId'] as String? ?? 'UTC',
      queriedAt: queriedAtMillis == null
          ? null
          : DateTime.fromMillisecondsSinceEpoch(queriedAtMillis)
                .toUtc()
                .toIso8601String(),
    );
  }
}

class ScreenTimeSummary {
  const ScreenTimeSummary({
    required this.hasPermission,
    required this.total,
    required this.apps,
    this.dailyUsage = const [],
    this.timezoneId = 'UTC',
    this.queriedAt,
  });
  final bool hasPermission;
  final Duration total;
  final List<ScreenTimeApp> apps;
  final List<ScreenTimeDay> dailyUsage;
  final String timezoneId;
  final String? queriedAt;
}

class ScreenTimeDay {
  const ScreenTimeDay({required this.localDate, required this.apps});
  final String localDate;
  final List<ScreenTimeUsage> apps;
}

class ScreenTimeUsage {
  const ScreenTimeUsage({
    required this.packageName,
    required this.appLabel,
    required this.usageSeconds,
  });
  final String packageName;
  final String appLabel;
  final int usageSeconds;
}

class ScreenTimeApp {
  const ScreenTimeApp({required this.packageName, required this.duration});
  final String packageName;
  final Duration duration;
}
