import 'dart:convert';
import 'dart:math';

import 'package:crypto/crypto.dart';
import 'package:flutter/material.dart';
import 'package:guardiao_core/guardiao_core.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// PIN de 4 dígitos que protege o painel do responsável neste aparelho.
/// É só uma trava contra o uso por engano: quem tem acesso ao aparelho pode
/// limpar os dados do app. Guardado com sal e SHA-256, nunca em texto puro.
abstract class PinStore {
  Future<bool> hasPin();
  Future<bool> verify(String pin);
  Future<void> set(String pin);
}

String _hash(String salt, String pin) =>
    sha256.convert(utf8.encode('$salt:$pin')).toString();

class PrefsPinStore implements PinStore {
  const PrefsPinStore();

  static const _saltKey = 'panel_pin_salt';
  static const _hashKey = 'panel_pin_hash';

  @override
  Future<bool> hasPin() async =>
      (await SharedPreferences.getInstance()).getString(_hashKey) != null;

  @override
  Future<bool> verify(String pin) async {
    final prefs = await SharedPreferences.getInstance();
    final salt = prefs.getString(_saltKey);
    final hash = prefs.getString(_hashKey);
    return salt != null && hash != null && _hash(salt, pin) == hash;
  }

  @override
  Future<void> set(String pin) async {
    final prefs = await SharedPreferences.getInstance();
    final salt = base64UrlEncode(
      List<int>.generate(16, (_) => Random.secure().nextInt(256)),
    );
    await prefs.setString(_saltKey, salt);
    await prefs.setString(_hashKey, _hash(salt, pin));
  }
}

class MemoryPinStore implements PinStore {
  MemoryPinStore([String? pin]) : _pin = pin;

  String? _pin;

  @override
  Future<bool> hasPin() async => _pin != null;

  @override
  Future<bool> verify(String pin) async => _pin == pin;

  @override
  Future<void> set(String pin) async => _pin = pin;
}

/// Teclado numérico com quatro bolinhas, como no design.
class PinPad extends StatefulWidget {
  const PinPad({
    super.key,
    required this.title,
    required this.subtitle,
    required this.onSubmit,
    this.hint,
  });

  final String title;
  final String subtitle;

  /// Recebe o PIN; devolve o texto do erro ou `null` se deu certo.
  final Future<String?> Function(String pin) onSubmit;
  final String? hint;

  @override
  State<PinPad> createState() => _PinPadState();
}

class _PinPadState extends State<PinPad> {
  String _pin = '';
  String? _error;
  bool _busy = false;

  void _add(String digit) {
    if (_busy || _pin.length >= 4) return;
    setState(() {
      _pin += digit;
      _error = null;
    });
  }

  void _delete() {
    if (_busy || _pin.isEmpty) return;
    setState(() => _pin = _pin.substring(0, _pin.length - 1));
  }

  Future<void> _ok() async {
    if (_busy) return;
    if (_pin.length != 4) {
      setState(() => _error = 'O PIN tem 4 números.');
      return;
    }
    setState(() => _busy = true);
    final error = await widget.onSubmit(_pin);
    if (!mounted) return;
    setState(() {
      _busy = false;
      if (error != null) {
        _error = error;
        _pin = '';
      }
    });
  }

  Widget _key(String label, {VoidCallback? onTap, Key? key, Widget? child}) =>
      Padding(
        padding: const EdgeInsets.all(6),
        child: Material(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          elevation: 1.5,
          shadowColor: const Color(0x220F172A),
          child: InkWell(
            key: key,
            borderRadius: BorderRadius.circular(20),
            onTap: onTap,
            child: SizedBox(
              height: 58,
              child: Center(
                child:
                    child ??
                    Text(
                      label,
                      style: const TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.w700,
                        color: GColors.ink,
                      ),
                    ),
              ),
            ),
          ),
        ),
      );

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 52,
          height: 52,
          decoration: BoxDecoration(
            color: GColors.orangeSoft,
            borderRadius: BorderRadius.circular(16),
          ),
          child: const Icon(Icons.lock, color: GColors.orange, size: 26),
        ),
        const SizedBox(height: 16),
        Text(widget.title, style: text.headlineSmall),
        const SizedBox(height: 4),
        Text(
          widget.subtitle,
          style: text.bodyMedium,
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 18),
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            for (var i = 0; i < 4; i++)
              Container(
                key: Key('pinDot$i'),
                width: 16,
                height: 16,
                margin: const EdgeInsets.symmetric(horizontal: 7),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: i < _pin.length ? GColors.blue : Colors.transparent,
                  border: Border.all(
                    color: i < _pin.length ? GColors.blue : GColors.blueMid,
                    width: 1.6,
                  ),
                ),
              ),
          ],
        ),
        SizedBox(
          height: 28,
          child: _error == null
              ? null
              : Center(
                  child: Text(
                    _error!,
                    key: const Key('pinError'),
                    style: const TextStyle(
                      color: GColors.redText,
                      fontSize: 13,
                    ),
                  ),
                ),
        ),
        ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 300),
          child: GridView.count(
            crossAxisCount: 3,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            childAspectRatio: 1.35,
            children: [
              for (var n = 1; n <= 9; n++)
                _key('$n', key: Key('pin_$n'), onTap: () => _add('$n')),
              _key(
                '',
                key: const Key('pin_del'),
                onTap: _delete,
                child: const Icon(Icons.backspace_outlined, color: GColors.ink),
              ),
              _key('0', key: const Key('pin_0'), onTap: () => _add('0')),
              _key('OK', key: const Key('pin_ok'), onTap: _ok),
            ],
          ),
        ),
        if (widget.hint != null) ...[
          const SizedBox(height: 8),
          GTag(widget.hint!, color: GColors.muted, background: GColors.track),
        ],
      ],
    );
  }
}
