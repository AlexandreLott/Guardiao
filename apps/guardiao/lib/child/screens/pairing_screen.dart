import 'dart:async';

import 'package:flutter/material.dart';
import 'package:guardiao_core/guardiao_core.dart';
import 'package:qr_flutter/qr_flutter.dart';

import '../platform/installed_apps_source.dart';
import '../usage/usage_monitor.dart';

/// Tela do aparelho do filho antes de ser vinculado: mostra o QR (e o código
/// escrito) para o responsável ler no aparelho dele. Vale para celular e PC.
class PairingScreen extends StatefulWidget {
  const PairingScreen({
    super.key,
    required this.backend,
    required this.source,
    required this.onChangeRole,
    this.monitor,
    this.isDemo = false,
  });

  final GuardianBackend backend;
  final InstalledAppsSource source;
  final VoidCallback onChangeRole;

  /// Quando informado, o passo de permissões do Android é mostrado.
  final UsageMonitor? monitor;
  final bool isDemo;

  @override
  State<PairingScreen> createState() => _PairingScreenState();
}

enum _Step { name, permissions, qr }

class _PairingScreenState extends State<PairingScreen>
    with WidgetsBindingObserver {
  final _name = TextEditingController();
  _Step _step = _Step.name;
  Set<MonitorPermission> _missing = const {};
  PairRequest? _request;
  String? _error;
  bool _busy = false;
  Timer? _tick;
  Duration _left = Duration.zero;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _detectName();
  }

  Future<void> _detectName() async {
    final detected = await widget.source.deviceName();
    if (!mounted) return;
    if (_name.text.isEmpty) _name.text = detected;
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // Voltou da tela de configurações do Android: confere o que foi liberado.
    if (state == AppLifecycleState.resumed) _refreshPermissions();
  }

  Future<void> _refreshPermissions() async {
    final monitor = widget.monitor;
    if (monitor == null || !monitor.supported) return;
    final missing = await monitor.missingPermissions();
    if (mounted) setState(() => _missing = missing);
  }

  /// Passo "Continuar" do nome: vai para as permissões, se faltar alguma, ou
  /// direto ao QR.
  Future<void> _afterName() async {
    final name = _name.text.trim();
    if (name.isEmpty) {
      setState(() => _error = 'Dê um nome para este aparelho.');
      return;
    }
    setState(() => _error = null);
    final monitor = widget.monitor;
    if (monitor != null && monitor.supported) {
      final missing = await monitor.missingPermissions();
      final needed = missing
          .where(
            (p) =>
                p == MonitorPermission.usageAccess ||
                p == MonitorPermission.overlay,
          )
          .toSet();
      if (!mounted) return;
      if (needed.isNotEmpty) {
        setState(() {
          _missing = missing;
          _step = _Step.permissions;
        });
        return;
      }
    }
    await _toQr();
  }

  Future<void> _toQr() async {
    setState(() => _step = _Step.qr);
    await _generate();
  }

  void _back() {
    switch (_step) {
      case _Step.name:
        widget.onChangeRole();
      case _Step.permissions:
        setState(() => _step = _Step.name);
      case _Step.qr:
        _tick?.cancel();
        final request = _request;
        if (request != null) {
          unawaited(widget.backend.cancelPairRequest(request.code));
        }
        setState(() {
          _request = null;
          _error = null;
          _step = _Step.name;
        });
    }
  }

  /// Gera um código novo (o anterior é cancelado pelo backend).
  Future<void> _generate() async {
    if (_busy) return;
    final name = _name.text.trim();
    if (name.isEmpty) {
      setState(() => _error = 'Dê um nome para este aparelho.');
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final request = await widget.backend.createPairRequest(
        deviceName: name,
        platform: widget.source.platform,
      );
      if (!mounted) {
        unawaited(widget.backend.cancelPairRequest(request.code));
        return;
      }
      setState(() => _request = request);
      _startCountdown(request.expiresAt);
    } on PairingException catch (e) {
      if (mounted) setState(() => _error = e.message);
    } catch (e) {
      if (mounted) setState(() => _error = 'Algo deu errado: $e');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  void _startCountdown(DateTime expiresAt) {
    _tick?.cancel();
    void update() {
      final left = expiresAt.difference(DateTime.now());
      setState(() => _left = left.isNegative ? Duration.zero : left);
    }

    update();
    _tick = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted) return;
      update();
      // O código venceu: troca por um novo, sem o usuário precisar fazer nada.
      if (_left == Duration.zero && !_busy) _generate();
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _tick?.cancel();
    final request = _request;
    // Depois do vínculo (ou ao sair), o código não serve mais para nada.
    if (request != null) {
      unawaited(widget.backend.cancelPairRequest(request.code));
    }
    _name.dispose();
    super.dispose();
  }

  String get _countdown {
    final m = _left.inMinutes;
    final s = (_left.inSeconds % 60).toString().padLeft(2, '0');
    return '$m:$s';
  }

  @override
  Widget build(BuildContext context) {
    return switch (_step) {
      _Step.name => _nameStep(context),
      _Step.permissions => _permissionsStep(context),
      _Step.qr => _qrStep(context),
    };
  }

  Widget _nameStep(BuildContext context) => OnboardScaffold(
    title: 'Vincular este aparelho',
    subtitle: 'Dê um nome para este aparelho. O responsável vai ver esse nome.',
    onBack: _back,
    backKey: const Key('changeRoleButton'),
    bottom: FilledButton(
      key: const Key('generateButton'),
      onPressed: _afterName,
      child: const Text('Gerar código'),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        GField(
          fieldKey: const Key('nameField'),
          label: 'Nome do aparelho',
          controller: _name,
          maxLength: 80,
          hint: 'Celular da Duda',
          onSubmitted: (_) => _afterName(),
        ),
        if (_error != null) ...[
          const SizedBox(height: 16),
          Notice(_error!, isError: true),
        ],
      ],
    ),
  );

  Widget _permissionsStep(BuildContext context) {
    final monitor = widget.monitor!;
    final usageOk = !_missing.contains(MonitorPermission.usageAccess);
    final overlayOk = !_missing.contains(MonitorPermission.overlay);
    return OnboardScaffold(
      title: 'Duas permissões',
      subtitle:
          'Para medir o tempo e mostrar o aviso quando ele acabar, o Android '
          'precisa da sua autorização.',
      showLogo: false,
      onBack: _back,
      bottom: FilledButton(
        key: const Key('permissionsContinue'),
        onPressed: usageOk && overlayOk ? _toQr : null,
        child: const Text('Continuar'),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          GCard(
            padding: EdgeInsets.zero,
            child: GSettingRow(
              key: const Key('permUsage'),
              icon: Icons.schedule,
              iconColor: GColors.blue,
              iconBackground: GColors.blueSoft,
              title: 'Acesso ao uso',
              subtitle: 'Saber quanto tempo cada app ficou aberto',
              value: usageOk,
              onChanged: (_) async {
                await monitor.request(MonitorPermission.usageAccess);
                await _refreshPermissions();
              },
            ),
          ),
          const SizedBox(height: 12),
          GCard(
            padding: EdgeInsets.zero,
            child: GSettingRow(
              key: const Key('permOverlay'),
              icon: Icons.lock_outline,
              iconColor: GColors.orange,
              iconBackground: GColors.orangeSoft,
              title: 'Sobrepor outros apps',
              subtitle: 'Mostrar a tela de bloqueio por cima do jogo',
              value: overlayOk,
              onChanged: (_) async {
                await monitor.request(MonitorPermission.overlay);
                await _refreshPermissions();
              },
            ),
          ),
          const SizedBox(height: 16),
          const Notice(
            'O Guardian não lê conversas, fotos nem contatos.',
            icon: Icons.shield_outlined,
          ),
        ],
      ),
    );
  }

  Widget _qrStep(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final request = _request;
    return OnboardScaffold(
      title: 'Mostre para o responsável',
      subtitle:
          'No celular do responsável, abra o Guardian e toque em '
          '"Vincular o aparelho do seu filho". Se não der para escanear, '
          'informe o código escrito abaixo do QR.',
      showLogo: false,
      onBack: _back,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (request == null)
            const SizedBox(
              height: 240,
              child: Center(child: CircularProgressIndicator()),
            )
          else ...[
            Center(
              child: Semantics(
                label:
                    'QR de vínculo. Código '
                    '${request.code.split('').join(' ')}',
                child: Container(
                  key: const Key('pairingQr'),
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(22),
                    border: Border.all(color: const Color(0xFFEDF1F7)),
                  ),
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      QrImageView(
                        // A chave leva o texto do QR, para os testes conferirem.
                        key: ValueKey(pairingQrPayload(request.code)),
                        data: pairingQrPayload(request.code),
                        size: 216,
                        padding: EdgeInsets.zero,
                        backgroundColor: Colors.white,
                        errorCorrectionLevel: QrErrorCorrectLevel.Q,
                        eyeStyle: const QrEyeStyle(
                          eyeShape: QrEyeShape.square,
                          color: GColors.ink,
                        ),
                        dataModuleStyle: const QrDataModuleStyle(
                          dataModuleShape: QrDataModuleShape.square,
                          color: GColors.ink,
                        ),
                      ),
                      const GuardianLogo(size: 40),
                    ],
                  ),
                ),
              ),
            ),
            const SizedBox(height: 18),
            Center(
              child: Text(
                'CÓDIGO',
                style: text.bodySmall?.copyWith(letterSpacing: 2),
              ),
            ),
            const SizedBox(height: 2),
            Center(
              child: Text(
                formatPairingCode(request.code),
                key: const Key('pairingCode'),
                style: text.headlineMedium?.copyWith(letterSpacing: 6),
              ),
            ),
            const SizedBox(height: 4),
            Text(
              'Vale por mais $_countdown',
              key: const Key('countdown'),
              textAlign: TextAlign.center,
              style: text.bodySmall,
            ),
            const SizedBox(height: 14),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                for (final shade in const [0.35, 0.6, 1.0])
                  Container(
                    width: 5,
                    height: 5,
                    margin: const EdgeInsets.only(right: 3),
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: GColors.blue.withValues(alpha: shade),
                    ),
                  ),
                const SizedBox(width: 10),
                Flexible(
                  child: Text(
                    'Aguardando o responsável aprovar…',
                    style: text.titleSmall?.copyWith(color: GColors.muted),
                  ),
                ),
              ],
            ),
          ],
          if (widget.isDemo) ...[
            const SizedBox(height: 16),
            Notice(
              'Modo demonstração, sem internet. Para ver o vínculo, entre '
              'como responsável e digite o código '
              '${formatPairingCode(demoPairingCode)}.',
            ),
          ],
          if (_error != null) ...[
            const SizedBox(height: 16),
            Notice(_error!, isError: true),
          ],
          const SizedBox(height: 12),
          TextButton.icon(
            key: const Key('newCodeButton'),
            onPressed: _busy ? null : _generate,
            icon: const Icon(Icons.refresh, size: 18),
            label: const Text('Gerar novo código'),
          ),
        ],
      ),
    );
  }
}
