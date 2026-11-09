import 'package:flutter/material.dart';
import 'package:guardiao_core/guardiao_core.dart';

import '../qr/qr_scanner.dart';
import 'add_device_screen.dart';
import 'device_screen.dart';

class DevicesScreen extends StatefulWidget {
  const DevicesScreen({
    super.key,
    required this.backend,
    required this.onChangeRole,
    required this.scanner,
    this.isDemo = false,
  });

  final GuardianBackend backend;
  final QrScanner scanner;
  final VoidCallback onChangeRole;
  final bool isDemo;

  @override
  State<DevicesScreen> createState() => _DevicesScreenState();
}

class _DevicesScreenState extends State<DevicesScreen> {
  late final Stream<List<PairedDevice>> _devices = widget.backend
      .watchDevices();

  Future<void> _add() => Navigator.of(context).push(
    MaterialPageRoute<void>(
      builder: (_) => AddDeviceScreen(
        backend: widget.backend,
        scanner: widget.scanner,
        isDemo: widget.isDemo,
      ),
    ),
  );

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<PairedDevice>>(
      stream: _devices,
      builder: (context, snap) {
        final devices = snap.data ?? const <PairedDevice>[];
        return Scaffold(
          appBar: AppBar(
            title: const Text('Meus aparelhos'),
            actions: [
              PopupMenuButton<String>(
                key: const Key('accountMenu'),
                tooltip: 'Conta',
                onSelected: (value) {
                  if (value == 'role') {
                    widget.onChangeRole();
                  } else {
                    widget.backend.signOut();
                  }
                },
                itemBuilder: (_) => const [
                  PopupMenuItem(
                    key: Key('signOutItem'),
                    value: 'signOut',
                    child: Text('Sair da conta'),
                  ),
                  PopupMenuItem(
                    key: Key('changeRoleItem'),
                    value: 'role',
                    child: Text('Trocar a função deste aparelho'),
                  ),
                ],
              ),
            ],
          ),
          floatingActionButton: FloatingActionButton.extended(
            key: const Key('addDeviceButton'),
            onPressed: _add,
            icon: const Icon(Icons.add),
            label: const Text('Adicionar aparelho'),
          ),
          body: SafeArea(
            child: Builder(
              builder: (context) {
                if (snap.hasError) {
                  return Padding(
                    padding: const EdgeInsets.all(16),
                    child: Notice(
                      'Não foi possível carregar os aparelhos. ${snap.error}',
                      isError: true,
                    ),
                  );
                }
                if (!snap.hasData) {
                  return const Center(child: CircularProgressIndicator());
                }
                if (devices.isEmpty) return const _EmptyState();
                return ListView.separated(
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 96),
                  itemCount: devices.length,
                  separatorBuilder: (_, _) => const SizedBox(height: 8),
                  itemBuilder: (context, i) => _DeviceTile(
                    backend: widget.backend,
                    device: devices[i],
                    onTap: () => Navigator.of(context).push(
                      MaterialPageRoute<void>(
                        builder: (_) => DeviceScreen(
                          backend: widget.backend,
                          device: devices[i],
                        ),
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
        );
      },
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState();

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.devices_other,
              size: 64,
              color: Theme.of(context).colorScheme.outline,
            ),
            const SizedBox(height: 16),
            Text('Nenhum aparelho ainda', style: text.titleLarge),
            const SizedBox(height: 8),
            Text(
              'Instale o Guardião no celular ou no computador do filho e '
              'selecione "Este aparelho é do filho"; a tela exibirá um QR. '
              'Em seguida, toque em "Adicionar aparelho" e escaneie o QR. '
              'É possível vincular quantos aparelhos forem necessários.',
              textAlign: TextAlign.center,
              style: text.bodyMedium,
            ),
          ],
        ),
      ),
    );
  }
}

class _DeviceTile extends StatefulWidget {
  const _DeviceTile({
    required this.backend,
    required this.device,
    required this.onTap,
  });

  final GuardianBackend backend;
  final PairedDevice device;
  final VoidCallback onTap;

  @override
  State<_DeviceTile> createState() => _DeviceTileState();
}

class _DeviceTileState extends State<_DeviceTile> {
  late final Stream<List<TamperAlert>> _alerts = widget.backend.watchAlerts(
    widget.device.id,
  );

  @override
  Widget build(BuildContext context) {
    final device = widget.device;
    final now = DateTime.now();
    final online = device.isOnline(now);
    final scheme = Theme.of(context).colorScheme;
    return StreamBuilder<List<TamperAlert>>(
      stream: _alerts,
      builder: (context, snap) {
        final unseen = (snap.data ?? const []).where((a) => !a.seen).length;
        final silent = device.hasNoSignal(now);
        final warn = unseen > 0 || silent;
        return Card(
          child: ListTile(
            onTap: widget.onTap,
            leading: Icon(
              device.platform == DevicePlatform.windows
                  ? Icons.computer
                  : Icons.smartphone,
              size: 32,
            ),
            title: Text(device.name),
            subtitle: Text(
              '${device.platform.label} · ${lastSeenLabel(device.lastSeen, now)}',
              style: silent ? TextStyle(color: scheme.error) : null,
            ),
            trailing: warn
                ? Badge(
                    key: const Key('deviceWarning'),
                    label: Text(unseen > 0 ? '$unseen' : '!'),
                    backgroundColor: scheme.error,
                    child: Icon(
                      Icons.warning_amber_rounded,
                      color: scheme.error,
                    ),
                  )
                : Icon(
                    Icons.circle,
                    size: 12,
                    color: online ? scheme.secondary : scheme.outlineVariant,
                    semanticLabel: online ? 'Online' : 'Offline',
                  ),
          ),
        );
      },
    );
  }
}

/// "Online agora", "Visto há 3 h", "Nunca conectou".
String lastSeenLabel(DateTime? lastSeen, DateTime now) {
  if (lastSeen == null) return 'Nunca conectou';
  final diff = now.difference(lastSeen);
  if (diff < const Duration(minutes: 30)) return 'Online agora';
  if (diff < const Duration(hours: 1)) return 'Visto há ${diff.inMinutes} min';
  if (diff < const Duration(days: 1)) return 'Visto há ${diff.inHours} h';
  return 'Visto há ${diff.inDays} d';
}
