import 'dart:async';
import 'dart:math';
import 'package:get/get.dart';
import 'package:wifi_signal_visualizer/app/data/local/heatmap_store.dart';
import 'package:wifi_signal_visualizer/app/data/models/path_point.dart';
import 'package:wifi_signal_visualizer/app/data/models/wifi_network.dart';
import 'package:wifi_signal_visualizer/app/services/rssi_history_service.dart';
import 'package:wifi_signal_visualizer/app/services/sensor_service.dart';
import 'package:wifi_signal_visualizer/app/services/wifi_service.dart';



class ScannerController extends GetxController {
  ScannerController({
    required WifiService        wifi,
    required SensorService      sensors,
    required RssiHistoryService history,
  })  : _wifi    = wifi,
        _sensors = sensors,
        _history = history;

  final WifiService        _wifi;
  final SensorService      _sensors;
  final RssiHistoryService _history;

  // ── Public reactive state ─────────────────────────────────────────────────
  List<WifiNetwork> get networks   => _wifi.nearby;
  bool              get isScanning => _wifi.isScanning.value;

  final selectedKey   = ''.obs;
  final routerBearing = 0.0.obs;
  final isRecording   = false.obs;
  final heatmap       = HeatmapStore();
  final bubblePositions = <String, ({double nx, double ny})>{}.obs;

  // Expose history service to views
  RssiHistoryService get historyService => _history;

  WifiNetwork? get selectedNetwork {
    final k = selectedKey.value;
    if (k.isEmpty) return null;
    try { return _wifi.nearby.firstWhere((n) => n.key == k); }
    catch (_) { return null; }
  }

  WifiNetwork get connectedNetwork => _wifi.connectedNetwork;
  double get azimuth          => _sensors.azimuth.value;
  double get arrowAngle       => (routerBearing.value - azimuth + 360) % 360;
  int    get stepsSinceStart  => _sensors.stepCount.value - _stepsAtStart;

  double _bestRssi     = -100.0;
  int    _stepsAtStart = 0;
  int    _lastSteps    = 0;
  double _posX = 0, _posY = 0;
  Timer? _recTimer;

  // ── Lifecycle ─────────────────────────────────────────────────────────────
  @override
  void onInit() {
    super.onInit();
    _wifi.startAll();
    _sensors.startListening();
    _history.startTracking(_wifi.nearby);

    ever(_wifi.connectedBssid, (String bssid) {
      if (bssid.isNotEmpty && selectedKey.value.isEmpty) {
        selectedKey.value = bssid;
      }
    });

    ever(_wifi.nearby, _onNetworks);
    ever(_sensors.stepCount, _onStep);
  }

  @override
  void onClose() {
    _recTimer?.cancel();
    _wifi.stopAll();
    _sensors.stopListening();
    _history.stopTracking();
    super.onClose();
  }

  // ── Network selection ─────────────────────────────────────────────────────
  void selectNetwork(String key) {
    selectedKey.value = key;
    _bestRssi = -100.0;
    routerBearing.value = 0;
  }

  // ── Recording ─────────────────────────────────────────────────────────────
  void toggleRecording() =>
      isRecording.value ? _stopRec() : _startRec();

  void _startRec() {
    if (selectedNetwork == null) {
      Get.snackbar('Select a network first',
          'Tap a WiFi bubble or choose from the Networks list.',
          snackPosition: SnackPosition.BOTTOM);
      return;
    }
    _posX = _posY = 0;
    _stepsAtStart = _sensors.stepCount.value;
    _lastSteps    = _stepsAtStart;
    heatmap.clear();
    isRecording.value = true;
    _sample();
    _recTimer = Timer.periodic(const Duration(seconds: 1), (_) => _sample());
  }

  void _stopRec() {
    _recTimer?.cancel();
    isRecording.value = false;
    if (heatmap.length >= 2) Get.toNamed('/heatmap');
  }

  void _sample() {
    final sel = selectedNetwork;
    if (sel == null || !isRecording.value) return;
    heatmap.addPoint(PathPoint(
      x:            _posX,
      y:            _posY,
      rssi:         sel.rssi,
      frequencyMhz: sel.frequencyMhz,
      azimuth:      _sensors.azimuth.value,
      timestamp:    DateTime.now(),
      ssid:         sel.ssid,
    ));
  }

  // ── Reactive handlers ─────────────────────────────────────────────────────
  void _onNetworks(List<WifiNetwork> nets) {
    _history.startTracking(nets); // keep history service up to date
    _computePositions(nets);
    final sel = selectedNetwork;
    if (sel != null && sel.rssi > _bestRssi) {
      _bestRssi = sel.rssi.toDouble();
      routerBearing.value = _sensors.azimuth.value;
    }
  }

  void _onStep(int current) {
    if (!isRecording.value) return;
    final newSteps = current - _lastSteps;
    if (newSteps <= 0) return;
    final dist = newSteps * SensorService.stepLengthM;
    final rad  = _sensors.azimuth.value * pi / 180;
    _posX += dist * sin(rad);
    _posY += dist * cos(rad);
    _lastSteps = current;
    _sample();
  }

  // ── Bubble layout ─────────────────────────────────────────────────────────
  void _computePositions(List<WifiNetwork> nets) {
    if (nets.isEmpty) { bubblePositions.clear(); return; }
    final sorted = [...nets]..sort((a, b) {
      if (a.key == selectedKey.value) return -1;
      if (b.key == selectedKey.value) return 1;
      return b.rssi.compareTo(a.rssi);
    });
    final count = sorted.length;
    final map   = <String, ({double nx, double ny})>{};
    for (int i = 0; i < count; i++) {
      final t  = count == 1 ? 0.5 : i / (count - 1);
      final nx = 0.10 + t * 0.80;
      final ny = 0.16 + (1.0 - sorted[i].ratio) * 0.52;
      map[sorted[i].key] = (nx: nx, ny: ny);
    }
    bubblePositions.value = map;
  }
}