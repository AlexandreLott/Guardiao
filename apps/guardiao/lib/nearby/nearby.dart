import 'dart:async';
import 'dart:io';

import 'package:flutter/services.dart';
import 'package:guardiao_core/guardiao_core.dart';

/// Resultado do preparo do Bluetooth (permissões e rádio ligado).
enum NearbyStatus {
  /// Tudo certo para usar.
  ready,

  /// O Bluetooth está desligado.
  off,

  /// O usuário negou a permissão.
  denied,

  /// Este aparelho não tem Bluetooth de baixa energia ou o sistema não suporta.
  unsupported,
}

/// Mensagem em português para cada situação que não seja [NearbyStatus.ready].
String nearbyStatusMessage(NearbyStatus status) => switch (status) {
      NearbyStatus.ready => '',
      NearbyStatus.off => 'O Bluetooth está desligado. Ligue-o e tente de novo.',
      NearbyStatus.denied =>
        'Sem a permissão de Bluetooth não dá para achar aparelhos por perto. '
            'Libere nas configurações do app.',
      NearbyStatus.unsupported => 'Este aparelho não consegue parear por Bluetooth.',
    };

/// Um aparelho do filho que está esperando um código por perto.
class NearbyDevice {
  const NearbyDevice({required this.id, required this.name});

  /// Endereço Bluetooth.
  final String id;

  /// Nome que o aparelho anuncia; pode vir vazio.
  final String name;

  String get label => name.trim().isEmpty ? 'Aparelho sem nome ($id)' : name.trim();

  @override
  bool operator ==(Object other) =>
      other is NearbyDevice && other.id == id && other.name == name;

  @override
  int get hashCode => Object.hash(id, name);
}

class NearbyException implements Exception {
  const NearbyException(this.message);
  final String message;

  @override
  String toString() => message;
}

/// Entrega do código de pareamento por Bluetooth, de um aparelho para outro.
///
/// O Firebase continua sendo a base: o Bluetooth só leva o código de 8
/// caracteres do responsável até o filho (e serve de plano B quando digitar
/// é ruim). O vínculo em si é feito pela internet, como sempre.
abstract class NearbyPairing {
  /// Falso onde não há implementação (Windows, demonstração).
  bool get supported;

  /// Pede as permissões e confere se o Bluetooth está ligado.
  Future<NearbyStatus> prepare({required bool asChild});

  /// Lado do filho: fica visível e entrega cada código recebido. Cancelar a
  /// escuta apaga o anúncio.
  Stream<String> receiveCodes();

  /// Lado do responsável: aparelhos que estão esperando um código. Cancelar
  /// a escuta para a busca.
  Stream<List<NearbyDevice>> scan();

  /// Lado do responsável: manda [code] para [device]. Lança [NearbyException].
  Future<void> sendCode(NearbyDevice device, String code);

  /// Escolhe a implementação do sistema atual.
  factory NearbyPairing.detect() =>
      Platform.isAndroid ? AndroidNearby() : UnsupportedNearby();
}

/// Sem Bluetooth de pareamento (Windows, Linux, testes sem doublê).
class UnsupportedNearby implements NearbyPairing {
  @override
  bool get supported => false;

  @override
  Future<NearbyStatus> prepare({required bool asChild}) async => NearbyStatus.unsupported;

  @override
  Stream<String> receiveCodes() => const Stream.empty();

  @override
  Stream<List<NearbyDevice>> scan() => const Stream.empty();

  @override
  Future<void> sendCode(NearbyDevice device, String code) =>
      Future.error(const NearbyException('Bluetooth indisponível neste aparelho.'));
}

/// Android: conversa com `BleNearby.kt` pelos canais de plataforma.
class AndroidNearby implements NearbyPairing {
  AndroidNearby({MethodChannel? methods, EventChannel? events})
      : _methods = methods ?? const MethodChannel('br.edu.guardiaogamer/nearby'),
        _events = events ?? const EventChannel('br.edu.guardiaogamer/nearby_events');

  final MethodChannel _methods;
  final EventChannel _events;

  Stream<Map<Object?, Object?>>? _shared;

  Stream<Map<Object?, Object?>> get _stream => _shared ??= _events
      .receiveBroadcastStream()
      .where((e) => e is Map)
      .map((e) => e as Map<Object?, Object?>)
      .asBroadcastStream();

  @override
  bool get supported => true;

  @override
  Future<NearbyStatus> prepare({required bool asChild}) async {
    final raw = await _methods.invokeMethod<String>('prepare', {'asChild': asChild});
    return switch (raw) {
      'ready' => NearbyStatus.ready,
      'off' => NearbyStatus.off,
      'denied' => NearbyStatus.denied,
      _ => NearbyStatus.unsupported,
    };
  }

  @override
  Stream<String> receiveCodes() {
    StreamSubscription<Map<Object?, Object?>>? sub;
    late final StreamController<String> controller;
    controller = StreamController<String>(
      onListen: () async {
        sub = _stream.listen((event) {
          final type = event['type'];
          if (type == 'code') {
            final code = normalizePairingCode('${event['value']}');
            if (isValidPairingCode(code)) controller.add(code);
          } else if (type == 'state' && '${event['value']}'.startsWith('error')) {
            controller.addError(
                const NearbyException('Não foi possível ficar visível por Bluetooth.'));
          }
        });
        try {
          final result = await _methods.invokeMethod<String>('startAdvertising');
          if (result != 'ok') {
            controller.addError(NearbyException(nearbyStatusMessage(
                result == 'off' ? NearbyStatus.off : NearbyStatus.unsupported)));
          }
        } on PlatformException catch (e) {
          controller.addError(NearbyException(e.message ?? 'Erro de Bluetooth.'));
        }
      },
      onCancel: () async {
        await sub?.cancel();
        try {
          await _methods.invokeMethod<void>('stopAdvertising');
        } on PlatformException {
          // já parou
        }
      },
    );
    return controller.stream;
  }

  @override
  Stream<List<NearbyDevice>> scan() {
    StreamSubscription<Map<Object?, Object?>>? sub;
    final found = <String, String>{};
    late final StreamController<List<NearbyDevice>> controller;
    controller = StreamController<List<NearbyDevice>>(
      onListen: () async {
        sub = _stream.listen((event) {
          final type = event['type'];
          if (type == 'device') {
            final address = '${event['address']}';
            final name = '${event['name'] ?? ''}';
            // O nome costuma chegar num segundo pacote: não perde o que já se sabe.
            if (name.isNotEmpty || !found.containsKey(address)) found[address] = name;
            controller.add([
              for (final e in found.entries) NearbyDevice(id: e.key, name: e.value),
            ]);
          } else if (type == 'state' && '${event['value']}'.startsWith('error')) {
            controller.addError(const NearbyException('A busca por Bluetooth falhou.'));
          }
        });
        try {
          final result = await _methods.invokeMethod<String>('startScan');
          if (result != 'ok') {
            controller.addError(NearbyException(nearbyStatusMessage(
                result == 'off' ? NearbyStatus.off : NearbyStatus.unsupported)));
          }
        } on PlatformException catch (e) {
          controller.addError(NearbyException(e.message ?? 'Erro de Bluetooth.'));
        }
      },
      onCancel: () async {
        await sub?.cancel();
        try {
          await _methods.invokeMethod<void>('stopScan');
        } on PlatformException {
          // já parou
        }
      },
    );
    return controller.stream;
  }

  @override
  Future<void> sendCode(NearbyDevice device, String code) async {
    try {
      await _methods.invokeMethod<void>('sendCode', {
        'address': device.id,
        'code': normalizePairingCode(code),
      });
    } on PlatformException catch (e) {
      throw NearbyException(e.message ?? 'Não foi possível enviar o código.');
    }
  }
}
