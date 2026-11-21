import 'package:flutter/services.dart';

import 'package:dream_force/core/platform/session_notice.dart';
import 'package:dream_force/core/platform/plan_reminder.dart';

abstract final class SessionMedia {
  static const _channel = MethodChannel('dream_force/session_media');

  static void setTransportHandler(
    Future<void> Function(String action)? handler,
  ) {
    _channel.setMethodCallHandler((call) async {
      if (call.method == 'onTransport' && handler != null) {
        final action = call.arguments;
        if (action is String) await handler(action);
      }
    });
  }

  static Future<bool> hasNotificationPermission() async {
    try {
      return await _channel.invokeMethod<bool>('hasNotificationPermission') ??
          false;
    } on MissingPluginException {
      return false;
    } on PlatformException {
      return false;
    }
  }

  static Future<bool> requestNotificationPermission() async {
    try {
      return await _channel.invokeMethod<bool>(
            'requestNotificationPermission',
          ) ??
          false;
    } on MissingPluginException {
      return false;
    } on PlatformException {
      return false;
    }
  }

  static Future<void> update({
    required String title,
    required String subtitle,
    required int positionMs,
    required int durationMs,
    required bool playing,
  }) async {
    try {
      await _channel.invokeMethod<void>('update', {
        'title': title,
        'subtitle': subtitle,
        'positionMs': positionMs,
        'durationMs': durationMs,
        'playing': playing,
      });
    } on MissingPluginException {
      // Tests and non-Android targets have no media session.
    } on PlatformException {
      // A denied notification permission must not stop the in-app timer.
    }
  }

  static Future<void> hide() async {
    try {
      await _channel.invokeMethod<void>('hide');
    } on MissingPluginException {
      return;
    } on PlatformException {
      return;
    }
  }

  static Future<void> alert(SessionNotice notice) async {
    try {
      await _channel.invokeMethod<void>('alert', {
        'title': notice.title,
        'body': notice.body,
      });
    } on MissingPluginException {
      return;
    } on PlatformException {
      return;
    }
  }

  static Future<void> schedulePlanReminders(
    List<PlanReminder> reminders,
  ) async {
    try {
      await _channel.invokeMethod<void>('schedulePlanReminders', {
        'reminders': [
          for (final reminder in reminders)
            {
              'id': reminder.id,
              'title': reminder.title,
              'atMillis': reminder.at.millisecondsSinceEpoch,
            },
        ],
      });
    } on MissingPluginException {
      return;
    } on PlatformException {
      return;
    }
  }
}
