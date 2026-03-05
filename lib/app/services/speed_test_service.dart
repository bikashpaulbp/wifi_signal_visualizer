import 'dart:math';
import 'dart:typed_data';
import 'package:http/http.dart' as http;
import 'package:wifi_signal_visualizer/app/data/models/speed_test_result.dart';


class SpeedTestService {
  static const _latencyUrl  = 'https://1.1.1.1/cdn-cgi/trace';
  static const _downloadUrl = 'https://speed.cloudflare.com/__down?bytes=1000000';
  static const _uploadUrl   = 'https://speed.cloudflare.com/__up';
  static const _timeout     = Duration(seconds: 15);
  static const _pingCount   = 5; // pings for jitter calc

  Future<SpeedTestResult> run({double posX = 0, double posY = 0}) async {
    final (latency, jitter) = await _measureLatencyAndJitter();
    final download          = await _measureDownload();
    final upload            = await _measureUpload();
    return SpeedTestResult(
      latencyMs:    latency,
      jitterMs:     jitter,
      downloadKbps: download,
      uploadKbps:   upload,
      timestamp:    DateTime.now(),
      posX:         posX,
      posY:         posY,
    );
  }

  Future<(int, int)> _measureLatencyAndJitter() async {
    final samples = <int>[];
    for (int i = 0; i < _pingCount; i++) {
      try {
        final t0 = DateTime.now();
        await http.get(Uri.parse(_latencyUrl)).timeout(_timeout);
        samples.add(DateTime.now().difference(t0).inMilliseconds);
      } catch (_) { samples.add(9999); }
    }
    final valid = samples.where((s) => s < 9000).toList();
    if (valid.isEmpty) return (9999, 0);
    final avg    = valid.reduce((a, b) => a + b) / valid.length;
    final jitter = valid.length > 1
        ? (sqrt(valid.map((v) => pow(v - avg, 2).toDouble())
              .reduce((a, b) => a + b) / valid.length)).round()
        : 0;
    return (avg.round(), jitter);
  }

  Future<double> _measureDownload() async {
    try {
      final t0    = DateTime.now();
      final res   = await http.get(Uri.parse(_downloadUrl)).timeout(_timeout);
      final ms    = DateTime.now().difference(t0).inMilliseconds.clamp(1, 30000);
      final bytes = (res.bodyBytes as Uint8List).lengthInBytes;
      return (bytes * 8.0) / ms;
    } catch (_) { return 0; }
  }

  Future<double> _measureUpload() async {
    try {
      final payload = Uint8List(512 * 1024); // 512 KB
      final t0      = DateTime.now();
      await http.post(
        Uri.parse(_uploadUrl),
        headers: {'Content-Type': 'application/octet-stream'},
        body: payload,
      ).timeout(_timeout);
      final ms = DateTime.now().difference(t0).inMilliseconds.clamp(1, 30000);
      return (payload.lengthInBytes * 8.0) / ms;
    } catch (_) { return 0; }
  }
}
