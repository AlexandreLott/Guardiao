/// Sistema operacional do dispositivo do filho.
enum DevicePlatform {
  android,
  windows,
  other;

  static DevicePlatform parse(String? value) => DevicePlatform.values
      .firstWhere((p) => p.name == value, orElse: () => DevicePlatform.other);

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
    this.icon,
  });

  /// Identificador estável (pacote no Android, chave do registro no Windows).
  final String id;
  final String name;
  final String? packageName;

  /// Ícone pequeno do app (imagem WebP/PNG em base64), quando o aparelho
  /// consegue enviá-lo. `null` → o app mostra a letra inicial.
  final String? icon;

  factory InstalledApp.fromMap(String id, Map<String, dynamic> data) =>
      InstalledApp(
        id: id,
        name: (data['name'] as String?) ?? id,
        packageName: data['packageName'] as String?,
        icon: data['icon'] as String?,
      );

  Map<String, dynamic> toMap() => {
    'name': name,
    if (packageName != null) 'packageName': packageName,
    if (icon != null) 'icon': icon,
  };

  @override
  bool operator ==(Object other) =>
      other is InstalledApp &&
      other.id == id &&
      other.name == name &&
      other.packageName == packageName &&
      other.icon == icon;

  @override
  int get hashCode => Object.hash(id, name, packageName, icon);
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
    this.parentLabel,
  });

  final String id;
  final String parentUid;
  final String name;
  final DevicePlatform platform;
  final DateTime pairedAt;
  final DateTime? lastSeen;

  /// E-mail do responsável com parte escondida (`jo***@gmail.com`), para o
  /// filho saber a quem está vinculado.
  final String? parentLabel;

  /// Considera o aparelho online se falou com a nuvem nos últimos 30 minutos.
  bool isOnline(DateTime now) =>
      lastSeen != null &&
      now.difference(lastSeen!) < const Duration(minutes: 30);
}

/// Data local no formato `2026-11-08`, usada para agrupar o uso por dia.
String dayKey(DateTime date) =>
    '${date.year.toString().padLeft(4, '0')}-'
    '${date.month.toString().padLeft(2, '0')}-'
    '${date.day.toString().padLeft(2, '0')}';

/// Tempo de uso de um aplicativo em um dia, enviado pelo aparelho do filho.
class UsageEntry {
  const UsageEntry({
    required this.day,
    required this.appId,
    required this.minutes,
  });

  final String day;
  final String appId;
  final int minutes;

  factory UsageEntry.fromMap(Map<String, dynamic> data) => UsageEntry(
    day: (data['day'] as String?) ?? '',
    appId: (data['appId'] as String?) ?? '',
    minutes: ((data['minutes'] as num?) ?? 0).toInt(),
  );

  @override
  bool operator ==(Object other) =>
      other is UsageEntry &&
      other.day == day &&
      other.appId == appId &&
      other.minutes == minutes;

  @override
  int get hashCode => Object.hash(day, appId, minutes);
}

/// Pedido de vínculo criado pelo aparelho do filho. O código vai no QR e,
/// por escrito, na tela do filho; o responsável o escaneia ou digita.
class PairRequest {
  const PairRequest({
    required this.code,
    required this.deviceId,
    required this.expiresAt,
  });

  final String code;
  final String deviceId;
  final DateTime expiresAt;
}

/// O que o responsável vê do aparelho antes de confirmar o vínculo.
class PairRequestPreview {
  const PairRequestPreview({
    required this.code,
    required this.deviceName,
    required this.platform,
    required this.expiresAt,
  });

  final String code;
  final String deviceName;
  final DevicePlatform platform;
  final DateTime expiresAt;
}

class PairingException implements Exception {
  const PairingException(this.message);
  final String message;
  @override
  String toString() => message;
}
