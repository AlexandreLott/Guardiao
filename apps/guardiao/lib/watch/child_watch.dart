import 'package:guardiao_core/guardiao_core.dart';

import 'health_source.dart';

/// Lado do filho: confere as proteções, avisa o responsável do que foi
/// retirado e mantém o "sinal de vida" em dia.
class HealthReporter {
  HealthReporter({
    required this.backend,
    required this.source,
    required this.store,
  });

  final GuardianBackend backend;
  final HealthSource source;
  final HealthStore store;

  /// Retorna os avisos enviados nesta rodada.
  Future<List<AlertKind>> run() async {
    final now = await source.read();
    if (now == null) {
      await backend.touch();
      return const [];
    }
    final before = await store.read();
    final lost = DeviceHealth.newlyLost(before, now);
    for (final kind in lost) {
      await backend.reportAlert(kind);
    }
    // Mesmo sem mudança, o contato precisa chegar à nuvem: é ele que prova
    // ao responsável que o aplicativo continua instalado e ativo.
    await backend.reportHealth(now);
    await store.write(now);
    return lost;
  }
}

/// Rotina da tarefa periódica do aparelho do filho. Só age se o aparelho já
/// estiver vinculado.
Future<void> runChildWatch({
  required GuardianBackend backend,
  required HealthSource source,
  required HealthStore store,
}) async {
  if (backend.currentUid == null) return;
  final device = await backend.watchOwnDevice().first;
  if (device == null) return;
  await HealthReporter(backend: backend, source: source, store: store).run();
}
