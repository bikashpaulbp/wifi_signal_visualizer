class SpeedTestResult {
  const SpeedTestResult({
    required this.latencyMs,
    required this.jitterMs,
    required this.downloadKbps,
    required this.uploadKbps,
    required this.timestamp,
    required this.posX,
    required this.posY,
  });

  final int      latencyMs;
  final int      jitterMs;
  final double   downloadKbps;
  final double   uploadKbps;
  final DateTime timestamp;
  final double   posX, posY;

  String get latencyLabel  => '${latencyMs}ms';
  String get jitterLabel   => '±${jitterMs}ms';
  String get downloadLabel => _fmt(downloadKbps);
  String get uploadLabel   => _fmt(uploadKbps);

  static String _fmt(double kbps) => kbps >= 1000
      ? '${(kbps / 1000).toStringAsFixed(1)} Mbps'
      : '${kbps.toStringAsFixed(0)} Kbps';

  String get rating {
    if (downloadKbps >= 25000) return 'Excellent';
    if (downloadKbps >= 5000)  return 'Good';
    if (downloadKbps >= 1000)  return 'Fair';
    return 'Poor';
  }

  /// Suitability flags
  bool get goodForVideoCall   => latencyMs < 150 && jitterMs < 30 && downloadKbps > 2000;
  bool get goodForGaming      => latencyMs < 50  && jitterMs < 15;
  bool get goodFor4kStreaming => downloadKbps > 20000;
}
