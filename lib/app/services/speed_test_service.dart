import 'dart:typed_data';
import 'package:http/http.dart' as http;
import 'package:wifi_signal_visualizer/app/data/models/speed_test_result.dart';


class SpeedTestService {
  static const _latencyUrl  = 'https://1.1.1.1/cdn-cgi/trace';
  static const _downloadUrl = 'https://speed.cloudflare.com/__down?bytes=500000';
  static const _timeout     = Duration(seconds: 12);

  Future<SpeedTestResult> run({double posX = 0, double posY = 0}) async {
    final latency  = await _measureLatency();
    final download = await _measureDownload();
    return SpeedTestResult(
      latencyMs:    latency,
      downloadKbps: download,
      timestamp:    DateTime.now(),
      posX:         posX,
      posY:         posY,
    );
  }

  Future<int> _measureLatency() async {
    try {
      final t0 = DateTime.now();
      await http.get(Uri.parse(_latencyUrl)).timeout(_timeout);
      return DateTime.now().difference(t0).inMilliseconds;
    } catch (_) { return 9999; }
  }

  Future<double> _measureDownload() async {
    try {
      final t0    = DateTime.now();
      final res   = await http.get(Uri.parse(_downloadUrl)).timeout(_timeout);
      final ms    = DateTime.now().difference(t0).inMilliseconds.clamp(1, 30000);
      final bytes = (res.bodyBytes as Uint8List).lengthInBytes;
      return (bytes * 8) / ms;
    } catch (_) { return 0; }
  }
}