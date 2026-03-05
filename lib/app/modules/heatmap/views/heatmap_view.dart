import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:wifi_signal_visualizer/app/constant/app_colors.dart';
import 'package:wifi_signal_visualizer/app/helper/heatmap_painter.dart';
import 'package:wifi_signal_visualizer/app/utils/signal_utils.dart';
import '../controllers/heatmap_controller.dart';


class HeatmapView extends StatelessWidget {
  const HeatmapView({super.key});

  @override
  Widget build(BuildContext context) {
    final ctrl = Get.find<HeatmapController>();
    return Scaffold(
      backgroundColor: AppColors.bg,
      body: SafeArea(child: Column(children: [
        _appBar(ctrl),
        _stats(ctrl),
        _bandFilter(ctrl),
        Expanded(child: _canvas(ctrl)),
        _actions(ctrl),
      ])),
    );
  }

  Widget _appBar(HeatmapController ctrl) => Padding(
    padding: const EdgeInsets.fromLTRB(16, 10, 16, 4),
    child: Row(children: [
      _iconBtn(Icons.arrow_back_ios_new_rounded, () => Get.back()),
      const SizedBox(width: 10),
      Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start,
          children: [
        const Text('Signal Heatmap', style: TextStyle(
            color: AppColors.textPrimary, fontSize: 16,
            fontWeight: FontWeight.w800, fontFamily: 'monospace')),
        Text(ctrl.ssid, style: const TextStyle(
            color: AppColors.accent, fontSize: 11, fontFamily: 'monospace')),
      ])),
      Obx(() => GestureDetector(
        onTap: ctrl.exportImage,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
          decoration: BoxDecoration(
            color: AppColors.accent.withOpacity(
                ctrl.isExporting.value ? 0.05 : 0.13),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: AppColors.accent.withOpacity(0.55)),
          ),
          child: ctrl.isExporting.value
              ? const SizedBox(width: 14, height: 14,
                  child: CircularProgressIndicator(
                      strokeWidth: 2, color: AppColors.accent))
              : const Row(mainAxisSize: MainAxisSize.min, children: [
                  Icon(Icons.ios_share_rounded, size: 14, color: AppColors.accent),
                  SizedBox(width: 5),
                  Text('Export', style: TextStyle(color: AppColors.accent,
                      fontSize: 11, fontWeight: FontWeight.w700,
                      fontFamily: 'monospace')),
                ]),
        ),
      )),
    ]),
  );

  Widget _iconBtn(IconData icon, VoidCallback onTap) => GestureDetector(
    onTap: onTap,
    child: Container(padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(color: AppColors.bgCard,
          borderRadius: BorderRadius.circular(9),
          border: Border.all(color: AppColors.bgCardBorder)),
      child: Icon(icon, size: 15, color: AppColors.textPrimary)),
  );

  Widget _stats(HeatmapController ctrl) => Container(
    margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
    decoration: BoxDecoration(color: AppColors.bgCard,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.bgCardBorder)),
    child: Row(mainAxisAlignment: MainAxisAlignment.spaceEvenly, children: [
      _Stat('Points',  '${ctrl.total}',                          AppColors.accent),
      _Vdiv(),
      _Stat('Best',    '${ctrl.bestRssi} dBm',                   AppColors.sigExcellent),
      _Vdiv(),
      _Stat('Avg',     '${ctrl.avgRssi.toStringAsFixed(0)} dBm', AppColors.sigFair),
      _Vdiv(),
      _Stat('Worst',   '${ctrl.worstRssi} dBm',                  AppColors.sigUnusable),
    ]),
  );

  Widget _bandFilter(HeatmapController ctrl) => Obx(() {
    final sel   = ctrl.filterBand.value;
    final items = [
      (null,                 '  All  ',  AppColors.textSecondary),
      (FrequencyBand.ghz2_4, '2.4 GHz', AppColors.band2_4),
      (FrequencyBand.ghz5,   '5 GHz',   AppColors.band5),
      (FrequencyBand.ghz6,   '6 GHz',   AppColors.band6),
    ];
    return SizedBox(height: 40,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        itemCount: items.length,
        separatorBuilder: (_, __) => const SizedBox(width: 6),
        itemBuilder: (_, i) {
          final (band, label, color) = items[i];
          final active = sel == band;
          return GestureDetector(
            onTap: () => ctrl.setFilter(band),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 160),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
              decoration: BoxDecoration(
                color: active ? color.withOpacity(0.18) : AppColors.bgCard,
                borderRadius: BorderRadius.circular(18),
                border: Border.all(
                    color: active ? color : AppColors.bgCardBorder,
                    width: active ? 1.4 : 1),
              ),
              child: Text(label, style: TextStyle(
                color: active ? color : AppColors.textSecondary,
                fontSize: 11,
                fontWeight: active ? FontWeight.w700 : FontWeight.w500,
                fontFamily: 'monospace',
              )),
            ),
          );
        },
      ),
    );
  });

  // ── Canvas: uses ctrl.store (public) and ctrl.cacheVersionObs (observable) ──
  Widget _canvas(HeatmapController ctrl) => Padding(
    padding: const EdgeInsets.all(10),
    child: ClipRRect(
      borderRadius: BorderRadius.circular(16),
      child: RepaintBoundary(
        key: ctrl.repaintKey,
        child: Obx(() => CustomPaint(
          painter: HeatmapPainter(
            store:   ctrl.store,              // public getter — no _sc access
            version: ctrl.cacheVersionObs.value, // observable — Obx can track it
          ),
          child: const SizedBox.expand(),
        )),
      ),
    ),
  );

  Widget _actions(HeatmapController ctrl) => Padding(
    padding: const EdgeInsets.fromLTRB(16, 6, 16, 16),
    child: Row(children: [
      Expanded(child: _Btn(label: 'Clear & Rescan',
          icon: Icons.delete_outline_rounded,
          color: AppColors.danger, onTap: ctrl.clearAndBack)),
      const SizedBox(width: 10),
      Expanded(child: _Btn(label: 'Back to Camera',
          icon: Icons.camera_alt_outlined,
          color: AppColors.accent, onTap: () => Get.back())),
    ]),
  );
}

class _Stat extends StatelessWidget {
  const _Stat(this.label, this.value, this.color);
  final String label, value; final Color color;
  @override Widget build(BuildContext context) =>
    Column(mainAxisSize: MainAxisSize.min, children: [
      Text(value, style: TextStyle(color: color, fontSize: 12,
          fontWeight: FontWeight.w800, fontFamily: 'monospace')),
      const SizedBox(height: 2),
      Text(label, style: const TextStyle(color: AppColors.textMuted,
          fontSize: 9, letterSpacing: 0.7)),
    ]);
}

class _Vdiv extends StatelessWidget {
  @override Widget build(BuildContext context) =>
    Container(width: 1, height: 26, color: AppColors.bgCardBorder);
}

class _Btn extends StatelessWidget {
  const _Btn({required this.label, required this.icon,
      required this.color, required this.onTap});
  final String label; final IconData icon;
  final Color color;  final VoidCallback onTap;
  @override Widget build(BuildContext context) => GestureDetector(
    onTap: onTap,
    child: Container(height: 46,
      decoration: BoxDecoration(color: color.withOpacity(0.10),
          borderRadius: BorderRadius.circular(11),
          border: Border.all(color: color.withOpacity(0.45))),
      child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
        Icon(icon, color: color, size: 16), const SizedBox(width: 7),
        Text(label, style: TextStyle(color: color, fontWeight: FontWeight.w700,
            fontFamily: 'monospace', fontSize: 12)),
      ])),
  );
}
