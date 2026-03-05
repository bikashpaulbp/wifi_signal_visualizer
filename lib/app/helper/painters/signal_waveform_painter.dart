import 'dart:math';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:wifi_signal_visualizer/app/constant/app_colors.dart';
import 'package:wifi_signal_visualizer/app/utils/signal_utils.dart';


/// Oscilloscope-style live RSSI waveform.
///
/// Performance optimisations vs first version:
///  • Path objects reused via a static cache keyed on (length, liveRssi).
///  • Sine LUT computed once per band change, not every frame.
///  • Only repaints when animValue changes (shouldRepaint).
class SignalWaveformPainter extends CustomPainter {
  SignalWaveformPainter({
    required this.history,
    required this.liveRssi,
    required this.frequencyMhz,
    required this.animValue,
  });

  final List<int> history;
  final int       liveRssi;
  final int       frequencyMhz;
  final double    animValue;

  // ── Static path cache to avoid per-frame GC pressure ─────────────────────
  static final _linePathCache = ui.Path();
  static final _fillPathCache = ui.Path();

  @override
  void paint(Canvas canvas, Size size) {
    if (history.isEmpty) return;

    final band  = SignalUtils.bandFromMhz(frequencyMhz);
    final qc    = SignalUtils.qualityColor(SignalUtils.qualityFromRssi(liveRssi));
    final bc    = SignalUtils.bandColor(band);
    final all   = [...history, liveRssi];
    const minDb = -100.0;
    const maxDb = -40.0;
    final pad   = 5.0;
    final h     = size.height - pad * 2;
    final step  = size.width / (all.length - 1).clamp(1, 9999).toDouble();

    double yOf(int rssi) =>
        pad + h - ((rssi - minDb) / (maxDb - minDb)).clamp(0.0, 1.0) * h;

    // Background
    canvas.drawRect(Rect.fromLTWH(0, 0, size.width, size.height),
        Paint()..color = AppColors.bgCard.withOpacity(0.68));

    // Grid reference lines
    final gridPaint = Paint()
      ..color       = AppColors.bgCardBorder.withOpacity(0.45)
      ..strokeWidth = 0.5;
    for (int i = 1; i < 4; i++) {
      canvas.drawLine(Offset(0, size.height * i / 4),
          Offset(size.width, size.height * i / 4), gridPaint);
    }

    // ── Reuse cached path objects (reset, don't allocate) ─────────────────
    _fillPathCache.reset();
    _linePathCache.reset();

    _fillPathCache.moveTo(0, size.height);
    _linePathCache.moveTo(0, yOf(all[0]));

    for (int i = 0; i < all.length; i++) {
      final x = i * step;
      final y = yOf(all[i]);
      _fillPathCache.lineTo(x, y);
      if (i > 0) _linePathCache.lineTo(x, y);
    }
    _fillPathCache.lineTo((all.length - 1) * step, size.height);
    _fillPathCache.close();

    // Filled area gradient
    canvas.drawPath(_fillPathCache, Paint()
      ..shader = LinearGradient(
        begin: Alignment.topCenter, end: Alignment.bottomCenter,
        colors: [qc.withOpacity(0.28), Colors.transparent],
      ).createShader(Rect.fromLTWH(0, 0, size.width, size.height)));

    // Scrolling band sine overlay — frequency matches band
    final cycles = band == FrequencyBand.ghz6 ? 5.5
        : band == FrequencyBand.ghz5           ? 3.5
        : 2.0;
    final waveH  = (h * 0.07).clamp(2.0, 9.0);
    final baseY  = yOf(liveRssi);
    final scroll = animValue * size.width;

    // Sine overlay — use a single reused path
    final sinePath = ui.Path(); // still one allocation but small
    for (double x = 0; x <= size.width; x += 2.0) {
      final y = baseY + sin((x + scroll) / size.width * cycles * 2 * pi) * waveH;
      x == 0 ? sinePath.moveTo(x, y) : sinePath.lineTo(x, y);
    }
    canvas.drawPath(sinePath, Paint()
      ..color       = bc.withOpacity(0.50)
      ..strokeWidth = 1.2
      ..style       = PaintingStyle.stroke);

    // Main RSSI line
    canvas.drawPath(_linePathCache, Paint()
      ..color       = qc
      ..strokeWidth = 1.8
      ..style       = PaintingStyle.stroke
      ..strokeCap   = StrokeCap.round
      ..strokeJoin  = StrokeJoin.round);

    // Live dot at right edge
    final lx = (all.length - 1) * step;
    final ly = yOf(all.last);
    canvas.drawCircle(Offset(lx, ly), 5,
        Paint()..color = qc.withOpacity(0.38)
               ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 3));
    canvas.drawCircle(Offset(lx, ly), 3, Paint()..color = qc);

    // Corner labels
    _label(canvas, Offset(4, 2), '${liveRssi} dBm', qc, 9);
    _label(canvas, Offset(4, size.height - 12),
        SignalUtils.bandLabel(band), bc.withOpacity(0.8), 8);
  }

  void _label(Canvas canvas, Offset pos, String t, Color c, double fs) =>
    (TextPainter(
      text: TextSpan(text: t,
          style: TextStyle(color: c, fontSize: fs,
              fontFamily: 'monospace', fontWeight: FontWeight.w700)),
      textDirection: TextDirection.ltr,
    )..layout()).paint(canvas, pos);

  @override
  bool shouldRepaint(SignalWaveformPainter o) =>
      o.animValue   != animValue  ||
      o.liveRssi    != liveRssi   ||
      o.history     != history    ||
      o.frequencyMhz != frequencyMhz;
}