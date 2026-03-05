import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:wifi_signal_visualizer/app/constant/app_colors.dart';
import 'package:wifi_signal_visualizer/app/data/models/saved_session.dart';
import 'package:wifi_signal_visualizer/app/utils/signal_utils.dart';
import '../controllers/sessions_controller.dart';


class SessionsView extends StatelessWidget {
  const SessionsView({super.key});

  @override
  Widget build(BuildContext context) {
    final ctrl = Get.find<SessionsController>();
    return Scaffold(
      backgroundColor: AppColors.bg,
      body: SafeArea(child: Column(children: [
        _header(ctrl),
        _compareBar(ctrl),
        Expanded(child: Obx(() {
          if (ctrl.sessions.isEmpty) return _empty();
          return ListView.builder(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            itemCount: ctrl.sessions.length,
            itemBuilder: (_, i) => _SessionCard(
                session: ctrl.sessions[i], ctrl: ctrl),
          );
        })),
      ])),
    );
  }

  Widget _header(SessionsController ctrl) => Padding(
    padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
    child: Row(children: [
      GestureDetector(onTap: () => Get.back(),
        child: Container(padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(color: AppColors.bgCard,
              borderRadius: BorderRadius.circular(9),
              border: Border.all(color: AppColors.bgCardBorder)),
          child: const Icon(Icons.arrow_back_ios_new_rounded,
              size: 14, color: AppColors.textPrimary))),
      const SizedBox(width: 12),
      const Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Saved Sessions', style: TextStyle(color: AppColors.textPrimary,
              fontSize: 16, fontWeight: FontWeight.w800, fontFamily: 'monospace')),
          Text('Tap to reload · Long press to delete',
              style: TextStyle(color: AppColors.textMuted, fontSize: 10,
                  fontFamily: 'monospace')),
        ])),
      Obx(() => GestureDetector(
        onTap: ctrl.isCompareMode.value
            ? ctrl.exitCompareMode : ctrl.enterCompareMode,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          decoration: BoxDecoration(
            color: AppColors.accent.withOpacity(
                ctrl.isCompareMode.value ? 0.20 : 0.10),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: AppColors.accent.withOpacity(0.5)),
          ),
          child: Text(ctrl.isCompareMode.value ? 'Cancel' : 'Compare',
              style: const TextStyle(color: AppColors.accent, fontSize: 11,
                  fontWeight: FontWeight.w700, fontFamily: 'monospace'))),
      )),
    ]));

  Widget _compareBar(SessionsController ctrl) => Obx(() {
    if (!ctrl.isCompareMode.value) return const SizedBox.shrink();
    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      margin: const EdgeInsets.fromLTRB(12, 4, 12, 4),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: AppColors.accent.withOpacity(0.08),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.accent.withOpacity(0.3)),
      ),
      child: Row(children: [
        const Icon(Icons.compare_arrows_rounded,
            color: AppColors.accent, size: 16),
        const SizedBox(width: 8),
        Expanded(child: Text(
          ctrl.comparingA.value == null
              ? 'Select session A…'
              : ctrl.comparingB.value == null
                  ? 'A: ${ctrl.comparingA.value!.ssid}  — Select session B…'
                  : 'A vs B ready',
          style: const TextStyle(color: AppColors.accent, fontSize: 11,
              fontFamily: 'monospace'),
          overflow: TextOverflow.ellipsis,
        )),
        if (ctrl.canCompare)
          GestureDetector(onTap: ctrl.openComparison,
            child: Container(padding: const EdgeInsets.symmetric(
                horizontal: 10, vertical: 5),
              decoration: BoxDecoration(color: AppColors.accent.withOpacity(0.18),
                  borderRadius: BorderRadius.circular(7)),
              child: const Text('Compare →',
                  style: TextStyle(color: AppColors.accent,
                      fontSize: 11, fontWeight: FontWeight.w700,
                      fontFamily: 'monospace')))),
      ]),
    );
  });

  Widget _empty() => const Center(child: Padding(
    padding: EdgeInsets.all(40),
    child: Column(mainAxisSize: MainAxisSize.min, children: [
      Icon(Icons.history_toggle_off_rounded,
          color: AppColors.textMuted, size: 42),
      SizedBox(height: 14),
      Text('No saved sessions yet', style: TextStyle(
          color: AppColors.textMuted, fontFamily: 'monospace', fontSize: 13)),
      SizedBox(height: 6),
      Text('Complete a heatmap walk and tap Save.',
          style: TextStyle(color: AppColors.textMuted,
              fontFamily: 'monospace', fontSize: 10)),
    ])));
}

class _SessionCard extends StatelessWidget {
  const _SessionCard({required this.session, required this.ctrl});
  final SavedSession        session;
  final SessionsController  ctrl;

  @override
  Widget build(BuildContext context) {
    final qc    = SignalUtils.qualityColor(
        SignalUtils.qualityFromRssi(session.bestRssi));
    final isA   = ctrl.isSelectedA(session.id);
    final isB   = ctrl.isSelectedB(session.id);
    final label = isA ? 'A' : isB ? 'B' : null;
    final borderColor = isA ? const Color(0xFF00E5FF)
        : isB ? const Color(0xFFD966FF) : AppColors.bgCardBorder;

    return Obx(() {
      // Rebuild when compare state changes
      ctrl.isCompareMode.value;
      ctrl.comparingA.value;
      ctrl.comparingB.value;
      final isA2   = ctrl.isSelectedA(session.id);
      final isB2   = ctrl.isSelectedB(session.id);
      final label2 = isA2 ? 'A' : isB2 ? 'B' : null;
      final border2 = isA2 ? const Color(0xFF00E5FF)
          : isB2 ? const Color(0xFFD966FF) : AppColors.bgCardBorder;

      return GestureDetector(
        onTap: ctrl.isCompareMode.value
            ? () => ctrl.selectForCompare(session)
            : () => ctrl.loadIntoHeatmap(session),
        onLongPress: () => _confirmDelete(context),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          margin: const EdgeInsets.only(bottom: 10),
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: (isA2 || isB2)
                ? border2.withOpacity(0.08) : AppColors.bgCard,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: border2,
                width: (isA2 || isB2) ? 1.8 : 1.0),
          ),
          child: Row(children: [
            // Compare label badge
            if (label2 != null)
              Container(width: 28, height: 28,
                decoration: BoxDecoration(color: border2.withOpacity(0.2),
                    shape: BoxShape.circle),
                child: Center(child: Text(label2, style: TextStyle(
                    color: border2, fontSize: 14,
                    fontWeight: FontWeight.w900))))
            else
              Container(width: 28, height: 28,
                decoration: BoxDecoration(
                    color: qc.withOpacity(0.15), shape: BoxShape.circle),
                child: Icon(Icons.wifi_rounded, color: qc, size: 16)),
            const SizedBox(width: 12),
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start,
              children: [
              Text(session.ssid, style: const TextStyle(
                  color: AppColors.textPrimary, fontSize: 13,
                  fontWeight: FontWeight.w700, fontFamily: 'monospace'),
                  overflow: TextOverflow.ellipsis),
              const SizedBox(height: 3),
              Text(_formatDate(session.savedAt),
                  style: const TextStyle(color: AppColors.textSecondary,
                      fontSize: 10, fontFamily: 'monospace')),
            ])),
            Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
              Text('${session.total} pts', style: const TextStyle(
                  color: AppColors.textSecondary, fontSize: 10,
                  fontFamily: 'monospace')),
              const SizedBox(height: 3),
              Text('best ${session.bestRssi} dBm',
                  style: TextStyle(color: qc, fontSize: 11,
                      fontWeight: FontWeight.w700, fontFamily: 'monospace')),
            ]),
          ]),
        ),
      );
    });
  }

  String _formatDate(DateTime dt) {
    final now  = DateTime.now();
    final diff = now.difference(dt);
    if (diff.inMinutes < 60)  return '${diff.inMinutes}m ago';
    if (diff.inHours   < 24)  return '${diff.inHours}h ago';
    return '${dt.day}/${dt.month}/${dt.year}';
  }

  void _confirmDelete(BuildContext ctx) {
    showDialog(context: ctx, builder: (_) => AlertDialog(
      backgroundColor: AppColors.bgSurface,
      title: const Text('Delete session?', style: TextStyle(
          color: AppColors.textPrimary, fontFamily: 'monospace')),
      content: Text('${session.ssid} · ${_formatDate(session.savedAt)}',
          style: const TextStyle(color: AppColors.textSecondary,
              fontFamily: 'monospace')),
      actions: [
        TextButton(onPressed: () => Get.back(),
            child: const Text('Cancel', style: TextStyle(
                color: AppColors.textSecondary))),
        TextButton(onPressed: () {
          ctrl.deleteSession(session.id);
          Get.back();
        }, child: const Text('Delete',
            style: TextStyle(color: AppColors.danger))),
      ],
    ));
  }
}