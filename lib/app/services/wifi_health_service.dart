import 'dart:math';
import 'package:get/get.dart';
import 'package:wifi_signal_visualizer/app/data/models/wifi_network.dart';
import '../utils/signal_utils.dart';


/// Computes a 0–100 composite WiFi Health Score every scan cycle.
///
/// Factors (weighted):
///   40% Signal strength   (RSSI ratio of connected AP)
///   20% Channel congestion (how many APs share the same channel)
///   20% Security          (WPA3=100, WPA2=80, WPA=50, WEP=10, OPEN=0)
///   20% Stability         (RSSI variance over last 10 samples — lower = better)
class WifiHealthService extends GetxService {
  final score       = 0.obs;       // 0-100
  final grade       = 'N/A'.obs;   // A+ / A / B / C / D / F
  final breakdown   = <String, int>{}.obs; // component scores

  // Rolling RSSI buffer for stability calc
  final _rssiBuffer = <int>[];
  static const _bufMax = 10;

  Future<WifiHealthService> init() async => this;

  void update(List<WifiNetwork> all, WifiNetwork? connected) {
    if (connected == null || connected.rssi == -100) {
      score.value     = 0;
      grade.value     = 'N/A';
      breakdown.value = {};
      return;
    }

    // ── 1. Signal score (40%) ────────────────────────────────────────────
    final sigScore = (connected.ratio * 100).round().clamp(0, 100);

    // ── 2. Congestion score (20%) ────────────────────────────────────────
    final ch      = SignalUtils.channelFromMhz(connected.frequencyMhz);
    final overlap = ch > 0
        ? all.where((n) => SignalUtils.channelsInterfere(
              SignalUtils.channelFromMhz(n.frequencyMhz), ch)).length
        : 1;
    // 1 AP on channel = 100, 2 = 70, 3 = 40, 4+ = 10
    final congScore = switch (overlap) {
      1     => 100,
      2     => 70,
      3     => 40,
      _     => 10,
    };

    // ── 3. Security score (20%) ──────────────────────────────────────────
    final sec     = SignalUtils.securityFromCapabilities(connected.capabilities);
    final secScore = switch (sec) {
      SecurityLevel.wpa3 => 100,
      SecurityLevel.wpa2 => 80,
      SecurityLevel.wpa  => 50,
      SecurityLevel.wep  => 10,
      SecurityLevel.open => 0,
    };

    // ── 4. Stability score (20%) ─────────────────────────────────────────
    _rssiBuffer.add(connected.rssi);
    if (_rssiBuffer.length > _bufMax) _rssiBuffer.removeAt(0);
    int stabScore = 100;
    if (_rssiBuffer.length >= 3) {
      final mean = _rssiBuffer.reduce((a, b) => a + b) / _rssiBuffer.length;
      final variance = _rssiBuffer
          .map((v) => pow(v - mean, 2).toDouble())
          .reduce((a, b) => a + b) / _rssiBuffer.length;
      final stddev = sqrt(variance);
      // stddev 0 = 100, 5 = 50, 10+ = 0
      stabScore = (100 - (stddev * 10)).round().clamp(0, 100);
    }

    // ── Composite ────────────────────────────────────────────────────────
    final total = (sigScore  * 0.40 +
                   congScore * 0.20 +
                   secScore  * 0.20 +
                   stabScore * 0.20).round().clamp(0, 100);

    score.value = total;
    grade.value = switch (total) {
      >= 90 => 'A+',
      >= 80 => 'A',
      >= 70 => 'B',
      >= 55 => 'C',
      >= 40 => 'D',
      _     => 'F',
    };
    breakdown.value = {
      'Signal':     sigScore,
      'Channel':    congScore,
      'Security':   secScore,
      'Stability':  stabScore,
    };
  }

  void reset() {
    _rssiBuffer.clear();
    score.value     = 0;
    grade.value     = 'N/A';
    breakdown.value = {};
  }
}