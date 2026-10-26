import 'package:flutter/material.dart';
import 'package:guardiao_core/guardiao_core.dart';

import 'add_device_sheet.dart';
import 'device_screen.dart';

class DevicesScreen extends StatefulWidget {
  const DevicesScreen({super.key, required this.backend, this.isDemo = false});

  final GuardianBackend backend;
  final bool isDemo;

  @override
  State<DevicesScreen> createState() => _DevicesScreenState();
}

class _DevicesScreenState extends State<DevicesScreen> {
  late final Stream<List<PairedDevice>> _devices = widget.backend.watchDevices();

  Future<void> _add(List<PairedDevice> current) async {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (_) => AddDeviceSheet(
        backend: widget.backend,
        knownDeviceIds: {for (final d in current) d.id},
      ),
    );
  }

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
              IconButton(
                tooltip: 'Sair',
                icon: const Icon(Icons.logout),
                onPressed: widget.backend.signOut,
              ),
            ],
          ),
          floatingActionButton: FloatingActionButton.extended(
            key: const Key('addDeviceButton'),
            onPressed: () => _add(devices),
            icon: const Icon(Icons.add),
            label: const Text('Adicionar aparelho'),
          ),
          body: SafeArea(
            child: Builder(builder: (context) {
              if (snap.hasError) {
                return Padding(
                  padding: const EdgeInsets.all(16),
                  child: Notice('Não foi possível carregar os aparelhos. ${snap.error}',
                      isError: true),
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
                  device: devices[i],
                  onTap: () => Navigator.of(context).push(MaterialPageRoute<void>(
                    builder: (_) => DeviceScreen(
                      backend: widget.backend,
                      device: devices[i],
                    ),
                  )),
                ),
              );
            }),
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
            Icon(Icons.devices_other, size: 64, color: Theme.of(context).colorScheme.outline),
            const SizedBox(height: 16),
            Text('Nenhum aparelho ainda', style: text.titleLarge),
            const SizedBox(height: 8),
            Text(
              'Instale o app do filho no celular ou no computador dele, '
              'toque em "Adicionar aparelho" aqui e digite o código no outro aparelho.',
              textAlign: TextAlign.center,
              style: text.bodyMedium,
            ),
          ],
        ),
      ),
    );
  }
}

class _DeviceTile extends StatelessWidget {
  const _DeviceTile({required this.device, required this.onTap});

  final PairedDevice device;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final online = device.isOnline(DateTime.now());
    final scheme = Theme.of(context).colorScheme;
    return Card(
      child: ListTile(
        onTap: onTap,
        leading: Icon(
          device.platform == DevicePlatform.windows ? Icons.computer : Icons.smartphone,
          size: 32,
        ),
        title: Text(device.name),
        subtitle: Text('${device.platform.label} · ${lastSeenLabel(device.lastSeen, DateTime.now())}'),
        trailing: Icon(Icons.circle,
            size: 12, color: online ? scheme.secondary : scheme.outlineVariant,
            semanticLabel: online ? 'Online' : 'Offline'),
      ),
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
