/// Sistema operacional do dispositivo do filho.
enum DevicePlatform {
  android,
  windows,
  other;

  static DevicePlatform parse(String? value) => DevicePlatform.values.firstWhere(
        (p) => p.name == value,
        orElse: () => DevicePlatform.other,
      );

  String get label => switch (this) {
        DevicePlatform.android => 'Android',
        DevicePlatform.windows => 'Windows',
        DevicePlatform.other => 'Outro',
      };
}

/// Transforma qualquer texto em um identificador aceito como id de documento
/// do Firestore (sem "/", sem espaços nas pontas, no máximo 120 caracteres).
String safeId(String raw) {
  final cleaned = raw.trim().replaceAll(RegExp(r'[/\\\s]+'), '_');
  final id = cleaned.isEmpty ? 'app' : cleaned;
  return id.length > 120 ? id.substring(0, 120) : id;
}

/// Um aplicativo instalado no aparelho do filho.
class InstalledApp {
  const InstalledApp({
    required this.id,
    required this.name,
    this.packageName,
  });

  /// Identificador estável (pacote no Android, chave do registro no Windows).
  final String id;
  final String name;
  final String? packageName;

  factory InstalledApp.fromMap(String id, Map<String, dynamic> data) =>
      InstalledApp(
        id: id,
        name: (data['name'] as String?) ?? id,
        packageName: data['packageName'] as String?,
      );

  Map<String, dynamic> toMap() => {
        'name': name,
        if (packageName != null) 'packageName': packageName,
      };

  @override
  bool operator ==(Object other) =>
      other is InstalledApp &&
      other.id == id &&
      other.name == name &&
      other.packageName == packageName;

  @override
  int get hashCode => Object.hash(id, name, packageName);
}

/// Regra definida pelo responsável para um aplicativo.
class AppRule {
  const AppRule({
    required this.appId,
    this.dailyLimitMinutes,
    this.blocked = false,
  });

  final String appId;

  /// Limite diário em minutos. `null` significa sem limite.
  final int? dailyLimitMinutes;

  /// Quando verdadeiro, o app fica bloqueado o dia todo.
  final bool blocked;

  bool get isDefault => dailyLimitMinutes == null && !blocked;

  factory AppRule.fromMap(String appId, Map<String, dynamic> data) => AppRule(
        appId: appId,
        dailyLimitMinutes: (data['dailyLimitMinutes'] as num?)?.toInt(),
        blocked: (data['blocked'] as bool?) ?? false,
      );

  Map<String, dynamic> toMap() => {
        'dailyLimitMinutes': dailyLimitMinutes,
        'blocked': blocked,
      };

  /// Minutos ainda disponíveis hoje, dado o tempo já usado.
  /// `null` quando não há limite; 0 quando bloqueado ou esgotado.
  int? remainingMinutes(int usedMinutes) {
    if (blocked) return 0;
    final limit = dailyLimitMinutes;
    if (limit == null) return null;
    final left = limit - usedMinutes;
    return left < 0 ? 0 : left;
  }
}

/// Dispositivo do filho já vinculado a um responsável.
class PairedDevice {
  const PairedDevice({
    required this.id,
    required this.parentUid,
    required this.name,
    required this.platform,
    required this.pairedAt,
    this.lastSeen,
  });

  final String id;
  final String parentUid;
  final String name;
  final DevicePlatform platform;
  final DateTime pairedAt;
  final DateTime? lastSeen;

  /// Considera o aparelho online se falou com a nuvem nos últimos 30 minutos.
  bool isOnline(DateTime now) =>
      lastSeen != null && now.difference(lastSeen!) < const Duration(minutes: 30);
}

/// Código temporário gerado pelo responsável para vincular um aparelho.
class PairingCode {
  const PairingCode({
    required this.code,
    required this.parentUid,
    required this.expiresAt,
  });

  final String code;
  final String parentUid;
  final DateTime expiresAt;
}

class PairingException implements Exception {
  const PairingException(this.message);
  final String message;
  @override
  String toString() => message;
}
