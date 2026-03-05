class SpeedTestResult {
  const SpeedTestResult({
    required this.latencyMs,
    required this.downloadKbps,
    required this.timestamp,
    required this.posX,
    required this.posY,
  });
  final int      latencyMs;
  final double   downloadKbps;
  final DateTime timestamp;
  final double   posX, posY;

  String get latencyLabel  => '${latencyMs}ms';
  String get downloadLabel => downloadKbps >= 1000
      ? '${(downloadKbps / 1000).toStringAsFixed(1)} Mbps'
      : '${downloadKbps.toStringAsFixed(0)} Kbps';
}