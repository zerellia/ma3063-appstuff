import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// Light futuristic theme tokens. Light only, no dark theme, no
/// version label anywhere in the UI.
const Color appBlue = Color(0xFF2F7CF6);
const Color appCyan = Color(0xFF00C2FF);
const Color appInk = Color(0xFF0F172A);
const Color appMuted = Color(0xFF64748B);
const Color appBg = Color(0xFFEDF3FA);
const Color appCard = Color(0xFFFFFFFF);
const Color appBorder = Color(0xFFDCE7F2);
const Color appSurfaceLow = Color(0xFFF7FAFD);
const Color appSurfaceContainer = Color(0xFFEAF1F8);
const Color appSurfaceHigh = Color(0xFFE2EBF5);
const Color appSecondaryContainer = Color(0xFFDCE9FD);
const Color appOnSecondary = Color(0xFF173A6B);
const Color appOutline = Color(0xFFCBD5E1);
const Color appOutlineVariant = Color(0xFFE2E8F0);
const Color appGreen = Color(0xFF15803D);
const Color appGreenBg = Color(0xFFDCFCE7);
const Color appAmber = Color(0xFFB45309);
const Color appAmberBg = Color(0xFFFEF3C7);
const Color appRed = Color(0xFFB42318);
const Color appRedBg = Color(0xFFFEECEB);

/// Content card: white at full opacity, hairline border, no shadow.
/// Depth comes from the page background versus the white card.
class GlassCard extends StatelessWidget {
  const GlassCard({super.key, required this.child, this.padding = const EdgeInsets.all(16), this.margin = const EdgeInsets.only(bottom: 12)});
  final Widget child;
  final EdgeInsets padding;
  final EdgeInsets margin;
  @override
  Widget build(BuildContext context) {
    return Container(
      margin: margin,
      decoration: BoxDecoration(
        color: appCard,
        border: Border.all(color: appOutlineVariant),
        borderRadius: BorderRadius.circular(24),
      ),
      child: Padding(padding: padding, child: child),
    );
  }
}

Widget pillChip(String text, {bool active = false, Color? color}) {
  final c = color ?? appBlue;
  return Container(
    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
    decoration: BoxDecoration(
      color: active ? c : const Color(0xFFEFF5FF),
      borderRadius: BorderRadius.circular(999),
    ),
    child: Text(
      text,
      style: TextStyle(
        color: active ? Colors.white : c,
        fontWeight: FontWeight.w700,
        fontSize: 12,
      ),
    ),
  );
}

class SegmentedControl<T> extends StatelessWidget {
  const SegmentedControl({super.key, required this.options, required this.value, required this.onChanged});
  final List<(T, String)> options;
  final T value;
  final ValueChanged<T> onChanged;
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(color: appSurfaceContainer, borderRadius: BorderRadius.circular(999)),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          for (final opt in options)
            Material(
              color: Colors.transparent,
              child: InkWell(
                borderRadius: BorderRadius.circular(999),
                onTap: () {
                  HapticFeedback.selectionClick();
                  onChanged(opt.$1);
                },
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  curve: Curves.easeOut,
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                  decoration: BoxDecoration(
                    color: opt.$1 == value ? appSecondaryContainer : Colors.transparent,
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Text(
                    opt.$2,
                    style: TextStyle(
                      color: opt.$1 == value ? appOnSecondary : appMuted,
                      fontWeight: FontWeight.w700,
                      fontSize: 13,
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

/// Simple skeleton block that pulses. No shimmer package needed.
class SkeletonBlock extends StatefulWidget {
  const SkeletonBlock({super.key, this.width = double.infinity, this.height = 16});
  final double width;
  final double height;
  @override
  State<SkeletonBlock> createState() => _SkeletonBlockState();
}

class _SkeletonBlockState extends State<SkeletonBlock> with SingleTickerProviderStateMixin {
  late final AnimationController _c;
  @override
  void initState() {
    super.initState();
    _c = AnimationController(vsync: this, duration: const Duration(milliseconds: 1100))..repeat(reverse: true);
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _c,
      builder: (_, __) => Container(
        width: widget.width,
        height: widget.height,
        decoration: BoxDecoration(
          color: Color.lerp(const Color(0xFFE2EAF4), const Color(0xFFF4F8FD), _c.value),
          borderRadius: BorderRadius.circular(12),
        ),
      ),
    );
  }
}

Widget skeletonCard() {
  return const GlassCard(
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SkeletonBlock(width: 160),
        SizedBox(height: 10),
        SkeletonBlock(),
        SizedBox(height: 8),
        SkeletonBlock(width: 220),
      ],
    ),
  );
}


/// Ring gauge for a 0 to 100 value, drawn with CustomPainter.
Widget emptyState(String title, String body, String actionLabel, VoidCallback onAction) {
  return GlassCard(
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Icon(Icons.inbox_outlined, size: 40, color: appMuted),
        const SizedBox(height: 10),
        Text(title, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 16, color: appInk)),
        const SizedBox(height: 6),
        Text(body, style: const TextStyle(color: appMuted, height: 1.45)),
        const SizedBox(height: 12),
        OutlinedButton(onPressed: onAction, child: Text(actionLabel)),
      ],
    ),
  );
}

/// Ring gauge for a 0 to 100 value, drawn with CustomPainter.
class RingGauge extends StatelessWidget {
  const RingGauge({super.key, required this.value, required this.label, this.color = appBlue, this.size = 76});
  final double value;
  final String label;
  final Color color;
  final double size;
  @override
  Widget build(BuildContext context) {
    final v = value.clamp(0, 100);
    return SizedBox(
      width: size,
      height: size + 20,
      child: Column(
        children: [
          SizedBox(
            width: size,
            height: size,
            child: CustomPaint(
              painter: _RingPainter(v / 100, color),
              child: Center(
                child: Text(
                  '${v.round()}%',
                  style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15, color: appInk, fontFeatures: [FontFeature.tabularFigures()]),
                ),
              ),
            ),
          ),
          const SizedBox(height: 4),
          Text(label, style: const TextStyle(color: appMuted, fontSize: 12)),
        ],
      ),
    );
  }
}

class _RingPainter extends CustomPainter {
  _RingPainter(this.fraction, this.color);
  final double fraction;
  final Color color;
  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2 - 5;
    final bg = Paint()
      ..color = const Color(0xFFE2EAF4)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 8
      ..strokeCap = StrokeCap.round;
    final fg = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 8
      ..strokeCap = StrokeCap.round;
    canvas.drawCircle(center, radius, bg);
    canvas.drawArc(Rect.fromCircle(center: center, radius: radius), -3.1415926535 / 2, fraction * 2 * 3.1415926535, false, fg);
  }

  @override
  bool shouldRepaint(covariant _RingPainter old) => old.fraction != fraction || old.color != color;
}

/// Horizontal bar for a 0 to 100 value.
class ValueBar extends StatelessWidget {
  const ValueBar({super.key, required this.value, this.color = appBlue, this.height = 8});
  final double value;
  final Color color;
  final double height;
  @override
  Widget build(BuildContext context) {
    final v = value.clamp(0, 100) / 100;
    return Container(
      height: height,
      decoration: BoxDecoration(color: const Color(0xFFE2EAF4), borderRadius: BorderRadius.circular(999)),
      child: FractionallySizedBox(
        alignment: Alignment.centerLeft,
        widthFactor: v,
        child: Container(decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(999))),
      ),
    );
  }
}

/// Area sparkline from a list of doubles, drawn with CustomPainter.
/// No chart dependency is needed.
class Sparkline extends StatelessWidget {
  const Sparkline({super.key, required this.values, this.color = appBlue, this.height = 48});
  final List<double> values;
  final Color color;
  final double height;
  @override
  Widget build(BuildContext context) {
    if (values.length < 2) {
      return SizedBox(height: height, child: const Center(child: Text('Not enough samples yet', style: TextStyle(color: appMuted, fontSize: 12))));
    }
    return SizedBox(height: height, child: CustomPaint(painter: _SparkPainter(values, color)));
  }
}

class _SparkPainter extends CustomPainter {
  _SparkPainter(this.values, this.color);
  final List<double> values;
  final Color color;
  @override
  void paint(Canvas canvas, Size size) {
    final max = values.reduce((a, b) => a > b ? a : b);
    final min = values.reduce((a, b) => a < b ? a : b);
    final span = (max - min).abs() < 0.001 ? 1.0 : (max - min);
    final points = <Offset>[];
    for (var i = 0; i < values.length; i++) {
      final x = values.length == 1 ? 0.0 : size.width * i / (values.length - 1);
      final y = size.height - 4 - (values[i] - min) / span * (size.height - 8);
      points.add(Offset(x, y));
    }
    final path = Path()..moveTo(points.first.dx, points.first.dy);
    for (var i = 1; i < points.length; i++) {
      path.lineTo(points[i].dx, points[i].dy);
    }
    final fill = Path.from(path)
      ..lineTo(size.width, size.height)
      ..lineTo(0, size.height)
      ..close();
    canvas.drawPath(
      fill,
      Paint()..color = color.withValues(alpha: 0.15),
    );
    canvas.drawPath(
      path,
      Paint()
        ..color = color
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2
        ..strokeCap = StrokeCap.round,
    );
  }

  @override
  bool shouldRepaint(covariant _SparkPainter old) => old.values != values;
}
