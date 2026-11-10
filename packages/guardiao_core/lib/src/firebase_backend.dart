import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import 'backend.dart';
import 'models.dart';
import 'pairing.dart';

/// Implementação de produção, em cima de Firebase Auth e Cloud Firestore.
///
/// Estrutura no Firestore:
/// - `pairRequests/{codigo}`: deviceId, name, platform, expiresAt, used, parentUid
///   (criado pelo aparelho do filho; o responsável o "queima" ao vincular)
/// - `devices/{deviceId}`: parentUid, parentLabel, name, platform, pairedAt,
///   lastSeen, pairingCode (criado pelo responsável, junto com a baixa do pedido)
/// - `devices/{deviceId}/apps/{appId}`: name, packageName
/// - `devices/{deviceId}/rules/{appId}`: dailyLimitMinutes, blocked
/// - `devices/{deviceId}/usage/{dia}_{appId}`: day, appId, minutes, updatedAt
/// - `devices/{deviceId}/alerts/{id}`: kind, at, seen (avisos de burla)
class FirebaseBackend implements GuardianBackend {
  FirebaseBackend({FirebaseAuth? auth, FirebaseFirestore? firestore})
    : _auth = auth ?? FirebaseAuth.instance,
      _db = firestore ?? FirebaseFirestore.instance;

  final FirebaseAuth _auth;
  final FirebaseFirestore _db;

  @override
  String? get currentUid => _auth.currentUser?.uid;

  String _requireUid() =>
      currentUid ??
      (throw const AuthException('Você precisa entrar primeiro.'));

  @override
  Stream<String?> authStateChanges() =>
      _auth.authStateChanges().map((u) => u?.uid);

  // ---- Conta ----

  Future<String> _auth0(Future<UserCredential> Function() action) async {
    try {
      final cred = await action();
      return cred.user!.uid;
    } on FirebaseAuthException catch (e) {
      throw AuthException(_authMessage(e));
    }
  }

  @override
  Future<String> registerParent(String email, String password) => _auth0(
    () => _auth.createUserWithEmailAndPassword(
      email: email.trim(),
      password: password,
    ),
  );

  @override
  Future<String> signInParent(String email, String password) => _auth0(
    () => _auth.signInWithEmailAndPassword(
      email: email.trim(),
      password: password,
    ),
  );

  @override
  Future<String> signInChild() async {
    final existing = _auth.currentUser;
    if (existing != null) return existing.uid;
    return _auth0(_auth.signInAnonymously);
  }

  @override
  Future<void> signOut() => _auth.signOut();

  static String _authMessage(FirebaseAuthException e) => switch (e.code) {
    'invalid-email' => 'E-mail inválido.',
    'user-not-found' ||
    'wrong-password' ||
    'invalid-credential' => 'E-mail ou senha incorretos.',
    'email-already-in-use' => 'Já existe uma conta com esse e-mail.',
    'weak-password' => 'A senha precisa ter pelo menos 6 caracteres.',
    'network-request-failed' => 'Sem conexão com a internet.',
    'too-many-requests' => 'Muitas tentativas. Aguarde um pouco.',
    'operation-not-allowed' =>
      'Esse tipo de login não está ativado no Firebase do projeto.',
    _ => 'Não foi possível entrar (${e.code}).',
  };

  // ---- App do responsável ----

  /// Lê o pedido e confere se ainda pode ser usado.
  Future<Map<String, dynamic>> _readOpenRequest(
    DocumentReference<Map<String, dynamic>> ref,
  ) async {
    final snap = await ref.get();
    final data = snap.data();
    if (!snap.exists || data == null) {
      throw const PairingException(
        'Código não encontrado. Confira e tente de novo.',
      );
    }
    if (data['used'] == true) {
      throw const PairingException(
        'Esse código já foi usado. Peça para gerar outro no aparelho do filho.',
      );
    }
    final expires = (data['expiresAt'] as Timestamp).toDate();
    if (!DateTime.now().isBefore(expires)) {
      throw const PairingException(
        'Esse código expirou. Peça para gerar outro no aparelho do filho.',
      );
    }
    return data;
  }

  PairingException _pairError(FirebaseException e, String denied) {
    if (e.code == 'permission-denied') return PairingException(denied);
    if (e.code == 'unavailable') {
      return const PairingException('Sem conexão com a internet.');
    }
    return PairingException('Erro ao falar com o servidor (${e.code}).');
  }

  @override
  Future<PairRequestPreview> previewPairRequest(String code) async {
    _requireUid();
    final normalized = normalizePairingCode(code);
    if (!isValidPairingCode(normalized)) {
      throw const PairingException('O código tem 8 letras e números.');
    }
    try {
      final data = await _readOpenRequest(
        _db.collection('pairRequests').doc(normalized),
      );
      return PairRequestPreview(
        code: normalized,
        deviceName: (data['name'] as String?) ?? 'Dispositivo',
        platform: DevicePlatform.parse(data['platform'] as String?),
        expiresAt: (data['expiresAt'] as Timestamp).toDate(),
      );
    } on FirebaseException catch (e) {
      throw _pairError(e, 'Não foi possível ler esse código.');
    }
  }

  @override
  Future<PairedDevice> approvePairRequest(
    String code, {
    String? deviceName,
  }) async {
    final uid = _requireUid();
    final normalized = normalizePairingCode(code);
    if (!isValidPairingCode(normalized)) {
      throw const PairingException('O código tem 8 letras e números.');
    }
    final requestRef = _db.collection('pairRequests').doc(normalized);
    try {
      final data = await _readOpenRequest(requestRef);
      final deviceId = data['deviceId'] as String;
      final deviceRef = _db.collection('devices').doc(deviceId);
      final name = (deviceName ?? '').trim();

      // Os dois documentos mudam juntos: ou o aparelho é vinculado e o
      // pedido é queimado, ou nada acontece.
      final batch = _db.batch()
        ..update(requestRef, {'used': true, 'parentUid': uid})
        ..set(deviceRef, {
          'parentUid': uid,
          'parentLabel': maskEmail(_auth.currentUser?.email),
          'name': name.isEmpty ? data['name'] : name,
          'platform': data['platform'],
          'pairingCode': normalized,
          'pairedAt': FieldValue.serverTimestamp(),
          'lastSeen': FieldValue.serverTimestamp(),
        });
      await batch.commit();
      return _deviceFrom(await deviceRef.get());
    } on FirebaseException catch (e) {
      throw _pairError(
        e,
        'Não foi possível vincular. Gere um novo código no aparelho do filho.',
      );
    }
  }

  @override
  Stream<List<PairedDevice>> watchDevices() {
    final uid = _requireUid();
    return _db
        .collection('devices')
        .where('parentUid', isEqualTo: uid)
        .snapshots()
        .map((q) {
          final list = q.docs.map(_deviceFrom).toList()
            ..sort((a, b) => a.pairedAt.compareTo(b.pairedAt));
          return list;
        });
  }

  @override
  Future<void> removeDevice(String deviceId) async {
    final ref = _db.collection('devices').doc(deviceId);
    // Subcoleções não são apagadas junto com o documento: limpamos antes.
    for (final sub in ['apps', 'rules', 'usage', 'alerts']) {
      final docs = await ref.collection(sub).get();
      for (var i = 0; i < docs.docs.length; i += 400) {
        final batch = _db.batch();
        for (final d in docs.docs.skip(i).take(400)) {
          batch.delete(d.reference);
        }
        await batch.commit();
      }
    }
    await ref.delete();
  }

  @override
  Stream<List<InstalledApp>> watchApps(String deviceId) =>
      _appsStream(deviceId);

  @override
  Stream<Map<String, AppRule>> watchRules(String deviceId) =>
      _rulesStream(deviceId);

  @override
  Future<void> setRule(String deviceId, AppRule rule) {
    final ref = _db
        .collection('devices')
        .doc(deviceId)
        .collection('rules')
        .doc(rule.appId);
    if (rule.isDefault) return ref.delete();
    return ref.set({
      ...rule.toMap(),
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  @override
  Stream<List<UsageEntry>> watchUsage(
    String deviceId, {
    required String sinceDay,
  }) => _db
      .collection('devices')
      .doc(deviceId)
      .collection('usage')
      .where('day', isGreaterThanOrEqualTo: sinceDay)
      .snapshots()
      .map((q) {
        final list = q.docs.map((d) => UsageEntry.fromMap(d.data())).toList()
          ..sort((a, b) {
            final byDay = a.day.compareTo(b.day);
            return byDay != 0 ? byDay : a.appId.compareTo(b.appId);
          });
        return list;
      });

  // ---- App do filho ----

  /// Código do último pedido deste aparelho (para cancelar ao gerar outro).
  String? _lastRequest;

  @override
  Future<PairRequest> createPairRequest({
    required String deviceName,
    required DevicePlatform platform,
  }) async {
    final uid = _requireUid();
    final expires = DateTime.now().add(pairingCodeTtl);
    for (var attempt = 0; attempt < 5; attempt++) {
      final code = generatePairingCode();
      final ref = _db.collection('pairRequests').doc(code);
      // A transação garante que o código só vira documento se ainda não existir.
      final bool created;
      try {
        created = await _db.runTransaction<bool>((tx) async {
          final snap = await tx.get(ref);
          if (snap.exists) return false;
          tx.set(ref, {
            'deviceId': uid,
            'name': deviceName,
            'platform': platform.name,
            'expiresAt': Timestamp.fromDate(expires),
            'used': false,
          });
          return true;
        });
      } on FirebaseException catch (e) {
        // As regras comparam a validade com o relógio do servidor.
        throw _pairError(
          e,
          'O servidor recusou o código. Confira a data e a hora do aparelho.',
        );
      }
      if (created) {
        final previous = _lastRequest;
        _lastRequest = code;
        if (previous != null) unawaited(cancelPairRequest(previous));
        return PairRequest(code: code, deviceId: uid, expiresAt: expires);
      }
    }
    throw const PairingException(
      'Não foi possível gerar um código. Tente novamente.',
    );
  }

  @override
  Future<void> cancelPairRequest(String code) async {
    try {
      await _db
          .collection('pairRequests')
          .doc(normalizePairingCode(code))
          .delete();
    } catch (_) {
      // Melhor esforço: o pedido expira sozinho em 10 minutos.
    }
    if (_lastRequest == code) _lastRequest = null;
  }

  @override
  Stream<PairedDevice?> watchOwnDevice() {
    final uid = _requireUid();
    return _db
        .collection('devices')
        .doc(uid)
        .snapshots()
        .map((s) => s.exists ? _deviceFrom(s) : null);
  }

  @override
  Future<void> syncInstalledApps(List<InstalledApp> apps) async {
    final uid = _requireUid();
    final col = _db.collection('devices').doc(uid).collection('apps');
    final existing = await col.get();
    final keep = {for (final a in apps) safeId(a.id): a};

    final current = {
      for (final d in existing.docs) d.id: InstalledApp.fromMap(d.id, d.data()),
    };

    final ops = <void Function(WriteBatch)>[];
    for (final entry in keep.entries) {
      // Só escreve o que mudou, para economizar escritas no Firestore.
      final app = entry.value;
      final before = current[entry.key];
      if (before != null &&
          before.name == app.name &&
          before.packageName == app.packageName &&
          before.icon == app.icon) {
        continue;
      }
      final ref = col.doc(entry.key);
      final data = {...app.toMap(), 'syncedAt': FieldValue.serverTimestamp()};
      ops.add((b) => b.set(ref, data));
    }
    for (final doc in existing.docs) {
      if (!keep.containsKey(doc.id)) ops.add((b) => b.delete(doc.reference));
    }
    // Lotes de até 400 operações (o limite do Firestore é 500).
    for (var i = 0; i < ops.length; i += 400) {
      final batch = _db.batch();
      for (final op in ops.skip(i).take(400)) {
        op(batch);
      }
      await batch.commit();
    }
  }

  /// Último valor enviado por dia+app, para não repetir escritas iguais.
  final _lastUsage = <String, int>{};

  @override
  Future<void> reportUsage(String day, Map<String, int> minutesByApp) async {
    final uid = _requireUid();
    final col = _db.collection('devices').doc(uid).collection('usage');
    final changed = <String, int>{};
    minutesByApp.forEach((appId, minutes) {
      final value = minutes.clamp(0, 1440);
      final key = '${day}_${safeId(appId)}';
      if (_lastUsage[key] != value) changed[appId] = value;
    });
    for (var i = 0; i < changed.length; i += 400) {
      final batch = _db.batch();
      for (final entry in changed.entries.skip(i).take(400)) {
        final key = '${day}_${safeId(entry.key)}';
        batch.set(col.doc(key), {
          'day': day,
          'appId': entry.key,
          'minutes': entry.value,
          'updatedAt': FieldValue.serverTimestamp(),
        });
      }
      await batch.commit();
    }
    changed.forEach(
      (appId, value) => _lastUsage['${day}_${safeId(appId)}'] = value,
    );
  }

  @override
  Stream<List<InstalledApp>> watchOwnApps() => _appsStream(_requireUid());

  @override
  Stream<Map<String, AppRule>> watchOwnRules() => _rulesStream(_requireUid());

  @override
  Future<void> touch() => _db.collection('devices').doc(_requireUid()).update({
    'lastSeen': FieldValue.serverTimestamp(),
  });

  @override
  Future<void> reportAlert(AlertKind kind) =>
      _db.collection('devices').doc(_requireUid()).collection('alerts').add({
        'kind': kind.wire,
        'at': FieldValue.serverTimestamp(),
        'seen': false,
      });

  @override
  Future<void> reportHealth(DeviceHealth health) =>
      _db.collection('devices').doc(_requireUid()).update({
        'lastSeen': FieldValue.serverTimestamp(),
        'health': {
          'usageAccess': health.usageAccess,
          'overlay': health.overlay,
          'notifications': health.notifications,
          'admin': health.admin,
          'monitorRunning': health.monitorRunning,
          'checkedAt': FieldValue.serverTimestamp(),
        },
      });

  @override
  Stream<List<TamperAlert>> watchAlerts(String deviceId) => _db
      .collection('devices')
      .doc(deviceId)
      .collection('alerts')
      .snapshots()
      .map((q) {
        final list = <TamperAlert>[];
        for (final d in q.docs) {
          final data = d.data();
          final kind = AlertKind.parse(data['kind'] as String?);
          if (kind == null) continue;
          list.add(
            TamperAlert(
              id: d.id,
              deviceId: deviceId,
              kind: kind,
              at: (data['at'] as Timestamp?)?.toDate() ?? DateTime.now(),
              seen: data['seen'] == true,
            ),
          );
        }
        list.sort((a, b) => b.at.compareTo(a.at));
        return list;
      });

  @override
  Future<void> markAlertsSeen(String deviceId) async {
    final col = _db.collection('devices').doc(deviceId).collection('alerts');
    final open = await col.where('seen', isEqualTo: false).get();
    for (var i = 0; i < open.docs.length; i += 400) {
      final batch = _db.batch();
      for (final d in open.docs.skip(i).take(400)) {
        batch.update(d.reference, {'seen': true});
      }
      await batch.commit();
    }
  }

  // ---- ajustes, créditos ----

  DocumentReference<Map<String, dynamic>> _configRef(String deviceId) =>
      _db.collection('devices').doc(deviceId).collection('config').doc('main');

  Stream<DeviceConfig> _configStream(String deviceId) =>
      _configRef(deviceId)
          .snapshots()
          .map((d) => DeviceConfig.fromMap(d.data()));

  Stream<List<Claim>> _claimsStream(String deviceId) => _db
      .collection('devices')
      .doc(deviceId)
      .collection('claims')
      .snapshots()
      .map((q) {
        final list = [
          for (final d in q.docs)
            Claim(
              id: d.id,
              title: (d.data()['title'] as String?) ?? '',
              minutes: (d.data()['minutes'] as num?)?.toInt() ?? 0,
              status: ClaimStatus.parse(d.data()['status'] as String?),
              createdAt:
                  (d.data()['createdAt'] as Timestamp?)?.toDate() ??
                  DateTime.now(),
              decidedAt: (d.data()['decidedAt'] as Timestamp?)?.toDate(),
              usedDay: (d.data()['usedDay'] as String?)?.isEmpty ?? true
                  ? null
                  : d.data()['usedDay'] as String?,
            ),
        ]..sort((a, b) => b.createdAt.compareTo(a.createdAt));
        return list;
      });

  @override
  Stream<DeviceConfig> watchConfig(String deviceId) => _configStream(deviceId);

  @override
  Future<void> saveConfig(String deviceId, DeviceConfig config) =>
      _configRef(deviceId).set(config.toMap());

  @override
  Stream<List<Claim>> watchClaims(String deviceId) => _claimsStream(deviceId);

  @override
  Future<void> decideClaim(String deviceId, String claimId, bool approved) =>
      _db
          .collection('devices')
          .doc(deviceId)
          .collection('claims')
          .doc(claimId)
          .update({
            'status': approved ? 'approved' : 'rejected',
            'decidedAt': FieldValue.serverTimestamp(),
          });

  @override
  Stream<DeviceConfig> watchOwnConfig() => _configStream(_requireUid());

  @override
  Stream<List<UsageEntry>> watchOwnUsage({required String sinceDay}) =>
      watchUsage(_requireUid(), sinceDay: sinceDay);

  @override
  Stream<List<Claim>> watchOwnClaims() => _claimsStream(_requireUid());

  @override
  Future<void> createClaim({required String title, required int minutes}) =>
      _db.collection('devices').doc(_requireUid()).collection('claims').add({
        'title': title,
        'minutes': minutes.clamp(1, 240),
        'status': 'pending',
        'createdAt': FieldValue.serverTimestamp(),
        'usedDay': '',
      });

  @override
  Future<void> useClaim(String claimId, String day) => _db
      .collection('devices')
      .doc(_requireUid())
      .collection('claims')
      .doc(claimId)
      .update({'usedDay': day});

  // ---- auxiliares ----

  Stream<List<InstalledApp>> _appsStream(String deviceId) => _db
      .collection('devices')
      .doc(deviceId)
      .collection('apps')
      .snapshots()
      .map((q) {
        final list =
            q.docs.map((d) => InstalledApp.fromMap(d.id, d.data())).toList()
              ..sort(
                (a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()),
              );
        return list;
      });

  Stream<Map<String, AppRule>> _rulesStream(String deviceId) => _db
      .collection('devices')
      .doc(deviceId)
      .collection('rules')
      .snapshots()
      .map(
        (q) => {for (final d in q.docs) d.id: AppRule.fromMap(d.id, d.data())},
      );

  PairedDevice _deviceFrom(DocumentSnapshot<Map<String, dynamic>> doc) {
    final d = doc.data()!;
    return PairedDevice(
      id: doc.id,
      parentUid: d['parentUid'] as String,
      name: (d['name'] as String?) ?? 'Dispositivo',
      platform: DevicePlatform.parse(d['platform'] as String?),
      // serverTimestamp ainda pendente aparece como null no cache local.
      pairedAt: (d['pairedAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      lastSeen: (d['lastSeen'] as Timestamp?)?.toDate(),
      parentLabel: d['parentLabel'] as String?,
      health: _healthFrom(d['health']),
    );
  }

  DeviceHealth? _healthFrom(Object? raw) {
    if (raw is! Map) return null;
    return DeviceHealth(
      usageAccess: raw['usageAccess'] == true,
      overlay: raw['overlay'] == true,
      notifications: raw['notifications'] == true,
      admin: raw['admin'] == true,
      monitorRunning: raw['monitorRunning'] != false,
      checkedAt: (raw['checkedAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }
}
