import 'dart:math';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:get/get_rx/src/rx_types/rx_types.dart';
import 'package:wifi_signal_visualizer/app/utils/signal_utils.dart';
import '../../data/models/path_point.dart';
class HeatmapStore {
  final points = <PathPoint>[];
  ui.Image? cachedImage;

  // Observable so HeatmapController.ever() can mirror it into the view
  final cacheVersionObs = 0.obs;
  int get cacheVersion  => cacheVersionObs.value;

  double minX = 0, maxX = 0, minY = 0, maxY = 0;

  static const _cs = Size(900, 900);
  ui.PictureRecorder? _rec;
  Canvas?             _cvs;

  bool get isEmpty => points.isEmpty;
  int  get length  => points.length;

  void addPoint(PathPoint pt) {
    if (points.isNotEmpty) {
      final l = points.last;
      final d = sqrt(pow(pt.x - l.x, 2) + pow(pt.y - l.y, 2));
      if (d < 0.12 && pt.rssi == l.rssi) return;
    }
    points.add(pt);
    _expandBounds(pt);
    _compositePoint(pt);
  }

  void clear() {
    points.clear();
    minX = maxX = minY = maxY = 0;
    _rec = null; _cvs = null;
    cachedImage = null;
    cacheVersionObs.value++;
  }

  Offset toCanvas(double mx, double my, Size cs) {
    final rX  = (maxX - minX).abs().clamp(1.0, double.infinity);
    final rY  = (maxY - minY).abs().clamp(1.0, double.infinity);
    final pad = cs.shortestSide * 0.10;
    return Offset(
      pad + (mx - minX) / rX * (cs.width  - pad * 2),
      pad + (my - minY) / rY * (cs.height - pad * 2),
    );
  }

  void _expandBounds(PathPoint pt) {
    if (points.length == 1) { minX = maxX = pt.x; minY = maxY = pt.y; }
    else {
      if (pt.x < minX) minX = pt.x; if (pt.x > maxX) maxX = pt.x;
      if (pt.y < minY) minY = pt.y; if (pt.y > maxY) maxY = pt.y;
    }
  }

  void _compositePoint(PathPoint pt) {
    if (_rec == null) {
      _rec = ui.PictureRecorder();
      _cvs = Canvas(_rec!);
      _cvs!.drawRect(Rect.fromLTWH(0, 0, _cs.width, _cs.height),
          Paint()..color = const Color(0xFF04080F));
    }
    _drawBlob(_cvs!, pt);
    _flushAsync();
  }

  void _drawBlob(Canvas canvas, PathPoint pt) {
    final c  = toCanvas(pt.x, pt.y, _cs);
    final qc = SignalUtils.qualityColor(pt.quality);
    final bc = SignalUtils.bandColor(pt.band);
    final r  = _cs.shortestSide * 0.11 * pt.ratio.clamp(0.25, 1.0);

    canvas.drawCircle(c, r, Paint()
      ..shader = RadialGradient(colors: [
        qc.withOpacity(0.55), qc.withOpacity(0.12), Colors.transparent,
      ]).createShader(Rect.fromCircle(center: c, radius: r))
      ..blendMode = BlendMode.screen);

    canvas.drawCircle(c, r * 0.14,
        Paint()..color = qc.withOpacity(0.9)..blendMode = BlendMode.screen);

    canvas.drawCircle(c, r * 0.26, Paint()
      ..color       = bc.withOpacity(0.75)
      ..style       = PaintingStyle.stroke
      ..strokeWidth = 1.5
      ..blendMode   = BlendMode.screen);
  }

  Future<void> _flushAsync() async {
    if (_rec == null) return;
    try {
      final pic = _rec!.endRecording();
      _rec = ui.PictureRecorder();
      _cvs = Canvas(_rec!);
      final img = await pic.toImage(_cs.width.toInt(), _cs.height.toInt());
      _cvs!.drawImage(img, Offset.zero, Paint());
      cachedImage = img;
      cacheVersionObs.value++;
    } catch (_) {}
  }
}