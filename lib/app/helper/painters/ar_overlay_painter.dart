import 'dart:math';
import 'package:flutter/material.dart';
import 'package:wifi_signal_visualizer/app/data/models/wifi_network.dart';
import 'package:wifi_signal_visualizer/app/utils/signal_utils.dart';


/// Background AR atmosphere: band vignette, radial glow, pulse rings, grid.
class ArOverlayPainter extends CustomPainter {
  const ArOverlayPainter({
    required this.network,
    required this.animValue,
    required this.isRecording,
  });

  final WifiNetwork? network;
  final double       animValue;
  final bool         isRecording;

  Color  get _qc => network != null ? SignalUtils.qualityColor(network!.quality) : const Color(0xFF2D4A62);
  Color  get _bc => network != null ? SignalUtils.bandColor(network!.band)       : const Color(0xFF2D4A62);
  double get _r  => network?.ratio ?? 0.0;

  @override
  void paint(Canvas canvas, Size size) {
    // Band vignette
    canvas.drawRect(
      Rect.fromLTWH(0, 0, size.width, size.height),
      Paint()..shader = LinearGradient(
        begin: Alignment.topLeft, end: Alignment.bottomRight,
        colors: [_bc.withOpacity(0.18 * _r), Colors.transparent,
                 Colors.transparent, _bc.withOpacity(0.10 * _r)],
      ).createShader(Rect.fromLTWH(0, 0, size.width, size.height)),
    );

    // Radial glow
    final center = Offset(size.width / 2, size.height / 2);
    canvas.drawRect(
      Rect.fromLTWH(0, 0, size.width, size.height),
      Paint()..shader = RadialGradient(colors: [
        _qc.withOpacity(0.22 * _r),
        _qc.withOpacity(0.06 * _r),
        Colors.transparent,
      ]).createShader(
        Rect.fromCircle(center: center, radius: size.longestSide * 0.7)),
    );

    // 3 staggered pulse rings
    for (int i = 0; i < 3; i++) {
      final phase  = (animValue + i / 3) % 1.0;
      final radius = size.shortestSide * 0.40 * phase;
      canvas.drawCircle(center, radius, Paint()
        ..color       = _qc.withOpacity((1.0 - phase) * 0.45 * _r)
        ..style       = PaintingStyle.stroke
        ..strokeWidth = 1.8 - phase * 0.8);
    }

    // AR grid
    const s = 46.0;
    final gp = Paint()
      ..color       = _bc.withOpacity(0.055 * _r.clamp(0.3, 1.0))
      ..strokeWidth = 0.5;
    for (double x = 0; x < size.width;  x += s)
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), gp);
    for (double y = 0; y < size.height; y += s)
      canvas.drawLine(Offset(0, y), Offset(size.width, y), gp);

    // Recording scan-line + corner brackets
    if (isRecording) {
      final sy = size.height * ((animValue * 1.5) % 1.0);
      canvas.drawLine(Offset(0, sy), Offset(size.width, sy),
          Paint()..color = const Color(0x55FF3B30)..strokeWidth = 1.2);
      const m = 18.0, l = 24.0;
      final bp = Paint()..color = const Color(0xCCFF3B30)..strokeWidth = 2.0;
      final segs = [
        (Offset(m, m), Offset(m + l, m)),
        (Offset(m, m), Offset(m, m + l)),
        (Offset(size.width - m, m), Offset(size.width - m - l, m)),
        (Offset(size.width - m, m), Offset(size.width - m, m + l)),
        (Offset(m, size.height - m), Offset(m + l, size.height - m)),
        (Offset(m, size.height - m), Offset(m, size.height - m - l)),
        (Offset(size.width - m, size.height - m), Offset(size.width - m - l, size.height - m)),
        (Offset(size.width - m, size.height - m), Offset(size.width - m, size.height - m - l)),
      ];
      for (final (a, b) in segs) canvas.drawLine(a, b, bp);
    }
  }

  @override
  bool shouldRepaint(ArOverlayPainter o) =>
      o.animValue   != animValue   ||
      o.isRecording != isRecording ||
      o.network?.rssi         != network?.rssi ||
      o.network?.frequencyMhz != network?.frequencyMhz;
}