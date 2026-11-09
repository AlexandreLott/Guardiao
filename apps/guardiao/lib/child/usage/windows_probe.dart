import 'dart:ffi';
import 'dart:io';

import 'package:ffi/ffi.dart';

/// O que o medidor do Windows precisa saber do sistema. Separado para o
/// medidor poder ser testado sem Windows.
abstract class SystemProbe {
  /// Nome do .exe da janela em primeiro plano (como `RobloxPlayerBeta.exe`).
  String? foregroundExe();

  /// Segundos desde o último toque no teclado ou mouse.
  int idleSeconds();

  /// Encerra todos os processos com esse nome.
  Future<void> kill(String exe);
}

final class _LastInputInfo extends Struct {
  @Uint32()
  external int cbSize;

  @Uint32()
  external int dwTime;
}

typedef _GetForegroundWindowC = Pointer<Void> Function();
typedef _GetForegroundWindowD = Pointer<Void> Function();
typedef _GetWindowThreadProcessIdC = Uint32 Function(
  Pointer<Void>,
  Pointer<Uint32>,
);
typedef _GetWindowThreadProcessIdD = int Function(
  Pointer<Void>,
  Pointer<Uint32>,
);
typedef _GetLastInputInfoC = Int32 Function(Pointer<_LastInputInfo>);
typedef _GetLastInputInfoD = int Function(Pointer<_LastInputInfo>);
typedef _OpenProcessC = Pointer<Void> Function(Uint32, Int32, Uint32);
typedef _OpenProcessD = Pointer<Void> Function(int, int, int);
typedef _QueryImageNameC = Int32 Function(
  Pointer<Void>,
  Uint32,
  Pointer<Utf16>,
  Pointer<Uint32>,
);
typedef _QueryImageNameD = int Function(
  Pointer<Void>,
  int,
  Pointer<Utf16>,
  Pointer<Uint32>,
);
typedef _CloseHandleC = Int32 Function(Pointer<Void>);
typedef _CloseHandleD = int Function(Pointer<Void>);
typedef _GetTickCountC = Uint32 Function();
typedef _GetTickCountD = int Function();

/// Usa as funções do Windows (user32/kernel32) por FFI. Só funciona no Windows.
class WindowsProbe implements SystemProbe {
  WindowsProbe() {
    final user32 = DynamicLibrary.open('user32.dll');
    final kernel32 = DynamicLibrary.open('kernel32.dll');
    _foregroundWindow = user32
        .lookupFunction<_GetForegroundWindowC, _GetForegroundWindowD>(
          'GetForegroundWindow',
        );
    _threadProcessId = user32
        .lookupFunction<_GetWindowThreadProcessIdC, _GetWindowThreadProcessIdD>(
          'GetWindowThreadProcessId',
        );
    _lastInput = user32.lookupFunction<_GetLastInputInfoC, _GetLastInputInfoD>(
      'GetLastInputInfo',
    );
    _openProcess = kernel32.lookupFunction<_OpenProcessC, _OpenProcessD>(
      'OpenProcess',
    );
    _queryImageName = kernel32
        .lookupFunction<_QueryImageNameC, _QueryImageNameD>(
          'QueryFullProcessImageNameW',
        );
    _closeHandle = kernel32.lookupFunction<_CloseHandleC, _CloseHandleD>(
      'CloseHandle',
    );
    _tickCount = kernel32.lookupFunction<_GetTickCountC, _GetTickCountD>(
      'GetTickCount',
    );
  }

  late final _GetForegroundWindowD _foregroundWindow;
  late final _GetWindowThreadProcessIdD _threadProcessId;
  late final _GetLastInputInfoD _lastInput;
  late final _OpenProcessD _openProcess;
  late final _QueryImageNameD _queryImageName;
  late final _CloseHandleD _closeHandle;
  late final _GetTickCountD _tickCount;

  static const _processQueryLimitedInformation = 0x1000;

  @override
  String? foregroundExe() {
    final window = _foregroundWindow();
    if (window == nullptr) return null;
    final pidPtr = calloc<Uint32>();
    try {
      _threadProcessId(window, pidPtr);
      final pid = pidPtr.value;
      if (pid == 0) return null;
      final handle = _openProcess(_processQueryLimitedInformation, 0, pid);
      if (handle == nullptr) return null;
      final buffer = calloc<Uint16>(1024).cast<Utf16>();
      final size = calloc<Uint32>()..value = 1024;
      try {
        if (_queryImageName(handle, 0, buffer, size) == 0) return null;
        final path = buffer.toDartString(length: size.value);
        final name = path.split(RegExp(r'[\\/]')).last.trim();
        return name.isEmpty ? null : name;
      } finally {
        calloc.free(buffer);
        calloc.free(size);
        _closeHandle(handle);
      }
    } finally {
      calloc.free(pidPtr);
    }
  }

  @override
  int idleSeconds() {
    final info = calloc<_LastInputInfo>();
    try {
      info.ref.cbSize = sizeOf<_LastInputInfo>();
      if (_lastInput(info) == 0) return 0;
      // GetTickCount dá a volta a cada ~49 dias; a subtração sem sinal resolve.
      final elapsed = (_tickCount() - info.ref.dwTime) & 0xFFFFFFFF;
      return elapsed ~/ 1000;
    } finally {
      calloc.free(info);
    }
  }

  @override
  Future<void> kill(String exe) async {
    // Só aceita um nome de arquivo simples; nada de caminhos ou opções.
    if (!RegExp(r'^[\w .\-()]+\.exe$', caseSensitive: false).hasMatch(exe)) {
      return;
    }
    await Process.run('taskkill', ['/IM', exe, '/F']);
  }
}
