import 'dart:async';
import 'dart:collection';
import 'package:get/get.dart';
import 'package:wifi_signal_visualizer/app/data/models/wifi_network.dart';


/// Maintains a 60-point (60-second) rolling RSSI history per network key.
class RssiHistoryService extends GetxService {
  static const _maxPoints = 60;
  static const _intervalMs = 1000;

  // key → circular list of (timestamp, rssi)
  final _history = <String, ListQueue<({DateTime ts, int rssi})>>{};
  final version  = 0.obs; // bumped every second so Obx can react

  Timer? _timer;

  Future<RssiHistoryService> init() async => this;

  void startTracking(List<WifiNetwork> networks) {
    _timer?.cancel();
    _timer = Timer.periodic(
      const Duration(milliseconds: _intervalMs),
      (_) => _tick(networks),
    );
  }

  void stopTracking() => _timer?.cancel();

  @override
  void onClose() { stopTracking(); super.onClose(); }

  void _tick(List<WifiNetwork> nets) {
    final now = DateTime.now();
    for (final n in nets) {
      final q = _history.putIfAbsent(n.key, ListQueue.new);
      q.addLast((ts: now, rssi: n.rssi));
      while (q.length > _maxPoints) q.removeFirst();
    }
    version.value++;
  }

  /// Returns a list of up to 60 RSSI values for [key], oldest first.
  List<int> history(String key) =>
      _history[key]?.map((e) => e.rssi).toList() ?? [];

  /// Min/max/avg for a key over the recorded window.
  ({int min, int max, double avg}) stats(String key) {
    final h = history(key);
    if (h.isEmpty) return (min: -100, max: -100, avg: -100.0);
    return (
      min: h.reduce((a, b) => a < b ? a : b),
      max: h.reduce((a, b) => a > b ? a : b),
      avg: h.reduce((a, b) => a + b) / h.length,
    );
  }
}