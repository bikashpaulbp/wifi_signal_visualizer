import 'dart:math';
import 'package:flutter/material.dart';
import 'package:wifi_signal_visualizer/app/constant/app_colors.dart';
import 'package:wifi_signal_visualizer/app/data/models/wifi_network.dart';
import 'package:wifi_signal_visualizer/app/utils/signal_utils.dart';

/// Renders a floating AR label card for every scanned WiFi network.
///
/// Card layout:
///   ┌─────────────────────────────┐
///   │ ● SSID_NAME          -67dBm │
///   │ ▪▪▪▪  5 GHz  ·  Good       │
///   └─────────────────────────────┘
///        (dashed connector line)
///        •  (anchor dot at bottom)
///
/// Selected network → cyan border + pulse halo
/// Connected network → gold border + pulse halo
/// Others → band-coloured dim border
///
/// After paint(), [hitRects] can be used for tap detection.
class NetworkBubblesPainter extends CustomPainter {
  NetworkBubblesPainter({required this.networks, required this.positions, required this.selectedKey, required this.animValue});

  final List<WifiNetwork> networks;
  final Map<String, ({double nx, double ny})> positions;
  final String selectedKey;
  final double animValue;

  /// Populated after each paint() call — use for hit testing taps.
  final hitRects = <String, Rect>{};

  static const _bW = 168.0, _bH = 54.0, _bR = 10.0;

  @override
  void paint(Canvas canvas, Size size) {
    hitRects.clear();
    // Draw weakest first → strongest renders on top
    final sorted = [...networks]..sort((a, b) => a.rssi.compareTo(b.rssi));
    for (final net in sorted) {
      final pos = positions[net.key];
      if (pos == null) continue;
      final rect = Rect.fromCenter(center: Offset(pos.nx * size.width, pos.ny * size.height), width: _bW, height: _bH);
      hitRects[net.key] = rect;
      final isSel = net.key == selectedKey;
      final isConn = net.isConnected;
      _drawConnector(canvas, rect, size, isSel);
      _drawBackground(canvas, rect, net, isSel, isConn);
      _drawContent(canvas, rect, net, isSel, isConn);
      if (isSel) _drawPulse(canvas, rect);
    }
  }

  // ── Dashed connector line ────────────────────────────────────────────────
  void _drawConnector(Canvas canvas, Rect rect, Size size, bool isSel) {
    final anchor = Offset(rect.center.dx, size.height * 0.88);
    if (anchor.dy <= rect.bottom + 4) return;

    final paint = Paint()
      ..color = (isSel ? AppColors.selected : Colors.white).withOpacity(0.22)
      ..strokeWidth = 1.0
      ..style = PaintingStyle.stroke;

    // Draw dashes manually
    final path = Path()
      ..moveTo(rect.center.dx, rect.bottom + 4)
      ..lineTo(anchor.dx, anchor.dy);
    final metric = path.computeMetrics().first;
    double dist = 0;
    while (dist < metric.length) {
      final end = (dist + 6).clamp(0.0, metric.length);
      canvas.drawPath(metric.extractPath(dist, end), paint);
      dist += 10;
    }
    canvas.drawCircle(anchor, 4, Paint()..color = (isSel ? AppColors.selected : Colors.white38));
  }

  // ── Card background + border ─────────────────────────────────────────────
  void _drawBackground(Canvas canvas, Rect rect, WifiNetwork net, bool isSel, bool isConn) {
    final rr = RRect.fromRectAndRadius(rect, const Radius.circular(_bR));
    final qc = SignalUtils.qualityColor(net.quality);
    final bc = SignalUtils.bandColor(net.band);

    // Dark fill
    canvas.drawRRect(rr, Paint()..color = AppColors.bgCard.withOpacity(0.88));

    // Subtle gradient tint
    canvas.drawRRect(rr, Paint()..shader = LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: [qc.withOpacity(0.10), bc.withOpacity(0.06)]).createShader(rect));

    // Border colour
    final borderColor = isConn
        ? AppColors.selected
        : isSel
        ? AppColors.accent
        : bc.withOpacity(0.55);
    canvas.drawRRect(
      rr,
      Paint()
        ..color = borderColor
        ..style = PaintingStyle.stroke
        ..strokeWidth = isConn || isSel ? 1.8 : 1.0,
    );

    // Animated glow halo for selected / connected
    if (isConn || isSel) {
      final pulse = 0.3 + 0.3 * sin(animValue * 2 * pi);
      canvas.drawRRect(
        RRect.fromRectAndRadius(rect.inflate(3 + 2 * pulse), Radius.circular(_bR + 3)),
        Paint()
          ..color = borderColor.withOpacity(0.25 * pulse)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2,
      );
    }
  }

  // ── Text content ─────────────────────────────────────────────────────────
  void _drawContent(Canvas canvas, Rect rect, WifiNetwork net, bool isSel, bool isConn) {
    final qc = SignalUtils.qualityColor(net.quality);
    final bc = SignalUtils.bandColor(net.band);
    final nameColor = isConn
        ? AppColors.selected
        : isSel
        ? AppColors.accent
        : AppColors.textPrimary;

    // ── Row 1: signal dot · SSID · dBm ────────────────────────────────
    // Glowing dot
    canvas.drawCircle(
      Offset(rect.left + 12, rect.top + 17),
      5,
      Paint()
        ..color = qc
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 3),
    );
    canvas.drawCircle(Offset(rect.left + 12, rect.top + 17), 4, Paint()..color = qc);

    // SSID (truncated)
    _tp(net.displaySsid, color: nameColor, size: 12.5, weight: FontWeight.w700, maxW: _bW - 74).paint(canvas, Offset(rect.left + 22, rect.top + 9));

    // dBm right-aligned
    final dbm = _tp('${net.rssi}', color: qc, size: 13, weight: FontWeight.w800);
    dbm.paint(canvas, Offset(rect.right - dbm.width - 10, rect.top + 9));

    // ── Row 2: signal bars · band / connected ────────────────────────
    _drawBars(canvas, rect.left + 10, rect.top + 34, net, qc);

    if (isConn) {
      // Band on left, pill badge on right — nothing overlaps
      _tp(SignalUtils.bandLabel(net.band), color: bc.withOpacity(0.85), size: 9.5).paint(canvas, Offset(rect.left + 34, rect.top + 35));
      final ctText = _tp('✓  connected', color: AppColors.selected, size: 8.5, weight: FontWeight.w700);
      final badgeW = ctText.width + 10;
      final badgeX = rect.right - badgeW - 6;
      final badgeY = rect.top + 32;
      canvas.drawRRect(RRect.fromRectAndRadius(Rect.fromLTWH(badgeX, badgeY, badgeW, 14), const Radius.circular(4)), Paint()..color = AppColors.selected.withOpacity(0.15));
      ctText.paint(canvas, Offset(badgeX + 5, badgeY + 1));
    } else {
      _tp('${SignalUtils.bandLabel(net.band)}  ·  ${SignalUtils.qualityLabel(net.quality)}', color: bc.withOpacity(0.85), size: 9.5).paint(canvas, Offset(rect.left + 34, rect.top + 35));
    }
  }

  void _drawBars(Canvas canvas, double x, double y, WifiNetwork net, Color col) {
    final filled = SignalUtils.qualityBars(net.rssi);
    for (int i = 0; i < 4; i++) {
      final h = 4.0 + i * 2.5;
      final bx = x + i * 4.5;
      final by = y + (4 * 2.5 - h);
      canvas.drawRRect(RRect.fromRectAndRadius(Rect.fromLTWH(bx, by, 3, h), const Radius.circular(1)), Paint()..color = i < filled ? col : col.withOpacity(0.2));
    }
  }

  void _drawPulse(Canvas canvas, Rect rect) {
    final phase = (animValue * 1.5) % 1.0;
    final expand = phase * 8;
    canvas.drawRRect(
      RRect.fromRectAndRadius(rect.inflate(expand), Radius.circular(_bR + expand)),
      Paint()
        ..color = AppColors.accent.withOpacity((1 - phase) * 0.18)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.5,
    );
  }

  TextPainter _tp(String text, {required Color color, required double size, FontWeight weight = FontWeight.w500, double? maxW}) => TextPainter(
    text: TextSpan(
      text: text,
      style: TextStyle(color: color, fontSize: size, fontWeight: weight, fontFamily: 'monospace', height: 1.2),
    ),
    textDirection: TextDirection.ltr,
    maxLines: 1,
    ellipsis: maxW != null ? '…' : null,
  )..layout(maxWidth: maxW ?? double.infinity);

  @override
  bool shouldRepaint(NetworkBubblesPainter o) => o.animValue != animValue || o.selectedKey != selectedKey || o.networks != networks || o.positions != positions;
}
