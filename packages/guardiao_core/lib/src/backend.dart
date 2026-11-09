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

  /// O aparelho do filho entra de forma anônima; o que o liga a um responsável
  /// é o pedido de vínculo (QR), não uma senha.
  Future<String> signInChild();
  Future<void> signOut();

  // ---- App do responsável ----

  /// Mostra o aparelho que gerou o [code] (lido do QR ou digitado), sem
  /// vinculá-lo. Lança [PairingException] se o código não existe, já foi
  /// usado ou expirou.
  Future<PairRequestPreview> previewPairRequest(String code);

  /// Vincula ao responsável o aparelho dono do [code]. Pode ser chamado várias
  /// vezes, com códigos de aparelhos diferentes: não há limite de aparelhos.
  /// [deviceName] troca o nome sugerido pelo aparelho.
  Future<PairedDevice> approvePairRequest(String code, {String? deviceName});
  Stream<List<PairedDevice>> watchDevices();
  Future<void> removeDevice(String deviceId);
  Stream<List<InstalledApp>> watchApps(String deviceId);
  Stream<Map<String, AppRule>> watchRules(String deviceId);
  Future<void> setRule(String deviceId, AppRule rule);

  /// Avisos de tentativa de burla enviados pelo aparelho do filho (os mais
  /// recentes primeiro).
  Stream<List<TamperAlert>> watchAlerts(String deviceId);

  /// Marca todos os avisos do aparelho como vistos.
  Future<void> markAlertsSeen(String deviceId);

  /// Tempo de uso por aplicativo a partir do dia [sinceDay] (`2026-11-08`).
  Stream<List<UsageEntry>> watchUsage(
    String deviceId, {
    required String sinceDay,
  });

  // ---- App do filho ----

  /// Gera o código (e o QR) que o responsável vai escanear. Cada chamada
  /// cancela o pedido anterior deste aparelho.
  Future<PairRequest> createPairRequest({
    required String deviceName,
    required DevicePlatform platform,
  });

  /// Apaga um pedido que não vai mais ser usado (melhor esforço).
  Future<void> cancelPairRequest(String code);

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

  /// Informa ao responsável que uma proteção foi retirada.
  Future<void> reportAlert(AlertKind kind);

  /// Guarda a situação atual das proteções (permissões, administrador).
  Future<void> reportHealth(DeviceHealth health);
}

class AuthException implements Exception {
  const AuthException(this.message);
  final String message;
  @override
  String toString() => message;
}
