import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:get/get.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:wifi_signal_visualizer/app/constant/app_colors.dart';
import 'package:wifi_signal_visualizer/app/data/local/heatmap_store.dart';
import 'package:wifi_signal_visualizer/app/utils/signal_utils.dart';
import '../../scanner/controllers/scanner_controller.dart';
import '../../../data/models/path_point.dart';

class HeatmapController extends GetxController {
  HeatmapController({required ScannerController scanner}) : _sc = scanner;

  final ScannerController _sc;

  final isExporting     = false.obs;
  final filterBand      = Rx<FrequencyBand?>(null);
  // Observable version counter — increments every time a new blob is composited
  final cacheVersionObs = 0.obs;
  final repaintKey      = GlobalKey();

  // Public accessor so the view never touches _sc directly
  HeatmapStore get store => _sc.heatmap;

  List<PathPoint> get allPoints => _sc.heatmap.points;
  int    get total     => allPoints.length;
  String get ssid      => allPoints.isEmpty ? '—' : allPoints.first.ssid;
  int    get bestRssi  => allPoints.isEmpty ? -100
      : allPoints.map((p) => p.rssi).reduce((a, b) => a > b ? a : b);
  int    get worstRssi => allPoints.isEmpty ? -100
      : allPoints.map((p) => p.rssi).reduce((a, b) => a < b ? a : b);
  double get avgRssi   => allPoints.isEmpty ? -100.0
      : allPoints.map((p) => p.rssi).fold(0, (s, p) => s + p) / allPoints.length;

  @override
  void onInit() {
    super.onInit();
    // Mirror the store's cacheVersion into our observable so Obx rebuilds work
    ever(_sc.heatmap.cacheVersionObs, (int v) => cacheVersionObs.value = v);
    cacheVersionObs.value = _sc.heatmap.cacheVersion;
  }

  void setFilter(FrequencyBand? b) => filterBand.value = b;

  Future<void> exportImage() async {
    if (isExporting.value) return;
    isExporting.value = true;
    try {
      final rb = repaintKey.currentContext?.findRenderObject()
          as RenderRepaintBoundary?;
      if (rb == null) return;
      final img  = await rb.toImage(pixelRatio: 2.5);
      final data = await img.toByteData(format: ui.ImageByteFormat.png);
      if (data == null) return;
      final dir  = await getTemporaryDirectory();
      final file = File(
          '${dir.path}/heatmap_${DateTime.now().millisecondsSinceEpoch}.png');
      await file.writeAsBytes(data.buffer.asUint8List());
      await Share.shareXFiles(
        [XFile(file.path, mimeType: 'image/png')],
        subject: 'WiFi Heatmap — $ssid',
        text: 'Network: $ssid | Points: $total | Best: $bestRssi dBm',
      );
    } catch (e) {
      Get.snackbar('Export failed', e.toString(),
          backgroundColor: AppColors.bgCard, colorText: Colors.white);
    } finally {
      isExporting.value = false;
    }
  }

  void clearAndBack() {
    _sc.heatmap.clear();
    Get.back();
  }
}
