import 'package:flutter_test/flutter_test.dart';
import 'package:guardiao/child/usage/usage_monitor.dart';
import 'package:guardiao/watch/headless_sync.dart';
import 'package:guardiao_core/guardiao_core.dart';

void main() {
  test(
    'sem tela aberta, o bloqueio geral do responsável chega ao medidor',
    () async {
      final cloud = MemoryCloud();
      final parent = MemoryBackend(cloud);
      await parent.registerParent('mae@exemplo.com', 'segredo1');
      final child = MemoryBackend(cloud);
      await child.signInChild();
      final request = await child.createPairRequest(
        deviceName: 'Celular do Pedro',
        platform: DevicePlatform.android,
      );
      final device = await parent.approvePairRequest(request.code);
      await child.syncInstalledApps(const [
        InstalledApp(
          id: 'roblox',
          name: 'Roblox',
          packageName: 'com.roblox.client',
        ),
      ]);

      final monitor = DemoUsageMonitor();
      final sync = HeadlessSync(
        backend: child,
        monitor: monitor,
        platform: DevicePlatform.android,
        pollEvery: const Duration(hours: 1),
      )..start();
      await Future<void>.delayed(const Duration(milliseconds: 50));
      expect(monitor.startedExtras.lockAll, isFalse);

      // O responsável liga o bloqueio geral; nenhuma tela do filho está aberta.
      final config = await parent.watchConfig(device.id).first;
      await parent.saveConfig(device.id, config.copyWith(lockAll: true));
      await Future<void>.delayed(const Duration(milliseconds: 50));
      expect(monitor.startedExtras.lockAll, isTrue);
      // Com o bloqueio geral, todos os apps entram na vigilância.
      expect(monitor.started.map((a) => a.key), contains('com.roblox.client'));

      await sync.stop();
    },
  );
}
