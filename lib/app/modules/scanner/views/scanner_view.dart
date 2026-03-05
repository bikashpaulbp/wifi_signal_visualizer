import 'dart:math';

import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:wifi_signal_visualizer/app/constant/app_colors.dart';
import 'package:wifi_signal_visualizer/app/helper/ar_overlay_painter.dart';
import 'package:wifi_signal_visualizer/app/helper/network_bubbles_painter.dart';
import 'package:wifi_signal_visualizer/app/modules/app_camera/controllers/app_camera_controller.dart';
import 'package:wifi_signal_visualizer/app/utils/signal_utils.dart';
import 'package:wifi_signal_visualizer/app/widgets/compass_widget.dart';
import 'package:wifi_signal_visualizer/app/widgets/network_list_sheet.dart';
import 'package:wifi_signal_visualizer/app/widgets/signal_hud.dart';
import '../controllers/scanner_controller.dart';

class ScannerView extends StatefulWidget {
  const ScannerView({super.key});
  @override
  State<ScannerView> createState() => _ScannerViewState();
}

class _ScannerViewState extends State<ScannerView> with SingleTickerProviderStateMixin {
  late final AnimationController _anim;
  final _ctrl = Get.find<ScannerController>();
  final _cam = Get.find<AppCameraController>();

  NetworkBubblesPainter? _lastPainter;

  @override
  void initState() {
    super.initState();
    _anim = AnimationController(vsync: this, duration: const Duration(seconds: 2))..repeat();
  }

  @override
  void dispose() {
    _anim.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bg,
      body: SafeArea(
        child: Obx(() {
          if (!_cam.isReady.value) return _buildLoading();
          if (_cam.hasError.value) return _buildError(_cam.errorMessage);

          final sel = _ctrl.selectedNetwork;
          final qColor = sel != null ? SignalUtils.qualityColor(sel.quality) : AppColors.accent;
          final isRec = _ctrl.isRecording.value;
          final networks = _ctrl.networks.toList();
          final positions = Map<String, ({double nx, double ny})>.from(_ctrl.bubblePositions);

          return Stack(
            fit: StackFit.expand,
            children: [
              // ── 1. Camera ───────────────────────────────────────────────────
              RepaintBoundary(child: CameraPreview(_cam.cameraController!)),

              // ── 2. THERMAL overlay on live camera ───────────────────────────
              // Colour-maps signal strength → blue (weak) → green → yellow → red (strong)
              // Opacity scales with signal ratio so it's subtle when signal is weak
              if (sel != null)
                AnimatedBuilder(
                  animation: _anim,
                  builder: (_, __) => CustomPaint(
                    painter: _ThermalPainter(ratio: sel.ratio, animValue: _anim.value),
                  ),
                ),

              // ── 3. Atmospheric AR overlay (grid, rings, vignette) ───────────
              AnimatedBuilder(
                animation: _anim,
                builder: (_, __) => CustomPaint(
                  painter: ArOverlayPainter(network: sel, animValue: _anim.value, isRecording: isRec),
                ),
              ),

              // ── 4. Network SSID bubbles ──────────────────────────────────────
              AnimatedBuilder(
                animation: _anim,
                builder: (_, __) {
                  final painter = NetworkBubblesPainter(networks: networks, positions: positions, selectedKey: _ctrl.selectedKey.value, animValue: _anim.value);
                  _lastPainter = painter;
                  return GestureDetector(
                    behavior: HitTestBehavior.translucent,
                    onTapUp: (d) => _onTapBubble(d.localPosition),
                    child: CustomPaint(painter: painter),
                  );
                },
              ),

              // ── 5. Top HUD ───────────────────────────────────────────────────
              Positioned(
                top: 0,
                left: 0,
                right: 0,
                child: SafeArea(
                  child: SignalHud(network: sel, totalNearby: networks.length, isRecording: isRec, stepCount: _ctrl.stepsSinceStart),
                ),
              ),

              // ── 6. Thermal legend (right edge, mid screen) ───────────────────
              if (sel != null)
                Positioned(
                  right: 10,
                  top: 0,
                  bottom: 0,
                  child: Center(child: _ThermalLegend(ratio: sel.ratio)),
                ),

              // ── 7. Compass ───────────────────────────────────────────────────
              Positioned(
                bottom: 138,
                right: 72,
                child: Obx(() => CompassWidget(currentAzimuth: _ctrl.azimuth, routerBearing: _ctrl.routerBearing.value, signalColor: qColor)),
              ),

              // ── 8. Bottom action bar ─────────────────────────────────────────
              Positioned(bottom: 0, left: 0, right: 0, child: _buildBottomBar(isRec, qColor)),
            ],
          );
        }),
      ),
    );
  }

  void _onTapBubble(Offset pos) {
    final p = _lastPainter;
    if (p == null) return;
    for (final e in p.hitRects.entries) {
      if (e.value.contains(pos)) {
        _ctrl.selectNetwork(e.key);
        return;
      }
    }
  }

  Widget _buildBottomBar(bool isRec, Color qColor) => Container(
    padding: const EdgeInsets.fromLTRB(24, 14, 24, 36),
    decoration: BoxDecoration(
      gradient: LinearGradient(begin: Alignment.bottomCenter, end: Alignment.topCenter, colors: [Colors.black.withOpacity(0.80), Colors.transparent]),
    ),
    child: Row(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: [
        _ActionButton(icon: Icons.wifi_find_rounded, label: 'Networks', color: AppColors.accent, onTap: NetworkListSheet.show),
        _RecordButton(isRecording: isRec, color: qColor, onTap: _ctrl.toggleRecording),
        _ActionButton(icon: Icons.map_outlined, label: 'Heatmap', color: AppColors.accent, onTap: () => Get.toNamed('/heatmap')),
      ],
    ),
  );

  Widget _buildLoading() => const Center(
    child: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        CircularProgressIndicator(color: AppColors.accent),
        SizedBox(height: 16),
        Text(
          'Starting camera…',
          style: TextStyle(color: AppColors.textSecondary, fontFamily: 'monospace'),
        ),
      ],
    ),
  );

  Widget _buildError(String msg) => Center(
    child: Padding(
      padding: const EdgeInsets.all(32),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.no_photography_outlined, color: AppColors.danger, size: 44),
          const SizedBox(height: 14),
          const Text(
            'Camera unavailable',
            style: TextStyle(color: AppColors.textPrimary, fontSize: 17, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          Text(
            msg,
            style: const TextStyle(color: AppColors.textSecondary),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    ),
  );
}

// ═══════════════════════════════════════════════════════════════════════════════
// THERMAL CAMERA OVERLAY
// Maps signal ratio 0-1 → thermal colour spectrum: blue → cyan → green → yellow → red
// Rendered as a full-screen radial gradient that "heats up" from the centre.
// ═══════════════════════════════════════════════════════════════════════════════

class _ThermalPainter extends CustomPainter {
  const _ThermalPainter({required this.ratio, required this.animValue});

  final double ratio; // 0 = weakest, 1 = strongest
  final double animValue; // 0-1 animation tick for subtle pulse

  /// Maps 0-1 ratio to a thermal colour:
  /// 0.0 → deep blue  (#0000FF)
  /// 0.25 → cyan       (#00FFFF)
  /// 0.50 → green      (#00FF00)
  /// 0.75 → yellow     (#FFFF00)
  /// 1.0 → red         (#FF0000)
  static Color _thermal(double t) {
    t = t.clamp(0.0, 1.0);
    if (t < 0.25) {
      final s = t / 0.25;
      return Color.fromARGB(255, 0, (s * 255).round(), 255);
    } else if (t < 0.50) {
      final s = (t - 0.25) / 0.25;
      return Color.fromARGB(255, 0, 255, (255 * (1 - s)).round());
    } else if (t < 0.75) {
      final s = (t - 0.50) / 0.25;
      return Color.fromARGB(255, (s * 255).round(), 255, 0);
    } else {
      final s = (t - 0.75) / 0.25;
      return Color.fromARGB(255, 255, (255 * (1 - s)).round(), 0);
    }
  }

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final hotCol = _thermal(ratio);
    final coolCol = _thermal((ratio * 0.4).clamp(0.0, 1.0));

    // Subtle pulse: ±3% opacity variation
    final pulse = 0.85 + 0.15 * sin(animValue * 2 * pi);
    // Overall opacity: 0.10 when weak signal, up to 0.38 at full strength
    final opacity = (0.10 + ratio * 0.28) * pulse;

    // Radial gradient: hot colour at centre fades to cool at edges
    canvas.drawRect(Rect.fromLTWH(0, 0, size.width, size.height), Paint()..shader = RadialGradient(center: Alignment.center, radius: 0.85, colors: [hotCol.withOpacity(opacity), hotCol.withOpacity(opacity * 0.55), coolCol.withOpacity(opacity * 0.20), Colors.transparent], stops: const [0.0, 0.35, 0.65, 1.0]).createShader(Rect.fromLTWH(0, 0, size.width, size.height)));

    // Thin animated "heat shimmer" rings
    for (int i = 0; i < 2; i++) {
      final phase = (animValue * 0.7 + i * 0.5) % 1.0;
      final radius = size.shortestSide * 0.25 * (0.6 + phase * 0.4);
      canvas.drawCircle(
        center,
        radius,
        Paint()
          ..color = hotCol.withOpacity((1.0 - phase) * opacity * 0.5)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.5 - phase,
      );
    }
  }

  @override
  bool shouldRepaint(_ThermalPainter o) => o.ratio != ratio || o.animValue != animValue;
}

// ═══════════════════════════════════════════════════════════════════════════════
// THERMAL LEGEND — vertical gradient bar with dBm labels
// ═══════════════════════════════════════════════════════════════════════════════

class _ThermalLegend extends StatelessWidget {
  const _ThermalLegend({required this.ratio});
  final double ratio;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 22,
      height: 140,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(4),
        gradient: const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            Color(0xFFFF0000), // red   = strong
            Color(0xFFFFFF00), // yellow
            Color(0xFF00FF00), // green
            Color(0xFF00FFFF), // cyan
            Color(0xFF0000FF), // blue  = weak
          ],
        ),
        border: Border.all(color: Colors.white24, width: 0.5),
        boxShadow: [BoxShadow(color: Colors.black45, blurRadius: 4)],
      ),
      child: Stack(
        children: [
          // Current signal indicator arrow
          Positioned(
            top: (1.0 - ratio) * 116 + 4,
            left: -8,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                CustomPaint(size: const Size(8, 10), painter: _ArrowPainter()),
                const SizedBox(width: 2),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ArrowPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final path = Path()
      ..moveTo(0, size.height / 2)
      ..lineTo(size.width, 0)
      ..lineTo(size.width, size.height)
      ..close();
    canvas.drawPath(
      path,
      Paint()
        ..color = Colors.white
        ..style = PaintingStyle.fill,
    );
  }

  @override
  bool shouldRepaint(_) => false;
}

// ── Reusable button widgets ───────────────────────────────────────────────────

class _RecordButton extends StatelessWidget {
  const _RecordButton({required this.isRecording, required this.color, required this.onTap});
  final bool isRecording;
  final Color color;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final c = isRecording ? AppColors.recDot : color;
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 250),
        width: 62,
        height: 62,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: c.withOpacity(0.16),
          border: Border.all(color: c, width: 2),
          boxShadow: [BoxShadow(color: c.withOpacity(0.45), blurRadius: 14)],
        ),
        child: Icon(isRecording ? Icons.stop_rounded : Icons.fiber_manual_record, color: c, size: 28),
      ),
    );
  }
}

class _ActionButton extends StatelessWidget {
  const _ActionButton({required this.icon, required this.label, required this.color, required this.onTap});
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => GestureDetector(
    onTap: onTap,
    child: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 48,
          height: 48,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: color.withOpacity(0.12),
            border: Border.all(color: color.withOpacity(0.50), width: 1.2),
          ),
          child: Icon(icon, color: color, size: 21),
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style: TextStyle(color: color.withOpacity(0.8), fontSize: 9, fontFamily: 'monospace'),
        ),
      ],
    ),
  );
}
