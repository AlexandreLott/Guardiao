import 'dart:io';

import 'package:flutter/widgets.dart';
import 'package:guardiao_core/guardiao_core.dart';
import 'package:workmanager/workmanager.dart';

import '../role/role.dart';
import 'child_watch.dart';
import 'health_source.dart';
import 'local_notifier.dart';
import 'parent_watch.dart';

/// Nome da tarefa periódica (a mesma para as duas funções; quem decide o que
/// fazer é a função gravada no aparelho).
const _taskName = 'guardiao.verificacao';

/// O Android só permite tarefas periódicas a cada 15 minutos, no mínimo.
const watchEvery = Duration(minutes: 15);

/// Liga ou desliga a verificação em segundo plano conforme a função.
abstract class BackgroundTasks {
  Future<void> enable(DeviceRole role);
  Future<void> disable();

  factory BackgroundTasks.detect() =>
      Platform.isAndroid ? WorkmanagerTasks() : NoBackgroundTasks();
}

class NoBackgroundTasks implements BackgroundTasks {
  @override
  Future<void> enable(DeviceRole role) async {}

  @override
  Future<void> disable() async {}
}

class WorkmanagerTasks implements BackgroundTasks {
  WorkmanagerTasks({LocalNotifier? notifier})
    : _notifier = notifier ?? LocalNotifier();

  final LocalNotifier _notifier;
  bool _initialized = false;

  Future<void> _init() async {
    if (_initialized) return;
    await Workmanager().initialize(guardiaoBackgroundDispatcher);
    _initialized = true;
  }

  @override
  Future<void> enable(DeviceRole role) async {
    try {
      await _init();
      await Workmanager().registerPeriodicTask(
        _taskName,
        _taskName,
        frequency: watchEvery,
        existingWorkPolicy: ExistingPeriodicWorkPolicy.update,
        constraints: Constraints(networkType: NetworkType.connected),
      );
      if (role == DeviceRole.parent) await _notifier.requestPermission();
    } catch (_) {
      // Sem a verificação periódica o app continua funcionando; os avisos
      // só aparecem quando o responsável abre o aplicativo.
    }
  }

  @override
  Future<void> disable() async {
    try {
      await _init();
      await Workmanager().cancelByUniqueName(_taskName);
    } catch (_) {}
  }
}

/// Ponto de entrada da tarefa periódica. Roda em um motor do Flutter à parte,
/// sem telas.
@pragma('vm:entry-point')
void guardiaoBackgroundDispatcher() {
  Workmanager().executeTask((task, inputData) async {
    try {
      WidgetsFlutterBinding.ensureInitialized();
      final setup = await createBackend();
      if (setup.isDemo) return true;
      // Dá tempo de o Firebase restaurar o login salvo no aparelho.
      await setup.backend.authStateChanges().first.timeout(
        const Duration(seconds: 15),
        onTimeout: () => null,
      );
      switch (await SharedPrefsRoleStore().read()) {
        case DeviceRole.child:
          await runChildWatch(
            backend: setup.backend,
            source: HealthSource.detect(background: true),
            store: const PrefsHealthStore(),
          );
        case DeviceRole.parent:
          await ParentWatch(
            backend: setup.backend,
            notifier: LocalNotifier(),
            store: const PrefsNoticeStore(),
          ).run();
        case null:
          break;
      }
      return true;
    } catch (_) {
      // Falhas de rede são normais; a próxima rodada tenta de novo.
      return true;
    }
  });
}
