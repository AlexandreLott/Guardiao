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
        final empty = snap.hasData && devices.isEmpty;
        return Scaffold(
          floatingActionButton: snap.hasData && !empty
              ? FloatingActionButton(
                  key: const Key('addDeviceButton'),
                  tooltip: 'Adicionar aparelho',
                  onPressed: _add,
                  backgroundColor: GColors.orange,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(18),
                  ),
                  child: const Icon(Icons.add, size: 28),
                )
              : null,
          body: SafeArea(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                GTitle(
                  'Meus aparelhos',
                  subtitle: empty
                      ? 'Olá! Vamos vincular o primeiro aparelho.'
                      : 'Toque em um aparelho para ver o painel.',
                  trailing: PopupMenuButton<String>(
                    key: const Key('accountMenu'),
                    tooltip: 'Conta',
                    icon: const GAvatar('R', size: 36),
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
                ),
                Expanded(
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
                      if (devices.isEmpty) return _EmptyState(onAdd: _add);
                      return ListView.separated(
                        padding: const EdgeInsets.fromLTRB(16, 4, 16, 96),
                        itemCount: devices.length,
                        separatorBuilder: (_, _) => const SizedBox(height: 12),
                        itemBuilder: (context, i) => _DeviceTile(
                          backend: widget.backend,
                          device: devices[i],
                          onTap: () => Navigator.of(context).push(
                            MaterialPageRoute<void>(
                              builder: (_) => DeviceScreen(
                                backend: widget.backend,
                                device: devices[i],
                                onChangeRole: widget.onChangeRole,
                              ),
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState({required this.onAdd});

  final VoidCallback onAdd;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return Column(
      children: [
        Expanded(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 32),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Stack(
                    clipBehavior: Clip.none,
                    children: [
                      const GIconBox(Icons.smartphone, size: 84),
                      Positioned(
                        right: -6,
                        bottom: -6,
                        child: Container(
                          width: 28,
                          height: 28,
                          decoration: BoxDecoration(
                            color: GColors.orange,
                            shape: BoxShape.circle,
                            border: Border.all(color: GColors.bg, width: 3),
                          ),
                          child: const Icon(
                            Icons.add,
                            color: Colors.white,
                            size: 16,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 22),
                  Text('Nenhum aparelho ainda', style: text.titleLarge),
                  const SizedBox(height: 8),
                  Text(
                    'Instale o Guardian no celular ou no computador do filho e '
                    'escolha "É do meu filho ou filha". Depois vincule aqui. '
                    'É possível vincular quantos aparelhos forem necessários.',
                    textAlign: TextAlign.center,
                    style: text.bodyMedium,
                  ),
                ],
              ),
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(24, 0, 24, 20),
          child: FilledButton(
            key: const Key('addDeviceButton'),
            onPressed: onAdd,
            child: const Text('Vincular o aparelho do seu filho'),
          ),
        ),
      ],
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
    return StreamBuilder<List<TamperAlert>>(
      stream: _alerts,
      builder: (context, snap) {
        final unseen = (snap.data ?? const []).where((a) => !a.seen).length;
        final silent = device.hasNoSignal(now);
        final warn = unseen > 0 || silent;
        return GCard(
          onTap: widget.onTap,
          child: Row(
            children: [
              GIconBox(
                device.platform == DevicePlatform.windows
                    ? Icons.computer
                    : Icons.smartphone,
                color: GColors.orange,
                background: GColors.orangeSoft,
                size: 48,
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      device.name,
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '${device.platform.label} · '
                      '${lastSeenLabel(device.lastSeen, now)}',
                      style: Theme.of(context).textTheme.bodySmall
                          ?.copyWith(color: silent ? GColors.redText : null),
                    ),
                  ],
                ),
              ),
              if (warn)
                Badge(
                  key: const Key('deviceWarning'),
                  label: Text(unseen > 0 ? '$unseen' : '!'),
                  backgroundColor: GColors.red,
                  child: const Icon(
                    Icons.warning_amber_rounded,
                    color: GColors.red,
                  ),
                )
              else if (online)
                const GTag('Online', icon: Icons.circle)
              else
                const Icon(Icons.chevron_right, color: GColors.muted),
            ],
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
