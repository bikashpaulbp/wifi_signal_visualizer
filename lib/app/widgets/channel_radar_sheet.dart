import 'dart:math';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:wifi_signal_visualizer/app/constant/app_colors.dart';
import 'package:wifi_signal_visualizer/app/data/models/wifi_network.dart';
import 'package:wifi_signal_visualizer/app/utils/signal_utils.dart';


/// Circular radar showing all visible APs.
/// X-axis = channel number, Y = distance from centre = RSSI strength.
/// Overlapping-channel pairs are highlighted in orange.
class ChannelRadarSheet extends StatefulWidget {
  const ChannelRadarSheet({super.key, required this.networks});
  final List<WifiNetwork> networks;

  static void show(List<WifiNetwork> nets) => Get.bottomSheet(
    ChannelRadarSheet(networks: nets),
    backgroundColor: Colors.transparent,
    isScrollControlled: true,
  );

  @override
  State<ChannelRadarSheet> createState() => _ChannelRadarSheetState();
}

class _ChannelRadarSheetState extends State<ChannelRadarSheet>
    with SingleTickerProviderStateMixin {
  late final AnimationController _sweep;
  @override void initState() {
    super.initState();
    _sweep = AnimationController(
        vsync: this, duration: const Duration(seconds: 3))..repeat();
  }
  @override void dispose() { _sweep.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) {
    return Container(
      height: MediaQuery.of(context).size.height * 0.72,
      decoration: BoxDecoration(
        color: AppColors.bgSurface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
        border: Border(top: BorderSide(color: AppColors.bgCardBorder, width: 1.5)),
      ),
      child: Column(children: [
        Center(child: Container(
          margin: const EdgeInsets.symmetric(vertical: 10),
          width: 36, height: 4,
          decoration: BoxDecoration(color: AppColors.bgCardBorder,
              borderRadius: BorderRadius.circular(2)))),
        const Padding(
          padding: EdgeInsets.symmetric(horizontal: 18),
          child: Row(children: [
            Icon(Icons.radar, color: AppColors.accent, size: 18),
            SizedBox(width: 8),
            Text('Channel Radar', style: TextStyle(
                color: AppColors.textPrimary, fontSize: 15,
                fontWeight: FontWeight.w800, fontFamily: 'monospace')),
          ])),
        const SizedBox(height: 4),
        _legend(),
        Expanded(child: AnimatedBuilder(
          animation: _sweep,
          builder: (_, __) => CustomPaint(
            painter: _RadarPainter(
                networks:  widget.networks,
                sweepAngle: _sweep.value),
            child: const SizedBox.expand(),
          ),
        )),
        _channelList(),
        const SizedBox(height: 16),
      ]),
    );
  }

  Widget _legend() => Padding(
    padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 4),
    child: Row(children: [
      _Dot(AppColors.band2_4), const SizedBox(width: 4),
      const Text('2.4 GHz', style: TextStyle(color: AppColors.textSecondary,
          fontSize: 10, fontFamily: 'monospace')),
      const SizedBox(width: 12),
      _Dot(AppColors.band5), const SizedBox(width: 4),
      const Text('5 GHz', style: TextStyle(color: AppColors.textSecondary,
          fontSize: 10, fontFamily: 'monospace')),
      const SizedBox(width: 12),
      _Dot(const Color(0xFFFF6B35)), const SizedBox(width: 4),
      const Text('Congested channel', style: TextStyle(
          color: AppColors.textSecondary, fontSize: 10, fontFamily: 'monospace')),
    ]));

  Widget _channelList() {
    // Show congested channels
    final channelMap = <int, List<WifiNetwork>>{};
    for (final n in widget.networks) {
      final ch = SignalUtils.channelFromMhz(n.frequencyMhz);
      if (ch > 0) channelMap.putIfAbsent(ch, () => []).add(n);
    }
    final congested = channelMap.entries.where((e) => e.value.length > 1).toList()
      ..sort((a, b) => b.value.length.compareTo(a.value.length));
    if (congested.isEmpty) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 18),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const Text('⚠ Congested Channels',
            style: TextStyle(color: Color(0xFFFF6B35), fontSize: 11,
                fontWeight: FontWeight.w700, fontFamily: 'monospace')),
        const SizedBox(height: 4),
        ...congested.take(3).map((e) => Padding(
          padding: const EdgeInsets.only(bottom: 2),
          child: Text(
            'Ch ${e.key}: ${e.value.map((n) => n.displaySsid).join(', ')}',
            style: const TextStyle(color: AppColors.textSecondary,
                fontSize: 10, fontFamily: 'monospace'),
            overflow: TextOverflow.ellipsis,
          ),
        )),
      ]));
  }
}

class _Dot extends StatelessWidget {
  const _Dot(this.color);
  final Color color;
  @override Widget build(BuildContext ctx) =>
    Container(width: 8, height: 8,
        decoration: BoxDecoration(color: color, shape: BoxShape.circle));
}

class _RadarPainter extends CustomPainter {
  const _RadarPainter({required this.networks, required this.sweepAngle});
  final List<WifiNetwork> networks;
  final double            sweepAngle;

  @override
  void paint(Canvas canvas, Size size) {
    final cx = size.width / 2, cy = size.height / 2;
    final maxR = min(cx, cy) * 0.88;

    // Background rings
    for (int i = 1; i <= 4; i++) {
      canvas.drawCircle(Offset(cx, cy), maxR * i / 4, Paint()
        ..color       = AppColors.bgCardBorder.withOpacity(0.4)
        ..style       = PaintingStyle.stroke
        ..strokeWidth = 0.6);
    }

    // RSSI labels on rings
    for (final (r, label) in [(0.25, '-90'), (0.5, '-80'), (0.75, '-67'), (1.0, '-50')]) {
      _label(canvas, Offset(cx + maxR * r + 3, cy - 8), label, Colors.white24, 8);
    }

    // Sweep line
    final sweepRad = sweepAngle * 2 * pi - pi / 2;
    canvas.drawLine(
      Offset(cx, cy),
      Offset(cx + maxR * cos(sweepRad), cy + maxR * sin(sweepRad)),
      Paint()
        ..color       = AppColors.accent.withOpacity(0.6)
        ..strokeWidth = 1.2,
    );
    canvas.drawArc(
      Rect.fromCircle(center: Offset(cx, cy), radius: maxR),
      sweepRad - pi / 6, pi / 6, false,
      Paint()
        ..shader = SweepGradient(
          center: Alignment.center,
          startAngle: sweepRad - pi / 6, endAngle: sweepRad,
          colors: [Colors.transparent, AppColors.accent.withOpacity(0.15)],
        ).createShader(Rect.fromCircle(center: Offset(cx, cy), radius: maxR))
        ..strokeWidth = maxR
        ..style = PaintingStyle.stroke,
    );

    // Channel grid lines (13 channels mapped 0-360°)
    for (int ch = 1; ch <= 13; ch++) {
      final a = (ch - 1) / 12 * 2 * pi - pi / 2;
      canvas.drawLine(Offset(cx, cy),
        Offset(cx + maxR * cos(a), cy + maxR * sin(a)),
        Paint()..color = AppColors.bgCardBorder.withOpacity(0.25)..strokeWidth = 0.4);
    }

    // Precompute congestion
    final channelCount = <int, int>{};
    for (final n in networks) {
      final ch = SignalUtils.channelFromMhz(n.frequencyMhz);
      if (ch > 0) channelCount[ch] = (channelCount[ch] ?? 0) + 1;
    }

    // Plot AP blips
    for (final net in networks) {
      final ch  = SignalUtils.channelFromMhz(net.frequencyMhz);
      if (ch <= 0) continue;

      // Angle from channel (map ch 1-13 to 0-360° for 2.4GHz, separate sector for 5GHz)
      double angleDeg;
      if (net.band == FrequencyBand.ghz2_4) {
        angleDeg = (ch - 1) / 12 * 360 - 90;
      } else if (net.band == FrequencyBand.ghz5) {
        // 5GHz channels (36-165) → right half of radar
        angleDeg = (((ch - 36) / 130).clamp(0, 1) * 180) - 90 + 180;
      } else {
        continue;
      }

      final angleRad = angleDeg * pi / 180;
      final distR    = maxR * net.ratio.clamp(0.1, 1.0);
      final blipX    = cx + distR * cos(angleRad);
      final blipY    = cy + distR * sin(angleRad);
      final blipC    = (channelCount[ch] ?? 0) > 1
          ? const Color(0xFFFF6B35)
          : SignalUtils.bandColor(net.band);

      // Blip glow
      canvas.drawCircle(Offset(blipX, blipY), 8,
          Paint()..color = blipC.withOpacity(0.18)
                 ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 6));
      canvas.drawCircle(Offset(blipX, blipY), 5, Paint()..color = blipC);
      canvas.drawCircle(Offset(blipX, blipY), 3, Paint()..color = Colors.white70);

      // SSID label
      _label(canvas, Offset(blipX + 6, blipY - 6),
          net.displaySsid.length > 8
              ? '${net.displaySsid.substring(0, 8)}…' : net.displaySsid,
          blipC, 8.5);
    }

    // Centre dot
    canvas.drawCircle(Offset(cx, cy), 4, Paint()..color = AppColors.accent);
    canvas.drawCircle(Offset(cx, cy), 6, Paint()
      ..color = AppColors.accent.withOpacity(0.3)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1);
  }

  void _label(Canvas canvas, Offset pos, String t, Color c, double fs) =>
    (TextPainter(
      text: TextSpan(text: t,
          style: TextStyle(color: c, fontSize: fs, fontFamily: 'monospace')),
      textDirection: TextDirection.ltr,
    )..layout()).paint(canvas, pos);

  @override bool shouldRepaint(_RadarPainter o) => o.sweepAngle != sweepAngle;
}