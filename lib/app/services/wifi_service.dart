import 'dart:async';
import 'package:get/get.dart';
import 'package:wifi_scan/wifi_scan.dart';
import 'package:network_info_plus/network_info_plus.dart';
import 'package:wifi_signal_visualizer/app/data/models/wifi_network.dart';


/// Owns all WiFi state using pub packages — no custom native code.
///
///  [nearby]     — all visible networks, refreshed every [_scanSec] seconds
///  [connectedBssid] / [connectedSsid] — current AP from network_info_plus
class WifiService extends GetxService {
  final nearby         = <WifiNetwork>[].obs;
  final connectedBssid = ''.obs;
  final connectedSsid  = ''.obs;
  final isScanning     = false.obs;

  static const _scanSec = 15;

  final _info = NetworkInfo();
  Timer? _connTimer;
  Timer? _scanTimer;

  Future<WifiService> init() async => this;

  void startAll() {
    _pollConnected();
    _connTimer = Timer.periodic(
        const Duration(milliseconds: 600), (_) => _pollConnected());
    _doScan();
    _scanTimer = Timer.periodic(
        const Duration(seconds: _scanSec), (_) => _doScan());
  }

  void stopAll() {
    _connTimer?.cancel();
    _scanTimer?.cancel();
  }

  @override
  void onClose() { stopAll(); super.onClose(); }

  // ── Connected network (fast poll) ─────────────────────────────────────────
  Future<void> _pollConnected() async {
    try {
      final bssid = await _info.getWifiBSSID() ?? '';
      final ssid  = (await _info.getWifiName() ?? '').replaceAll('"', '');
      connectedBssid.value = bssid;
      connectedSsid.value  = ssid;
    } catch (_) {}
  }

  // ── Scan all nearby networks ──────────────────────────────────────────────
  Future<void> _doScan() async {
    if (isScanning.value) return;
    isScanning.value = true;
    try {
      // Check if scanning is possible
      final can = await WiFiScan.instance.canStartScan();
      if (can == CanStartScan.yes) {
        await WiFiScan.instance.startScan();
        // Brief pause for results to be ready
        await Future.delayed(const Duration(milliseconds: 600));
      }

      final canGet = await WiFiScan.instance.canGetScannedResults();
      if (canGet != CanGetScannedResults.yes) return;

      final results = await WiFiScan.instance.getScannedResults();

      // Deduplicate by SSID — keep strongest RSSI per name
      final best = <String, WiFiAccessPoint>{};
      for (final ap in results) {
        final ssid = ap.ssid.trim();
        if (ssid.isEmpty) continue;
        final prev = best[ssid];
        if (prev == null || ap.level > prev.level) best[ssid] = ap;
      }

      final bssid = connectedBssid.value;
      final nets = best.values
          .map((ap) => WifiNetwork(
                ssid:         ap.ssid,
                bssid:        ap.bssid,
                rssi:         ap.level,
                frequencyMhz: ap.frequency,
                isConnected:  ap.bssid == bssid,
                capabilities: ap.capabilities,
              ))
          .toList()
        ..sort((a, b) => b.rssi.compareTo(a.rssi));

      nearby.value = nets;
    } catch (_) {
      // Keep last results on any error
    } finally {
      isScanning.value = false;
    }
  }

  // ── Helper: currently connected WifiNetwork (merged from scan + info) ─────
  WifiNetwork get connectedNetwork {
    final bssid = connectedBssid.value;
    if (bssid.isEmpty) return WifiNetwork.disconnected();
    try {
      return nearby.firstWhere((n) => n.bssid == bssid);
    } catch (_) {
      // Not in scan results yet — build minimal entry from network_info_plus
      return WifiNetwork(
        ssid:         connectedSsid.value,
        bssid:        bssid,
        rssi:         -100,
        frequencyMhz: 0,
        isConnected:  true,
      );
    }
  }
}