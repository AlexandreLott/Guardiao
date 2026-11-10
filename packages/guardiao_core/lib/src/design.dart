import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'theme.dart';

// ---------------------------------------------------------------------------
// Logo
// ---------------------------------------------------------------------------

/// Coração azul e laranja com duas pessoas dentro (o ícone do Guardian).
class GuardianLogo extends StatelessWidget {
  const GuardianLogo({super.key, this.size = 48, this.framed = true});

  final double size;

  /// Com o quadrado branco de cantos arredondados atrás.
  final bool framed;

  @override
  Widget build(BuildContext context) {
    final mark = CustomPaint(
      size: Size.square(framed ? size * 0.72 : size),
      painter: _HeartPainter(),
    );
    return ExcludeSemantics(
      child: framed
          ? Container(
              width: size,
              height: size,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(size * 0.3),
                boxShadow: const [
                  BoxShadow(
                    color: Color(0x140F172A),
                    blurRadius: 12,
                    offset: Offset(0, 4),
                  ),
                ],
              ),
              child: mark,
            )
          : mark,
    );
  }
}

class _HeartPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final s = size.width / 100;
    canvas.save();
    canvas.scale(s);

    final heart = Path()
      ..moveTo(50, 92)
      ..cubicTo(14, 66, 4, 44, 6, 30)
      ..cubicTo(8, 14, 22, 8, 33, 10)
      ..cubicTo(42, 12, 47, 18, 50, 24)
      ..cubicTo(53, 18, 58, 12, 67, 10)
      ..cubicTo(78, 8, 92, 14, 94, 30)
      ..cubicTo(96, 44, 86, 66, 50, 92)
      ..close();

    canvas.save();
    canvas.clipPath(heart);
    canvas.drawRect(
      const Rect.fromLTWH(0, 0, 50, 100),
      Paint()..color = GColors.blue,
    );
    canvas.drawRect(
      const Rect.fromLTWH(50, 0, 50, 100),
      Paint()..color = GColors.orange,
    );
    canvas.restore();

    // Duas pessoas.
    final white = Paint()..color = Colors.white;
    final cream = Paint()..color = const Color(0xFFFFE3C8);
    final lime = Paint()..color = GColors.lime;
    canvas.drawCircle(const Offset(40, 42), 7, white);
    canvas.drawCircle(const Offset(60, 46), 6, cream);
    final body1 = Path()
      ..addArc(const Rect.fromLTWH(28, 52, 24, 24), math.pi, math.pi);
    canvas.drawPath(body1, white);
    final body2 = Path()
      ..addArc(const Rect.fromLTWH(49, 55, 22, 22), math.pi, math.pi);
    canvas.drawPath(body2, lime);

    // Brilho.
    final star = Path()
      ..moveTo(90, 4)
      ..lineTo(92.5, 10)
      ..lineTo(98.5, 12.5)
      ..lineTo(92.5, 15)
      ..lineTo(90, 21)
      ..lineTo(87.5, 15)
      ..lineTo(81.5, 12.5)
      ..lineTo(87.5, 10)
      ..close();
    canvas.drawPath(star, lime);
    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

// ---------------------------------------------------------------------------
// Blocos
// ---------------------------------------------------------------------------

/// Cartão branco com sombra leve.
class GCard extends StatelessWidget {
  const GCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(16),
    this.onTap,
    this.color,
    this.borderColor,
  });

  final Widget child;
  final EdgeInsetsGeometry padding;
  final VoidCallback? onTap;
  final Color? color;
  final Color? borderColor;

  @override
  Widget build(BuildContext context) {
    final radius = BorderRadius.circular(20);
    return Container(
      decoration: BoxDecoration(
        color: color ?? Colors.white,
        borderRadius: radius,
        border: Border.all(color: borderColor ?? const Color(0xFFEDF1F7)),
        boxShadow: const [
          BoxShadow(
            color: Color(0x0F0F172A),
            blurRadius: 14,
            offset: Offset(0, 4),
          ),
        ],
      ),
      child: Material(
        type: MaterialType.transparency,
        borderRadius: radius,
        child: InkWell(
          borderRadius: radius,
          onTap: onTap,
          child: Padding(padding: padding, child: child),
        ),
      ),
    );
  }
}

/// Quadradinho colorido com um ícone.
class GIconBox extends StatelessWidget {
  const GIconBox(
    this.icon, {
    super.key,
    this.color = GColors.blue,
    this.background = GColors.blueSoft,
    this.size = 44,
  });

  final IconData icon;
  final Color color;
  final Color background;
  final double size;

  @override
  Widget build(BuildContext context) => Container(
    width: size,
    height: size,
    decoration: BoxDecoration(
      color: background,
      borderRadius: BorderRadius.circular(size * 0.3),
    ),
    child: Icon(icon, color: color, size: size * 0.5),
  );
}

/// Etiqueta arredondada ("Dentro do limite", "Esgotado"...).
class GTag extends StatelessWidget {
  const GTag(
    this.text, {
    super.key,
    this.color = GColors.greenText,
    this.background = GColors.greenSoft,
    this.icon,
  });

  factory GTag.ok(String text, {Key? key}) => GTag(text, key: key);
  factory GTag.bad(String text, {Key? key}) =>
      GTag(text, key: key, color: GColors.redText, background: GColors.redSoft);
  factory GTag.warn(String text, {Key? key}) => GTag(
    text,
    key: key,
    color: GColors.orangeDark,
    background: GColors.orangeSoft,
  );
  factory GTag.info(String text, {Key? key}) =>
      GTag(text, key: key, color: GColors.blue, background: GColors.blueSoft);

  final String text;
  final Color color;
  final Color background;
  final IconData? icon;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
    decoration: BoxDecoration(
      color: background,
      borderRadius: BorderRadius.circular(99),
    ),
    child: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (icon != null) ...[
          Icon(icon, size: 13, color: color),
          const SizedBox(width: 4),
        ],
        Flexible(
          child: Text(
            text,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: color,
              fontSize: 12,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
      ],
    ),
  );
}

/// Título pequeno de seção ("Jogos monitorados", "Família").
class GSectionLabel extends StatelessWidget {
  const GSectionLabel(this.text, {super.key, this.trailing});

  final String text;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.fromLTRB(4, 8, 4, 8),
    child: Row(
      children: [
        Expanded(
          child: Text(
            text,
            style: const TextStyle(
              color: GColors.muted,
              fontSize: 14,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
        ?trailing,
      ],
    ),
  );
}

/// Barra de progresso fina e arredondada.
class GProgress extends StatelessWidget {
  const GProgress(
    this.value, {
    super.key,
    this.color = GColors.green,
    this.height = 7,
  });

  final double value;
  final Color color;
  final double height;

  @override
  Widget build(BuildContext context) => ClipRRect(
    borderRadius: BorderRadius.circular(99),
    child: LinearProgressIndicator(
      value: value.clamp(0.0, 1.0),
      minHeight: height,
      color: color,
      backgroundColor: GColors.track,
    ),
  );
}

/// Cartão grande e colorido com um círculo decorativo ("Tempo de tela hoje").
class GHero extends StatelessWidget {
  const GHero({
    super.key,
    required this.child,
    this.color = GColors.blue,
    this.padding = const EdgeInsets.fromLTRB(20, 18, 20, 18),
  });

  final Widget child;
  final Color color;
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) => ClipRRect(
    borderRadius: BorderRadius.circular(24),
    child: DecoratedBox(
      decoration: BoxDecoration(color: color),
      child: Stack(
        children: [
          Positioned(
            right: -36,
            top: -48,
            child: Container(
              width: 140,
              height: 140,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.white.withValues(alpha: 0.14),
              ),
            ),
          ),
          Padding(padding: padding, child: child),
        ],
      ),
    ),
  );
}

/// Letra num círculo colorido (o "D" da Duda).
class GAvatar extends StatelessWidget {
  const GAvatar(
    this.name, {
    super.key,
    this.size = 36,
    this.color = GColors.lime,
    this.foreground = GColors.ink,
  });

  final String name;
  final double size;
  final Color color;
  final Color foreground;

  @override
  Widget build(BuildContext context) {
    final letter = name.trim().isEmpty ? '?' : name.trim()[0].toUpperCase();
    return Container(
      width: size,
      height: size,
      alignment: Alignment.center,
      decoration: BoxDecoration(color: color, shape: BoxShape.circle),
      child: Text(
        letter,
        style: TextStyle(
          color: foreground,
          fontWeight: FontWeight.w700,
          fontSize: size * 0.42,
        ),
      ),
    );
  }
}

/// Topo das telas internas: logo, "Guardian" e o nome de quem está usando.
class GHeader extends StatelessWidget {
  const GHeader({super.key, this.userName, this.online = true, this.trailing});

  final String? userName;
  final bool online;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
    child: Row(
      children: [
        const GuardianLogo(size: 40),
        const SizedBox(width: 12),
        const Text(
          guardianName,
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.w700,
            color: GColors.ink,
          ),
        ),
        const Spacer(),
        if (trailing != null)
          trailing!
        else if (userName != null)
          Container(
            padding: const EdgeInsets.fromLTRB(4, 4, 12, 4),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(99),
              boxShadow: const [
                BoxShadow(
                  color: Color(0x140F172A),
                  blurRadius: 10,
                  offset: Offset(0, 3),
                ),
              ],
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                GAvatar(userName!, size: 30),
                const SizedBox(width: 8),
                Text(
                  userName!,
                  style: const TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 14,
                  ),
                ),
                const SizedBox(width: 6),
                Container(
                  width: 9,
                  height: 9,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: online ? GColors.green : const Color(0xFFCBD5E1),
                  ),
                ),
              ],
            ),
          ),
      ],
    ),
  );
}

/// Título e subtítulo das telas internas ("Relatório", "Últimos 7 dias...").
class GTitle extends StatelessWidget {
  const GTitle(this.title, {super.key, this.subtitle, this.trailing});

  final String title;
  final String? subtitle;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.fromLTRB(20, 12, 20, 12),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: Theme.of(context).textTheme.headlineMedium),
              if (subtitle != null) ...[
                const SizedBox(height: 2),
                Text(subtitle!, style: Theme.of(context).textTheme.bodyMedium),
              ],
            ],
          ),
        ),
        ?trailing,
      ],
    ),
  );
}

/// Abas em "pílula" (Hoje / 7 dias / 30 dias; Resumo / Apps / ...).
class GSegmented extends StatelessWidget {
  const GSegmented({
    super.key,
    required this.labels,
    required this.index,
    required this.onChanged,
    this.icons,
    this.badges,
  });

  final List<String> labels;
  final int index;
  final ValueChanged<int> onChanged;
  final List<IconData>? icons;

  /// Número em uma bolinha laranja sobre a aba (pedidos para aprovar).
  final Map<int, int>? badges;

  @override
  Widget build(BuildContext context) {
    final withIcons = icons != null;
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: const Color(0xFFECEFF6),
        borderRadius: BorderRadius.circular(18),
      ),
      child: Row(
        children: [
          for (var i = 0; i < labels.length; i++)
            Expanded(
              child: Semantics(
                button: true,
                selected: i == index,
                label: labels[i],
                child: GestureDetector(
                  key: Key('seg_$i'),
                  behavior: HitTestBehavior.opaque,
                  onTap: () => onChanged(i),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 160),
                    padding: EdgeInsets.symmetric(vertical: withIcons ? 8 : 10),
                    decoration: BoxDecoration(
                      color: i == index ? Colors.white : Colors.transparent,
                      borderRadius: BorderRadius.circular(14),
                      boxShadow: i == index
                          ? const [
                              BoxShadow(
                                color: Color(0x140F172A),
                                blurRadius: 8,
                                offset: Offset(0, 2),
                              ),
                            ]
                          : null,
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (withIcons)
                          Stack(
                            clipBehavior: Clip.none,
                            children: [
                              Icon(
                                icons![i],
                                size: 22,
                                color: i == index
                                    ? GColors.blue
                                    : GColors.muted,
                              ),
                              if ((badges?[i] ?? 0) > 0)
                                Positioned(
                                  right: -10,
                                  top: -6,
                                  child: Container(
                                    width: 17,
                                    height: 17,
                                    alignment: Alignment.center,
                                    decoration: const BoxDecoration(
                                      color: GColors.orange,
                                      shape: BoxShape.circle,
                                    ),
                                    child: Text(
                                      '${badges![i]}',
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontSize: 10,
                                        fontWeight: FontWeight.w700,
                                      ),
                                    ),
                                  ),
                                ),
                            ],
                          ),
                        if (withIcons) const SizedBox(height: 2),
                        Text(
                          labels[i],
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: i == index
                                ? FontWeight.w700
                                : FontWeight.w500,
                            color: i == index ? GColors.blue : GColors.muted,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

/// Item da barra de baixo.
class GNavItem {
  const GNavItem(this.label, this.icon, [this.key]);
  final String label;
  final IconData icon;
  final Key? key;
}

/// Barra de baixo: o item escolhido vira um círculo azul que sobe.
class GNavBar extends StatelessWidget {
  const GNavBar({
    super.key,
    required this.items,
    required this.index,
    required this.onChanged,
  });

  final List<GNavItem> items;
  final int index;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        boxShadow: [
          BoxShadow(
            color: Color(0x140F172A),
            blurRadius: 18,
            offset: Offset(0, -4),
          ),
        ],
      ),
      child: SafeArea(
        top: false,
        child: SizedBox(
          height: 70,
          child: Row(
            children: [
              for (var i = 0; i < items.length; i++)
                Expanded(
                  child: Semantics(
                    button: true,
                    selected: i == index,
                    label: items[i].label,
                    child: GestureDetector(
                      key: items[i].key ?? Key('nav_$i'),
                      behavior: HitTestBehavior.opaque,
                      onTap: () => onChanged(i),
                      child: Stack(
                        alignment: Alignment.center,
                        clipBehavior: Clip.none,
                        children: [
                          AnimatedPositioned(
                            duration: const Duration(milliseconds: 180),
                            top: i == index ? -16 : 12,
                            child: AnimatedContainer(
                              duration: const Duration(milliseconds: 180),
                              width: i == index ? 52 : 28,
                              height: i == index ? 52 : 28,
                              decoration: BoxDecoration(
                                color: i == index
                                    ? GColors.blue
                                    : Colors.transparent,
                                shape: BoxShape.circle,
                                boxShadow: i == index
                                    ? const [
                                        BoxShadow(
                                          color: Color(0x552B59FF),
                                          blurRadius: 14,
                                          offset: Offset(0, 6),
                                        ),
                                      ]
                                    : null,
                              ),
                              child: Icon(
                                items[i].icon,
                                size: 24,
                                color: i == index
                                    ? Colors.white
                                    : const Color(0xFF7B8798),
                              ),
                            ),
                          ),
                          Positioned(
                            bottom: 10,
                            child: Text(
                              items[i].label,
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: i == index
                                    ? FontWeight.w700
                                    : FontWeight.w500,
                                color: i == index
                                    ? GColors.blue
                                    : const Color(0xFF7B8798),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Telas de entrada (abertura, login, escolha...)
// ---------------------------------------------------------------------------

/// Esqueleto das telas de cadastro: "‹ Voltar", logo, título, texto, conteúdo
/// e um botão fixo no pé da tela.
class OnboardScaffold extends StatelessWidget {
  const OnboardScaffold({
    super.key,
    required this.title,
    this.subtitle,
    this.onBack,
    this.backKey = const Key('backButton'),
    this.showLogo = true,
    this.child,
    this.bottom,
    this.centerContent = false,
  });

  final String title;
  final String? subtitle;
  final VoidCallback? onBack;
  final Key backKey;
  final bool showLogo;
  final Widget? child;
  final Widget? bottom;

  /// Centraliza o conteúdo na vertical (telas de "Tudo pronto!").
  final bool centerContent;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final header = <Widget>[
      if (onBack != null)
        Align(
          alignment: Alignment.centerLeft,
          child: TextButton.icon(
            key: backKey,
            onPressed: onBack,
            icon: const Icon(Icons.chevron_left, size: 20),
            label: const Text('Voltar'),
            style: TextButton.styleFrom(
              foregroundColor: GColors.muted,
              padding: EdgeInsets.zero,
              minimumSize: const Size(0, 32),
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
            ),
          ),
        ),
      if (showLogo) ...[
        const SizedBox(height: 8),
        const Align(
          alignment: Alignment.centerLeft,
          child: GuardianLogo(size: 52),
        ),
      ],
      const SizedBox(height: 16),
      Text(title, style: text.headlineMedium),
      if (subtitle != null) ...[
        const SizedBox(height: 8),
        Text(subtitle!, style: text.bodyLarge),
      ],
      const SizedBox(height: 24),
    ];
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 460),
            child: Column(
              children: [
                Expanded(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.fromLTRB(24, 12, 24, 16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [...header, ?child],
                    ),
                  ),
                ),
                if (bottom != null)
                  Padding(
                    padding: const EdgeInsets.fromLTRB(24, 0, 24, 20),
                    child: bottom,
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Opção grande e tocável com título, texto e seta ("Sou o responsável").
class GChoiceTile extends StatelessWidget {
  const GChoiceTile({
    super.key,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  final String title;
  final String subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => GCard(
    onTap: onTap,
    child: Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: Theme.of(context).textTheme.titleMedium),
              const SizedBox(height: 2),
              Text(subtitle, style: Theme.of(context).textTheme.bodyMedium),
            ],
          ),
        ),
        const Icon(Icons.chevron_right, color: GColors.muted),
      ],
    ),
  );
}

/// Linha de configuração com ícone, texto e interruptor (ou seta).
class GSettingRow extends StatelessWidget {
  const GSettingRow({
    super.key,
    required this.icon,
    required this.title,
    this.subtitle,
    this.value,
    this.onChanged,
    this.onTap,
    this.iconColor = GColors.muted,
    this.iconBackground = const Color(0xFFF1F4F9),
  });

  final IconData icon;
  final String title;
  final String? subtitle;
  final bool? value;
  final ValueChanged<bool>? onChanged;
  final VoidCallback? onTap;
  final Color iconColor;
  final Color iconBackground;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return InkWell(
      onTap: onTap ?? (value != null ? () => onChanged?.call(!value!) : null),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        child: Row(
          children: [
            GIconBox(
              icon,
              color: iconColor,
              background: iconBackground,
              size: 40,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: text.titleSmall),
                  if (subtitle != null) Text(subtitle!, style: text.bodySmall),
                ],
              ),
            ),
            if (value != null)
              Switch(value: value!, onChanged: onChanged)
            else if (onTap != null)
              const Icon(Icons.chevron_right, color: GColors.muted),
          ],
        ),
      ),
    );
  }
}

/// Texto "Duda · 9 anos", "Hoje, terça-feira, 10 de novembro".
const _weekdays = [
  'segunda-feira',
  'terça-feira',
  'quarta-feira',
  'quinta-feira',
  'sexta-feira',
  'sábado',
  'domingo',
];
const _months = [
  'janeiro',
  'fevereiro',
  'março',
  'abril',
  'maio',
  'junho',
  'julho',
  'agosto',
  'setembro',
  'outubro',
  'novembro',
  'dezembro',
];

String todayLabel(DateTime now) =>
    'Hoje, ${_weekdays[now.weekday - 1]}, ${now.day} de ${_months[now.month - 1]}';

String weekdayShort(int weekday) =>
    const ['Seg', 'Ter', 'Qua', 'Qui', 'Sex', 'Sáb', 'Dom'][weekday - 1];

/// Campo de texto com o rótulo acima, como no design.
class GField extends StatelessWidget {
  const GField({
    super.key,
    required this.label,
    required this.controller,
    this.hint,
    this.enabled = true,
    this.obscure = false,
    this.keyboardType,
    this.autofillHints,
    this.onSubmitted,
    this.suffix,
    this.maxLength,
    this.helper,
    this.textAlign = TextAlign.start,
    this.style,
    this.formatters,
    this.capitalization = TextCapitalization.none,
    this.fieldKey,
  });

  final String label;
  final TextEditingController controller;
  final String? hint;
  final bool enabled;
  final bool obscure;
  final TextInputType? keyboardType;
  final Iterable<String>? autofillHints;
  final ValueChanged<String>? onSubmitted;
  final Widget? suffix;
  final int? maxLength;
  final String? helper;
  final TextAlign textAlign;
  final TextStyle? style;
  final List<TextInputFormatter>? formatters;
  final TextCapitalization capitalization;
  final Key? fieldKey;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Padding(
        padding: const EdgeInsets.only(left: 2, bottom: 6),
        child: Text(
          label,
          style: const TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: GColors.ink,
          ),
        ),
      ),
      TextField(
        key: fieldKey,
        controller: controller,
        enabled: enabled,
        obscureText: obscure,
        keyboardType: keyboardType,
        autofillHints: autofillHints,
        onSubmitted: onSubmitted,
        maxLength: maxLength,
        textAlign: textAlign,
        style: style,
        inputFormatters: formatters,
        textCapitalization: capitalization,
        autocorrect: !obscure,
        decoration: InputDecoration(
          hintText: hint,
          suffixIcon: suffix,
          counterText: '',
        ),
      ),
      if (helper != null)
        Padding(
          padding: const EdgeInsets.only(left: 2, top: 6),
          child: Text(helper!, style: Theme.of(context).textTheme.bodySmall),
        ),
    ],
  );
}
