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
    this.alwaysAllowed = false,
  });

  final String appId;

  /// Fica liberado mesmo no "Bloqueio geral" e nas rotinas que pausam tudo.
  final bool alwaysAllowed;

  /// Limite diário em minutos. `null` significa sem limite.
  final int? dailyLimitMinutes;

  /// Quando verdadeiro, o app fica bloqueado o dia todo.
  final bool blocked;

  bool get isDefault => dailyLimitMinutes == null && !blocked && !alwaysAllowed;

  factory AppRule.fromMap(String appId, Map<String, dynamic> data) => AppRule(
    appId: appId,
    dailyLimitMinutes: (data['dailyLimitMinutes'] as num?)?.toInt(),
    blocked: (data['blocked'] as bool?) ?? false,
    alwaysAllowed: (data['alwaysAllowed'] as bool?) ?? false,
  );

  Map<String, dynamic> toMap() => {
    'dailyLimitMinutes': dailyLimitMinutes,
    'blocked': blocked,
    'alwaysAllowed': alwaysAllowed,
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

// ---------------------------------------------------------------------------
// Rotinas, missões e créditos
// ---------------------------------------------------------------------------

/// Grupo de apps para filtrar a lista e somar o uso no relatório.
enum AppCategory {
  games('Jogos'),
  videos('Vídeos'),
  social('Redes'),
  study('Estudo'),
  other('Outros');

  const AppCategory(this.label);
  final String label;
}

const _gameWords = [
  'game',
  'jogo',
  'roblox',
  'minecraft',
  'fortnite',
  'freefire',
  'free fire',
  'brawl',
  'clash',
  'subway',
  'puzzle',
  'candy',
  'pubg',
  'garena',
  'supercell',
  'mojang',
  'epicgames',
  'among',
  'stumble',
  'cod',
  'valorant',
  'steam',
];
const _videoWords = [
  'youtube',
  'netflix',
  'disney',
  'primevideo',
  'hbo',
  'max',
  'twitch',
  'globoplay',
  'video',
  'vídeo',
  'tiktok',
  'kwai',
  'cinema',
  'tv',
];
const _socialWords = [
  'whatsapp',
  'instagram',
  'facebook',
  'telegram',
  'discord',
  'snapchat',
  'twitter',
  'messenger',
  'pinterest',
  'reddit',
  'bluesky',
  'threads',
];
const _studyWords = [
  'duolingo',
  'khan',
  'classroom',
  'escola',
  'estudo',
  'edu',
  'dictionary',
  'dicionário',
  'wikipedia',
  'calculator',
  'calculadora',
  'spotify',
  'music',
  'música',
  'deezer',
  'kindle',
  'livros',
  'books',
];

/// Melhor palpite da categoria de um app, pelo nome e pelo pacote.
AppCategory categoryOf(InstalledApp app) {
  final text = '${app.name} ${app.packageName ?? app.id}'.toLowerCase();
  bool any(List<String> words) => words.any(text.contains);
  if (any(_studyWords)) return AppCategory.study;
  if (any(_gameWords)) return AppCategory.games;
  if (any(_videoWords)) return AppCategory.videos;
  if (any(_socialWords)) return AppCategory.social;
  return AppCategory.other;
}

/// O que uma rotina faz enquanto está valendo.
enum RoutineMode {
  /// Pausa todos os apps (menos os "sempre liberados").
  pauseAll('pause_all', 'Pausa tudo'),

  /// Só deixa abrir apps de estudo e música.
  studyOnly('study_only', 'Só estudo e música'),

  /// Só deixa abrir jogos.
  gamesOnly('games_only', 'Libera só jogos');

  const RoutineMode(this.wire, this.label);
  final String wire;
  final String label;

  static RoutineMode parse(String? value) => RoutineMode.values.firstWhere(
    (m) => m.wire == value,
    orElse: () => RoutineMode.pauseAll,
  );
}

/// Horário recorrente com uma regra especial ("Hora de dormir", "Almoço").
class Routine {
  const Routine({
    required this.id,
    required this.name,
    required this.startMinute,
    required this.endMinute,
    this.days = const {1, 2, 3, 4, 5, 6, 7},
    this.mode = RoutineMode.pauseAll,
    this.icon = 'sun',
    this.enabled = true,
  });

  final String id;
  final String name;

  /// Minutos desde a meia-noite (07:00 = 420).
  final int startMinute;
  final int endMinute;

  /// Dias da semana (1 = segunda ... 7 = domingo).
  final Set<int> days;
  final RoutineMode mode;

  /// Nome do ícone (veja `routineIcons` no app).
  final String icon;
  final bool enabled;

  /// A rotina vale neste instante? Faixas que atravessam a meia-noite
  /// (21:00–07:00) valem até de manhã, no dia seguinte ao marcado.
  bool isActive(DateTime now) {
    if (!enabled) return false;
    final minute = now.hour * 60 + now.minute;
    if (startMinute <= endMinute) {
      return days.contains(now.weekday) &&
          minute >= startMinute &&
          minute < endMinute;
    }
    if (minute >= startMinute) return days.contains(now.weekday);
    if (minute < endMinute) {
      final yesterday = now.weekday == 1 ? 7 : now.weekday - 1;
      return days.contains(yesterday);
    }
    return false;
  }

  Routine copyWith({
    String? name,
    int? startMinute,
    int? endMinute,
    Set<int>? days,
    RoutineMode? mode,
    String? icon,
    bool? enabled,
  }) => Routine(
    id: id,
    name: name ?? this.name,
    startMinute: startMinute ?? this.startMinute,
    endMinute: endMinute ?? this.endMinute,
    days: days ?? this.days,
    mode: mode ?? this.mode,
    icon: icon ?? this.icon,
    enabled: enabled ?? this.enabled,
  );

  Map<String, dynamic> toMap() => {
    'id': id,
    'name': name,
    'start': startMinute,
    'end': endMinute,
    'days': (days.toList()..sort()),
    'mode': mode.wire,
    'icon': icon,
    'enabled': enabled,
  };

  static Routine? fromMap(Object? raw) {
    if (raw is! Map) return null;
    final id = raw['id'];
    final name = raw['name'];
    final start = raw['start'];
    final end = raw['end'];
    if (id is! String || name is! String || start is! num || end is! num) {
      return null;
    }
    final days = <int>{
      for (final d in (raw['days'] as List? ?? const []))
        if (d is num && d >= 1 && d <= 7) d.toInt(),
    };
    return Routine(
      id: id,
      name: name,
      startMinute: start.toInt().clamp(0, 1439),
      endMinute: end.toInt().clamp(0, 1439),
      days: days.isEmpty ? const {1, 2, 3, 4, 5, 6, 7} : days,
      mode: RoutineMode.parse(raw['mode'] as String?),
      icon: (raw['icon'] as String?) ?? 'sun',
      enabled: raw['enabled'] != false,
    );
  }
}

/// Tarefa da família que rende tempo extra ("Arrumar o quarto", +50 min).
class Mission {
  const Mission({
    required this.id,
    required this.title,
    required this.minutes,
    this.icon = 'broom',
  });

  final String id;
  final String title;
  final int minutes;
  final String icon;

  Map<String, dynamic> toMap() => {
    'id': id,
    'title': title,
    'minutes': minutes,
    'icon': icon,
  };

  static Mission? fromMap(Object? raw) {
    if (raw is! Map) return null;
    final id = raw['id'];
    final title = raw['title'];
    final minutes = raw['minutes'];
    if (id is! String || title is! String || minutes is! num) return null;
    return Mission(
      id: id,
      title: title,
      minutes: minutes.toInt().clamp(1, 240),
      icon: (raw['icon'] as String?) ?? 'broom',
    );
  }
}

/// Ajustes do responsável para um aparelho (um documento só).
class DeviceConfig {
  const DeviceConfig({
    this.lockAll = false,
    this.routines = const [],
    this.missions = const [],
    this.blockMessage = '',
    this.suggestedMissionId,
    this.allowRequests = true,
  });

  /// "Bloqueio geral": pausa tudo agora, menos os apps sempre liberados.
  final bool lockAll;
  final List<Routine> routines;
  final List<Mission> missions;

  /// Texto da tela de bloqueio ("Arrume o quarto e ganhe mais 50 minutos!").
  final String blockMessage;
  final String? suggestedMissionId;

  /// A criança pode pedir mais tempo.
  final bool allowRequests;

  Mission? get suggestedMission {
    for (final m in missions) {
      if (m.id == suggestedMissionId) return m;
    }
    return null;
  }

  /// Rotinas valendo agora.
  List<Routine> activeRoutines(DateTime now) => [
    for (final r in routines)
      if (r.isActive(now)) r,
  ];

  DeviceConfig copyWith({
    bool? lockAll,
    List<Routine>? routines,
    List<Mission>? missions,
    String? blockMessage,
    String? suggestedMissionId,
    bool clearSuggested = false,
    bool? allowRequests,
  }) => DeviceConfig(
    lockAll: lockAll ?? this.lockAll,
    routines: routines ?? this.routines,
    missions: missions ?? this.missions,
    blockMessage: blockMessage ?? this.blockMessage,
    suggestedMissionId: clearSuggested
        ? null
        : (suggestedMissionId ?? this.suggestedMissionId),
    allowRequests: allowRequests ?? this.allowRequests,
  );

  Map<String, dynamic> toMap() => {
    'lockAll': lockAll,
    'routines': [for (final r in routines) r.toMap()],
    'missions': [for (final m in missions) m.toMap()],
    'blockMessage': blockMessage,
    'suggestedMissionId': suggestedMissionId ?? '',
    'allowRequests': allowRequests,
  };

  factory DeviceConfig.fromMap(Map<String, dynamic>? data) {
    if (data == null) return const DeviceConfig();
    final suggested = data['suggestedMissionId'] as String?;
    return DeviceConfig(
      lockAll: data['lockAll'] == true,
      routines: [
        for (final r in (data['routines'] as List? ?? const []))
          ?Routine.fromMap(r),
      ],
      missions: [
        for (final m in (data['missions'] as List? ?? const []))
          ?Mission.fromMap(m),
      ],
      blockMessage: (data['blockMessage'] as String?) ?? '',
      suggestedMissionId: (suggested == null || suggested.isEmpty)
          ? null
          : suggested,
      allowRequests: data['allowRequests'] != false,
    );
  }
}

/// Missões sugeridas na primeira vez.
const defaultMissions = [
  Mission(
    id: 'm-quarto',
    title: 'Arrumar o quarto',
    minutes: 50,
    icon: 'broom',
  ),
  Mission(
    id: 'm-louca',
    title: 'Lavar a louça do almoço',
    minutes: 30,
    icon: 'dish',
  ),
  Mission(id: 'm-ler', title: 'Ler 20 minutos', minutes: 30, icon: 'book'),
  Mission(
    id: 'm-cachorro',
    title: 'Passear com o cachorro',
    minutes: 15,
    icon: 'pet',
  ),
];

enum ClaimStatus {
  pending,
  approved,
  rejected;

  static ClaimStatus parse(String? value) => ClaimStatus.values.firstWhere(
    (s) => s.name == value,
    orElse: () => ClaimStatus.pending,
  );
}

/// "Fiz a tarefa": pedido de crédito da criança, que o responsável aprova.
class Claim {
  const Claim({
    required this.id,
    required this.title,
    required this.minutes,
    required this.status,
    required this.createdAt,
    this.decidedAt,
    this.usedDay,
  });

  final String id;
  final String title;
  final int minutes;
  final ClaimStatus status;
  final DateTime createdAt;
  final DateTime? decidedAt;

  /// Dia (`2026-11-10`) em que o crédito foi usado; `null` = ainda disponível.
  final String? usedDay;

  bool get available => status == ClaimStatus.approved && usedDay == null;
}

/// Minutos de crédito aprovados e ainda não usados.
int availableCredit(Iterable<Claim> claims) =>
    claims.where((c) => c.available).fold(0, (sum, c) => sum + c.minutes);

/// Minutos extras valendo no [day] (créditos usados nesse dia).
int bonusMinutesOf(Iterable<Claim> claims, String day) => claims
    .where((c) => c.status == ClaimStatus.approved && c.usedDay == day)
    .fold(0, (sum, c) => sum + c.minutes);
