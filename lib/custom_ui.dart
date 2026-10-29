import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'theme.dart';

/// Fully custom UI pieces. No plain Card, no default AppBar, no
/// default Material slider or chip where a custom one is specified.
/// Light theme only. Gradients and blur are used sparingly, only on
/// the hero and on sheets, never on every card.

void uiHaptic() {
  HapticFeedback.selectionClick();
}

/// Minimal back row used by every detail screen instead of an
/// AppBar widget: back button, title, no elevation, transparent,
/// no shadow. SafeArea is applied by the caller scroll view.
class DetailTopBar extends StatelessWidget {
  const DetailTopBar({super.key, required this.title, this.subtitle, this.actions = const []});
  final String title;
  final String? subtitle;
  final List<Widget> actions;
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(4, 8, 4, 16),
      child: Row(
        children: [
          Material(
            color: Colors.white,
            shape: const CircleBorder(side: BorderSide(color: appOutlineVariant)),
            child: InkWell(
              customBorder: const CircleBorder(),
              onTap: () {
                uiHaptic();
                Navigator.of(context).maybePop();
              },
              child: const Padding(padding: EdgeInsets.all(10), child: Icon(Icons.arrow_back, size: 22, color: appInk)),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w700, color: appInk, height: 1.15)),
                if (subtitle != null) ...[
                  const SizedBox(height: 2),
                  Text(subtitle!, style: const TextStyle(color: appMuted, fontSize: 13), maxLines: 1, overflow: TextOverflow.ellipsis),
                ],
              ],
            ),
          ),
          ...actions,
        ],
      ),
    );
  }
}

/// Large in-content header for main tabs. The tab itself carries
/// the title, so MainShell has no AppBar at all.
class TabHeader extends StatelessWidget {
  const TabHeader({super.key, required this.title, required this.subtitle, this.icon = Icons.home_outlined});
  final String title;
  final String subtitle;
  final IconData icon;
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(0, 8, 0, 16),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              gradient: const LinearGradient(colors: [Color(0xFF0A1E46), appBlue], begin: Alignment.topLeft, end: Alignment.bottomRight),
              borderRadius: BorderRadius.circular(14),
              boxShadow: const [BoxShadow(color: Color(0x330F172A), blurRadius: 8, offset: Offset(0, 3))],
            ),
            child: Icon(icon, color: Colors.white, size: 24),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: const TextStyle(fontSize: 26, fontWeight: FontWeight.w700, color: appInk, height: 1.1, fontFeatures: [FontFeature.tabularFigures()])),
                const SizedBox(height: 2),
                Text(subtitle, style: const TextStyle(color: appMuted, fontSize: 13)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Scroll view for long screens: CustomScrollView with a SliverList.
/// Drop-in replacement for a padded ListView: same padding and
/// children, but built on slivers.
class CustomScrollList extends StatelessWidget {
  const CustomScrollList({super.key, this.padding = const EdgeInsets.all(16), required this.children});
  final EdgeInsets padding;
  final List<Widget> children;
  @override
  Widget build(BuildContext context) {
    final bottom = padding.bottom + 96 + MediaQuery.of(context).padding.bottom;
    return CustomScrollView(
      slivers: [
        SliverPadding(
          padding: EdgeInsets.fromLTRB(padding.left, padding.top, padding.right, bottom),
          sliver: SliverList(delegate: SliverChildListDelegate(children)),
        ),
      ],
    );
  }
}

/// Detail screen scroll view: minimal back row as a sliver header,
/// then the screen content as a SliverList. No AppBar widget.
class DetailScroll extends StatelessWidget {
  const DetailScroll({super.key, required this.title, this.subtitle, this.actions = const [], this.padding = const EdgeInsets.fromLTRB(16, 0, 16, 16), required this.children, this.loading = false});
  final String title;
  final String? subtitle;
  final List<Widget> actions;
  final EdgeInsets padding;
  final List<Widget> children;
  /// When true, ONLY the top bar and a skeleton render. No form field,
  /// button, or list from children is shown while loading.
  final bool loading;
  @override
  Widget build(BuildContext context) {
    return CustomScrollView(
      slivers: [
        SliverToBoxAdapter(
          child: Padding(
            padding: EdgeInsets.only(top: MediaQuery.of(context).padding.top),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(12, 0, 12, 0),
              child: DetailTopBar(title: title, subtitle: subtitle, actions: actions),
            ),
          ),
        ),
        SliverPadding(
          padding: padding,
          sliver: SliverList(delegate: SliverChildListDelegate(loading ? [skeletonCard()] : children)),
        ),
      ],
    );
  }
}

/// Hero number that counts up in under 300ms on load and on change.
/// AnimatedBuilder rebuilds only this subtree, never the screen.
class CountUp extends StatefulWidget {
  const CountUp({super.key, required this.value, this.style});
  final int value;
  final TextStyle? style;
  @override
  State<CountUp> createState() => _CountUpState();
}

class _CountUpState extends State<CountUp> with SingleTickerProviderStateMixin {
  late final AnimationController _c;
  late Animation<double> _anim;
  @override
  void initState() {
    super.initState();
    _c = AnimationController(vsync: this, duration: const Duration(milliseconds: 280));
    _anim = Tween<double>(begin: 0, end: widget.value.toDouble()).animate(CurvedAnimation(parent: _c, curve: Curves.easeOut));
    _c.forward();
  }

  @override
  void didUpdateWidget(covariant CountUp old) {
    super.didUpdateWidget(old);
    if (old.value != widget.value) {
      _anim = Tween<double>(begin: 0, end: widget.value.toDouble()).animate(CurvedAnimation(parent: _c, curve: Curves.easeOut));
      _c.forward(from: 0);
    }
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _anim,
      builder: (_, __) => Text(
        '${_anim.value.round()}',
        style: widget.style ?? const TextStyle(fontSize: 40, fontWeight: FontWeight.w700, color: Colors.white, fontFeatures: [FontFeature.tabularFigures()]),
      ),
    );
  }
}

/// Hero card with a custom shape: gradient plus two soft arcs
/// painted by CustomPainter, top right only. No plain Card widget.
class HeroCard extends StatelessWidget {
  const HeroCard({super.key, required this.child, this.margin = const EdgeInsets.only(bottom: 12)});
  final Widget child;
  final EdgeInsets margin;
  @override
  Widget build(BuildContext context) {
    return Container(
      margin: margin,
      decoration: BoxDecoration(
        gradient: const LinearGradient(colors: [Color(0xFF0A1E46), appBlue], begin: Alignment.topLeft, end: Alignment.bottomRight),
        borderRadius: BorderRadius.circular(28),
      ),
      child: CustomPaint(
        painter: _HeroArcPainter(),
        child: Padding(padding: const EdgeInsets.all(20), child: child),
      ),
    );
  }
}

class _HeroArcPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..color = Colors.white.withValues(alpha: 0.14);
    canvas.drawCircle(Offset(size.width - 10, 10), 70, paint);
    canvas.drawCircle(Offset(size.width - 40, 30), 44, Paint()..color = Colors.white.withValues(alpha: 0.10));
  }

  @override
  bool shouldRepaint(covariant CustomPainter old) => false;
}

/// Own choice chip: AnimatedContainer, InkWell ripple, haptic.
/// No FilterChip, no Chip widget.
class CustomChoiceChip extends StatelessWidget {
  const CustomChoiceChip({super.key, required this.label, required this.selected, required this.onTap, this.icon});
  final String label;
  final bool selected;
  final VoidCallback onTap;
  final IconData? icon;
  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(999),
        onTap: () {
          uiHaptic();
          onTap();
        },
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
          decoration: BoxDecoration(
            color: selected ? appSecondaryContainer : Colors.white,
            border: Border.all(color: selected ? appBlue : appOutlineVariant),
            borderRadius: BorderRadius.circular(999),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (icon != null) ...[Icon(icon, size: 16, color: selected ? appOnSecondary : appMuted), const SizedBox(width: 8)],
              Text(label, style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13, color: selected ? appOnSecondary : appInk)),
            ],
          ),
        ),
      ),
    );
  }
}

/// Thick slider built on the Material Slider for reliability:
/// 12px rounded track, 28px white thumb with a 2.5px border and soft
/// shadow, tick marks at preset positions, value bubble while
/// dragging, 48px touch target. Stability wins over hand-rolled code.
class CustomSlider extends StatefulWidget {
  const CustomSlider({super.key, required this.value, required this.min, required this.max, required this.divisions, required this.onChanged, this.activeColor = appBlue, this.label});
  final double value;
  final double min;
  final double max;
  final int divisions;
  final ValueChanged<double> onChanged;
  final Color activeColor;
  final String? label;
  @override
  State<CustomSlider> createState() => _CustomSliderState();
}

class _ThickThumbShape extends SliderComponentShape {
  const _ThickThumbShape(this.borderColor);
  final Color borderColor;
  @override
  Size getPreferredSize(bool isEnabled, bool isDiscrete) => const Size(28, 28);
  @override
  void paint(
    PaintingContext context,
    Offset center, {
    required Animation<double> activationAnimation,
    required Animation<double> enableAnimation,
    required bool isDiscrete,
    required TextPainter labelPainter,
    required RenderBox parentBox,
    required SliderThemeData sliderTheme,
    required TextDirection textDirection,
    required double value,
    required double textScaleFactor,
    required Size sizeWithOverflow,
  }) {
    final canvas = context.canvas;
    final shadowPath = Path()..addOval(Rect.fromCircle(center: center, radius: 14));
    canvas.drawShadow(shadowPath, const Color(0x330F172A), 6, false);
    canvas.drawCircle(center, 14, Paint()..color = Colors.white);
    canvas.drawCircle(
      center,
      14,
      Paint()
        ..color = borderColor
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.5,
    );
  }
}

class _CustomSliderState extends State<CustomSlider> {
  double? _last;
  @override
  Widget build(BuildContext context) {
    final value = widget.value.clamp(widget.min, widget.max);
    return SizedBox(
      height: 48,
      child: SliderTheme(
        data: SliderTheme.of(context).copyWith(
          trackHeight: 12,
          trackShape: const RoundedRectSliderTrackShape(),
          activeTrackColor: widget.activeColor,
          inactiveTrackColor: const Color(0xFFE2EAF4),
          thumbShape: _ThickThumbShape(widget.activeColor),
          tickMarkShape: const RoundSliderTickMarkShape(tickMarkRadius: 3),
          activeTickMarkColor: Colors.white.withValues(alpha: 0.7),
          inactiveTickMarkColor: const Color(0xFF94A3B8),
          valueIndicatorColor: appInk,
          valueIndicatorTextStyle: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700),
          showValueIndicator: ShowValueIndicator.onlyForDiscrete,
          overlayShape: const RoundSliderOverlayShape(overlayRadius: 20),
        ),
        child: Slider(
          value: value,
          min: widget.min,
          max: widget.max,
          divisions: widget.divisions > 0 ? widget.divisions : null,
          label: widget.label ?? value.toStringAsFixed(0),
          onChanged: (v) {
            if (_last != v) {
              _last = v;
              uiHaptic();
            }
            widget.onChanged(v);
          },
        ),
      ),
    );
  }
}

/// Own bottom sheet: gradient strip on top, drag handle, custom
/// radio rows with ripple and haptic. Gradient only on the sheet
/// header, nowhere else on the page.
Future<T?> showCustomChoiceSheet<T>(
  BuildContext context, {
  required String title,
  required List<(T, String, String?)> options,
  required T current,
  bool searchable = false,
}) async {
  var query = '';
  return showModalBottomSheet<T>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.white,
    shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(28))),
    builder: (ctx) => StatefulBuilder(
      builder: (ctx, setS) {
        final shown = query.isEmpty ? options : options.where((o) => o.$2.toLowerCase().contains(query.toLowerCase())).toList();
        return SafeArea(
          child: Padding(
            padding: EdgeInsets.only(bottom: MediaQuery.of(ctx).viewInsets.bottom),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  height: 4,
                  decoration: const BoxDecoration(
                    color: appBlue,
                    borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
                  ),
                ),
                const SizedBox(height: 12),
                Container(width: 36, height: 5, decoration: BoxDecoration(color: appBorder, borderRadius: BorderRadius.circular(999))),
                const SizedBox(height: 12),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: Align(alignment: Alignment.centerLeft, child: Text(title, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w700, color: appInk))),
                ),
                if (searchable) ...[
                  const SizedBox(height: 12),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    child: TextField(decoration: const InputDecoration(prefixIcon: Icon(Icons.search), hintText: 'Search'), onChanged: (v) => setS(() => query = v)),
                  ),
                ],
                const SizedBox(height: 8),
                Flexible(
                  child: ListView(
                    shrinkWrap: true,
                    children: [
                      for (final o in options)
                        if (shown.contains(o))
                          Material(
                            color: o.$1 == current ? appSecondaryContainer : Colors.transparent,
                            child: InkWell(
                              onTap: () {
                                uiHaptic();
                                Navigator.pop(ctx, o.$1);
                              },
                              child: Padding(
                                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 13),
                                child: Row(
                                  children: [
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Text(o.$2, style: const TextStyle(fontWeight: FontWeight.w600, color: appInk)),
                                          if (o.$3 != null) ...[const SizedBox(height: 2), Text(o.$3!, style: const TextStyle(color: appMuted, fontSize: 12))],
                                        ],
                                      ),
                                    ),
                                    if (o.$1 == current) const Icon(Icons.check, color: appBlue),
                                  ],
                                ),
                              ),
                            ),
                          ),
                      if (shown.isEmpty) const Padding(padding: EdgeInsets.all(20), child: Text('Nothing matches that search.', style: TextStyle(color: appMuted))),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
              ],
            ),
          ),
        );
      },
    ),
  );
}

/// Topology map: lines drawn by CustomPainter, nodes as custom
/// circular widgets. No signal values are drawn, because the router
/// does not report mesh signal strength.
class TopologyMap extends StatelessWidget {
  const TopologyMap({super.key, required this.names});
  final List<String> names;
  @override
  Widget build(BuildContext context) {
    if (names.isEmpty) return const SizedBox.shrink();
    final children = names.length > 1 ? names.sublist(1) : <String>[];
    return SizedBox(
      height: children.isEmpty ? 120 : 230,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final w = constraints.maxWidth;
          final h = children.isEmpty ? 120.0 : 230.0;
          final cx = w / 2;
          final cy = children.isEmpty ? 60.0 : 115.0;
          final radius = children.isEmpty ? 0.0 : math.min(w, h) * 0.38;
          final points = <Offset>[Offset(cx, cy)];
          for (var i = 0; i < children.length; i++) {
            final angle = -math.pi / 2 + (children.length == 1 ? 0 : (i / children.length) * 2 * math.pi);
            points.add(Offset(cx + radius * math.cos(angle), cy + radius * math.sin(angle) * 0.85));
          }
          return Stack(
            children: [
              Positioned.fill(child: CustomPaint(painter: _TopologyPainter(points))),
              for (var i = 0; i < points.length; i++)
                Positioned(
                  left: (points[i].dx - 30).clamp(0.0, w - 60),
                  top: (points[i].dy - 30).clamp(0.0, h - 60),
                  child: SizedBox(
                    width: 60,
                    child: Column(
                      children: [
                        Container(
                          width: 44,
                          height: 44,
                          decoration: BoxDecoration(
                            color: i == 0 ? appBlue : Colors.white,
                            shape: BoxShape.circle,
                            border: Border.all(color: i == 0 ? appBlue : appOutlineVariant, width: 2),
                          ),
                          child: Icon(i == 0 ? Icons.router : Icons.devices, color: i == 0 ? Colors.white : appBlue, size: 22),
                        ),
                        const SizedBox(height: 4),
                        Text(names[i], textAlign: TextAlign.center, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: appInk)),
                      ],
                    ),
                  ),
                ),
            ],
          );
        },
      ),
    );
  }
}

class _TopologyPainter extends CustomPainter {
  _TopologyPainter(this.points);
  final List<Offset> points;
  @override
  void paint(Canvas canvas, Size size) {
    if (points.length < 2) return;
    final paint = Paint()
      ..color = appBlue.withValues(alpha: 0.35)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2;
    for (var i = 1; i < points.length; i++) {
      canvas.drawLine(points[0], points[i], paint);
    }
  }

  @override
  bool shouldRepaint(covariant _TopologyPainter old) => old.points != points;
}
