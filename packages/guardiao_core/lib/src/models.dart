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
    this.health,
  });

  final String id;
  final String parentUid;
  final String name;
  final DevicePlatform platform;
  final DateTime pairedAt;
  final DateTime? lastSeen;

  /// Última situação das permissões informada pelo aparelho (Android).
  final DeviceHealth? health;

  /// E-mail do responsável com parte escondida (`jo***@gmail.com`), para o
  /// filho saber a quem está vinculado.
  final String? parentLabel;

  /// Considera o aparelho online se falou com a nuvem nos últimos 30 minutos.
  bool isOnline(DateTime now) =>
      lastSeen != null &&
      now.difference(lastSeen!) < const Duration(minutes: 30);

  /// O aparelho filho avisa a nuvem a cada ~15 minutos em segundo plano. Se
  /// passar [noSignalAfter] sem aviso, o Guardião pode ter sido desinstalado,
  /// parado à força, ou o aparelho está desligado ou sem internet.
  bool hasNoSignal(DateTime now) =>
      lastSeen != null && now.difference(lastSeen!) > noSignalAfter;

  PairedDevice copyWith({
    String? name,
    DateTime? lastSeen,
    DeviceHealth? health,
  }) => PairedDevice(
    id: id,
    parentUid: parentUid,
    name: name ?? this.name,
    platform: platform,
    pairedAt: pairedAt,
    lastSeen: lastSeen ?? this.lastSeen,
    parentLabel: parentLabel,
    health: health ?? this.health,
  );
}

/// Tempo sem sinal do aparelho do filho a partir do qual o responsável é
/// avisado (três verificações perdidas).
const noSignalAfter = Duration(minutes: 45);

/// Tempo sem o serviço de acompanhamento "bater" para considerá-lo parado.
const monitorStaleAfter = Duration(minutes: 20);

/// O que o responsável precisa saber quando alguém tenta burlar o Guardião.
enum AlertKind {
  usageAccessRevoked,
  overlayRevoked,
  notificationsRevoked,
  adminDisabled,
  monitorStopped;

  /// Nome usado no Firestore.
  String get wire => switch (this) {
    AlertKind.usageAccessRevoked => 'usage_access_revoked',
    AlertKind.overlayRevoked => 'overlay_revoked',
    AlertKind.notificationsRevoked => 'notifications_revoked',
    AlertKind.adminDisabled => 'admin_disabled',
    AlertKind.monitorStopped => 'monitor_stopped',
  };

  static AlertKind? parse(String? value) {
    for (final kind in AlertKind.values) {
      if (kind.wire == value) return kind;
    }
    return null;
  }

  String get title => switch (this) {
    AlertKind.usageAccessRevoked => 'Acesso ao uso foi retirado',
    AlertKind.overlayRevoked => 'Permissão de sobreposição foi retirada',
    AlertKind.notificationsRevoked => 'Notificações foram desativadas',
    AlertKind.adminDisabled => 'Proteção contra desinstalação desativada',
    AlertKind.monitorStopped => 'Acompanhamento interrompido',
  };

  String get description => switch (this) {
    AlertKind.usageAccessRevoked => 'Sem o acesso ao uso, o Guardião não consegue medir o tempo nem bloquear.',
    AlertKind.overlayRevoked =>
      'Sem essa permissão, a tela de bloqueio não pode ser exibida.',
    AlertKind.notificationsRevoked =>
      'O aviso fixo do acompanhamento deixou de ser exibido.',
    AlertKind.adminDisabled => 'O administrador do dispositivo foi desativado; o aplicativo pode ser desinstalado em seguida.',
    AlertKind.monitorStopped =>
      'O serviço que mede e bloqueia deixou de funcionar neste aparelho.',
  };
}

/// Um aviso gerado pelo aparelho do filho.
class TamperAlert {
  const TamperAlert({
    required this.id,
    required this.deviceId,
    required this.kind,
    required this.at,
    this.seen = false,
  });

  final String id;
  final String deviceId;
  final AlertKind kind;
  final DateTime at;
  final bool seen;
}

/// Situação das proteções do Guardião em um aparelho Android.
class DeviceHealth {
  const DeviceHealth({
    required this.usageAccess,
    required this.overlay,
    required this.notifications,
    required this.admin,
    required this.monitorRunning,
    required this.checkedAt,
  });

  final bool usageAccess;
  final bool overlay;
  final bool notifications;

  /// Administrador do dispositivo (impede desinstalar sem desativá-lo antes).
  final bool admin;

  /// O serviço de acompanhamento bateu há pouco tempo (ou nem deveria estar
  /// ligado, caso em que vale `true`).
  final bool monitorRunning;
  final DateTime checkedAt;

  /// Proteções que estavam ativas em [before] e deixaram de estar agora.
  /// Sem leitura anterior não há como saber o que mudou, então não avisa.
  static List<AlertKind> newlyLost(DeviceHealth? before, DeviceHealth now) {
    if (before == null) return const [];
    return [
      if (before.usageAccess && !now.usageAccess) AlertKind.usageAccessRevoked,
      if (before.overlay && !now.overlay) AlertKind.overlayRevoked,
      if (before.notifications && !now.notifications)
        AlertKind.notificationsRevoked,
      if (before.admin && !now.admin) AlertKind.adminDisabled,
      if (before.monitorRunning && !now.monitorRunning)
        AlertKind.monitorStopped,
    ];
  }

  /// Mesmo estado das proteções, ignorando o horário da leitura.
  bool sameState(DeviceHealth? other) =>
      other != null &&
      other.usageAccess == usageAccess &&
      other.overlay == overlay &&
      other.notifications == notifications &&
      other.admin == admin &&
      other.monitorRunning == monitorRunning;

  /// Formato guardado no aparelho (SharedPreferences, escrito pelo Android).
  factory DeviceHealth.fromJson(Map<String, dynamic> json) => DeviceHealth(
    usageAccess: json['usageAccess'] == true,
    overlay: json['overlay'] == true,
    notifications: json['notifications'] == true,
    admin: json['admin'] == true,
    monitorRunning: json['monitorRunning'] != false,
    checkedAt: DateTime.fromMillisecondsSinceEpoch(
      ((json['checkedAt'] as num?) ?? 0).toInt(),
    ),
  );

  Map<String, dynamic> toJson() => {
    'usageAccess': usageAccess,
    'overlay': overlay,
    'notifications': notifications,
    'admin': admin,
    'monitorRunning': monitorRunning,
    'checkedAt': checkedAt.millisecondsSinceEpoch,
  };

  @override
  bool operator ==(Object other) =>
      other is DeviceHealth && sameState(other) && other.checkedAt == checkedAt;

  @override
  int get hashCode =>
      Object.hash(usageAccess, overlay, notifications, admin, monitorRunning);
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
