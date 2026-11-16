import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/services.dart';

import 'theme.dart';

// ---------------------------------------------------------------------------
// Movimento
// ---------------------------------------------------------------------------

/// Curva e duração padrão do movimento do app (as mesmas do protótipo).
const gCurve = Cubic(0.22, 0.8, 0.24, 1);
const gMotion = Duration(milliseconds: 420);

/// Entrada suave: o conteúdo sobe um pouco e aparece. Vários [GEnter] criados
/// no mesmo quadro entram em sequência, um depois do outro.
class GEnter extends StatefulWidget {
  const GEnter({super.key, required this.child});

  final Widget child;

  @override
  State<GEnter> createState() => _GEnterState();
}

class _GEnterState extends State<GEnter> with SingleTickerProviderStateMixin {
  static int _inFrame = 0;
  static bool _resetScheduled = false;

  late final AnimationController _c;
  late final Animation<double> _a;

  @override
  void initState() {
    super.initState();
    final order = _inFrame++;
    if (!_resetScheduled) {
      _resetScheduled = true;
      SchedulerBinding.instance.addPostFrameCallback((_) {
        _inFrame = 0;
        _resetScheduled = false;
      });
    }
    final delay = (order > 8 ? 8 : order) * 45;
    final total = gMotion.inMilliseconds + delay;
    // `preserve`: o movimento continua mesmo com "remover animações" ligado
    // no aparelho; ele é curto e faz parte do desenho do app.
    _c = AnimationController(
      vsync: this,
      duration: Duration(milliseconds: total),
      animationBehavior: AnimationBehavior.preserve,
    );
    _a = CurvedAnimation(
      parent: _c,
      curve: Interval(delay / total, 1, curve: gCurve),
    );
    _c.forward();
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => FadeTransition(
    opacity: _a,
    child: AnimatedBuilder(
      animation: _a,
      builder: (context, child) => Transform.translate(
        offset: Offset(0, 16 * (1 - _a.value)),
        child: child,
      ),
      child: widget.child,
    ),
  );
}

/// Resposta ao toque: o conteúdo encolhe um pouco enquanto o dedo está nele.
class GPress extends StatefulWidget {
  const GPress({super.key, required this.child, this.enabled = true});

  final Widget child;
  final bool enabled;

  @override
  State<GPress> createState() => _GPressState();
}

class _GPressState extends State<GPress> with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 110),
    reverseDuration: const Duration(milliseconds: 260),
    animationBehavior: AnimationBehavior.preserve,
  );

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!widget.enabled) return widget.child;
    return Listener(
      onPointerDown: (_) => _c.forward(),
      onPointerUp: (_) => _c.reverse(),
      onPointerCancel: (_) => _c.reverse(),
      child: ScaleTransition(
        scale: Tween<double>(
          begin: 1,
          end: 0.975,
        ).animate(CurvedAnimation(parent: _c, curve: Curves.easeOut)),
        child: widget.child,
      ),
    );
  }
}

/// Troca de conteúdo (abas e sub-abas): o antigo some e o novo sobe.
/// O [child] precisa de uma `key` diferente a cada conteúdo.
class GSwitch extends StatelessWidget {
  const GSwitch({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) => AnimatedSwitcher(
    duration: const Duration(milliseconds: 380),
    reverseDuration: const Duration(milliseconds: 160),
    switchInCurve: gCurve,
    switchOutCurve: Curves.easeIn,
    layoutBuilder: (current, previous) =>
        Stack(fit: StackFit.expand, children: [...previous, ?current]),
    transitionBuilder: (child, animation) => FadeTransition(
      opacity: animation,
      child: SlideTransition(
        position: Tween<Offset>(
          begin: const Offset(0, 0.035),
          end: Offset.zero,
        ).animate(animation),
        child: child,
      ),
    ),
    child: child,
  );
}

/// Troca de tela: a nova sobe e aparece; a de baixo recua um pouco.
class GPageTransitionsBuilder extends PageTransitionsBuilder {
  const GPageTransitionsBuilder();

  @override
  Widget buildTransitions<T>(
    PageRoute<T> route,
    BuildContext context,
    Animation<double> animation,
    Animation<double> secondaryAnimation,
    Widget child,
  ) {
    final enter = CurvedAnimation(
      parent: animation,
      curve: gCurve,
      reverseCurve: Curves.easeIn,
    );
    final under = CurvedAnimation(parent: secondaryAnimation, curve: gCurve);
    return FadeTransition(
      opacity: Tween<double>(begin: 1, end: 0.6).animate(under),
      child: ScaleTransition(
        scale: Tween<double>(begin: 1, end: 0.97).animate(under),
        child: FadeTransition(
          opacity: enter,
          child: SlideTransition(
            position: Tween<Offset>(
              begin: const Offset(0, 0.07),
              end: Offset.zero,
            ).animate(enter),
            child: child,
          ),
        ),
      ),
    );
  }
}

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
    return GEnter(
      child: GPress(enabled: onTap != null, child: _card(radius)),
    );
  }

  Widget _card(BorderRadius radius) {
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
    child: TweenAnimationBuilder<double>(
      tween: Tween<double>(begin: 0, end: value.clamp(0.0, 1.0)),
      duration: const Duration(milliseconds: 800),
      curve: gCurve,
      builder: (context, v, _) => LinearProgressIndicator(
        value: v,
        minHeight: height,
        color: color,
        backgroundColor: GColors.track,
      ),
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
  const GNavItem(this.label, this.icon, [this.key, this.badge = 0]);
  final String label;
  final IconData icon;
  final Key? key;

  /// Número pequeno sobre o ícone (0 esconde).
  final int badge;
}

/// Barra de baixo com o "calombo líquido" do protótipo: uma bolha branca na
/// borda da barra escorre com mola até o item escolhido, que sobe num círculo
/// azul.
class GNavBar extends StatefulWidget {
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
  State<GNavBar> createState() => _GNavBarState();
}

class _GNavBarState extends State<GNavBar> with SingleTickerProviderStateMixin {
  /// Altura do calombo acima da barra.
  static const _bulge = 12.0;
  static const _barHeight = 64.0;
  static const _step = 1 / 60; // a mola anda em passos fixos, como no protótipo

  late final Ticker _ticker = createTicker(_onTick);
  double _width = 0;
  double? _x; // centro atual da bolha
  double _v = 0; // velocidade (estica e inclina a bolha)
  Duration _last = Duration.zero;
  double _pending = 0;

  /// Margem lateral da barra: os itens não encostam nas bordas da tela.
  static const _side = 10.0;

  double get _target =>
      _side + (_width - 2 * _side) / widget.items.length * (widget.index + 0.5);

  void _onTick(Duration elapsed) {
    _pending += (elapsed - _last).inMicroseconds / 1e6;
    _last = elapsed;
    var x = _x ?? _target;
    var steps = 0;
    while (_pending >= _step && steps < 12) {
      _pending -= _step;
      steps++;
      _v = (_v + (_target - x) * 0.075) * 0.78;
      x += _v;
    }
    if ((_target - x).abs() < 0.3 && _v.abs() < 0.3) {
      x = _target;
      _v = 0;
      _ticker.stop();
    }
    setState(() => _x = x);
  }

  @override
  void didUpdateWidget(GNavBar old) {
    super.didUpdateWidget(old);
    if (old.index != widget.index && !_ticker.isActive && _x != null) {
      _last = Duration.zero;
      _pending = 0;
      _ticker.start();
    }
  }

  @override
  void dispose() {
    _ticker.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final inset = MediaQuery.paddingOf(context).bottom;
    return SizedBox(
      height: _barHeight + _bulge + inset,
      child: LayoutBuilder(
        builder: (context, box) {
          if (box.maxWidth != _width) {
            _width = box.maxWidth;
            if (!_ticker.isActive) _x = _target;
          }
          return Stack(
            children: [
              Positioned.fill(
                child: CustomPaint(
                  painter: _BulgePainter(_x ?? _target, _v, _bulge),
                ),
              ),
              Positioned(
                left: _side,
                right: _side,
                top: _bulge,
                height: _barHeight,
                child: Row(
                  children: [
                    for (var i = 0; i < widget.items.length; i++)
                      Expanded(child: _item(i)),
                  ],
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _item(int i) {
    final item = widget.items[i];
    final active = i == widget.index;
    return Semantics(
      button: true,
      selected: active,
      label: item.label,
      child: GestureDetector(
        key: item.key ?? Key('nav_$i'),
        behavior: HitTestBehavior.opaque,
        onTap: () => widget.onChanged(i),
        child: TweenAnimationBuilder<double>(
          tween: Tween<double>(end: active ? 1 : 0),
          duration: const Duration(milliseconds: 650),
          curve: const Cubic(0.25, 1.35, 0.5, 1),
          builder: (context, t, _) {
            final k = t.clamp(0.0, 1.0);
            return Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Transform.translate(
                  offset: Offset(0, -14 * t),
                  child: Stack(
                    clipBehavior: Clip.none,
                    children: [
                      Container(
                        width: 40,
                        height: 40,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: Color.lerp(
                            const Color(0x002B59FF),
                            GColors.blue,
                            k,
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: Color.lerp(
                                const Color(0x002B59FF),
                                const Color(0x802B59FF),
                                k,
                              )!,
                              blurRadius: 12,
                              spreadRadius: -6,
                              offset: const Offset(0, 6),
                            ),
                          ],
                        ),
                        child: Icon(
                          item.icon,
                          size: 22,
                          color: Color.lerp(
                            const Color(0xFF7B8798),
                            Colors.white,
                            k,
                          ),
                        ),
                      ),
                      if (item.badge > 0)
                        Positioned(
                          right: -4,
                          top: -2,
                          child: Container(
                            constraints: const BoxConstraints(minWidth: 17),
                            height: 17,
                            padding: const EdgeInsets.symmetric(horizontal: 4),
                            alignment: Alignment.center,
                            decoration: BoxDecoration(
                              color: GColors.orange,
                              borderRadius: BorderRadius.circular(99),
                              border: Border.all(
                                color: Colors.white,
                                width: 1.5,
                              ),
                            ),
                            child: Text(
                              '${item.badge}',
                              style: const TextStyle(
                                fontFamily: guardianFont,
                                fontSize: 9.5,
                                height: 1,
                                fontWeight: FontWeight.w700,
                                color: Colors.white,
                              ),
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
                Transform.translate(
                  offset: Offset(0, -10 * t),
                  child: ExcludeSemantics(
                    child: FittedBox(
                      fit: BoxFit.scaleDown,
                      child: Text(
                        item.label,
                        maxLines: 1,
                        style: TextStyle(
                          fontFamily: guardianFont,
                          fontSize: widget.items.length > 4 ? 10.5 : 11.5,
                          height: 1.2,
                          fontWeight: active
                              ? FontWeight.w700
                              : FontWeight.w500,
                          color: Color.lerp(
                            const Color(0xBF7B8798),
                            GColors.blue,
                            k,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}

/// Fundo branco da barra com a bolha: alarga com a velocidade, inclina na
/// direção do movimento e achata um pouco enquanto anda.
class _BulgePainter extends CustomPainter {
  _BulgePainter(this.cx, this.stretch, this.bulge);

  final double cx;
  final double stretch;
  final double bulge;

  @override
  void paint(Canvas canvas, Size size) {
    final w = 36 + math.min(18.0, stretch.abs() * 0.7);
    final lean = (stretch * 0.25).clamp(-10.0, 10.0);
    final top = 1.5 + math.min(4.0, stretch.abs() * 0.1);
    final b = bulge;
    final path = Path()
      ..moveTo(0, b)
      ..lineTo(cx - w - 10, b)
      ..cubicTo(cx - w * 0.45, b, cx - w * 0.55 + lean, top, cx + lean, top)
      ..cubicTo(cx + w * 0.55 + lean, top, cx + w * 0.45, b, cx + w + 10, b)
      ..lineTo(size.width, b)
      ..lineTo(size.width, size.height + 40)
      ..lineTo(0, size.height + 40)
      ..close();
    canvas.drawPath(
      path.shift(const Offset(0, -3)),
      Paint()
        ..color = const Color(0x140F172A)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 8),
    );
    canvas.drawPath(path, Paint()..color = Colors.white);
    canvas.drawPath(
      path,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1
        ..color = const Color(0xFFE3E8F2),
    );
  }

  @override
  bool shouldRepaint(_BulgePainter old) =>
      old.cx != cx || old.stretch != stretch || old.bulge != bulge;
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
