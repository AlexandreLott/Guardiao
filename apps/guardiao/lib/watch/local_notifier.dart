import 'package:flutter_local_notifications/flutter_local_notifications.dart';

import 'parent_watch.dart';

/// Notificações do sistema (Android) para os avisos do Guardião.
class LocalNotifier implements Notifier {
  LocalNotifier();

  static const _channelId = 'guardiao_alertas';
  final _plugin = FlutterLocalNotificationsPlugin();
  bool _ready = false;

  Future<void> _init() async {
    if (_ready) return;
    await _plugin.initialize(
      settings: const InitializationSettings(
        android: AndroidInitializationSettings('@mipmap/ic_launcher'),
      ),
    );
    _ready = true;
  }

  /// Android 13+ pede permissão para mostrar notificações.
  Future<bool> requestPermission() async {
    await _init();
    final android = _plugin
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >();
    return await android?.requestNotificationsPermission() ?? true;
  }

  @override
  Future<void> show(WatchNotice notice) async {
    await _init();
    await _plugin.show(
      id: notice.id,
      title: notice.title,
      body: notice.body,
      notificationDetails: const NotificationDetails(
        android: AndroidNotificationDetails(
          _channelId,
          'Alertas do Guardião',
          channelDescription: 'Avisos de tentativa de burlar o acompanhamento e de aparelhos sem sinal.',
          importance: Importance.high,
          priority: Priority.high,
        ),
      ),
    );
  }
}
