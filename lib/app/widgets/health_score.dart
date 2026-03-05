import 'dart:math';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:wifi_signal_visualizer/app/constant/app_colors.dart';
import 'package:wifi_signal_visualizer/app/services/wifi_health_service.dart';


/// Circular arc gauge showing the 0–100 WiFi Health Score.
/// Tap to expand breakdown sheet.
class HealthScoreWidget extends StatelessWidget {
  const HealthScoreWidget({super.key});

  @override
  Widget build(BuildContext context) {
    final svc = Get.find<WifiHealthService>();
    return Obx(() {
      final s = svc.score.value;
      final g = svc.grade.value;
      return GestureDetector(
        onTap: () => _showBreakdown(context, svc),
        child: SizedBox(
          width: 56, height: 56,
          child: CustomPaint(
            painter: _GaugePainter(score: s),
            child: Center(child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(g, style: TextStyle(
                    color: _gradeColor(s), fontSize: 14,
                    fontWeight: FontWeight.w900,
                    fontFamily: 'monospace')),
                Text('$s', style: const TextStyle(
                    color: AppColors.textSecondary, fontSize: 8,
                    fontFamily: 'monospace')),
              ],
            )),
          ),
        ),
      );
    });
  }

  static Color _gradeColor(int s) {
    if (s >= 90) return AppColors.sigExcellent;
    if (s >= 70) return AppColors.sigGood;
    if (s >= 50) return AppColors.sigFair;
    if (s >= 30) return AppColors.sigPoor;
    return AppColors.sigUnusable;
  }

  void _showBreakdown(BuildContext ctx, WifiHealthService svc) {
    showModalBottomSheet(
      context: ctx,
      backgroundColor: Colors.transparent,
      builder: (_) => _HealthBreakdownSheet(svc: svc),
    );
  }
}

class _GaugePainter extends CustomPainter {
  const _GaugePainter({required this.score});
  final int score;

  @override
  void paint(Canvas canvas, Size size) {
    final cx = size.width / 2;
    final cy = size.height / 2;
    final r  = min(cx, cy) - 4;
    const startAngle = pi * 0.75;
    const sweepFull  = pi * 1.5;

    // Background arc
    canvas.drawArc(
      Rect.fromCircle(center: Offset(cx, cy), radius: r),
      startAngle, sweepFull, false,
      Paint()
        ..color       = AppColors.bgCardBorder
        ..strokeWidth = 5
        ..style       = PaintingStyle.stroke
        ..strokeCap   = StrokeCap.round,
    );

    // Score arc
    if (score > 0) {
      final sweep   = sweepFull * score / 100;
      final gc      = HealthScoreWidget._gradeColor(score);
      canvas.drawArc(
        Rect.fromCircle(center: Offset(cx, cy), radius: r),
        startAngle, sweep, false,
        Paint()
          ..color       = gc
          ..strokeWidth = 5
          ..style       = PaintingStyle.stroke
          ..strokeCap   = StrokeCap.round
          ..maskFilter  = MaskFilter.blur(BlurStyle.normal, score > 50 ? 2 : 0),
      );
    }
  }

  @override bool shouldRepaint(_GaugePainter o) => o.score != score;
}

class _HealthBreakdownSheet extends StatelessWidget {
  const _HealthBreakdownSheet({required this.svc});
  final WifiHealthService svc;

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      final s = svc.score.value;
      final g = svc.grade.value;
      final b = Map<String, int>.from(svc.breakdown);

      return Container(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
        decoration: BoxDecoration(
          color: AppColors.bgSurface,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
          border: Border(top: BorderSide(
              color: AppColors.bgCardBorder, width: 1.5)),
        ),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Center(child: Container(
            width: 36, height: 4,
            decoration: BoxDecoration(
                color: AppColors.bgCardBorder,
                borderRadius: BorderRadius.circular(2)))),
          const SizedBox(height: 14),
          Row(children: [
            // Big gauge
            SizedBox(width: 80, height: 80,
                child: CustomPaint(painter: _GaugePainter(score: s),
                  child: Center(child: Text(g, style: TextStyle(
                      color: HealthScoreWidget._gradeColor(s),
                      fontSize: 22, fontWeight: FontWeight.w900,
                      fontFamily: 'monospace'))))),
            const SizedBox(width: 16),
            Expanded(child: Column(
                crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('WiFi Health Score', style: const TextStyle(
                  color: AppColors.textPrimary, fontSize: 15,
                  fontWeight: FontWeight.w800, fontFamily: 'monospace')),
              const SizedBox(height: 4),
              Text('$s / 100  ·  ${_ratingText(s)}',
                  style: TextStyle(
                      color: HealthScoreWidget._gradeColor(s),
                      fontSize: 12, fontFamily: 'monospace')),
            ])),
          ]),
          const SizedBox(height: 18),
          if (b.isEmpty)
            const Text('Connect to a network to see breakdown.',
                style: TextStyle(color: AppColors.textSecondary,
                    fontFamily: 'monospace'))
          else
            ...b.entries.map((e) => _Bar(
                label: e.key,
                score: e.value,
                weight: _weight(e.key))),
        ]),
      );
    });
  }

  String _ratingText(int s) {
    if (s >= 90) return 'Excellent connection';
    if (s >= 70) return 'Good connection';
    if (s >= 50) return 'Fair connection';
    if (s >= 30) return 'Poor connection';
    return 'Very poor connection';
  }

  String _weight(String k) => switch (k) {
    'Signal'    => '40%',
    'Channel'   => '20%',
    'Security'  => '20%',
    'Stability' => '20%',
    _           => '',
  };
}

class _Bar extends StatelessWidget {
  const _Bar({required this.label, required this.score, required this.weight});
  final String label, weight;
  final int    score;

  @override
  Widget build(BuildContext context) {
    final c = HealthScoreWidget._gradeColor(score);
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Expanded(child: Text('$label  ·  $weight',
              style: const TextStyle(color: AppColors.textSecondary,
                  fontSize: 10, fontFamily: 'monospace'))),
          Text('$score', style: TextStyle(color: c, fontSize: 11,
              fontWeight: FontWeight.w800, fontFamily: 'monospace')),
        ]),
        const SizedBox(height: 4),
        ClipRRect(
          borderRadius: BorderRadius.circular(3),
          child: Stack(children: [
            Container(height: 6, color: AppColors.bgCardBorder),
            FractionallySizedBox(
              widthFactor: score / 100,
              child: Container(height: 6,
                decoration: BoxDecoration(
                    color: c,
                    borderRadius: BorderRadius.circular(3),
                    boxShadow: [BoxShadow(color: c.withOpacity(0.5),
                        blurRadius: 4)])),
            ),
          ]),
        ),
      ]),
    );
  }
}