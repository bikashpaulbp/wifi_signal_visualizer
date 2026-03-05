import 'dart:convert';
import 'path_point.dart';

class SavedSession {
  SavedSession({
    required this.id,
    required this.ssid,
    required this.savedAt,
    required this.points,
  });

  final String          id;
  final String          ssid;
  final DateTime        savedAt;
  final List<PathPoint> points;

  int    get total     => points.length;
  int    get bestRssi  => points.isEmpty ? -100
      : points.map((p) => p.rssi).reduce((a, b) => a > b ? a : b);
  int    get worstRssi => points.isEmpty ? -100
      : points.map((p) => p.rssi).reduce((a, b) => a < b ? a : b);
  double get avgRssi   => points.isEmpty ? -100.0
      : points.map((p) => p.rssi).fold(0, (s, p) => s + p) / points.length;

  Map<String, dynamic> toJson() => {
    'id':      id,
    'ssid':    ssid,
    'savedAt': savedAt.toIso8601String(),
    'points':  points.map((p) => {
      'x':    p.x,    'y': p.y,
      'rssi': p.rssi, 'freq': p.frequencyMhz,
      'az':   p.azimuth,
      'ts':   p.timestamp.toIso8601String(),
      'ssid': p.ssid,
    }).toList(),
  };

  factory SavedSession.fromJson(Map<String, dynamic> j) => SavedSession(
    id:      j['id'] as String,
    ssid:    j['ssid'] as String,
    savedAt: DateTime.parse(j['savedAt'] as String),
    points:  (j['points'] as List).map((p) => PathPoint(
      x:            (p['x']    as num).toDouble(),
      y:            (p['y']    as num).toDouble(),
      rssi:         p['rssi']  as int,
      frequencyMhz: p['freq']  as int,
      azimuth:      (p['az']   as num).toDouble(),
      timestamp:    DateTime.parse(p['ts'] as String),
      ssid:         p['ssid']  as String,
    )).toList(),
  );

  String toJsonString()                  => jsonEncode(toJson());
  factory SavedSession.fromJsonString(String s) =>
      SavedSession.fromJson(jsonDecode(s) as Map<String, dynamic>);
}