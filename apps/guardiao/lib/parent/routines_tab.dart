import 'package:flutter/material.dart';
import 'package:guardiao_core/guardiao_core.dart';

import '../common/icons.dart';
import '../common/names.dart';
import 'device_screen.dart';

const _dayNames = ['Seg', 'Ter', 'Qua', 'Qui', 'Sex', 'Sáb', 'Dom'];

/// "Seg a sex", "Todos os dias", "Sáb e dom", "Seg, qua e sex".
String daysLabel(Set<int> days) {
  final sorted = (days.toList()..sort());
  if (sorted.length == 7) return 'Todos os dias';
  if (sorted.join() == '12345') return 'Seg a sex';
  if (sorted.join() == '67') return 'Sáb e dom';
  final names = [for (final d in sorted) _dayNames[d - 1]];
  if (names.length == 1) return names.single;
  return '${names.sublist(0, names.length - 1).join(', ')} e ${names.last}';
}

/// Rotinas sugeridas para começar.
List<Routine> suggestedRoutines() => const [
  Routine(
    id: 'r-cafe',
    name: 'Café da manhã',
    startMinute: 420,
    endMinute: 450,
    days: {1, 2, 3, 4, 5},
    icon: 'sun',
  ),
  Routine(
    id: 'r-almoco',
    name: 'Almoço',
    startMinute: 720,
    endMinute: 780,
    icon: 'fork',
  ),
  Routine(
    id: 'r-licao',
    name: 'Hora da lição',
    startMinute: 840,
    endMinute: 960,
    days: {1, 2, 3, 4, 5},
    mode: RoutineMode.studyOnly,
    icon: 'book',
  ),
  Routine(
    id: 'r-jantar',
    name: 'Jantar',
    startMinute: 1140,
    endMinute: 1200,
    icon: 'fork',
  ),
  Routine(
    id: 'r-dormir',
    name: 'Hora de dormir',
    startMinute: 1260,
    endMinute: 420,
    icon: 'moon',
  ),
];

/// "Rotinas": horários com regra especial ("Hora de dormir", "Almoço").
class RoutinesTab extends StatelessWidget {
  const RoutinesTab({super.key, required this.data, required this.onSave});

  final PanelData data;
  final Future<void> Function(DeviceConfig config) onSave;

  Future<void> _edit(BuildContext context, Routine? routine) async {
    final result = await showModalBottomSheet<_RoutineResult>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (_) => RoutineSheet(routine: routine),
    );
    if (result == null) return;
    final list = [...data.config.routines];
    final i = list.indexWhere((r) => r.id == result.routine.id);
    if (result.delete) {
      if (i >= 0) list.removeAt(i);
    } else if (i >= 0) {
      list[i] = result.routine;
    } else {
      list.add(result.routine);
    }
    await onSave(data.config.copyWith(routines: list));
  }

  @override
  Widget build(BuildContext context) {
    final routines = [...data.config.routines]
      ..sort((a, b) => a.startMinute.compareTo(b.startMinute));
    final text = Theme.of(context).textTheme;
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
      children: [
        GSectionLabel(
          'Rotinas',
          trailing: TextButton(
            key: const Key('newRoutine'),
            style: TextButton.styleFrom(
              backgroundColor: GColors.blueSoft,
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
              minimumSize: const Size(0, 34),
            ),
            onPressed: () => _edit(context, null),
            child: const Text('+ Nova rotina'),
          ),
        ),
        if (routines.isEmpty)
          GCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Nenhuma rotina ainda', style: text.titleSmall),
                const SizedBox(height: 4),
                Text(
                  'Rotinas pausam os apps em horários como refeições, lição e '
                  'hora de dormir.',
                  style: text.bodySmall,
                ),
                const SizedBox(height: 12),
                FilledButton.tonal(
                  key: const Key('suggestedRoutines'),
                  style: FilledButton.styleFrom(minimumSize: const Size(0, 44)),
                  onPressed: () => onSave(
                    data.config.copyWith(routines: suggestedRoutines()),
                  ),
                  child: const Text('Criar rotinas sugeridas'),
                ),
              ],
            ),
          )
        else
          GCard(
            padding: EdgeInsets.zero,
            child: Column(
              children: [
                for (var i = 0; i < routines.length; i++) ...[
                  if (i > 0) const Divider(height: 1),
                  _RoutineRow(
                    routine: routines[i],
                    onTap: () => _edit(context, routines[i]),
                    onToggle: (v) {
                      final list = [
                        for (final r in data.config.routines)
                          r.id == routines[i].id ? r.copyWith(enabled: v) : r,
                      ];
                      onSave(data.config.copyWith(routines: list));
                    },
                  ),
                ],
              ],
            ),
          ),
      ],
    );
  }
}

class _RoutineRow extends StatelessWidget {
  const _RoutineRow({
    required this.routine,
    required this.onTap,
    required this.onToggle,
  });

  final Routine routine;
  final VoidCallback onTap;
  final ValueChanged<bool> onToggle;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final on = routine.enabled;
    final tag = routine.mode == RoutineMode.pauseAll
        ? GTag.warn(routine.mode.label)
        : (routine.mode == RoutineMode.studyOnly
              ? GTag.info(routine.mode.label)
              : GTag.ok(routine.mode.label));
    return InkWell(
      key: Key('routine_${routine.id}'),
      onTap: onTap,
      child: Opacity(
        opacity: on ? 1 : 0.55,
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Row(
            children: [
              GIconBox(
                routineIcon(routine.icon),
                color: GColors.orange,
                background: GColors.orangeSoft,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(routine.name, style: text.titleSmall),
                    Text(
                      '${clockText(routine.startMinute)} – ${clockText(routine.endMinute)} · ${daysLabel(routine.days)}',
                      style: text.bodySmall,
                    ),
                    const SizedBox(height: 6),
                    Align(alignment: Alignment.centerLeft, child: tag),
                  ],
                ),
              ),
              Switch(
                key: Key('routineSwitch_${routine.id}'),
                value: on,
                onChanged: onToggle,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _RoutineResult {
  const _RoutineResult(this.routine, {this.delete = false});
  final Routine routine;
  final bool delete;
}

/// Folha para criar ou editar uma rotina.
class RoutineSheet extends StatefulWidget {
  const RoutineSheet({super.key, this.routine});

  final Routine? routine;

  @override
  State<RoutineSheet> createState() => _RoutineSheetState();
}

class _RoutineSheetState extends State<RoutineSheet> {
  late final _name = TextEditingController(text: widget.routine?.name ?? '');
  late int _start = widget.routine?.startMinute ?? 14 * 60;
  late int _end = widget.routine?.endMinute ?? 16 * 60;
  late final Set<int> _days = {
    ...(widget.routine?.days ?? const {1, 2, 3, 4, 5}),
  };
  late RoutineMode _mode = widget.routine?.mode ?? RoutineMode.pauseAll;
  late String _icon = widget.routine?.icon ?? 'sun';
  String? _error;

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  Future<void> _pick(bool start) async {
    final current = start ? _start : _end;
    final t = await showTimePicker(
      context: context,
      initialTime: TimeOfDay(hour: current ~/ 60, minute: current % 60),
    );
    if (t == null) return;
    setState(
      () => start
          ? _start = t.hour * 60 + t.minute
          : _end = t.hour * 60 + t.minute,
    );
  }

  void _save() {
    final name = _name.text.trim();
    if (name.isEmpty) {
      setState(() => _error = 'Dê um nome para a rotina.');
      return;
    }
    if (_days.isEmpty) {
      setState(() => _error = 'Escolha pelo menos um dia.');
      return;
    }
    if (_start == _end) {
      setState(() => _error = 'O início e o fim não podem ser iguais.');
      return;
    }
    Navigator.of(context).pop(
      _RoutineResult(
        Routine(
          id:
              widget.routine?.id ??
              'r-${DateTime.now().microsecondsSinceEpoch}',
          name: name,
          startMinute: _start,
          endMinute: _end,
          days: _days,
          mode: _mode,
          icon: _icon,
          enabled: widget.routine?.enabled ?? true,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return SafeArea(
      child: SingleChildScrollView(
        padding: EdgeInsets.fromLTRB(
          20,
          0,
          20,
          16 + MediaQuery.of(context).viewInsets.bottom,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              widget.routine == null ? 'Nova rotina' : 'Editar rotina',
              style: text.titleLarge,
            ),
            const SizedBox(height: 14),
            GField(
              fieldKey: const Key('routineName'),
              label: 'Nome',
              controller: _name,
              hint: 'Hora da lição',
              maxLength: 40,
            ),
            const SizedBox(height: 14),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    key: const Key('routineStart'),
                    onPressed: () => _pick(true),
                    child: Text('Início ${clockText(_start)}'),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: OutlinedButton(
                    key: const Key('routineEnd'),
                    onPressed: () => _pick(false),
                    child: Text('Fim ${clockText(_end)}'),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            Text('Dias', style: text.titleSmall),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (var d = 1; d <= 7; d++)
                  FilterChip(
                    key: Key('day_$d'),
                    label: Text(_dayNames[d - 1]),
                    selected: _days.contains(d),
                    onSelected: (v) =>
                        setState(() => v ? _days.add(d) : _days.remove(d)),
                  ),
              ],
            ),
            const SizedBox(height: 14),
            Text('O que acontece', style: text.titleSmall),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final m in RoutineMode.values)
                  ChoiceChip(
                    key: Key('mode_${m.name}'),
                    label: Text(m.label),
                    selected: _mode == m,
                    onSelected: (_) => setState(() => _mode = m),
                  ),
              ],
            ),
            const SizedBox(height: 14),
            Text('Ícone', style: text.titleSmall),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final e in routineIcons.entries)
                  InkWell(
                    onTap: () => setState(() => _icon = e.key),
                    borderRadius: BorderRadius.circular(14),
                    child: GIconBox(
                      e.value,
                      color: _icon == e.key ? Colors.white : GColors.muted,
                      background: _icon == e.key ? GColors.blue : GColors.track,
                      size: 44,
                    ),
                  ),
              ],
            ),
            if (_error != null) ...[
              const SizedBox(height: 12),
              Notice(_error!, isError: true),
            ],
            const SizedBox(height: 16),
            FilledButton(
              key: const Key('saveRoutine'),
              onPressed: _save,
              child: const Text('Salvar'),
            ),
            if (widget.routine != null)
              TextButton(
                key: const Key('deleteRoutine'),
                style: TextButton.styleFrom(foregroundColor: GColors.redText),
                onPressed: () =>
                    Navigator.of(context)
                        .pop(_RoutineResult(widget.routine!, delete: true)),
                child: const Text('Excluir rotina'),
              ),
          ],
        ),
      ),
    );
  }
}
