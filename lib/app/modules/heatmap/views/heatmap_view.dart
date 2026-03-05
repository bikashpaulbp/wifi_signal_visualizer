import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:wifi_signal_visualizer/app/constant/app_colors.dart';
import 'package:wifi_signal_visualizer/app/helper/painters/heatmap_painter.dart';
import 'package:wifi_signal_visualizer/app/helper/painters/placement_painter.dart';
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
        _speedTestRow(ctrl),
        _actions(ctrl),
      ])),
    );
  }

  // ── App bar ───────────────────────────────────────────────────────────────
  Widget _appBar(HeatmapController ctrl) => Padding(
    padding: const EdgeInsets.fromLTRB(16, 10, 16, 4),
    child: Row(children: [
      _iconBtn(Icons.arrow_back_ios_new_rounded, () => Get.back()),
      const SizedBox(width: 10),
      Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start,
          children: [
        const Text('Signal Heatmap', style: TextStyle(
            color: AppColors.textPrimary, fontSize: 15,
            fontWeight: FontWeight.w800, fontFamily: 'monospace')),
        Text(ctrl.ssid, style: const TextStyle(
            color: AppColors.accent, fontSize: 11, fontFamily: 'monospace')),
      ])),
      // Sessions button
      _iconBtn(Icons.history_rounded, () => Get.toNamed('/sessions'),
          color: AppColors.textSecondary),
      const SizedBox(width: 6),
      // Save button
      Obx(() => _iconBtn(
        ctrl.isSaving.value ? Icons.hourglass_empty_rounded : Icons.save_alt_rounded,
        ctrl.isSaving.value ? () {} : ctrl.saveSession,
        color: AppColors.sigGood,
      )),
      const SizedBox(width: 6),
      // Export button
      Obx(() => GestureDetector(
        onTap: ctrl.exportImage,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          decoration: BoxDecoration(
            color: AppColors.accent.withOpacity(
                ctrl.isExporting.value ? 0.05 : 0.13),
            borderRadius: BorderRadius.circular(9),
            border: Border.all(color: AppColors.accent.withOpacity(0.55)),
          ),
          child: ctrl.isExporting.value
              ? const SizedBox(width: 13, height: 13,
                  child: CircularProgressIndicator(
                      strokeWidth: 2, color: AppColors.accent))
              : const Row(mainAxisSize: MainAxisSize.min, children: [
                  Icon(Icons.ios_share_rounded, size: 13, color: AppColors.accent),
                  SizedBox(width: 4),
                  Text('Export', style: TextStyle(color: AppColors.accent,
                      fontSize: 10, fontWeight: FontWeight.w700,
                      fontFamily: 'monospace')),
                ]),
        ),
      )),
    ]),
  );

  Widget _iconBtn(IconData icon, VoidCallback onTap, {Color? color}) =>
    GestureDetector(onTap: onTap,
      child: Container(padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(color: AppColors.bgCard,
            borderRadius: BorderRadius.circular(9),
            border: Border.all(color: AppColors.bgCardBorder)),
        child: Icon(icon, size: 15,
            color: color ?? AppColors.textPrimary)));

  // ── Stats row ─────────────────────────────────────────────────────────────
  Widget _stats(HeatmapController ctrl) => Container(
    margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 5),
    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
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

  // ── Band filter ───────────────────────────────────────────────────────────
  Widget _bandFilter(HeatmapController ctrl) => Obx(() {
    final sel   = ctrl.filterBand.value;
    final items = [
      (null,                 '  All  ',  AppColors.textSecondary),
      (FrequencyBand.ghz2_4, '2.4 GHz', AppColors.band2_4),
      (FrequencyBand.ghz5,   '5 GHz',   AppColors.band5),
      (FrequencyBand.ghz6,   '6 GHz',   AppColors.band6),
    ];
    return SizedBox(height: 38,
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
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 3),
              decoration: BoxDecoration(
                color: active ? color.withOpacity(0.18) : AppColors.bgCard,
                borderRadius: BorderRadius.circular(18),
                border: Border.all(color: active ? color : AppColors.bgCardBorder,
                    width: active ? 1.4 : 1),
              ),
              child: Text(label, style: TextStyle(
                color: active ? color : AppColors.textSecondary, fontSize: 11,
                fontWeight: active ? FontWeight.w700 : FontWeight.w500,
                fontFamily: 'monospace')),
            ));
        },
      ));
  });

  // ── Heatmap canvas ────────────────────────────────────────────────────────
  Widget _canvas(HeatmapController ctrl) => Padding(
    padding: const EdgeInsets.fromLTRB(10, 6, 10, 4),
    child: ClipRRect(
      borderRadius: BorderRadius.circular(16),
      child: Stack(children: [
        RepaintBoundary(key: ctrl.repaintKey,
          child: Obx(() => CustomPaint(
            painter: HeatmapPainter(
              store:   ctrl.store,
              version: ctrl.cacheVersionObs.value,
            ),
            child: const SizedBox.expand(),
          ))),
        // Placement advisor overlay
        Obx(() => CustomPaint(
          painter: PlacementPainter(
            store: ctrl.store,
            show:  ctrl.showPlacement.value,
          ),
          child: const SizedBox.expand(),
        )),
        // Placement toggle button
        Positioned(top: 8, right: 8,
          child: Obx(() => GestureDetector(
            onTap: ctrl.togglePlacement,
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
              decoration: BoxDecoration(
                color: ctrl.showPlacement.value
                    ? AppColors.selected.withOpacity(0.20)
                    : AppColors.bgCard.withOpacity(0.85),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                    color: ctrl.showPlacement.value
                        ? AppColors.selected : AppColors.bgCardBorder),
              ),
              child: Row(mainAxisSize: MainAxisSize.min, children: [
                Icon(Icons.place_rounded, size: 12,
                    color: ctrl.showPlacement.value
                        ? AppColors.selected : AppColors.textSecondary),
                const SizedBox(width: 4),
                Text('Advisor', style: TextStyle(
                  color: ctrl.showPlacement.value
                      ? AppColors.selected : AppColors.textSecondary,
                  fontSize: 9, fontFamily: 'monospace',
                  fontWeight: FontWeight.w700,
                )),
              ]),
            ),
          )),
        ),
      ]),
    ),
  );

  // ── Speed test row ────────────────────────────────────────────────────────
  Widget _speedTestRow(HeatmapController ctrl) => Obx(() {
    final latest = ctrl.speedResults.isEmpty ? null : ctrl.speedResults.first;
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 3),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      decoration: BoxDecoration(color: AppColors.bgCard,
          borderRadius: BorderRadius.circular(11),
          border: Border.all(color: AppColors.bgCardBorder)),
      child: Row(children: [
        const Icon(Icons.speed_rounded, color: AppColors.accent, size: 16),
        const SizedBox(width: 8),
        Expanded(child: latest == null
          ? const Text('Run a speed test at this location',
              style: TextStyle(color: AppColors.textSecondary,
                  fontSize: 11, fontFamily: 'monospace'))
          : Row(children: [
              _SpeedChip('Latency', latest.latencyLabel,
                  _latencyColor(latest.latencyMs)),
              const SizedBox(width: 10),
              _SpeedChip('Download', latest.downloadLabel,
                  AppColors.sigExcellent),
            ])),
        GestureDetector(
          onTap: ctrl.isTestingSpeed.value ? null : ctrl.runSpeedTest,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
            decoration: BoxDecoration(
              color: AppColors.accent.withOpacity(
                  ctrl.isTestingSpeed.value ? 0.05 : 0.13),
              borderRadius: BorderRadius.circular(7),
              border: Border.all(color: AppColors.accent.withOpacity(0.5)),
            ),
            child: ctrl.isTestingSpeed.value
              ? const SizedBox(width: 12, height: 12,
                  child: CircularProgressIndicator(
                      strokeWidth: 2, color: AppColors.accent))
              : const Text('Test', style: TextStyle(color: AppColors.accent,
                    fontSize: 10, fontWeight: FontWeight.w700,
                    fontFamily: 'monospace'))),
        ),
      ]),
    );
  });

  Color _latencyColor(int ms) => ms < 50   ? AppColors.sigExcellent
      : ms < 100  ? AppColors.sigGood
      : ms < 200  ? AppColors.sigFair
      : ms < 500  ? AppColors.sigPoor
      : AppColors.sigUnusable;

  // ── Action buttons ────────────────────────────────────────────────────────
  Widget _actions(HeatmapController ctrl) => Padding(
    padding: const EdgeInsets.fromLTRB(12, 4, 12, 14),
    child: Row(children: [
      Expanded(child: _Btn(label: 'Clear & Rescan',
          icon: Icons.delete_outline_rounded,
          color: AppColors.danger, onTap: ctrl.clearAndBack)),
      const SizedBox(width: 8),
      Expanded(child: _Btn(label: 'Back to Camera',
          icon: Icons.camera_alt_outlined,
          color: AppColors.accent, onTap: () => Get.back())),
    ]),
  );
}

// ── Small widget helpers ──────────────────────────────────────────────────────

class _Stat extends StatelessWidget {
  const _Stat(this.label, this.value, this.color);
  final String label, value; final Color color;
  @override Widget build(BuildContext ctx) =>
    Column(mainAxisSize: MainAxisSize.min, children: [
      Text(value, style: TextStyle(color: color, fontSize: 11,
          fontWeight: FontWeight.w800, fontFamily: 'monospace')),
      const SizedBox(height: 2),
      Text(label, style: const TextStyle(color: AppColors.textMuted,
          fontSize: 9, letterSpacing: 0.7)),
    ]);
}

class _Vdiv extends StatelessWidget {
  @override Widget build(BuildContext ctx) =>
    Container(width: 1, height: 26, color: AppColors.bgCardBorder);
}

class _Btn extends StatelessWidget {
  const _Btn({required this.label, required this.icon,
      required this.color, required this.onTap});
  final String label; final IconData icon;
  final Color color;  final VoidCallback onTap;
  @override Widget build(BuildContext ctx) => GestureDetector(
    onTap: onTap,
    child: Container(height: 44,
      decoration: BoxDecoration(color: color.withOpacity(0.10),
          borderRadius: BorderRadius.circular(11),
          border: Border.all(color: color.withOpacity(0.45))),
      child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
        Icon(icon, color: color, size: 15),
        const SizedBox(width: 6),
        Text(label, style: TextStyle(color: color, fontWeight: FontWeight.w700,
            fontFamily: 'monospace', fontSize: 11)),
      ])),
  );
}

class _SpeedChip extends StatelessWidget {
  const _SpeedChip(this.label, this.value, this.color);
  final String label, value; final Color color;
  @override Widget build(BuildContext ctx) => Column(
    mainAxisSize: MainAxisSize.min,
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(value, style: TextStyle(color: color, fontSize: 12,
          fontWeight: FontWeight.w800, fontFamily: 'monospace')),
      Text(label, style: const TextStyle(color: AppColors.textMuted,
          fontSize: 8, letterSpacing: 0.5)),
    ]);
}
