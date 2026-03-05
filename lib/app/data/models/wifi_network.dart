import 'package:wifi_signal_visualizer/app/utils/signal_utils.dart';


class WifiNetwork {
  const WifiNetwork({
    required this.ssid,
    required this.bssid,
    required this.rssi,
    required this.frequencyMhz,
    required this.isConnected,
    this.capabilities = '',
  });

  final String ssid;
  final String bssid;
  final int    rssi;
  final int    frequencyMhz;
  final bool   isConnected;
  final String capabilities;

  SignalQuality get quality     => SignalUtils.qualityFromRssi(rssi);
  FrequencyBand get band        => SignalUtils.bandFromMhz(frequencyMhz);
  double        get ratio       => SignalUtils.signalRatio(rssi);
  String        get displaySsid => ssid.isEmpty ? '(hidden)' : ssid;
  // Use BSSID as unique key (SSID can be duplicate across APs)
  String        get key         => bssid.isNotEmpty ? bssid : ssid;

  static WifiNetwork disconnected() => const WifiNetwork(
      ssid: '', bssid: '', rssi: -100, frequencyMhz: 0, isConnected: false);

  @override
  bool operator ==(Object other) =>
      other is WifiNetwork && other.key == key && other.rssi == rssi;
  @override
  int get hashCode => Object.hash(key, rssi);
}