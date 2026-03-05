import 'package:wifi_signal_visualizer/app/utils/signal_utils.dart';


class PathPoint {
  const PathPoint({
    required this.x,
    required this.y,
    required this.rssi,
    required this.frequencyMhz,
    required this.azimuth,
    required this.timestamp,
    required this.ssid,
  });

  final double   x, y;
  final int      rssi;
  final int      frequencyMhz;
  final double   azimuth;
  final DateTime timestamp;
  final String   ssid;

  SignalQuality get quality => SignalUtils.qualityFromRssi(rssi);
  FrequencyBand get band    => SignalUtils.bandFromMhz(frequencyMhz);
  double        get ratio   => SignalUtils.signalRatio(rssi);
}