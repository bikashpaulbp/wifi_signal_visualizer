import 'dart:math';
import 'package:flutter/material.dart';
import 'package:wifi_signal_visualizer/app/constant/app_colors.dart';
import 'package:wifi_signal_visualizer/app/data/models/wifi_network.dart';
import 'package:wifi_signal_visualizer/app/utils/signal_utils.dart';

/// Floating AR label card for every scanned WiFi network.
///
/// New in this version:
///  • Coverage radius ring behind each bubble
///  • Security badge (OPEN / WEP / default SSID warning)
///  • Channel congestion dot
///  • Connected row 2 no longer overlaps quality label
class NetworkBubblesPainter extends CustomPainter {
  NetworkBubblesPainter({
    required this.networks,
    required this.positions,
    required this.selectedKey,
    required this.animValue,
  });

  final List<WifiNetwork>                     networks;
  final Map<String, ({double nx, double ny})> positions;
  final String                                selectedKey;
  final double                                animValue;

  final hitRects = <String, Rect>{};

  static const _bW = 172.0, _bH = 56.0, _bR = 10.0;

  @override
  void paint(Canvas canvas, Size size) {
    hitRects.clear();

    // Precompute channel → count (for congestion)
    final channelCounts = <int, int>{};
    for (final n in networks) {
      final ch = SignalUtils.channelFromMhz(n.frequencyMhz);
      if (ch > 0) channelCounts[ch] = (channelCounts[ch] ?? 0) + 1;
    }

    // Draw weakest first → strongest on top
    final sorted = [...networks]..sort((a, b) => a.rssi.compareTo(b.rssi));
    for (final net in sorted) {
      final pos = positions[net.key];
      if (pos == null) continue;
      final rect = Rect.fromCenter(
        center: Offset(pos.nx * size.width, pos.ny * size.height),
        width: _bW, height: _bH,
      );
      hitRects[net.key] = rect;
      final isSel  = net.key == selectedKey;
      final isConn = net.isConnected;
      final ch     = SignalUtils.channelFromMhz(net.frequencyMhz);
      final congested = ch > 0 && (channelCounts[ch] ?? 0) > 2;

      _drawCoverageRing(canvas, rect, size, net, isSel);
      _drawConnector(canvas, rect, size, isSel);
      _drawBackground(canvas, rect, net, isSel, isConn);
      _drawContent(canvas, rect, net, isSel, isConn, congested);
      if (isSel) _drawPulse(canvas, rect);
    }
  }

  // ── Coverage radius ring ──────────────────────────────────────────────────
  void _drawCoverageRing(Canvas canvas, Rect rect, Size size,
      WifiNetwork net, bool isSel) {
    // Estimated range → normalise to screen pixels (max 30% of screen width)
    final rangeM  = SignalUtils.estimatedRangeMetres(net.rssi, net.band);
    final maxPx   = size.width * 0.30;
    final ringR   = (maxPx * (1 - net.ratio.clamp(0.1, 0.95))).clamp(18.0, maxPx);
    final qc      = SignalUtils.qualityColor(net.quality);
    final bc      = SignalUtils.bandColor(net.band);
    final opacity = isSel ? 0.18 : 0.08;
    // Outer glow ring
    canvas.drawCircle(rect.center, ringR, Paint()
      ..color = qc.withOpacity(opacity)
      ..style = PaintingStyle.stroke
      ..strokeWidth = isSel ? 1.8 : 0.8
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4));
    canvas.drawCircle(rect.center, ringR, Paint()
      ..color = bc.withOpacity(opacity * 0.6)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 0.8);
    // Tiny range label at ring edge
    if (isSel) {
      _drawRangeLabel(canvas, rect.center, ringR, rangeM);
    }
  }

  void _drawRangeLabel(Canvas canvas, Offset center, double r, double metres) {
    final label = metres < 10
        ? '~${metres.toStringAsFixed(0)}m'
        : '~${metres.toStringAsFixed(0)}m';
    final tp = _tp(label, color: Colors.white38, size: 8);
    tp.paint(canvas, Offset(center.dx + r * 0.70 - tp.width / 2,
                            center.dy - 6));
  }

  // ── Dashed connector ──────────────────────────────────────────────────────
  void _drawConnector(Canvas canvas, Rect rect, Size size, bool isSel) {
    final anchor = Offset(rect.center.dx, size.height * 0.88);
    if (anchor.dy <= rect.bottom + 4) return;
    final paint = Paint()
      ..color       = (isSel ? AppColors.selected : Colors.white).withOpacity(0.22)
      ..strokeWidth = 1.0
      ..style       = PaintingStyle.stroke;
    final path   = Path()
      ..moveTo(rect.center.dx, rect.bottom + 4)
      ..lineTo(anchor.dx, anchor.dy);
    final metric = path.computeMetrics().first;
    double d = 0;
    while (d < metric.length) {
      canvas.drawPath(metric.extractPath(d, (d + 6).clamp(0, metric.length)), paint);
      d += 10;
    }
    canvas.drawCircle(anchor, 4,
        Paint()..color = isSel ? AppColors.selected : Colors.white38);
  }

  // ── Card background ───────────────────────────────────────────────────────
  void _drawBackground(Canvas canvas, Rect rect, WifiNetwork net,
      bool isSel, bool isConn) {
    final rr  = RRect.fromRectAndRadius(rect, const Radius.circular(_bR));
    final qc  = SignalUtils.qualityColor(net.quality);
    final bc  = SignalUtils.bandColor(net.band);

    canvas.drawRRect(rr, Paint()..color = AppColors.bgCard.withOpacity(0.90));
    canvas.drawRRect(rr, Paint()
      ..shader = LinearGradient(
        begin: Alignment.topLeft, end: Alignment.bottomRight,
        colors: [qc.withOpacity(0.10), bc.withOpacity(0.06)],
      ).createShader(rect));

    final security = SignalUtils.securityFromCapabilities(net.capabilities);
    final borderColor = isConn ? AppColors.selected
        : isSel  ? AppColors.accent
        : SignalUtils.isSecurityWarning(security) ? SignalUtils.securityColor(security).withOpacity(0.7)
        : bc.withOpacity(0.55);

    canvas.drawRRect(rr, Paint()
      ..color       = borderColor
      ..style       = PaintingStyle.stroke
      ..strokeWidth = isConn || isSel ? 1.8 : 1.0);

    if (isConn || isSel) {
      final pulse = 0.3 + 0.3 * sin(animValue * 2 * pi);
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          rect.inflate(3 + 2 * pulse), Radius.circular(_bR + 3)),
        Paint()
          ..color       = borderColor.withOpacity(0.25 * pulse)
          ..style       = PaintingStyle.stroke
          ..strokeWidth = 2);
    }
  }

  // ── Card content ──────────────────────────────────────────────────────────
  void _drawContent(Canvas canvas, Rect rect, WifiNetwork net,
      bool isSel, bool isConn, bool congested) {
    final qc        = SignalUtils.qualityColor(net.quality);
    final bc        = SignalUtils.bandColor(net.band);
    final nameColor = isConn ? AppColors.selected
        : isSel  ? AppColors.accent
        : AppColors.textPrimary;
    final security  = SignalUtils.securityFromCapabilities(net.capabilities);
    final isDefault = SignalUtils.isDefaultSsid(net.ssid);

    // ── Row 1: signal dot · SSID · [security/default badges] · dBm ──
    canvas.drawCircle(Offset(rect.left + 12, rect.top + 17), 5,
        Paint()..color = qc..maskFilter = const MaskFilter.blur(BlurStyle.normal, 3));
    canvas.drawCircle(Offset(rect.left + 12, rect.top + 17), 4,
        Paint()..color = qc);

    // Security badge (right of dBm)
    double rightX = rect.right - 10;
    if (SignalUtils.isSecurityWarning(security)) {
      final sc     = SignalUtils.securityColor(security);
      final slabel = SignalUtils.securityLabel(security);
      final st     = _tp(slabel, color: sc, size: 8, weight: FontWeight.w800);
      final bx     = rightX - st.width - 8;
      canvas.drawRRect(
        RRect.fromRectAndRadius(Rect.fromLTWH(bx - 3, rect.top + 6, st.width + 8, 13),
            const Radius.circular(3)),
        Paint()..color = sc.withOpacity(0.18));
      st.paint(canvas, Offset(bx, rect.top + 7.5));
      rightX = bx - 5;
    } else if (isDefault) {
      final dt = _tp('DEFAULT', color: AppColors.sigFair, size: 7.5);
      final bx = rightX - dt.width - 8;
      canvas.drawRRect(
        RRect.fromRectAndRadius(Rect.fromLTWH(bx - 3, rect.top + 6, dt.width + 8, 13),
            const Radius.circular(3)),
        Paint()..color = AppColors.sigFair.withOpacity(0.15));
      dt.paint(canvas, Offset(bx, rect.top + 7.5));
      rightX = bx - 5;
    }

    // dBm
    final dbm = _tp('${net.rssi}', color: qc, size: 13, weight: FontWeight.w800);
    dbm.paint(canvas, Offset(rightX - dbm.width, rect.top + 9));

    // SSID truncated
    final ssidMaxW = (rightX - dbm.width - rect.left - 28).clamp(40.0, 200.0);
    _tp(net.displaySsid, color: nameColor, size: 12.5,
        weight: FontWeight.w700, maxW: ssidMaxW)
      .paint(canvas, Offset(rect.left + 22, rect.top + 9));

    // ── Row 2: bars · band · quality/connected · congestion dot ─────
    _drawBars(canvas, rect.left + 10, rect.top + 36, net, qc);

    if (isConn) {
      _tp(SignalUtils.bandLabel(net.band),
          color: bc.withOpacity(0.85), size: 9.5)
        .paint(canvas, Offset(rect.left + 34, rect.top + 37));

      final ctText = _tp('✓  connected',
          color: AppColors.selected, size: 8.5, weight: FontWeight.w700);
      final badgeW = ctText.width + 10;
      final badgeX = rect.right - badgeW - 6;
      final badgeY = rect.top + 34;
      canvas.drawRRect(
        RRect.fromRectAndRadius(Rect.fromLTWH(badgeX, badgeY, badgeW, 15),
            const Radius.circular(4)),
        Paint()..color = AppColors.selected.withOpacity(0.15));
      ctText.paint(canvas, Offset(badgeX + 5, badgeY + 1.5));
    } else {
      _tp('${SignalUtils.bandLabel(net.band)}  ·  '
          '${SignalUtils.qualityLabel(net.quality)}',
          color: bc.withOpacity(0.85), size: 9.5)
        .paint(canvas, Offset(rect.left + 34, rect.top + 37));
    }

    // Congestion dot (top-right corner of card)
    if (congested) {
      canvas.drawCircle(Offset(rect.right - 7, rect.top + 7), 4,
          Paint()..color = const Color(0xFFFF6B35));
      canvas.drawCircle(Offset(rect.right - 7, rect.top + 7), 4, Paint()
        ..color       = const Color(0xFFFF6B35).withOpacity(0.4)
        ..style       = PaintingStyle.stroke
        ..strokeWidth = 2);
    }
  }

  void _drawBars(Canvas canvas, double x, double y, WifiNetwork net, Color col) {
    final filled = SignalUtils.qualityBars(net.rssi);
    for (int i = 0; i < 4; i++) {
      final h  = 4.0 + i * 2.5;
      final bx = x + i * 4.5;
      final by = y + (4 * 2.5 - h);
      canvas.drawRRect(
        RRect.fromRectAndRadius(Rect.fromLTWH(bx, by, 3, h), const Radius.circular(1)),
        Paint()..color = i < filled ? col : col.withOpacity(0.2));
    }
  }

  void _drawPulse(Canvas canvas, Rect rect) {
    final phase  = (animValue * 1.5) % 1.0;
    final expand = phase * 8;
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        rect.inflate(expand), Radius.circular(_bR + expand)),
      Paint()
        ..color       = AppColors.accent.withOpacity((1 - phase) * 0.18)
        ..style       = PaintingStyle.stroke
        ..strokeWidth = 1.5);
  }

  TextPainter _tp(String text, {
    required Color color, required double size,
    FontWeight weight = FontWeight.w500, double? maxW,
  }) => TextPainter(
    text: TextSpan(text: text, style: TextStyle(
      color: color, fontSize: size, fontWeight: weight,
      fontFamily: 'monospace', height: 1.2,
    )),
    textDirection: TextDirection.ltr,
    maxLines: 1,
    ellipsis: maxW != null ? '…' : null,
  )..layout(maxWidth: maxW ?? double.infinity);

  @override
  bool shouldRepaint(NetworkBubblesPainter o) =>
      o.animValue   != animValue   ||
      o.selectedKey != selectedKey ||
      o.networks    != networks    ||
      o.positions   != positions;
}
