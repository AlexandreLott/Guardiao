import 'dart:convert';
import 'dart:io';

import 'package:flutter/services.dart';
import 'package:guardiao_core/guardiao_core.dart';

/// Lê informações do aparelho onde o app do filho está instalado.
abstract class InstalledAppsSource {
  DevicePlatform get platform;

  /// Nome amigável do aparelho (modelo do celular, nome do computador).
  Future<String> deviceName();

  /// Aplicativos que o usuário abre pelo menu/ícone.
  Future<List<InstalledApp>> list();

  /// Escolhe a implementação certa para o sistema em que o app está rodando.
  factory InstalledAppsSource.detect() {
    if (Platform.isAndroid) return AndroidAppsSource();
    if (Platform.isWindows) return WindowsAppsSource();
    return DemoAppsSource();
  }
}

// ---------------------------------------------------------------- Android

/// Usa o PackageManager por um canal de plataforma (veja MainActivity.kt).
/// Só aparecem apps com ícone de lançamento, como no menu do celular.
class AndroidAppsSource implements InstalledAppsSource {
  AndroidAppsSource([MethodChannel? channel])
    : _channel = channel ?? const MethodChannel('br.edu.guardiaogamer/device');

  final MethodChannel _channel;

  @override
  DevicePlatform get platform => DevicePlatform.android;

  @override
  Future<String> deviceName() async {
    final name = (await _channel.invokeMethod<String>('deviceName'))?.trim();
    return (name == null || name.isEmpty) ? 'Celular Android' : name;
  }

  @override
  Future<List<InstalledApp>> list() async {
    final raw = await _channel.invokeListMethod<Map<Object?, Object?>>(
      'listInstalledApps',
    );
    return parseAndroidApps(raw ?? const []);
  }
}

/// Converte a resposta do canal em modelos, sem repetições e sem o próprio app.
List<InstalledApp> parseAndroidApps(
  List<Map<Object?, Object?>> raw, {
  String ownPackage = 'br.edu.guardiaogamer.guardiao',
}) {
  final byPackage = <String, InstalledApp>{};
  for (final item in raw) {
    final pkg = (item['packageName'] as String?)?.trim();
    if (pkg == null || pkg.isEmpty || pkg == ownPackage) continue;
    final name = (item['name'] as String?)?.trim();
    byPackage[pkg] = InstalledApp(
      id: safeId(pkg),
      name: (name == null || name.isEmpty) ? pkg : name,
      packageName: pkg,
    );
  }
  return byPackage.values.toList();
}

// ---------------------------------------------------------------- Windows

/// Lê os programas instalados no registro do Windows (chaves "Uninstall").
class WindowsAppsSource implements InstalledAppsSource {
  WindowsAppsSource({
    Future<ProcessResult> Function(String, List<String>)? runner,
  }) : _run = runner ?? Process.run;

  final Future<ProcessResult> Function(String, List<String>) _run;

  @override
  DevicePlatform get platform => DevicePlatform.windows;

  @override
  Future<String> deviceName() async {
    final host = Platform.localHostname.trim();
    return host.isEmpty ? 'Computador Windows' : host;
  }

  static const _script = r'''
[Console]::OutputEncoding = [System.Text.Encoding]::UTF8
$paths = 'HKLM:\Software\Microsoft\Windows\CurrentVersion\Uninstall\*',
         'HKLM:\Software\WOW6432Node\Microsoft\Windows\CurrentVersion\Uninstall\*',
         'HKCU:\Software\Microsoft\Windows\CurrentVersion\Uninstall\*'
Get-ItemProperty $paths -ErrorAction SilentlyContinue |
  Where-Object { $_.DisplayName -and -not $_.SystemComponent -and -not $_.ParentKeyName } |
  Select-Object @{n='key';e={$_.PSChildName}}, DisplayName, Publisher, DisplayIcon |
  ConvertTo-Json -Compress
''';

  @override
  Future<List<InstalledApp>> list() async {
    final result = await _run('powershell', [
      '-NoProfile',
      '-NonInteractive',
      '-ExecutionPolicy',
      'Bypass',
      '-Command',
      _script,
    ]);
    if (result.exitCode != 0) {
      throw StateError(
        'Não foi possível ler os programas instalados (${result.exitCode}).',
      );
    }
    return parseWindowsPrograms(result.stdout.toString());
  }
}

/// Converte o JSON do PowerShell (um objeto ou uma lista) em modelos.
List<InstalledApp> parseWindowsPrograms(String json) {
  final text = json.trim();
  if (text.isEmpty) return const [];
  final decoded = jsonDecode(text);
  final items = decoded is List ? decoded : [decoded];
  final byName = <String, InstalledApp>{};
  for (final item in items) {
    if (item is! Map) continue;
    final name = (item['DisplayName'] as String?)?.trim();
    final key = (item['key'] as String?)?.trim();
    if (name == null || name.isEmpty || key == null || key.isEmpty) continue;
    if (_isNoise(name)) continue;
    byName.putIfAbsent(
      name.toLowerCase(),
      () => InstalledApp(
        id: safeId('win:$key'),
        name: name,
        packageName: _executableFromIcon(item['DisplayIcon'] as String?),
      ),
    );
  }
  return byName.values.toList();
}

/// Atualizações e redistribuíveis aparecem no registro mas não são "apps".
bool _isNoise(String name) {
  final n = name.toLowerCase();
  return n.startsWith('update for ') ||
      n.startsWith('security update') ||
      n.startsWith('hotfix') ||
      n.contains('redistributable') ||
      n.startsWith('microsoft visual c++') ||
      n.startsWith('microsoft .net');
}

/// `"C:\Games\Roblox\RobloxPlayer.exe",0` -> `RobloxPlayer.exe`.
String? _executableFromIcon(String? icon) {
  if (icon == null) return null;
  var path = icon.trim();
  if (path.startsWith('"')) {
    final end = path.indexOf('"', 1);
    path = end > 0 ? path.substring(1, end) : path.substring(1);
  } else {
    final comma = path.lastIndexOf(',');
    if (comma > 0) path = path.substring(0, comma);
  }
  final file = path.split(RegExp(r'[\\/]')).last.trim();
  return file.toLowerCase().endsWith('.exe') ? file : null;
}

// ------------------------------------------------------------- Demonstração

/// Usada em testes e em sistemas sem leitura real (por exemplo, Linux).
class DemoAppsSource implements InstalledAppsSource {
  @override
  DevicePlatform get platform => DevicePlatform.other;

  @override
  Future<String> deviceName() async => 'Aparelho de demonstração';

  @override
  Future<List<InstalledApp>> list() async => const [
    InstalledApp(id: 'demo.roblox', name: 'Roblox'),
    InstalledApp(id: 'demo.minecraft', name: 'Minecraft'),
    InstalledApp(id: 'demo.freefire', name: 'Free Fire'),
    InstalledApp(id: 'demo.chrome', name: 'Chrome'),
  ];
}
