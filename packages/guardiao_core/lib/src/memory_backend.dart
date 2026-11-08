import 'dart:async';
import 'dart:math';

import 'backend.dart';
import 'models.dart';
import 'pairing.dart';

/// "Nuvem" em memória compartilhada entre vários [MemoryBackend].
/// Serve para testes e para demonstrar os dois apps sem Firebase.
class MemoryCloud {
  MemoryCloud({DateTime Function()? now, Random? random})
      : now = now ?? DateTime.now,
        random = random ?? Random();

  final DateTime Function() now;
  final Random random;

  final accounts = <String, ({String password, String uid})>{};
  final pairings = <String, _Pairing>{};
  final devices = <String, _Device>{};
  final _changes = StreamController<void>.broadcast(sync: true);

  /// Registra um código de pareamento direto (usado no modo demonstração).
  void addPairing(String code, String parentUid, DateTime expiresAt) =>
      pairings[code] = _Pairing(parentUid, expiresAt, emailOf(parentUid));

  /// E-mail da conta com esse uid (ou `null`).
  String? emailOf(String uid) {
    for (final entry in accounts.entries) {
      if (entry.value.uid == uid) return entry.key;
    }
    return null;
  }

  void notify() => _changes.add(null);

  Stream<T> watch<T>(T Function() read) => Stream<T>.multi((controller) {
        controller.add(read());
        final sub = _changes.stream.listen((_) => controller.add(read()));
        controller.onCancel = sub.cancel;
      });

  int _counter = 0;
  String newUid(String prefix) => '$prefix-${++_counter}';
}

class _Pairing {
  _Pairing(this.parentUid, this.expiresAt, [String? email])
      : parentLabel = maskEmail(email);
  final String parentUid;
  final DateTime expiresAt;
  final String parentLabel;
  bool used = false;
  String? deviceId;
}

class _Device {
  _Device(this.info);
  PairedDevice info;
  final apps = <String, InstalledApp>{};
  final rules = <String, AppRule>{};
  final usage = <String, UsageEntry>{};
}

class MemoryBackend implements GuardianBackend {
  MemoryBackend(this.cloud);

  final MemoryCloud cloud;
  String? _uid;
  final _auth = StreamController<String?>.broadcast();

  @override
  String? get currentUid => _uid;

  @override
  Stream<String?> authStateChanges() => Stream<String?>.multi((c) {
        c.add(_uid);
        final sub = _auth.stream.listen(c.add);
        c.onCancel = sub.cancel;
      });

  void _setUid(String? uid) {
    _uid = uid;
    _auth.add(uid);
  }

  String _requireUid() =>
      _uid ?? (throw const AuthException('Você precisa entrar primeiro.'));

  @override
  Future<String> registerParent(String email, String password) async {
    final key = email.trim().toLowerCase();
    if (!key.contains('@')) throw const AuthException('E-mail inválido.');
    if (password.length < 6) {
      throw const AuthException('A senha precisa ter pelo menos 6 caracteres.');
    }
    if (cloud.accounts.containsKey(key)) {
      throw const AuthException('Já existe uma conta com esse e-mail.');
    }
    final uid = cloud.newUid('parent');
    cloud.accounts[key] = (password: password, uid: uid);
    _setUid(uid);
    return uid;
  }

  @override
  Future<String> signInParent(String email, String password) async {
    final account = cloud.accounts[email.trim().toLowerCase()];
    if (account == null || account.password != password) {
      throw const AuthException('E-mail ou senha incorretos.');
    }
    _setUid(account.uid);
    return account.uid;
  }

  @override
  Future<String> signInChild() async {
    final uid = _uid ?? cloud.newUid('child');
    _setUid(uid);
    return uid;
  }

  @override
  Future<void> signOut() async => _setUid(null);

  // ---- responsável ----

  @override
  Future<PairingCode> createPairingCode() async {
    final uid = _requireUid();
    String code;
    do {
      code = generatePairingCode(cloud.random);
    } while (cloud.pairings.containsKey(code));
    final expires = cloud.now().add(pairingCodeTtl);
    cloud.pairings[code] = _Pairing(uid, expires, cloud.emailOf(uid));
    return PairingCode(code: code, parentUid: uid, expiresAt: expires);
  }

  @override
  Stream<List<PairedDevice>> watchDevices() {
    final uid = _requireUid();
    return cloud.watch(() {
      final list = cloud.devices.values
          .map((d) => d.info)
          .where((d) => d.parentUid == uid)
          .toList()
        ..sort((a, b) => a.pairedAt.compareTo(b.pairedAt));
      return list;
    });
  }

  _Device _ownedDevice(String deviceId) {
    final device = cloud.devices[deviceId];
    if (device == null || device.info.parentUid != _requireUid()) {
      throw const PairingException('Dispositivo não encontrado.');
    }
    return device;
  }

  @override
  Future<void> removeDevice(String deviceId) async {
    _ownedDevice(deviceId);
    cloud.devices.remove(deviceId);
    cloud.notify();
  }

  @override
  Stream<List<InstalledApp>> watchApps(String deviceId) {
    _ownedDevice(deviceId);
    return cloud.watch(() => _sortedApps(cloud.devices[deviceId]));
  }

  @override
  Stream<Map<String, AppRule>> watchRules(String deviceId) {
    _ownedDevice(deviceId);
    return cloud.watch(
        () => Map.of(cloud.devices[deviceId]?.rules ?? const <String, AppRule>{}));
  }

  @override
  Future<void> setRule(String deviceId, AppRule rule) async {
    final device = _ownedDevice(deviceId);
    if (rule.isDefault) {
      device.rules.remove(rule.appId);
    } else {
      device.rules[rule.appId] = rule;
    }
    cloud.notify();
  }

  @override
  Stream<List<UsageEntry>> watchUsage(String deviceId, {required String sinceDay}) {
    _ownedDevice(deviceId);
    return cloud.watch(() {
      final list = [
        for (final e in cloud.devices[deviceId]?.usage.values ?? const <UsageEntry>[])
          if (e.day.compareTo(sinceDay) >= 0) e,
      ]..sort((a, b) {
          final byDay = a.day.compareTo(b.day);
          return byDay != 0 ? byDay : a.appId.compareTo(b.appId);
        });
      return list;
    });
  }

  // ---- filho ----

  _Pairing _openPairing(String code) {
    _requireUid();
    final pairing = cloud.pairings[normalizePairingCode(code)];
    if (pairing == null) {
      throw const PairingException('Código não encontrado. Confira e tente de novo.');
    }
    if (pairing.used) {
      throw const PairingException('Esse código já foi usado. Peça um novo ao responsável.');
    }
    if (!cloud.now().isBefore(pairing.expiresAt)) {
      throw const PairingException('Esse código expirou. Peça um novo ao responsável.');
    }
    return pairing;
  }

  @override
  Future<PairingPreview> previewPairing(String code) async {
    final pairing = _openPairing(code);
    return PairingPreview(
        parentLabel: pairing.parentLabel, expiresAt: pairing.expiresAt);
  }

  @override
  Future<PairedDevice> claimPairing({
    required String code,
    required String deviceName,
    required DevicePlatform platform,
  }) async {
    final uid = _requireUid();
    final pairing = _openPairing(code);
    pairing
      ..used = true
      ..deviceId = uid;
    final info = PairedDevice(
      id: uid,
      parentUid: pairing.parentUid,
      name: deviceName,
      platform: platform,
      pairedAt: cloud.now(),
      lastSeen: cloud.now(),
    );
    cloud.devices[uid] = _Device(info);
    cloud.notify();
    return info;
  }

  @override
  Stream<PairedDevice?> watchOwnDevice() {
    final uid = _requireUid();
    return cloud.watch(() => cloud.devices[uid]?.info);
  }

  _Device _ownDevice() {
    final device = cloud.devices[_requireUid()];
    if (device == null) {
      throw const PairingException('Este aparelho ainda não foi vinculado.');
    }
    return device;
  }

  @override
  Future<void> syncInstalledApps(List<InstalledApp> apps) async {
    final device = _ownDevice();
    device.apps
      ..clear()
      ..addEntries(apps.map((a) => MapEntry(a.id, a)));
    cloud.notify();
  }

  @override
  Future<void> reportUsage(String day, Map<String, int> minutesByApp) async {
    final device = _ownDevice();
    minutesByApp.forEach((appId, minutes) {
      final entry = UsageEntry(day: day, appId: appId, minutes: minutes.clamp(0, 1440));
      device.usage['$day|$appId'] = entry;
    });
    cloud.notify();
  }

  @override
  Stream<List<InstalledApp>> watchOwnApps() {
    final uid = _requireUid();
    return cloud.watch(() => _sortedApps(cloud.devices[uid]));
  }

  @override
  Stream<Map<String, AppRule>> watchOwnRules() {
    final uid = _requireUid();
    return cloud.watch(
        () => Map.of(cloud.devices[uid]?.rules ?? const <String, AppRule>{}));
  }

  @override
  Future<void> touch() async {
    final device = _ownDevice();
    final i = device.info;
    device.info = PairedDevice(
      id: i.id,
      parentUid: i.parentUid,
      name: i.name,
      platform: i.platform,
      pairedAt: i.pairedAt,
      lastSeen: cloud.now(),
    );
    cloud.notify();
  }

  List<InstalledApp> _sortedApps(_Device? device) {
    final list = (device?.apps.values.toList() ?? <InstalledApp>[])
      ..sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
    return list;
  }
}
