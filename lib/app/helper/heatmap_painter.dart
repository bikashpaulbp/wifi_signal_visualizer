import 'package:flutter/material.dart';
import 'package:wifi_signal_visualizer/app/constant/app_colors.dart';
import 'package:wifi_signal_visualizer/app/data/local/heatmap_store.dart';
import 'package:wifi_signal_visualizer/app/utils/signal_utils.dart';


class HeatmapPainter extends CustomPainter {
  const HeatmapPainter({required this.store, required this.version});

  final HeatmapStore store;
  final int          version;

  @override
  void paint(Canvas canvas, Size size) {
    // Background
    canvas.drawRect(Rect.fromLTWH(0, 0, size.width, size.height),
        Paint()..color = AppColors.bg);

    // Grid
    const s = 40.0;
    final gp = Paint()
      ..color       = AppColors.bgCardBorder.withOpacity(0.35)
      ..strokeWidth = 0.5;
    for (double x = 0; x < size.width;  x += s)
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), gp);
    for (double y = 0; y < size.height; y += s)
      canvas.drawLine(Offset(0, y), Offset(size.width, y), gp);

    // Heatmap blobs — use cached GPU image if ready, else software fallback
    if (store.cachedImage != null) {
      paintImage(
        canvas: canvas,
        image:  store.cachedImage!,
        rect:   Rect.fromLTWH(0, 0, size.width, size.height),
        fit:    BoxFit.cover,
        filterQuality: FilterQuality.medium,
      );
    } else {
      for (final pt in store.points) {
        final c  = store.toCanvas(pt.x, pt.y, size);
        final qc = SignalUtils.qualityColor(pt.quality);
        final r  = size.shortestSide * 0.10 * pt.ratio.clamp(0.25, 1.0);
        canvas.drawCircle(c, r, Paint()
          ..shader = RadialGradient(
            colors: [qc.withOpacity(0.5), Colors.transparent],
          ).createShader(Rect.fromCircle(center: c, radius: r))
          ..blendMode = BlendMode.screen);
      }
    }

    // Walk path line
    if (store.points.length >= 2) {
      final path = Path();
      Offset first = store.toCanvas(
          store.points.first.x, store.points.first.y, size);
      path.moveTo(first.dx, first.dy);
      for (int i = 1; i < store.points.length; i++) {
        final p = store.toCanvas(store.points[i].x, store.points[i].y, size);
        path.lineTo(p.dx, p.dy);
      }
      canvas.drawPath(path, Paint()
        ..color       = Colors.white.withOpacity(0.22)
        ..style       = PaintingStyle.stroke
        ..strokeWidth = 1.5
        ..strokeCap   = StrokeCap.round
        ..strokeJoin  = StrokeJoin.round);
    }

    // Origin marker
    if (store.points.isNotEmpty) {
      final o  = store.toCanvas(0, 0, size);
      final op = Paint()..color = AppColors.accent..strokeWidth = 1.4;
      canvas.drawLine(Offset(o.dx - 10, o.dy), Offset(o.dx + 10, o.dy), op);
      canvas.drawLine(Offset(o.dx, o.dy - 10), Offset(o.dx, o.dy + 10), op);
      canvas.drawCircle(o, 3, Paint()..color = AppColors.accent);
      _label(canvas, o + const Offset(12, -9), 'START', AppColors.accent);
    }

    // Scale bar
    if (store.points.isNotEmpty) {
      final rX  = (store.maxX - store.minX).abs().clamp(1.0, double.infinity);
      final pad = size.shortestSide * 0.10;
      final mPx = (size.width - pad * 2) / rX;
      final bl  = mPx.clamp(30.0, 120.0);
      const bx  = 18.0;
      final by  = size.height - 22.0;
      final sp  = Paint()..color = Colors.white54..strokeWidth = 1.8;
      canvas.drawLine(Offset(bx, by), Offset(bx + bl, by), sp);
      canvas.drawLine(Offset(bx, by - 4), Offset(bx, by + 4), sp);
      canvas.drawLine(Offset(bx + bl, by - 4), Offset(bx + bl, by + 4), sp);
      _label(canvas, Offset(bx + bl / 2 - 10, by - 14),
          bl >= mPx ? '1 m' : '${(bl / mPx).toStringAsFixed(1)} m',
          Colors.white54);
    }

    // Legend
    final items = [
      (AppColors.sigExcellent, 'Excellent'),
      (AppColors.sigGood,      'Good'),
      (AppColors.sigFair,      'Fair'),
      (AppColors.sigPoor,      'Poor'),
      (AppColors.sigUnusable,  'No signal'),
    ];
    double ly = 18;
    for (final (c, l) in items) {
      canvas.drawCircle(Offset(size.width - 92, ly + 5), 5,
          Paint()..color = c.withOpacity(0.9));
      _label(canvas, Offset(size.width - 82, ly), l, Colors.white60, fs: 10);
      ly += 18;
    }
  }

  void _label(Canvas canvas, Offset pos, String text, Color color,
      {double fs = 9}) {
    (TextPainter(
      text: TextSpan(text: text, style: TextStyle(
        color: color, fontSize: fs,
        fontFamily: 'monospace', fontWeight: FontWeight.w600,
      )),
      textDirection: TextDirection.ltr,
    )..layout()).paint(canvas, pos);
  }

  @override
  bool shouldRepaint(HeatmapPainter o) => o.version != version;
}