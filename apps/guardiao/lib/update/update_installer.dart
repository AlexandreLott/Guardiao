import 'dart:async';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:flutter/services.dart';

import 'update_models.dart';

/// Baixa e instala uma nova versão do app. No Android o próprio sistema abre a
/// tela "Atualizar este app?" e a pessoa confirma com um toque (o Android não
/// deixa nenhum app se atualizar em silêncio).
abstract class UpdateInstaller {
  /// Falso onde não dá para atualizar de dentro do app (Windows).
  bool get supported;

  /// Número da versão instalada (`versionCode`).
  Future<int> currentBuild();

  /// Nome da versão instalada, como "0.1.0".
  Future<String> currentName();

  /// Baixa o APK para uma pasta temporária e confere o tamanho e a soma
  /// SHA-256 quando conhecidos. [onProgress] recebe de 0 a 1 (ou `null` se o
  /// tamanho é desconhecido).
  Future<File> download(AppUpdate update, void Function(double? p) onProgress);

  /// Se o app já pode instalar APKs ("Instalar apps desconhecidos").
  Future<bool> canInstall();

  /// Abre a tela do sistema para liberar a instalação por este app.
  Future<void> openInstallSettings();

  /// Abre o instalador do sistema com o APK baixado.
  Future<void> install(File apk);

  factory UpdateInstaller.detect() => Platform.isAndroid
      ? AndroidUpdateInstaller()
      : UnsupportedUpdateInstaller();
}

class UnsupportedUpdateInstaller implements UpdateInstaller {
  @override
  bool get supported => false;
  @override
  Future<int> currentBuild() async => 0;
  @override
  Future<String> currentName() async => '';
  @override
  Future<File> download(
    AppUpdate update,
    void Function(double? p) onProgress,
  ) => throw UnsupportedError('Atualização não disponível neste sistema.');
  @override
  Future<bool> canInstall() async => false;
  @override
  Future<void> openInstallSettings() async {}
  @override
  Future<void> install(File apk) async {}
}

/// Usa `UpdateChannel` em `MainActivity.kt` (versão, pasta, permissão e
/// instalador) e baixa o arquivo pelo próprio Dart.
class AndroidUpdateInstaller implements UpdateInstaller {
  AndroidUpdateInstaller([MethodChannel? channel, HttpClient? client])
    : _channel = channel ?? const MethodChannel('br.edu.guardiaogamer/update'),
      _client = client ?? HttpClient();

  final MethodChannel _channel;
  final HttpClient _client;

  @override
  bool get supported => true;

  Future<Map<String, Object?>> _version() async =>
      (await _channel.invokeMapMethod<String, Object?>('version')) ?? const {};

  @override
  Future<int> currentBuild() async =>
      ((await _version())['versionCode'] as num?)?.toInt() ?? 0;

  @override
  Future<String> currentName() async =>
      ((await _version())['versionName'] as String?) ?? '';

  @override
  Future<File> download(
    AppUpdate update,
    void Function(double? p) onProgress,
  ) async {
    final dir = await _channel.invokeMethod<String>('updateDir');
    if (dir == null) throw const FileSystemException('Sem pasta para baixar.');
    final target = File('$dir/guardiao-gamer-${update.build}.apk');
    if (await target.exists()) await target.delete();

    final request = await _client.getUrl(Uri.parse(update.apkUrl));
    request.headers.set('User-Agent', 'guardiao-gamer-app');
    final response = await request.close();
    if (response.statusCode != 200) {
      await response.drain<void>();
      throw HttpException('O download falhou (código ${response.statusCode}).');
    }
    final total = response.contentLength > 0
        ? response.contentLength
        : update.sizeBytes;
    final sink = target.openWrite();
    var received = 0;
    try {
      await for (final chunk in response) {
        sink.add(chunk);
        received += chunk.length;
        onProgress(total == null || total <= 0 ? null : received / total);
      }
    } finally {
      await sink.close();
    }
    await _verify(target, update);
    return target;
  }

  Future<void> _verify(File file, AppUpdate update) async {
    final size = update.sizeBytes;
    if (size != null && await file.length() != size) {
      await file.delete();
      throw const FormatException('O arquivo baixado veio incompleto.');
    }
    final expected = update.sha256;
    if (expected != null) {
      final digest = await sha256.bind(file.openRead()).first;
      if (digest.toString() != expected) {
        await file.delete();
        throw const FormatException('O arquivo baixado não confere (SHA-256).');
      }
    }
  }

  @override
  Future<bool> canInstall() async =>
      (await _channel.invokeMethod<bool>('canInstall')) ?? false;

  @override
  Future<void> openInstallSettings() =>
      _channel.invokeMethod<void>('openInstallSettings');

  @override
  Future<void> install(File apk) =>
      _channel.invokeMethod<void>('install', {'path': apk.path});
}

/// Instalador de mentira para testes.
class FakeUpdateInstaller implements UpdateInstaller {
  FakeUpdateInstaller({
    this.build = 1,
    this.name = '0.1.0',
    this.allowed = true,
    this.failDownload = false,
  });

  int build;
  String name;
  bool allowed;
  bool failDownload;
  int downloads = 0;
  int installs = 0;
  int settingsOpened = 0;
  File? installed;

  @override
  bool get supported => true;
  @override
  Future<int> currentBuild() async => build;
  @override
  Future<String> currentName() async => name;

  @override
  Future<File> download(
    AppUpdate update,
    void Function(double? p) onProgress,
  ) async {
    downloads++;
    if (failDownload) throw const HttpException('sem rede');
    onProgress(0.5);
    onProgress(1);
    return File('/tmp/guardiao-gamer-${update.build}.apk');
  }

  @override
  Future<bool> canInstall() async => allowed;
  @override
  Future<void> openInstallSettings() async => settingsOpened++;
  @override
  Future<void> install(File apk) async {
    installs++;
    installed = apk;
  }
}
