import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';

import 'update_installer.dart';
import 'update_models.dart';
import 'update_source.dart';

enum UpdateStatus {
  idle,
  available,
  downloading,
  needsPermission,
  readyToInstall,
  error,
}

/// Avisa que há versão nova, baixa e abre o instalador. Quem desenha a barra
/// só escuta este objeto.
class UpdateController extends ChangeNotifier {
  UpdateController({
    required this.source,
    required this.installer,
    this.recheckEvery = const Duration(hours: 6),
  });

  final UpdateSource source;
  final UpdateInstaller installer;
  final Duration recheckEvery;

  UpdateStatus status = UpdateStatus.idle;
  AppUpdate? update;

  /// 0 a 1 durante o download (`null` se o tamanho é desconhecido).
  double? progress;
  String? error;
  String currentName = '';
  bool _dismissed = false;
  bool _disposed = false;
  File? _file;
  Timer? _timer;

  bool get supported => installer.supported;

  /// A barra só aparece quando há algo a mostrar.
  bool get visible => supported && status != UpdateStatus.idle && !_dismissed;

  void begin() {
    if (!supported) return;
    unawaited(check());
    _timer = Timer.periodic(recheckEvery, (_) => unawaited(check()));
  }

  /// Consulta o GitHub. Não atrapalha um download ou instalação em andamento.
  Future<void> check() async {
    if (!supported || _busy) return;
    final local = await installer.currentBuild();
    currentName = await installer.currentName();
    final latest = await source.latest();
    if (_disposed || _busy) return;
    if (latest != null && latest.build > local) {
      if (update?.build != latest.build) {
        _file = null;
        _dismissed = false;
      }
      update = latest;
      if (status == UpdateStatus.idle || status == UpdateStatus.error) {
        status = UpdateStatus.available;
      }
    } else if (status == UpdateStatus.available) {
      status = UpdateStatus.idle;
    }
    _notify();
  }

  bool get _busy =>
      status == UpdateStatus.downloading ||
      status == UpdateStatus.readyToInstall;

  /// Baixa (se ainda não baixou) e abre o instalador.
  Future<void> start() async {
    final target = update;
    if (target == null || status == UpdateStatus.downloading) return;
    error = null;
    try {
      var file = _file;
      if (file == null || !await file.exists()) {
        status = UpdateStatus.downloading;
        progress = 0;
        _notify();
        file = await installer.download(target, (p) {
          progress = p;
          _notify();
        });
        _file = file;
      }
      await _install(file);
    } on Object catch (e) {
      _file = null;
      error = _message(e);
      status = UpdateStatus.error;
      _notify();
    }
  }

  Future<void> _install(File file) async {
    if (!await installer.canInstall()) {
      status = UpdateStatus.needsPermission;
      _notify();
      await installer.openInstallSettings();
      return;
    }
    status = UpdateStatus.readyToInstall;
    _notify();
    await installer.install(file);
  }

  /// Depois de liberar "instalar apps desconhecidos", segue para o instalador.
  Future<void> continueInstall() async {
    final file = _file;
    if (file == null) return start();
    try {
      await _install(file);
    } on Object catch (e) {
      error = _message(e);
      status = UpdateStatus.error;
      _notify();
    }
  }

  void dismiss() {
    _dismissed = true;
    _notify();
  }

  String _message(Object e) {
    if (e is SocketException || e is HttpException) {
      return 'Sem internet ou o download falhou. Tente de novo.';
    }
    if (e is FormatException) return e.message;
    return 'Não deu para atualizar: $e';
  }

  void _notify() {
    if (!_disposed) notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    _timer?.cancel();
    super.dispose();
  }
}
