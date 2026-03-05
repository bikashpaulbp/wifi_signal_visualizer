import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:wifi_signal_visualizer/app/constant/app_colors.dart';
import 'package:wifi_signal_visualizer/app/data/local/heatmap_store.dart';
import 'package:wifi_signal_visualizer/app/data/models/saved_session.dart';
import 'package:wifi_signal_visualizer/app/helper/painters/heatmap_painter.dart';


class CompareView extends StatelessWidget {
  const CompareView({super.key});

  @override
  Widget build(BuildContext context) {
    final args = Get.arguments as Map<String, dynamic>;
    final a    = args['a'] as SavedSession;
    final b    = args['b'] as SavedSession;

    final storeA = _buildStore(a);
    final storeB = _buildStore(b);

    return Scaffold(
      backgroundColor: AppColors.bg,
      body: SafeArea(child: Column(children: [
        _header(a, b),
        _statsRow(a, b),
        Expanded(child: Row(children: [
          Expanded(child: _panel(storeA, 'A', a, const Color(0xFF00E5FF))),
          Container(width: 1, color: AppColors.bgCardBorder),
          Expanded(child: _panel(storeB, 'B', b, const Color(0xFFD966FF))),
        ])),
        _diffSummary(a, b),
      ])),
    );
  }

  HeatmapStore _buildStore(SavedSession s) {
    final store = HeatmapStore();
    for (final p in s.points) store.addPoint(p);
    return store;
  }

  Widget _header(SavedSession a, SavedSession b) => Padding(
    padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
    child: Row(children: [
      GestureDetector(onTap: () => Get.back(),
        child: Container(padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(color: AppColors.bgCard,
              borderRadius: BorderRadius.circular(9),
              border: Border.all(color: AppColors.bgCardBorder)),
          child: const Icon(Icons.arrow_back_ios_new_rounded,
              size: 14, color: AppColors.textPrimary))),
      const SizedBox(width: 12),
      const Expanded(child: Text('Session Comparison',
          style: TextStyle(color: AppColors.textPrimary, fontSize: 15,
              fontWeight: FontWeight.w800, fontFamily: 'monospace'))),
    ]));

  Widget _statsRow(SavedSession a, SavedSession b) => Container(
    margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
    decoration: BoxDecoration(color: AppColors.bgCard,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.bgCardBorder)),
    child: Row(mainAxisAlignment: MainAxisAlignment.spaceEvenly, children: [
      _StatCol('A', a.ssid, const Color(0xFF00E5FF)),
      Container(width: 1, height: 32, color: AppColors.bgCardBorder),
      _DiffChip('Avg', a.avgRssi, b.avgRssi),
      Container(width: 1, height: 32, color: AppColors.bgCardBorder),
      _StatCol('B', b.ssid, const Color(0xFFD966FF)),
    ]));

  Widget _panel(HeatmapStore store, String label, SavedSession s, Color c) =>
    Column(children: [
      Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        color: c.withOpacity(0.08),
        child: Row(children: [
          Container(width: 8, height: 8,
              decoration: BoxDecoration(color: c, shape: BoxShape.circle)),
          const SizedBox(width: 5),
          Expanded(child: Text('$label: ${s.ssid}',
              style: TextStyle(color: c, fontSize: 10,
                  fontWeight: FontWeight.w700, fontFamily: 'monospace'),
              overflow: TextOverflow.ellipsis)),
        ])),
      Expanded(child: CustomPaint(
        painter: HeatmapPainter(store: store, version: store.cacheVersion),
        child: const SizedBox.expand(),
      )),
    ]);

  Widget _diffSummary(SavedSession a, SavedSession b) {
    final avgDiff  = a.avgRssi  - b.avgRssi;
    final bestDiff = a.bestRssi - b.bestRssi;
    final winner   = avgDiff > 0 ? 'A' : 'B';
    final wColor   = winner == 'A' ? const Color(0xFF00E5FF) : const Color(0xFFD966FF);

    return Container(
      margin: const EdgeInsets.all(12),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: BoxDecoration(
        color: wColor.withOpacity(0.08),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: wColor.withOpacity(0.4)),
      ),
      child: Row(children: [
        Icon(Icons.emoji_events_rounded, color: wColor, size: 18),
        const SizedBox(width: 8),
        Expanded(child: Text(
          'Session $winner is stronger · avg ${avgDiff.abs().toStringAsFixed(1)} dBm '
          '${avgDiff > 0 ? 'better' : 'weaker'} · best ${bestDiff.abs()} dBm '
          '${bestDiff > 0 ? 'better' : 'weaker'}',
          style: TextStyle(color: wColor, fontSize: 10,
              fontFamily: 'monospace', fontWeight: FontWeight.w600),
        )),
      ]),
    );
  }
}

class _StatCol extends StatelessWidget {
  const _StatCol(this.label, this.ssid, this.color);
  final String label, ssid; final Color color;
  @override Widget build(BuildContext ctx) => Column(
    mainAxisSize: MainAxisSize.min, children: [
    Text(label, style: TextStyle(color: color, fontSize: 13,
        fontWeight: FontWeight.w800, fontFamily: 'monospace')),
    Text(ssid, style: const TextStyle(color: AppColors.textSecondary,
        fontSize: 9, fontFamily: 'monospace'),
        overflow: TextOverflow.ellipsis),
  ]);
}

class _DiffChip extends StatelessWidget {
  const _DiffChip(this.label, this.a, this.b);
  final String label; final double a, b;
  @override Widget build(BuildContext ctx) {
    final diff  = a - b;
    final c     = diff > 3 ? AppColors.sigExcellent
        : diff < -3 ? AppColors.sigUnusable : AppColors.sigFair;
    return Column(mainAxisSize: MainAxisSize.min, children: [
      Text('${diff >= 0 ? '+' : ''}${diff.toStringAsFixed(1)}',
          style: TextStyle(color: c, fontSize: 12,
              fontWeight: FontWeight.w800, fontFamily: 'monospace')),
      Text('$label dBm', style: const TextStyle(color: AppColors.textMuted,
          fontSize: 8, letterSpacing: 0.6)),
    ]);
  }
}