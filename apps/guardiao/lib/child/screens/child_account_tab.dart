import 'package:flutter/material.dart';
import 'package:guardiao_core/guardiao_core.dart';

import '../../common/names.dart';
import '../../common/pin.dart';
import '../usage/usage_controller.dart';
import 'home_screen.dart';

/// "Responsável": pede o PIN e mostra as configurações deste aparelho. Quem
/// muda limites, rotinas e missões é o responsável, no celular dele.
class ChildAccountTab extends StatefulWidget {
  const ChildAccountTab({
    super.key,
    required this.data,
    required this.usage,
    required this.pinStore,
    this.isDemo = false,
  });

  final ChildData data;
  final UsageController usage;
  final PinStore pinStore;
  final bool isDemo;

  @override
  State<ChildAccountTab> createState() => _ChildAccountTabState();
}

class _ChildAccountTabState extends State<ChildAccountTab> {
  bool _unlocked = false;
  bool? _hasPin;
  bool _changing = false;

  @override
  void initState() {
    super.initState();
    widget.pinStore.hasPin().then((v) {
      if (mounted) setState(() => _hasPin = v);
    });
  }

  @override
  void didUpdateWidget(covariant ChildAccountTab old) {
    super.didUpdateWidget(old);
    // O demo cria o PIN 1234 de forma assíncrona.
    if (_hasPin == false) {
      widget.pinStore.hasPin().then((v) {
        if (mounted && v) setState(() => _hasPin = true);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final hasPin = _hasPin;
    if (hasPin == null) return const SizedBox.shrink();
    if (!hasPin) {
      return _PinCenter(
        child: PinPad(
          key: const Key('createPin'),
          title: 'Crie um PIN',
          subtitle: 'Só o responsável deve saber. São 4 números.',
          onSubmit: (pin) async {
            await widget.pinStore.set(pin);
            if (mounted) {
              setState(() {
                _hasPin = true;
                _unlocked = true;
              });
            }
            return null;
          },
        ),
      );
    }
    if (_changing) {
      return _PinCenter(
        child: PinPad(
          key: const Key('changePin'),
          title: 'Novo PIN',
          subtitle: 'Escolha 4 números.',
          onSubmit: (pin) async {
            await widget.pinStore.set(pin);
            if (mounted) setState(() => _changing = false);
            return null;
          },
        ),
      );
    }
    if (!_unlocked) {
      return _PinCenter(
        child: PinPad(
          key: const Key('enterPin'),
          title: 'Painel do responsável',
          subtitle: 'Digite o PIN para acessar',
          hint: widget.isDemo ? 'PIN de demonstração: 1234' : null,
          onSubmit: (pin) async {
            if (await widget.pinStore.verify(pin)) {
              if (mounted) setState(() => _unlocked = true);
              return null;
            }
            return 'PIN incorreto.';
          },
        ),
      );
    }
    return _Account(
      data: widget.data,
      usage: widget.usage,
      onChangePin: () => setState(() => _changing = true),
      onLock: () => setState(() => _unlocked = false),
    );
  }
}

class _PinCenter extends StatelessWidget {
  const _PinCenter({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) => Center(
    child: SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: child,
    ),
  );
}

class _Account extends StatelessWidget {
  const _Account({
    required this.data,
    required this.usage,
    required this.onChangePin,
    required this.onLock,
  });

  final ChildData data;
  final UsageController usage;
  final VoidCallback onChangePin;
  final VoidCallback onLock;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final device = data.device;
    final label = device.parentLabel;
    final since = data.now.difference(device.pairedAt).inDays;
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
      children: [
        const GTitle('Minha conta', subtitle: 'Configurações do responsável'),
        GCard(
          child: Row(
            children: [
              Container(
                width: 56,
                height: 56,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: GColors.blue,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Text(
                  (label ?? 'R')
                      .substring(0, label == null || label.length < 2 ? 1 : 2)
                      .toUpperCase(),
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w700,
                    fontSize: 18,
                  ),
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(label ?? 'Responsável', style: text.titleMedium),
                    const SizedBox(height: 4),
                    GTag.info('Responsável'),
                  ],
                ),
              ),
            ],
          ),
        ),
        const GSectionLabel('Família'),
        GCard(
          padding: EdgeInsets.zero,
          child: GSettingRow(
            icon: Icons.person_outline,
            title: '${childName(device.name)} · ${device.platform.label}',
            subtitle: since <= 0
                ? 'vinculado hoje'
                : 'vinculado há $since ${since == 1 ? 'dia' : 'dias'}',
            onTap: null,
          ),
        ),
        const GSectionLabel('Segurança'),
        GCard(
          padding: EdgeInsets.zero,
          child: Column(
            children: [
              GSettingRow(
                key: const Key('changePinRow'),
                icon: Icons.key_outlined,
                title: 'Alterar PIN do painel',
                subtitle: 'PIN atual: ••••',
                onTap: onChangePin,
              ),
              if (usage.supported && usage.adminActive != null) ...[
                const Divider(height: 1),
                GSettingRow(
                  key: const Key('adminRow'),
                  icon: Icons.shield_outlined,
                  title: 'Proteção contra desinstalação',
                  subtitle:
                      'Avisa o responsável se tentarem remover o Guardian',
                  value: usage.adminActive!,
                  onChanged: usage.adminActive!
                      ? null
                      : (_) => usage.requestAdmin(),
                ),
              ],
            ],
          ),
        ),
        const SizedBox(height: 20),
        OutlinedButton.icon(
          key: const Key('lockPanelButton'),
          onPressed: onLock,
          icon: const Icon(Icons.lock_outline),
          label: const Text('Trancar o painel'),
        ),
        const SizedBox(height: 8),
        Text(
          'Limites, rotinas e missões são definidos no aparelho do responsável.',
          textAlign: TextAlign.center,
          style: text.bodySmall,
        ),
      ],
    );
  }
}
