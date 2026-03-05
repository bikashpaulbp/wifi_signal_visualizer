import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:get/get.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:wifi_signal_visualizer/app/constant/app_colors.dart';
import 'package:wifi_signal_visualizer/app/data/local/heatmap_store.dart';
import 'package:wifi_signal_visualizer/app/data/local/session_store.dart';
import 'package:wifi_signal_visualizer/app/data/models/speed_test_result.dart';
import 'package:wifi_signal_visualizer/app/services/speed_test_service.dart';
import 'package:wifi_signal_visualizer/app/utils/signal_utils.dart';
import '../../scanner/controllers/scanner_controller.dart';
import '../../../data/models/path_point.dart';

class HeatmapController extends GetxController {
  HeatmapController({
    required ScannerController scanner,
    required SessionStore      sessions,
  }) : _sc       = scanner,
       _sessions = sessions;

  final ScannerController _sc;
  final SessionStore      _sessions;
  final _speedTest = SpeedTestService();

  final isExporting       = false.obs;
  final isSaving          = false.obs;
  final isTestingSpeed    = false.obs;
  final showPlacement     = false.obs;
  final filterBand        = Rx<FrequencyBand?>(null);
  final cacheVersionObs   = 0.obs;
  final speedResults      = <SpeedTestResult>[].obs;
  final repaintKey        = GlobalKey();

  HeatmapStore get store => _sc.heatmap;

  List<PathPoint> get allPoints => store.points;
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
    ever(store.cacheVersionObs, (int v) => cacheVersionObs.value = v);
    cacheVersionObs.value = store.cacheVersion;
  }

  void setFilter(FrequencyBand? b) => filterBand.value = b;
  void togglePlacement()           => showPlacement.value = !showPlacement.value;

  // ── Speed test ────────────────────────────────────────────────────────────
  Future<void> runSpeedTest() async {
    if (isTestingSpeed.value) return;
    isTestingSpeed.value = true;
    try {
      // Use position of last heatmap point as location stamp
      final lastPt = allPoints.isEmpty ? null : allPoints.last;
      final result = await _speedTest.run(
        posX: lastPt?.x ?? 0,
        posY: lastPt?.y ?? 0,
      );
      speedResults.insert(0, result);
    } catch (e) {
      Get.snackbar('Speed test failed', e.toString(),
          backgroundColor: AppColors.bgCard, colorText: Colors.white);
    } finally {
      isTestingSpeed.value = false;
    }
  }

  // ── Save session ──────────────────────────────────────────────────────────
  Future<void> saveSession() async {
    if (isSaving.value || allPoints.isEmpty) return;
    isSaving.value = true;
    try {
      await _sessions.save(ssid, List.from(allPoints));
      Get.snackbar('Session saved', '$total points saved for $ssid',
          backgroundColor: AppColors.bgCard.withOpacity(0.95),
          colorText: AppColors.sigExcellent,
          snackPosition: SnackPosition.BOTTOM);
    } catch (e) {
      Get.snackbar('Save failed', e.toString(),
          backgroundColor: AppColors.bgCard, colorText: Colors.white);
    } finally {
      isSaving.value = false;
    }
  }

  // ── Export image ──────────────────────────────────────────────────────────
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
    store.clear();
    Get.back();
  }
}
