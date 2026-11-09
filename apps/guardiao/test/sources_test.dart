import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:guardiao/child/platform/installed_apps_source.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Android', () {
    test(
      'converte a resposta do canal e ignora duplicados e o próprio app',
      () {
        final apps = parseAndroidApps([
          {'packageName': 'com.roblox.client', 'name': 'Roblox'},
          {'packageName': 'com.roblox.client', 'name': 'Roblox'},
          {'packageName': 'br.edu.guardiaogamer.guardiao', 'name': 'Guardião'},
          {'packageName': 'com.sem.nome', 'name': ''},
          {'packageName': '', 'name': 'Vazio'},
          {'name': 'Sem pacote'},
        ]);
        expect(apps.map((a) => a.id), ['com.roblox.client', 'com.sem.nome']);
        expect(apps.last.name, 'com.sem.nome');
        expect(apps.first.packageName, 'com.roblox.client');
      },
    );

    test('guarda o ícone só quando é um texto de tamanho razoável', () {
      final apps = parseAndroidApps([
        {'packageName': 'com.a', 'name': 'A', 'icon': 'AAAA'},
        {'packageName': 'com.b', 'name': 'B', 'icon': ''},
        {'packageName': 'com.c', 'name': 'C', 'icon': 'x' * 50000},
        {'packageName': 'com.d', 'name': 'D'},
      ]);
      expect(apps.map((a) => a.icon), ['AAAA', null, null, null]);
    });

    test('lê o canal de plataforma', () async {
      const channel = MethodChannel('br.edu.guardiaogamer/device');
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, (call) async {
            if (call.method == 'listInstalledApps') {
              return [
                {'packageName': 'com.mojang.minecraftpe', 'name': 'Minecraft'},
              ];
            }
            if (call.method == 'deviceName') return '  Samsung Galaxy A15 ';
            return null;
          });
      final source = AndroidAppsSource(channel);
      expect((await source.list()).single.name, 'Minecraft');
      expect(await source.deviceName(), 'Samsung Galaxy A15');
    });
  });

  group('Windows', () {
    const json =
        '['
        '{"key":"{ABC-1}","DisplayName":"Roblox Player","Publisher":"Roblox","DisplayIcon":"\\"C:\\\\Games\\\\Roblox\\\\RobloxPlayerBeta.exe\\",0"},'
        '{"key":"Minecraft Launcher","DisplayName":"Minecraft Launcher","DisplayIcon":"C:\\\\MC\\\\launcher.exe,0"},'
        '{"key":"KB5","DisplayName":"Update for Windows 11 (KB5)"},'
        '{"key":"vc","DisplayName":"Microsoft Visual C++ 2015-2022 Redistributable (x64)"},'
        '{"key":"dup","DisplayName":"roblox player"},'
        '{"key":"semicone","DisplayName":"Steam"}'
        ']';

    test('lê programas, remove ruído e duplicados e extrai o executável', () {
      final apps = parseWindowsPrograms(json);
      expect(apps.map((a) => a.name), [
        'Roblox Player',
        'Minecraft Launcher',
        'Steam',
      ]);
      expect(apps[0].packageName, 'RobloxPlayerBeta.exe');
      expect(apps[1].packageName, 'launcher.exe');
      expect(apps[2].packageName, isNull);
      expect(apps[0].id, startsWith('win:'));
      expect(apps[0].id.contains('/'), isFalse);
    });

    test('aceita um único objeto (o PowerShell não usa lista com 1 item)', () {
      final apps = parseWindowsPrograms('{"key":"k","DisplayName":"Steam"}');
      expect(apps.single.name, 'Steam');
    });

    test('saída vazia vira lista vazia', () {
      expect(parseWindowsPrograms('  \n'), isEmpty);
    });

    test('falha do PowerShell vira erro claro', () async {
      final source = WindowsAppsSource(
        runner: (_, _) async => ProcessResult(0, 1, '', 'x'),
      );
      expect(source.list(), throwsA(isA<StateError>()));
    });

    test('usa o PowerShell sem perfil e devolve a lista', () async {
      List<String>? args;
      final source = WindowsAppsSource(
        runner: (exe, a) async {
          args = a;
          return ProcessResult(0, 0, json, '');
        },
      );
      expect(await source.list(), hasLength(3));
      expect(args, containsAll(['-NoProfile', '-NonInteractive']));
    });
  });
}
