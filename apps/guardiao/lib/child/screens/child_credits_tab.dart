import 'package:flutter/material.dart';
import 'package:guardiao_core/guardiao_core.dart';

import '../../common/icons.dart';
import 'home_screen.dart';

/// "Créditos": missões da família que viram tempo extra.
class ChildCreditsTab extends StatefulWidget {
  const ChildCreditsTab({
    super.key,
    required this.data,
    required this.onClaim,
    required this.onUse,
  });

  final ChildData data;
  final Future<void> Function(String title, int minutes) onClaim;
  final Future<void> Function(List<Claim> available) onUse;

  @override
  State<ChildCreditsTab> createState() => _ChildCreditsTabState();
}

class _ChildCreditsTabState extends State<ChildCreditsTab> {
  bool _busy = false;
  String? _error;

  Future<void> _run(Future<void> Function() action) async {
    if (_busy) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await action();
    } catch (e) {
      if (mounted) setState(() => _error = 'Não deu certo: $e');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  /// Pedido de hoje para a missão, se houver.
  Claim? _claimOf(Mission m) {
    final today = widget.data.today;
    for (final c in widget.data.claims) {
      if (c.title == m.title && dayKey(c.createdAt) == today) return c;
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final data = widget.data;
    final text = Theme.of(context).textTheme;
    final available = data.claims.where((c) => c.available).toList();
    final credit = availableCredit(data.claims);
    final history = data.claims.take(8).toList();
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
      children: [
        const GTitle('Créditos', subtitle: 'Missões que viram tempo extra'),
        GHero(
          color: GColors.orange,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      'Seus créditos',
                      style: text.titleSmall?.copyWith(
                        color: Colors.white.withValues(alpha: 0.9),
                      ),
                    ),
                  ),
                  if (credit > 0)
                    const GTag(
                      'Disponível agora',
                      color: Colors.white,
                      background: Color(0x33FFFFFF),
                    ),
                ],
              ),
              const SizedBox(height: 4),
              Text(
                formatDur(credit),
                key: const Key('creditTotal'),
                style: text.headlineMedium?.copyWith(
                  color: Colors.white,
                  fontSize: 36,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                data.bonus > 0
                    ? 'Hoje você já ganhou ${formatDur(data.bonus)} extras'
                    : 'Vira tempo extra de hoje quando você usar',
                style: text.titleSmall?.copyWith(
                  color: Colors.white,
                  fontSize: 13,
                ),
              ),
              const SizedBox(height: 14),
              FilledButton.icon(
                key: const Key('useCreditButton'),
                style: FilledButton.styleFrom(
                  backgroundColor: Colors.white,
                  foregroundColor: GColors.orangeDark,
                  disabledBackgroundColor: Colors.white.withValues(alpha: 0.5),
                  disabledForegroundColor: GColors.orangeDark.withValues(
                    alpha: 0.6,
                  ),
                ),
                onPressed: credit > 0 && !_busy
                    ? () => _run(() => widget.onUse(available))
                    : null,
                icon: const Icon(Icons.star_border_rounded),
                label: const Text('Usar crédito'),
              ),
            ],
          ),
        ),
        if (_error != null) ...[
          const SizedBox(height: 12),
          Notice(_error!, isError: true),
        ],
        const GSectionLabel('Missões da família'),
        if (data.config.missions.isEmpty)
          const GCard(
            child: Text(
              'O responsável ainda não criou missões. Quando criar, elas '
              'aparecem aqui.',
            ),
          )
        else
          GCard(
            padding: EdgeInsets.zero,
            child: Column(
              children: [
                for (var i = 0; i < data.config.missions.length; i++) ...[
                  if (i > 0) const Divider(height: 1),
                  _MissionRow(
                    mission: data.config.missions[i],
                    claim: _claimOf(data.config.missions[i]),
                    canAsk: data.config.allowRequests,
                    busy: _busy,
                    onDone: () => _run(
                      () => widget.onClaim(
                        data.config.missions[i].title,
                        data.config.missions[i].minutes,
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
        const GSectionLabel('Histórico'),
        if (history.isEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4),
            child: Text('Nada por aqui ainda.', style: text.bodyMedium),
          )
        else
          GCard(
            padding: EdgeInsets.zero,
            child: Column(
              children: [
                for (var i = 0; i < history.length; i++) ...[
                  if (i > 0) const Divider(height: 1),
                  _HistoryRow(claim: history[i], now: data.now),
                ],
              ],
            ),
          ),
      ],
    );
  }
}

class _MissionRow extends StatelessWidget {
  const _MissionRow({
    required this.mission,
    required this.claim,
    required this.canAsk,
    required this.busy,
    required this.onDone,
  });

  final Mission mission;
  final Claim? claim;
  final bool canAsk;
  final bool busy;
  final VoidCallback onDone;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final Widget trailing;
    if (claim?.status == ClaimStatus.pending) {
      trailing = GTag.warn('Esperando aprovação');
    } else if (claim?.status == ClaimStatus.approved) {
      trailing = const GTag('Feita', icon: Icons.check);
    } else if (!canAsk) {
      trailing = const SizedBox.shrink();
    } else {
      trailing = FilledButton(
        key: Key('claim_${mission.id}'),
        style: FilledButton.styleFrom(
          minimumSize: const Size(64, 40),
          padding: const EdgeInsets.symmetric(horizontal: 18),
        ),
        onPressed: busy ? null : onDone,
        child: const Text('Fiz!'),
      );
    }
    return Padding(
      padding: const EdgeInsets.all(14),
      child: Row(
        children: [
          GIconBox(
            missionIcon(mission.icon),
            color: GColors.orange,
            background: GColors.orangeSoft,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(mission.title, style: text.titleSmall),
                Text(
                  '+${mission.minutes} min de diversão',
                  style: text.bodySmall,
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Flexible(child: trailing),
        ],
      ),
    );
  }
}

class _HistoryRow extends StatelessWidget {
  const _HistoryRow({required this.claim, required this.now});

  final Claim claim;
  final DateTime now;

  String get _when {
    final t = claim.decidedAt ?? claim.createdAt;
    final hh =
        '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}';
    final sameDay = dayKey(t) == dayKey(now);
    return sameDay ? 'hoje, $hh' : '${t.day}/${t.month}, $hh';
  }

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final (icon, label) = switch (claim.status) {
      ClaimStatus.approved => (
        Icons.add,
        'Ganhou ${claim.minutes} min · ${claim.title}',
      ),
      ClaimStatus.rejected => (Icons.close, 'Recusado · ${claim.title}'),
      ClaimStatus.pending => (
        Icons.hourglass_empty,
        'Pediu ${claim.minutes} min · ${claim.title}',
      ),
    };
    return Padding(
      padding: const EdgeInsets.all(14),
      child: Row(
        children: [
          Container(
            width: 34,
            height: 34,
            decoration: BoxDecoration(
              color: claim.status == ClaimStatus.rejected
                  ? GColors.redSoft
                  : GColors.greenSoft,
              shape: BoxShape.circle,
            ),
            child: Icon(
              icon,
              size: 18,
              color: claim.status == ClaimStatus.rejected
                  ? GColors.redText
                  : GColors.greenText,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: text.titleSmall),
                Text(_when, style: text.bodySmall),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
