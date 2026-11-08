import 'models.dart';

/// Tudo que os dois aplicativos precisam da nuvem.
///
/// Há duas implementações: [FirebaseBackend] (produção) e [MemoryBackend]
/// (testes e demonstração sem internet).
abstract class GuardianBackend {
  // ---- Conta ----
  String? get currentUid;
  Stream<String?> authStateChanges();

  /// Cria a conta do responsável (e-mail e senha).
  Future<String> registerParent(String email, String password);
  Future<String> signInParent(String email, String password);

  /// O aparelho do filho entra de forma anônima; quem o identifica é o
  /// código de pareamento, não uma senha.
  Future<String> signInChild();
  Future<void> signOut();

  // ---- App do responsável ----
  Future<PairingCode> createPairingCode();
  Stream<List<PairedDevice>> watchDevices();
  Future<void> removeDevice(String deviceId);
  Stream<List<InstalledApp>> watchApps(String deviceId);
  Stream<Map<String, AppRule>> watchRules(String deviceId);
  Future<void> setRule(String deviceId, AppRule rule);

  /// Tempo de uso por aplicativo a partir do dia [sinceDay] (`2026-11-08`).
  Stream<List<UsageEntry>> watchUsage(String deviceId, {required String sinceDay});

  // ---- App do filho ----

  /// Mostra a quem pertence um código antes de aceitá-lo.
  /// Lança [PairingException] se o código não existe, já foi usado ou expirou.
  Future<PairingPreview> previewPairing(String code);

  Future<PairedDevice> claimPairing({
    required String code,
    required String deviceName,
    required DevicePlatform platform,
  });

  /// `null` enquanto o aparelho não está vinculado (ou foi desvinculado).
  Stream<PairedDevice?> watchOwnDevice();
  Future<void> syncInstalledApps(List<InstalledApp> apps);

  /// Envia o tempo usado hoje, por aplicativo (em minutos). Só escreve o que
  /// mudou desde o último envio.
  Future<void> reportUsage(String day, Map<String, int> minutesByApp);
  Stream<List<InstalledApp>> watchOwnApps();
  Stream<Map<String, AppRule>> watchOwnRules();

  /// Avisa a nuvem que o aparelho está ativo.
  Future<void> touch();
}

class AuthException implements Exception {
  const AuthException(this.message);
  final String message;
  @override
  String toString() => message;
}
