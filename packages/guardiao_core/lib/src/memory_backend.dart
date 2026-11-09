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
  final pairRequests = <String, _PairRequest>{};
  final devices = <String, _Device>{};
  final _changes = StreamController<void>.broadcast(sync: true);

  /// Registra um pedido de vínculo direto (usado no modo demonstração, para
  /// simular um segundo aparelho de filho).
  void addPairRequest(
    String code, {
    required String deviceId,
    required String deviceName,
    required DevicePlatform platform,
    required DateTime expiresAt,
  }) => pairRequests[code] = _PairRequest(
    deviceId,
    deviceName,
    platform,
    expiresAt,
  );

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

class _PairRequest {
  _PairRequest(this.deviceId, this.deviceName, this.platform, this.expiresAt);
  final String deviceId;
  final String deviceName;
  final DevicePlatform platform;
  final DateTime expiresAt;
  bool used = false;
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

  _PairRequest _openRequest(String code) {
    _requireUid();
    final normalized = normalizePairingCode(code);
    if (!isValidPairingCode(normalized)) {
      throw const PairingException('O código tem 8 letras e números.');
    }
    final request = cloud.pairRequests[normalized];
    if (request == null) {
      throw const PairingException(
        'Código não encontrado. Confira e tente de novo.',
      );
    }
    if (request.used) {
      throw const PairingException(
        'Esse código já foi usado. Peça para gerar outro no aparelho do filho.',
      );
    }
    if (!cloud.now().isBefore(request.expiresAt)) {
      throw const PairingException(
        'Esse código expirou. Peça para gerar outro no aparelho do filho.',
      );
    }
    return request;
  }

  @override
  Future<PairRequestPreview> previewPairRequest(String code) async {
    final request = _openRequest(code);
    return PairRequestPreview(
      code: normalizePairingCode(code),
      deviceName: request.deviceName,
      platform: request.platform,
      expiresAt: request.expiresAt,
    );
  }

  @override
  Future<PairedDevice> approvePairRequest(
    String code, {
    String? deviceName,
  }) async {
    final uid = _requireUid();
    final request = _openRequest(code);
    if (cloud.devices.containsKey(request.deviceId)) {
      throw const PairingException('Esse aparelho já está vinculado.');
    }
    final name = (deviceName ?? '').trim();
    request.used = true;
    final info = PairedDevice(
      id: request.deviceId,
      parentUid: uid,
      name: name.isEmpty ? request.deviceName : name,
      platform: request.platform,
      pairedAt: cloud.now(),
      lastSeen: cloud.now(),
      parentLabel: maskEmail(cloud.emailOf(uid)),
    );
    cloud.devices[request.deviceId] = _Device(info);
    cloud.notify();
    return info;
  }

  @override
  Stream<List<PairedDevice>> watchDevices() {
    final uid = _requireUid();
    return cloud.watch(() {
      final list =
          cloud.devices.values
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
      () => Map.of(cloud.devices[deviceId]?.rules ?? const <String, AppRule>{}),
    );
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
  Stream<List<UsageEntry>> watchUsage(
    String deviceId, {
    required String sinceDay,
  }) {
    _ownedDevice(deviceId);
    return cloud.watch(() {
      final list =
          [
            for (final e
                in cloud.devices[deviceId]?.usage.values ??
                    const <UsageEntry>[])
              if (e.day.compareTo(sinceDay) >= 0) e,
          ]..sort((a, b) {
            final byDay = a.day.compareTo(b.day);
            return byDay != 0 ? byDay : a.appId.compareTo(b.appId);
          });
      return list;
    });
  }

  // ---- filho ----

  /// Código do último pedido deste aparelho (para cancelar ao gerar outro).
  String? _lastRequest;

  @override
  Future<PairRequest> createPairRequest({
    required String deviceName,
    required DevicePlatform platform,
  }) async {
    final uid = _requireUid();
    final previous = _lastRequest;
    if (previous != null) cloud.pairRequests.remove(previous);
    String code;
    do {
      code = generatePairingCode(cloud.random);
    } while (cloud.pairRequests.containsKey(code));
    final expires = cloud.now().add(pairingCodeTtl);
    cloud.pairRequests[code] = _PairRequest(uid, deviceName, platform, expires);
    _lastRequest = code;
    return PairRequest(code: code, deviceId: uid, expiresAt: expires);
  }

  @override
  Future<void> cancelPairRequest(String code) async {
    final request = cloud.pairRequests[normalizePairingCode(code)];
    if (request != null && request.deviceId == _uid) {
      cloud.pairRequests.remove(normalizePairingCode(code));
    }
    if (_lastRequest == code) _lastRequest = null;
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
      final entry = UsageEntry(
        day: day,
        appId: appId,
        minutes: minutes.clamp(0, 1440),
      );
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
      () => Map.of(cloud.devices[uid]?.rules ?? const <String, AppRule>{}),
    );
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
      parentLabel: i.parentLabel,
    );
    cloud.notify();
  }

  List<InstalledApp> _sortedApps(_Device? device) {
    final list = (device?.apps.values.toList() ?? <InstalledApp>[])
      ..sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
    return list;
  }
}
