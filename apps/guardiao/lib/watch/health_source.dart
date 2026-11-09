import 'dart:convert';
import 'dart:io';

import 'package:flutter/services.dart';
import 'package:guardiao_core/guardiao_core.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// De onde sai a situação das proteções do Guardião neste aparelho.
abstract class HealthSource {
  /// `null` quando o sistema não sabe informar (por exemplo, no Windows).
  Future<DeviceHealth?> read();

  factory HealthSource.detect({bool background = false}) {
    if (!Platform.isAndroid) return const NoHealthSource();
    return background
        ? const SnapshotHealthSource()
        : const ChannelHealthSource();
  }
}

class NoHealthSource implements HealthSource {
  const NoHealthSource();

  @override
  Future<DeviceHealth?> read() async => null;
}

/// Com o app aberto: pergunta ao Android na hora (e ele aproveita para
/// atualizar a leitura guardada).
class ChannelHealthSource implements HealthSource {
  const ChannelHealthSource([this._channel]);

  final MethodChannel? _channel;

  @override
  Future<DeviceHealth?> read() async {
    final channel =
        _channel ?? const MethodChannel('br.edu.guardiaogamer/monitor');
    final raw = await channel.invokeMethod<String>('health');
    return parseHealth(raw);
  }
}

/// Em segundo plano: o motor do Flutter que o Android abre para a tarefa
/// periódica não tem os canais do aplicativo; por isso o serviço de
/// acompanhamento deixa a última leitura nas preferências compartilhadas
/// (arquivo `FlutterSharedPreferences`, chave `flutter.guardiao_health`).
class SnapshotHealthSource implements HealthSource {
  const SnapshotHealthSource();

  static const key = 'guardiao_health';

  @override
  Future<DeviceHealth?> read() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.reload();
    return parseHealth(prefs.getString(key));
  }
}

/// Lê o JSON escrito pelo Android; `null` se faltar ou estiver quebrado.
DeviceHealth? parseHealth(String? raw) {
  if (raw == null || raw.isEmpty) return null;
  try {
    final decoded = jsonDecode(raw);
    if (decoded is! Map<String, dynamic>) return null;
    return DeviceHealth.fromJson(decoded);
  } catch (_) {
    return null;
  }
}

/// Última situação já informada ao responsável. Serve para só avisar do que
/// mudou desde então.
abstract class HealthStore {
  Future<DeviceHealth?> read();
  Future<void> write(DeviceHealth health);
}

class PrefsHealthStore implements HealthStore {
  const PrefsHealthStore();

  static const _key = 'last_reported_health';

  @override
  Future<DeviceHealth?> read() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.reload();
    return parseHealth(prefs.getString(_key));
  }

  @override
  Future<void> write(DeviceHealth health) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_key, jsonEncode(health.toJson()));
  }
}

class MemoryHealthStore implements HealthStore {
  MemoryHealthStore([this.value]);

  DeviceHealth? value;

  @override
  Future<DeviceHealth?> read() async => value;

  @override
  Future<void> write(DeviceHealth health) async => value = health;
}

class FakeHealthSource implements HealthSource {
  FakeHealthSource([this.value]);

  DeviceHealth? value;

  @override
  Future<DeviceHealth?> read() async => value;
}
