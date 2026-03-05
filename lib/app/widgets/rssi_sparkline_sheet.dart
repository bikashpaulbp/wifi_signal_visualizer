import 'dart:math';
import 'package:flutter/material.dart';
import 'package:wifi_signal_visualizer/app/constant/app_colors.dart';
import 'package:wifi_signal_visualizer/app/utils/signal_utils.dart';


/// 60-second rolling RSSI sparkline with min/max/avg labels.
/// Shown in a bottom sheet when the user long-presses a bubble.
class RssiSparklineSheet extends StatelessWidget {
  const RssiSparklineSheet({
    super.key,
    required this.ssid,
    required this.history,
    required this.liveRssi,
  });

  final String   ssid;
  final List<int> history;
  final int      liveRssi;

  static void show(BuildContext ctx, String ssid, List<int> history, int rssi) {
    showModalBottomSheet(
      context: ctx,
      backgroundColor: Colors.transparent,
      isScrollControlled: false,
      builder: (_) => RssiSparklineSheet(
          ssid: ssid, history: history, liveRssi: rssi),
    );
  }

  @override
  Widget build(BuildContext context) {
    final stats = _stats();
    final qc    = SignalUtils.qualityColor(SignalUtils.qualityFromRssi(liveRssi));

    return Container(
      height: 260,
      decoration: BoxDecoration(
        color: AppColors.bgSurface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
        border: Border(top: BorderSide(color: AppColors.bgCardBorder, width: 1.5)),
      ),
      child: Column(children: [
        // Handle
        Center(child: Container(
          margin: const EdgeInsets.symmetric(vertical: 10),
          width: 36, height: 4,
          decoration: BoxDecoration(
              color: AppColors.bgCardBorder,
              borderRadius: BorderRadius.circular(2)))),
        // Header
        Padding(padding: const EdgeInsets.symmetric(horizontal: 18),
          child: Row(children: [
            Container(width: 8, height: 8,
              decoration: BoxDecoration(color: qc, shape: BoxShape.circle,
                boxShadow: [BoxShadow(color: qc.withOpacity(0.6), blurRadius: 4)])),
            const SizedBox(width: 8),
            Expanded(child: Text(ssid,
              style: const TextStyle(color: AppColors.textPrimary,
                  fontSize: 14, fontWeight: FontWeight.w700,
                  fontFamily: 'monospace'),
              overflow: TextOverflow.ellipsis)),
            Text('${liveRssi} dBm', style: TextStyle(
                color: qc, fontSize: 15,
                fontWeight: FontWeight.w800, fontFamily: 'monospace')),
          ])),
        const SizedBox(height: 8),
        // Stats row
        Padding(padding: const EdgeInsets.symmetric(horizontal: 18),
          child: Row(mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              _Chip('MIN',  '${stats.$1}', AppColors.sigPoor),
              _Chip('AVG',  '${stats.$2.toStringAsFixed(0)}', AppColors.sigFair),
              _Chip('MAX',  '${stats.$3}', AppColors.sigExcellent),
              _Chip('SPAN', '${history.length}s', AppColors.textSecondary),
            ])),
        const SizedBox(height: 10),
        // Chart
        Expanded(child: Padding(
          padding: const EdgeInsets.fromLTRB(18, 0, 18, 16),
          child: CustomPaint(
            painter: _SparklinePainter(history: history, liveRssi: liveRssi),
            child: const SizedBox.expand(),
          ),
        )),
      ]),
    );
  }

  (int, double, int) _stats() {
    if (history.isEmpty) return (liveRssi, liveRssi.toDouble(), liveRssi);
    final mn = history.reduce(min);
    final mx = history.reduce(max);
    final av = history.reduce((a, b) => a + b) / history.length;
    return (mn, av, mx);
  }
}

class _Chip extends StatelessWidget {
  const _Chip(this.label, this.value, this.color);
  final String label, value; final Color color;
  @override Widget build(BuildContext ctx) => Column(
    mainAxisSize: MainAxisSize.min, children: [
      Text(value, style: TextStyle(color: color, fontSize: 12,
          fontWeight: FontWeight.w800, fontFamily: 'monospace')),
      Text(label, style: const TextStyle(color: AppColors.textMuted,
          fontSize: 8, letterSpacing: 0.8)),
    ]);
}

class _SparklinePainter extends CustomPainter {
  const _SparklinePainter({required this.history, required this.liveRssi});
  final List<int> history;
  final int       liveRssi;

  @override
  void paint(Canvas canvas, Size size) {
    if (history.isEmpty) return;

    final all  = [...history, liveRssi];
    final mn   = all.reduce(min).toDouble();
    final mx   = all.reduce(max).toDouble();
    final rng  = (mx - mn).abs().clamp(5.0, double.infinity);
    final pad  = 4.0;
    final w    = size.width - pad * 2;
    final h    = size.height - pad * 2;

    double xOf(int i) => pad + (i / (all.length - 1).clamp(1, 999)) * w;
    double yOf(int v) => pad + h - ((v - mn) / rng * h);

    // Filled area under curve
    final fill = Path()..moveTo(xOf(0), size.height);
    for (int i = 0; i < all.length; i++) fill.lineTo(xOf(i), yOf(all[i]));
    fill..lineTo(xOf(all.length - 1), size.height)..close();
    canvas.drawPath(fill, Paint()
      ..shader = LinearGradient(
        begin: Alignment.topCenter, end: Alignment.bottomCenter,
        colors: [AppColors.accent.withOpacity(0.25), Colors.transparent],
      ).createShader(Rect.fromLTWH(0, 0, size.width, size.height)));

    // Grid lines at -50, -67, -80
    for (final dBm in [-50, -67, -80]) {
      if (dBm < mn || dBm > mx) continue;
      final y = yOf(dBm);
      canvas.drawLine(Offset(pad, y), Offset(size.width - pad, y),
          Paint()..color = Colors.white12..strokeWidth = 0.5);
      _label(canvas, Offset(2, y - 7), '${dBm}', Colors.white24, 7);
    }

    // Line
    final linePath = Path()..moveTo(xOf(0), yOf(all[0]));
    for (int i = 1; i < all.length; i++) linePath.lineTo(xOf(i), yOf(all[i]));
    canvas.drawPath(linePath, Paint()
      ..color       = AppColors.accent
      ..strokeWidth = 1.8
      ..style       = PaintingStyle.stroke
      ..strokeCap   = StrokeCap.round
      ..strokeJoin  = StrokeJoin.round);

    // Live dot
    final lx = xOf(all.length - 1);
    final ly = yOf(all.last);
    final qc = SignalUtils.qualityColor(SignalUtils.qualityFromRssi(liveRssi));
    canvas.drawCircle(Offset(lx, ly), 5,
        Paint()..color = qc.withOpacity(0.4)
               ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4));
    canvas.drawCircle(Offset(lx, ly), 3.5, Paint()..color = qc);
  }

  void _label(Canvas canvas, Offset pos, String t, Color c, double fs) =>
    (TextPainter(
      text: TextSpan(text: t, style: TextStyle(
          color: c, fontSize: fs, fontFamily: 'monospace')),
      textDirection: TextDirection.ltr,
    )..layout()).paint(canvas, pos);

  @override bool shouldRepaint(_SparklinePainter o) =>
      o.history != history || o.liveRssi != liveRssi;
}