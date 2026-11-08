import 'dart:async';

import 'package:guardiao/nearby/nearby.dart';

/// "Ar" compartilhado entre um aparelho do filho e um do responsável nos testes.
class FakeAir {
  final _listeners = <String, StreamController<String>>{};
  final _changes = StreamController<void>.broadcast(sync: true);

  /// Quem está visível: endereço → nome.
  final Map<String, String> visible = {};
  Stream<void> get changes => _changes.stream;

  /// Cada código entregue, em ordem.
  final List<String> delivered = [];
}

class FakeNearby implements NearbyPairing {
  FakeNearby(this.air, {this.address = 'AA:BB:CC:00:00:01', this.name = 'Celular do Pedro'});

  final FakeAir air;
  final String address;
  final String name;

  NearbyStatus status = NearbyStatus.ready;
  bool failSend = false;
  bool? lastPrepareAsChild;

  @override
  bool get supported => true;

  @override
  Future<NearbyStatus> prepare({required bool asChild}) async {
    lastPrepareAsChild = asChild;
    return status;
  }

  @override
  Stream<String> receiveCodes() {
    late final StreamController<String> c;
    c = StreamController<String>(
      onListen: () {
        air._listeners[address] = c;
        air.visible[address] = name;
        air._changes.add(null);
      },
      onCancel: () {
        air._listeners.remove(address);
        air.visible.remove(address);
        air._changes.add(null);
      },
    );
    return c.stream;
  }

  @override
  Stream<List<NearbyDevice>> scan() {
    List<NearbyDevice> snapshot() => [
          for (final e in air.visible.entries) NearbyDevice(id: e.key, name: e.value),
        ];
    late final StreamController<List<NearbyDevice>> c;
    StreamSubscription<void>? sub;
    c = StreamController<List<NearbyDevice>>(
      onListen: () {
        c.add(snapshot());
        sub = air.changes.listen((_) {
          if (c.hasListener && !c.isClosed) c.add(snapshot());
        });
      },
      onCancel: () {
        sub?.cancel();
        sub = null;
      },
    );
    return c.stream;
  }

  @override
  Future<void> sendCode(NearbyDevice device, String code) async {
    if (failSend) throw const NearbyException('Não foi possível conectar ao aparelho.');
    final target = air._listeners[device.id];
    if (target == null) throw const NearbyException('Esse aparelho não está esperando um código.');
    air.delivered.add(code);
    target.add(code);
  }
}
