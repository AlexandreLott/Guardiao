import 'package:flutter/material.dart';
import 'package:guardiao_core/guardiao_core.dart';

import 'app.dart';
import 'child/platform/installed_apps_source.dart';
import 'child/usage/usage_monitor.dart';
import 'common/pin.dart';
import 'qr/qr_scanner.dart';
import 'role/role.dart';
import 'update/update_controller.dart';
import 'update/update_installer.dart';
import 'update/update_source.dart';
import 'watch/background_tasks.dart';
import 'watch/headless_sync.dart';
import 'watch/health_source.dart';

/// Função fixa do aparelho (`parent` ou `child`), usada nos APKs de teste
/// "Guardian Mãe" e "Guardian Filho", que convivem no mesmo celular.
const _fixedRole = String.fromEnvironment('ROLE');

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final setup = await createBackend();
  final roleStore = SharedPrefsRoleStore();
  final fixed = switch (_fixedRole) {
    'parent' => DeviceRole.parent,
    'child' => DeviceRole.child,
    _ => null,
  };
  if (fixed != null) await roleStore.write(fixed);
  final updates = UpdateController(
    source: GithubUpdateSource(),
    installer: UpdateInstaller.detect(),
  )..begin();
  runApp(
    GuardiaoApp(
      backend: setup.backend,
      roleStore: roleStore,
      source: InstalledAppsSource.detect(),
      monitor: UsageMonitor.detect(),
      scanner: QrScanner.detect(),
      initialRole: fixed ?? await roleStore.read(),
      isDemo: setup.isDemo,
      showWelcome: true,
      updates: fixed == null ? updates : null,
      background: BackgroundTasks.detect(),
      healthSource: HealthSource.detect(),
      healthStore: const PrefsHealthStore(),
      pinStore: const PrefsPinStore(),
    ),
  );
}

// Guardado para o coletor de lixo não encerrar a sincronização.
// ignore: unused_element
HeadlessSync? _headless;

/// Roda dentro do serviço de bloqueio do Android, num motor do Flutter sem
/// telas: mantém as regras do aparelho do filho em dia com a nuvem mesmo com
/// o app fechado. Só age se este aparelho é o do filho e já está vinculado.
@pragma('vm:entry-point')
Future<void> guardianHeadlessSync() async {
  WidgetsFlutterBinding.ensureInitialized();
  try {
    final setup = await createBackend();
    if (setup.isDemo) return;
    final backend = setup.backend;
    // Dá tempo de o Firebase restaurar o login salvo no aparelho.
    await backend.authStateChanges().first.timeout(
      const Duration(seconds: 15),
      onTimeout: () => null,
    );
    if (backend.currentUid == null) return;
    if (await SharedPrefsRoleStore().read() != DeviceRole.child) return;
    _headless = HeadlessSync(
      backend: backend,
      monitor: UsageMonitor.detect(),
      platform: InstalledAppsSource.detect().platform,
    )..start();
  } catch (_) {
    // Sem a sincronização sem tela, tudo segue como antes: as regras chegam
    // quando o app é aberto.
  }
}
