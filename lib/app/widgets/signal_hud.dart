import 'package:flutter/material.dart';
import 'package:wifi_signal_visualizer/app/constant/app_colors.dart';
import 'package:wifi_signal_visualizer/app/data/models/wifi_network.dart';
import 'package:wifi_signal_visualizer/app/utils/signal_utils.dart';


class SignalHud extends StatelessWidget {
  const SignalHud({
    super.key,
    required this.network,
    required this.totalNearby,
    this.isRecording = false,
    this.stepCount   = 0,
  });

  final WifiNetwork? network;
  final int          totalNearby;
  final bool         isRecording;
  final int          stepCount;

  @override
  Widget build(BuildContext context) {
    final net    = network;
    final qColor = net != null ? SignalUtils.qualityColor(net.quality) : AppColors.textMuted;
    final bColor = net != null ? SignalUtils.bandColor(net.band)       : AppColors.textMuted;

    return Container(
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 14),
      decoration: BoxDecoration(gradient: LinearGradient(
        begin: Alignment.topCenter, end: Alignment.bottomCenter,
        colors: [Colors.black.withOpacity(0.82), Colors.transparent],
      )),
      child: Row(children: [
        // Left: SSID + meta row
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min, children: [
          Row(children: [
            if (isRecording) ...[_RecDot(), const SizedBox(width: 6)],
            Flexible(child: Text(
              net?.displaySsid ?? 'No network selected',
              style: const TextStyle(color: AppColors.textPrimary, fontSize: 15,
                  fontWeight: FontWeight.w800, fontFamily: 'monospace'),
              overflow: TextOverflow.ellipsis,
            )),
          ]),
          const SizedBox(height: 3),
          Row(children: [
            Text(net != null ? SignalUtils.qualityLabel(net.quality) : '—',
                style: TextStyle(color: qColor, fontSize: 10, letterSpacing: 0.6)),
            const SizedBox(width: 8),
            _Chip('$totalNearby found', AppColors.textSecondary),
            if (isRecording) ...[
              const SizedBox(width: 5),
              _Chip('$stepCount steps', AppColors.recDot),
            ],
          ]),
        ])),

        const SizedBox(width: 8),

        // Right: dBm + band badge
        if (net != null) Column(crossAxisAlignment: CrossAxisAlignment.end,
          mainAxisSize: MainAxisSize.min, children: [
          _Badge('${net.rssi} dBm', qColor, large: true),
          const SizedBox(height: 4),
          Row(mainAxisSize: MainAxisSize.min, children: [
            _Badge(SignalUtils.bandLabel(net.band), bColor),
          ]),
        ]),
      ]),
    );
  }
}

class _Badge extends StatelessWidget {
  const _Badge(this.label, this.color, {this.large = false});
  final String label; final Color color; final bool large;
  @override
  Widget build(BuildContext context) => Container(
    padding: EdgeInsets.symmetric(
        horizontal: large ? 10 : 6, vertical: large ? 5 : 2),
    decoration: BoxDecoration(
      color: color.withOpacity(0.12),
      border: Border.all(color: color.withOpacity(0.55)),
      borderRadius: BorderRadius.circular(6),
    ),
    child: Text(label, style: TextStyle(
      color: color, fontSize: large ? 15 : 9,
      fontWeight: FontWeight.w800, fontFamily: 'monospace',
    )),
  );
}

class _Chip extends StatelessWidget {
  const _Chip(this.label, this.color);
  final String label; final Color color;
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
    decoration: BoxDecoration(
      color: color.withOpacity(0.10),
      borderRadius: BorderRadius.circular(4),
    ),
    child: Text(label, style: TextStyle(
        color: color, fontSize: 9, fontFamily: 'monospace')),
  );
}

class _RecDot extends StatefulWidget {
  @override State<_RecDot> createState() => _RecDotState();
}
class _RecDotState extends State<_RecDot> with SingleTickerProviderStateMixin {
  late final AnimationController _a;
  @override void initState() {
    super.initState();
    _a = AnimationController(vsync: this,
        duration: const Duration(milliseconds: 700))..repeat(reverse: true);
  }
  @override void dispose() { _a.dispose(); super.dispose(); }
  @override Widget build(BuildContext context) => AnimatedBuilder(
    animation: _a,
    builder: (_, __) => Container(width: 7, height: 7,
      decoration: BoxDecoration(shape: BoxShape.circle,
        color: AppColors.recDot.withOpacity(0.4 + 0.6 * _a.value),
        boxShadow: [BoxShadow(
            color: AppColors.recDot.withOpacity(0.5 * _a.value), blurRadius: 5)],
      )),
  );
}