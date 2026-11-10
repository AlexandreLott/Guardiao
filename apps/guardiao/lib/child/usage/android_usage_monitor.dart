import 'dart:convert';

import 'package:flutter/services.dart';

import 'usage_monitor.dart';

/// Conversa com `MonitorService.kt`: o Android conta o uso (UsageStats) e um
/// serviço em primeiro plano cobre o app bloqueado, mesmo com este app fechado.
class AndroidUsageMonitor implements UsageMonitor {
  AndroidUsageMonitor([MethodChannel? channel])
    : _channel = channel ?? const MethodChannel('br.edu.guardiaogamer/monitor');

  final MethodChannel _channel;

  @override
  bool get supported => true;

  @override
  Future<Set<MonitorPermission>> missingPermissions() async {
    final raw =
        await _channel.invokeMapMethod<String, bool>('permissions') ?? const {};
    return {
      if (raw['usageAccess'] != true) MonitorPermission.usageAccess,
      if (raw['overlay'] != true) MonitorPermission.overlay,
      if (raw['notifications'] != true) MonitorPermission.notifications,
    };
  }

  @override
  Future<void> request(MonitorPermission permission) async {
    switch (permission) {
      case MonitorPermission.usageAccess:
        await _channel.invokeMethod<void>('openUsageAccessSettings');
      case MonitorPermission.overlay:
        await _channel.invokeMethod<void>('openOverlaySettings');
      case MonitorPermission.notifications:
        await _channel.invokeMethod<bool>('requestNotifications');
    }
  }

  @override
  Future<void> start(
    List<MonitoredApp> apps, {
    MonitorExtras extras = const MonitorExtras(),
  }) => _channel.invokeMethod<void>('start', {
    'apps': jsonEncode({
      'apps': [for (final a in apps) a.toJson()],
      ...extras.toJson(),
    }),
  });

  @override
  Future<String?> takeLaunchTab() =>
      _channel.invokeMethod<String>('takeLaunchTab');

  @override
  Future<Map<String, int>> usageByKey() async =>
      await _channel.invokeMapMethod<String, int>('usageToday') ?? const {};

  @override
  Future<void> stop() => _channel.invokeMethod<void>('stop');

  @override
  Future<bool?> adminActive() => _channel.invokeMethod<bool>('adminActive');

  @override
  Future<void> requestAdmin() => _channel.invokeMethod<void>('requestAdmin');
}
