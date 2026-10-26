import 'package:flutter/material.dart';

import 'models.dart';

/// Letra inicial em um círculo colorido, usada no lugar do ícone do app
/// (os ícones reais entram em uma próxima versão).
class AppAvatar extends StatelessWidget {
  const AppAvatar(this.app, {super.key, this.size = 40});

  final InstalledApp app;
  final double size;

  @override
  Widget build(BuildContext context) {
    final letter = app.name.trim().isEmpty ? '?' : app.name.trim()[0].toUpperCase();
    final hue = (app.id.hashCode.abs() % 360).toDouble();
    final dark = Theme.of(context).brightness == Brightness.dark;
    final bg = HSLColor.fromAHSL(1, hue, 0.45, dark ? 0.30 : 0.82).toColor();
    final fg = HSLColor.fromAHSL(1, hue, 0.55, dark ? 0.85 : 0.25).toColor();
    return ExcludeSemantics(
      child: Container(
        width: size,
        height: size,
        alignment: Alignment.center,
        decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(size * 0.3)),
        child: Text(letter,
            style: TextStyle(color: fg, fontWeight: FontWeight.w700, fontSize: size * 0.45)),
      ),
    );
  }
}

/// Mostra "1 h 30 min", "45 min", "sem limite".
String formatMinutes(int? minutes) {
  if (minutes == null) return 'sem limite';
  if (minutes <= 0) return '0 min';
  final h = minutes ~/ 60;
  final m = minutes % 60;
  if (h == 0) return '$m min';
  if (m == 0) return '$h h';
  return '$h h $m min';
}

/// Aviso em destaque (erro, informação).
class Notice extends StatelessWidget {
  const Notice(this.message, {super.key, this.isError = false, this.icon});

  final String message;
  final bool isError;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final bg = isError ? scheme.errorContainer : scheme.secondaryContainer;
    final fg = isError ? scheme.onErrorContainer : scheme.onSecondaryContainer;
    return Semantics(
      liveRegion: true,
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(12)),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon ?? (isError ? Icons.error_outline : Icons.info_outline), color: fg, size: 20),
            const SizedBox(width: 10),
            Expanded(child: Text(message, style: TextStyle(color: fg))),
          ],
        ),
      ),
    );
  }
}
