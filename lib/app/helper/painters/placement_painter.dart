import 'dart:math';
import 'package:flutter/material.dart';
import 'package:wifi_signal_visualizer/app/constant/app_colors.dart';
import 'package:wifi_signal_visualizer/app/data/local/heatmap_store.dart';


/// Computes and renders the Optimal Placement Advisor overlay.
///
/// Algorithm:
///  1. Divide the bounding box into a grid of cells.
///  2. Interpolate RSSI for each cell centre using IDW (inverse-distance weighting).
///  3. Find the cell with lowest estimated RSSI → that is the "dead zone".
///  4. Recommend the midpoint between the dead zone and the best-signal point.
class PlacementPainter extends CustomPainter {
  const PlacementPainter({required this.store, required this.show});
  final HeatmapStore store;
  final bool         show;

  static const _gridN = 20; // 20×20 cells

  @override
  void paint(Canvas canvas, Size size) {
    if (!show || store.points.length < 4) return;

    final cells = _buildGrid(size);
    if (cells.isEmpty) return;

    // Dead zone = cell with lowest IDW RSSI
    final dead = cells.reduce((a, b) => a.rssi < b.rssi ? a : b);
    // Ideal spot = halfway between dead zone and best measured point
    final best = store.points.reduce((a, b) => a.rssi > b.rssi ? a : b);
    final bestPx = store.toCanvas(best.x, best.y, size);
    final midPx  = Offset(
        (dead.px + bestPx.dx) / 2, (dead.py + bestPx.dy) / 2);

    // Draw dead-zone halo
    canvas.drawCircle(Offset(dead.px, dead.py), 28, Paint()
      ..color = AppColors.sigUnusable.withOpacity(0.25)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 12));
    canvas.drawCircle(Offset(dead.px, dead.py), 20, Paint()
      ..color = AppColors.sigUnusable.withOpacity(0.45)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2);

    // Dead zone label
    _drawLabel(canvas, Offset(dead.px, dead.py - 32),
        'DEAD ZONE', AppColors.sigUnusable);
    _drawLabel(canvas, Offset(dead.px, dead.py - 21),
        '${dead.rssi.round()} dBm', AppColors.sigUnusable.withOpacity(0.7));

    // Arrow from dead zone to suggested placement
    _drawArrow(canvas, Offset(dead.px, dead.py), midPx);

    // Suggested placement star
    _drawStar(canvas, midPx);
    _drawLabel(canvas, Offset(midPx.dx, midPx.dy - 34),
        '★ MOVE ROUTER HERE', AppColors.selected);

    // Distance estimate
    final dxM = best.x - (dead.px - size.width * 0.10)
        / (size.width * 0.80)
        * ((store.maxX - store.minX).abs().clamp(1.0, 1000.0));
    _drawLabel(canvas, Offset(midPx.dx, midPx.dy - 20),
        '~${_estimateMetres(dead, bestPx, store, size).toStringAsFixed(1)} m from current',
        AppColors.selected.withOpacity(0.65));
  }

  List<_Cell> _buildGrid(Size size) {
    final pts = store.points;
    if (pts.isEmpty) return [];
    final cells = <_Cell>[];
    for (int iy = 0; iy < _gridN; iy++) {
      for (int ix = 0; ix < _gridN; ix++) {
        final px = size.width  * (ix + 0.5) / _gridN;
        final py = size.height * (iy + 0.5) / _gridN;
        double wsum = 0, vsum = 0;
        for (final p in pts) {
          final ppx = store.toCanvas(p.x, p.y, size);
          final d   = sqrt(pow(px - ppx.dx, 2) + pow(py - ppx.dy, 2)).clamp(1.0, 1e6);
          final w   = 1.0 / (d * d);
          wsum += w;
          vsum += w * p.rssi;
        }
        cells.add(_Cell(px: px, py: py, rssi: wsum > 0 ? vsum / wsum : -100));
      }
    }
    return cells;
  }

  double _estimateMetres(_Cell dead, Offset best, HeatmapStore s, Size sz) {
    final rX = (s.maxX - s.minX).abs().clamp(1.0, 1000.0);
    final rY = (s.maxY - s.minY).abs().clamp(1.0, 1000.0);
    final pad = sz.shortestSide * 0.10;
    final pxPerMx = (sz.width  - pad * 2) / rX;
    final pxPerMy = (sz.height - pad * 2) / rY;
    return sqrt(pow((dead.px - best.dx) / pxPerMx, 2) +
                pow((dead.py - best.dy) / pxPerMy, 2));
  }

  void _drawArrow(Canvas canvas, Offset from, Offset to) {
    final dir  = (to - from);
    final len  = dir.distance.clamp(10.0, 1000.0);
    final unit = dir / len;
    final end  = from + unit * (len - 16);

    canvas.drawLine(from + unit * 24, end, Paint()
      ..color       = AppColors.selected.withOpacity(0.5)
      ..strokeWidth = 1.5
      ..style       = PaintingStyle.stroke);

    final perp = Offset(-unit.dy, unit.dx);
    final tip  = to;
    canvas.drawPath(
      Path()
        ..moveTo(tip.dx, tip.dy)
        ..lineTo((end + perp * 6).dx, (end + perp * 6).dy)
        ..lineTo((end - perp * 6).dx, (end - perp * 6).dy)
        ..close(),
      Paint()..color = AppColors.selected.withOpacity(0.55));
  }

  void _drawStar(Canvas canvas, Offset c) {
    const n = 5, outerR = 14.0, innerR = 6.0;
    final path = Path();
    for (int i = 0; i < n * 2; i++) {
      final r = i.isEven ? outerR : innerR;
      final a = i * pi / n - pi / 2;
      final pt = Offset(c.dx + r * cos(a), c.dy + r * sin(a));
      i == 0 ? path.moveTo(pt.dx, pt.dy) : path.lineTo(pt.dx, pt.dy);
    }
    path.close();
    canvas.drawPath(path, Paint()
      ..color = AppColors.selected.withOpacity(0.3)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 8));
    canvas.drawPath(path, Paint()..color = AppColors.selected);
  }

  void _drawLabel(Canvas canvas, Offset pos, String text, Color color) {
    final tp = TextPainter(
      text: TextSpan(text: text, style: TextStyle(
        color: color, fontSize: 9.5, fontWeight: FontWeight.w700,
        fontFamily: 'monospace',
      )),
      textDirection: TextDirection.ltr,
    )..layout();
    tp.paint(canvas, pos - Offset(tp.width / 2, 0));
  }

  @override
  bool shouldRepaint(PlacementPainter o) => o.show != show;
}

class _Cell {
  const _Cell({required this.px, required this.py, required this.rssi});
  final double px, py, rssi;
}