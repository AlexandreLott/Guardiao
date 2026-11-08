import 'package:firebase_core/firebase_core.dart';

import 'backend.dart';
import 'firebase_backend.dart';
import 'memory_backend.dart';
import 'models.dart';

/// Configuração lida de `--dart-define`, sem arquivos secretos no código.
///
/// Exemplo:
/// ```
/// flutter run \
///   --dart-define=FIREBASE_API_KEY=... \
///   --dart-define=FIREBASE_APP_ID=... \
///   --dart-define=FIREBASE_PROJECT_ID=... \
///   --dart-define=FIREBASE_MESSAGING_SENDER_ID=...
/// ```
/// Sem essas chaves (ou com `--dart-define=BACKEND=memory`), o app abre em
/// modo demonstração, com dados de exemplo e sem internet.
class AppConfig {
  const AppConfig._();

  static const backend = String.fromEnvironment('BACKEND');
  static const apiKey = String.fromEnvironment('FIREBASE_API_KEY');
  static const appId = String.fromEnvironment('FIREBASE_APP_ID');
  static const projectId = String.fromEnvironment('FIREBASE_PROJECT_ID');
  static const senderId = String.fromEnvironment('FIREBASE_MESSAGING_SENDER_ID');

  static bool get firebaseConfigured =>
      apiKey.isNotEmpty && appId.isNotEmpty && projectId.isNotEmpty;

  static bool get useFirebase => backend != 'memory' && firebaseConfigured;

  static FirebaseOptions get firebaseOptions => FirebaseOptions(
        apiKey: apiKey,
        appId: appId,
        projectId: projectId,
        messagingSenderId: senderId,
      );
}

/// Resultado da inicialização: o backend e se ele é de demonstração.
class BackendSetup {
  const BackendSetup(this.backend, {required this.isDemo});
  final GuardianBackend backend;
  final bool isDemo;
}

/// Código fixo usado no modo demonstração para vincular um aparelho do filho.
const demoPairingCode = 'DEMX2345';

/// Conta do responsável usada no modo demonstração.
const demoParentEmail = 'demo@guardiaogamer.app';
const demoParentPassword = 'demo1234';

/// Liga o Firebase quando configurado; senão usa a nuvem em memória.
Future<BackendSetup> createBackend() async {
  if (AppConfig.useFirebase) {
    await Firebase.initializeApp(options: AppConfig.firebaseOptions);
    return BackendSetup(FirebaseBackend(), isDemo: false);
  }
  final cloud = MemoryCloud();
  final backend = MemoryBackend(cloud);
  await _seedDemo(cloud);
  return BackendSetup(backend, isDemo: true);
}

/// Dados de exemplo: um responsável com um aparelho já vinculado (cheio de
/// apps, com algumas regras) e um código livre para vincular outro aparelho.
Future<void> _seedDemo(MemoryCloud cloud) async {
  final parent = MemoryBackend(cloud);
  await parent.registerParent(demoParentEmail, demoParentPassword);
  final code = await parent.createPairingCode();
  final child = MemoryBackend(cloud);
  await child.signInChild();
  await child.claimPairing(
    code: code.code,
    deviceName: 'Celular do Pedro (exemplo)',
    platform: DevicePlatform.android,
  );
  await child.syncInstalledApps(const [
    InstalledApp(id: 'com.roblox.client', name: 'Roblox', packageName: 'com.roblox.client'),
    InstalledApp(id: 'com.dts.freefireth', name: 'Free Fire', packageName: 'com.dts.freefireth'),
    InstalledApp(id: 'com.mojang.minecraftpe', name: 'Minecraft', packageName: 'com.mojang.minecraftpe'),
    InstalledApp(id: 'com.epicgames.fortnite', name: 'Fortnite', packageName: 'com.epicgames.fortnite'),
    InstalledApp(id: 'com.android.chrome', name: 'Chrome', packageName: 'com.android.chrome'),
    InstalledApp(id: 'com.whatsapp', name: 'WhatsApp', packageName: 'com.whatsapp'),
    InstalledApp(id: 'com.google.android.youtube', name: 'YouTube', packageName: 'com.google.android.youtube'),
  ]);
  await parent.setRule(child.currentUid!,
      const AppRule(appId: 'com.roblox.client', dailyLimitMinutes: 60));
  await parent.setRule(
      child.currentUid!, const AppRule(appId: 'com.dts.freefireth', blocked: true));
  // Uma semana de uso de exemplo, para o painel do responsável não ficar vazio.
  final today = cloud.now();
  const week = [
    {'com.roblox.client': 95, 'com.mojang.minecraftpe': 40, 'com.whatsapp': 20},
    {'com.roblox.client': 70, 'com.mojang.minecraftpe': 55, 'com.android.chrome': 25},
    {'com.roblox.client': 120, 'com.epicgames.fortnite': 30, 'com.whatsapp': 15},
    {'com.roblox.client': 55, 'com.google.android.youtube': 45},
    {'com.roblox.client': 80, 'com.mojang.minecraftpe': 60, 'com.whatsapp': 10},
    {'com.roblox.client': 60, 'com.mojang.minecraftpe': 35},
    {'com.roblox.client': 45, 'com.mojang.minecraftpe': 20, 'com.whatsapp': 12},
  ];
  for (var i = 0; i < week.length; i++) {
    final day = dayKey(DateTime(today.year, today.month, today.day - (week.length - 1 - i)));
    await child.reportUsage(day, week[i]);
  }
  // Segundo código, fixo, para quem quiser vincular o próprio aparelho.
  cloud.addPairing(demoPairingCode, parent.currentUid!,
      cloud.now().add(const Duration(days: 1)));
}
