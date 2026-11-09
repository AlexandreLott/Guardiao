import 'dart:convert';

import 'package:guardiao_core/guardiao_core.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Um aviso a mostrar ao responsável como notificação.
class WatchNotice {
  const WatchNotice({
    required this.key,
    required this.title,
    required this.body,
  });

  /// Identifica o fato (para não avisar duas vezes).
  final String key;
  final String title;
  final String body;

  /// Número da notificação no sistema, estável para a mesma [key].
  int get id => key.hashCode & 0x7fffffff;
}

abstract class Notifier {
  Future<void> show(WatchNotice notice);
}

/// Guarda quais fatos já viraram notificação.
abstract class NoticeStore {
  Future<Set<String>> read();
  Future<void> write(Set<String> keys);
}

class PrefsNoticeStore implements NoticeStore {
  const PrefsNoticeStore();

  static const _key = 'notified_keys';

  @override
  Future<Set<String>> read() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.reload();
    final raw = prefs.getString(_key);
    if (raw == null) return {};
    try {
      return {for (final k in jsonDecode(raw) as List) '$k'};
    } catch (_) {
      return {};
    }
  }

  @override
  Future<void> write(Set<String> keys) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_key, jsonEncode(keys.toList()));
  }
}

class MemoryNoticeStore implements NoticeStore {
  Set<String> keys = {};

  @override
  Future<Set<String>> read() async => {...keys};

  @override
  Future<void> write(Set<String> value) async => keys = {...value};
}

class FakeNotifier implements Notifier {
  final shown = <WatchNotice>[];

  @override
  Future<void> show(WatchNotice notice) async => shown.add(notice);
}

/// Texto de "há quanto tempo", em linguagem simples.
String sinceText(Duration d) {
  if (d.inMinutes < 60) return '${d.inMinutes} min';
  if (d.inHours < 24) return '${d.inHours} h';
  return '${d.inDays} d';
}

/// Lado do responsável: junta o que merece notificação (avisos novos do
/// filho e aparelhos sem sinal) e mostra o que ainda não foi mostrado.
class ParentWatch {
  ParentWatch({
    required this.backend,
    required this.notifier,
    required this.store,
    DateTime Function()? clock,
  }) : _clock = clock ?? DateTime.now;

  final GuardianBackend backend;
  final Notifier notifier;
  final NoticeStore store;
  final DateTime Function() _clock;

  static const _maxKeys = 300;

  /// Retorna as notificações mostradas.
  Future<List<WatchNotice>> run() async {
    if (backend.currentUid == null) return const [];
    final devices = await backend.watchDevices().first;
    final now = _clock();
    final known = await store.read();
    final fresh = <WatchNotice>[];

    for (final device in devices) {
      final alerts = await backend.watchAlerts(device.id).first;
      for (final alert in alerts) {
        if (alert.seen) continue;
        final key = 'alert:${device.id}:${alert.id}';
        if (known.contains(key)) continue;
        fresh.add(
          WatchNotice(
            key: key,
            title: '${device.name}: ${alert.kind.title}',
            body: alert.kind.description,
          ),
        );
      }
      final last = device.lastSeen;
      if (last != null && device.hasNoSignal(now)) {
        // Um aviso por período de silêncio (identificado pelo último contato).
        final key = 'silent:${device.id}:${last.millisecondsSinceEpoch}';
        if (!known.contains(key)) {
          fresh.add(
            WatchNotice(
              key: key,
              title: '${device.name}: sem comunicação',
              body:
                  'O Guardião não se comunica há ${sinceText(now.difference(last))}. '
                  'Pode ter sido desinstalado ou parado à força, ou o aparelho '
                  'está desligado ou sem internet.',
            ),
          );
        }
      }
    }

    final shown = <WatchNotice>[];
    for (final notice in fresh) {
      try {
        await notifier.show(notice);
        known.add(notice.key);
        shown.add(notice);
      } catch (_) {
        // Tenta de novo na próxima rodada.
      }
    }
    if (shown.isNotEmpty) {
      final keep = known.length > _maxKeys
          ? known.skip(known.length - _maxKeys).toSet()
          : known;
      await store.write(keep);
    }
    return shown;
  }
}
