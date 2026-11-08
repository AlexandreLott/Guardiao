import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:guardiao/app.dart';
import 'package:guardiao/child/platform/installed_apps_source.dart';
import 'package:guardiao/child/usage/usage_monitor.dart';
import 'package:guardiao/nearby/nearby.dart';
import 'package:guardiao/role/role.dart';
import 'package:guardiao_core/guardiao_core.dart';

/// Abre o app inteiro já na função indicada (ou na tela de escolha, se `null`).
Widget appFor(
  GuardianBackend backend, {
  DeviceRole? role,
  RoleStore? store,
  InstalledAppsSource? source,
  NearbyPairing? nearby,
  UsageMonitor? monitor,
  bool isDemo = false,
}) =>
    GuardiaoApp(
      backend: backend,
      roleStore: store ?? MemoryRoleStore(role),
      source: source ?? DemoAppsSource(),
      nearby: nearby ?? UnsupportedNearby(),
      monitor: monitor ?? UnsupportedUsageMonitor(),
      initialRole: role,
      isDemo: isDemo,
    );

/// Desmonta a árvore para cancelar os temporizadores da sincronização.
Future<void> closeApp(WidgetTester tester) async =>
    tester.pumpWidget(const SizedBox());
