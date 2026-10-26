import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import 'backend.dart';
import 'models.dart';
import 'pairing.dart';

/// Implementação de produção, em cima de Firebase Auth e Cloud Firestore.
///
/// Estrutura no Firestore:
/// - `pairings/{codigo}`: parentUid, expiresAt, used, deviceId
/// - `devices/{deviceId}`: parentUid, name, platform, pairedAt, lastSeen, pairingCode
/// - `devices/{deviceId}/apps/{appId}`: name, packageName
/// - `devices/{deviceId}/rules/{appId}`: dailyLimitMinutes, blocked
class FirebaseBackend implements GuardianBackend {
  FirebaseBackend({FirebaseAuth? auth, FirebaseFirestore? firestore})
      : _auth = auth ?? FirebaseAuth.instance,
        _db = firestore ?? FirebaseFirestore.instance;

  final FirebaseAuth _auth;
  final FirebaseFirestore _db;

  @override
  String? get currentUid => _auth.currentUser?.uid;

  String _requireUid() =>
      currentUid ?? (throw const AuthException('Você precisa entrar primeiro.'));

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
  Future<String> registerParent(String email, String password) => _auth0(() =>
      _auth.createUserWithEmailAndPassword(email: email.trim(), password: password));

  @override
  Future<String> signInParent(String email, String password) => _auth0(() =>
      _auth.signInWithEmailAndPassword(email: email.trim(), password: password));

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
        'invalid-credential' =>
          'E-mail ou senha incorretos.',
        'email-already-in-use' => 'Já existe uma conta com esse e-mail.',
        'weak-password' => 'A senha precisa ter pelo menos 6 caracteres.',
        'network-request-failed' => 'Sem conexão com a internet.',
        'too-many-requests' => 'Muitas tentativas. Aguarde um pouco.',
        'operation-not-allowed' =>
          'Esse tipo de login não está ativado no Firebase do projeto.',
        _ => 'Não foi possível entrar (${e.code}).',
      };

  // ---- App do responsável ----

  @override
  Future<PairingCode> createPairingCode() async {
    final uid = _requireUid();
    final expires = DateTime.now().add(pairingCodeTtl);
    for (var attempt = 0; attempt < 5; attempt++) {
      final code = generatePairingCode();
      final ref = _db.collection('pairings').doc(code);
      // A transação garante que o código só vira documento se ainda não existir.
      final bool created;
      try {
        created = await _db.runTransaction<bool>((tx) async {
          final snap = await tx.get(ref);
          if (snap.exists) return false;
          tx.set(ref, {
            'parentUid': uid,
            'expiresAt': Timestamp.fromDate(expires),
            'used': false,
          });
          return true;
        });
      } on FirebaseException catch (e) {
        // As regras comparam a validade com o relógio do servidor.
        if (e.code == 'permission-denied') {
          throw const PairingException(
              'O servidor recusou o código. Confira a data e a hora do aparelho.');
        }
        if (e.code == 'unavailable') {
          throw const PairingException('Sem conexão com a internet.');
        }
        rethrow;
      }
      if (created) {
        return PairingCode(code: code, parentUid: uid, expiresAt: expires);
      }
    }
    throw const PairingException('Não foi possível gerar um código. Tente de novo.');
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
    for (final sub in ['apps', 'rules']) {
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
    final ref =
        _db.collection('devices').doc(deviceId).collection('rules').doc(rule.appId);
    if (rule.isDefault) return ref.delete();
    return ref.set({
      ...rule.toMap(),
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  // ---- App do filho ----

  @override
  Future<PairedDevice> claimPairing({
    required String code,
    required String deviceName,
    required DevicePlatform platform,
  }) async {
    final uid = _requireUid();
    final normalized = normalizePairingCode(code);
    if (!isValidPairingCode(normalized)) {
      throw const PairingException('O código tem 8 letras e números.');
    }
    final pairingRef = _db.collection('pairings').doc(normalized);
    final deviceRef = _db.collection('devices').doc(uid);

    try {
      final snap = await pairingRef.get();
      final data = snap.data();
      if (!snap.exists || data == null) {
        throw const PairingException(
            'Código não encontrado. Confira e tente de novo.');
      }
      if (data['used'] == true) {
        throw const PairingException(
            'Esse código já foi usado. Peça um novo ao responsável.');
      }
      final expires = (data['expiresAt'] as Timestamp).toDate();
      if (!DateTime.now().isBefore(expires)) {
        throw const PairingException(
            'Esse código expirou. Peça um novo ao responsável.');
      }
      final parentUid = data['parentUid'] as String;

      // Os dois documentos mudam juntos: ou o aparelho é vinculado e o
      // código é queimado, ou nada acontece.
      final batch = _db.batch()
        ..update(pairingRef, {'used': true, 'deviceId': uid})
        ..set(deviceRef, {
          'parentUid': parentUid,
          'name': deviceName,
          'platform': platform.name,
          'pairingCode': normalized,
          'pairedAt': FieldValue.serverTimestamp(),
          'lastSeen': FieldValue.serverTimestamp(),
        });
      await batch.commit();
    } on FirebaseException catch (e) {
      if (e.code == 'permission-denied') {
        throw const PairingException(
            'Não foi possível usar esse código. Peça um novo ao responsável.');
      }
      if (e.code == 'unavailable') {
        throw const PairingException('Sem conexão com a internet.');
      }
      rethrow;
    }
    final created = await deviceRef.get();
    return _deviceFrom(created);
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
          before.packageName == app.packageName) {
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

  @override
  Stream<List<InstalledApp>> watchOwnApps() => _appsStream(_requireUid());

  @override
  Stream<Map<String, AppRule>> watchOwnRules() => _rulesStream(_requireUid());

  @override
  Future<void> touch() => _db
      .collection('devices')
      .doc(_requireUid())
      .update({'lastSeen': FieldValue.serverTimestamp()});

  // ---- auxiliares ----

  Stream<List<InstalledApp>> _appsStream(String deviceId) => _db
          .collection('devices')
          .doc(deviceId)
          .collection('apps')
          .snapshots()
          .map((q) {
        final list = q.docs.map((d) => InstalledApp.fromMap(d.id, d.data())).toList()
          ..sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
        return list;
      });

  Stream<Map<String, AppRule>> _rulesStream(String deviceId) => _db
      .collection('devices')
      .doc(deviceId)
      .collection('rules')
      .snapshots()
      .map((q) => {for (final d in q.docs) d.id: AppRule.fromMap(d.id, d.data())});

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
    );
  }
}
