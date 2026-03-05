import 'package:get/get.dart';
import 'package:wifi_signal_visualizer/app/data/models/wifi_network.dart';
import '../utils/signal_utils.dart';

enum TimelineEventType { appeared, disappeared, signalJump, connected, disconnected }

class TimelineEvent {
  const TimelineEvent({
    required this.type,
    required this.ssid,
    required this.bssid,
    required this.rssi,
    required this.frequencyMhz,
    required this.ts,
    this.rssiDelta = 0,
  });

  final TimelineEventType type;
  final String            ssid, bssid;
  final int               rssi, frequencyMhz, rssiDelta;
  final DateTime          ts;

  String get timeLabel {
    final now  = DateTime.now();
    final diff = now.difference(ts);
    if (diff.inSeconds < 60) return '${diff.inSeconds}s ago';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    return '${diff.inHours}h ago';
  }

  String get icon => switch (type) {
    TimelineEventType.appeared      => '↑',
    TimelineEventType.disappeared   => '↓',
    TimelineEventType.signalJump    => rssiDelta > 0 ? '▲' : '▼',
    TimelineEventType.connected     => '✓',
    TimelineEventType.disconnected  => '✗',
  };
}

/// Tracks network appearance/disappearance and signal jumps over time.
class NetworkTimelineService extends GetxService {
  static const _maxEvents     = 120;
  static const _jumpThreshold = 8; // dBm change to log as jump

  final events = <TimelineEvent>[].obs;

  // Last-seen bssid → rssi
  final _prev = <String, int>{};
  final _seen = <String, bool>{};

  Future<NetworkTimelineService> init() async => this;

  void update(List<WifiNetwork> current, String connectedBssid) {
    final currentKeys = <String>{};

    for (final n in current) {
      currentKeys.add(n.bssid);

      if (!_seen.containsKey(n.bssid)) {
        // New network appeared
        _add(TimelineEvent(
          type:         TimelineEventType.appeared,
          ssid:         n.ssid,
          bssid:        n.bssid,
          rssi:         n.rssi,
          frequencyMhz: n.frequencyMhz,
          ts:           DateTime.now(),
        ));
      } else {
        // Check for significant signal jump
        final prev = _prev[n.bssid] ?? n.rssi;
        final delta = n.rssi - prev;
        if (delta.abs() >= _jumpThreshold) {
          _add(TimelineEvent(
            type:         TimelineEventType.signalJump,
            ssid:         n.ssid,
            bssid:        n.bssid,
            rssi:         n.rssi,
            frequencyMhz: n.frequencyMhz,
            ts:           DateTime.now(),
            rssiDelta:    delta,
          ));
        }
      }

      _seen[n.bssid]  = true;
      _prev[n.bssid]  = n.rssi;
    }

    // Detect disappeared
    for (final bssid in List.from(_seen.keys)) {
      if (!currentKeys.contains(bssid) && (_seen[bssid] ?? false)) {
        final rssi = _prev[bssid] ?? -100;
        final freq = 0;
        _add(TimelineEvent(
          type:         TimelineEventType.disappeared,
          ssid:         bssid, // fallback if ssid not cached
          bssid:        bssid,
          rssi:         rssi,
          frequencyMhz: freq,
          ts:           DateTime.now(),
        ));
        _seen[bssid] = false;
      }
    }
  }

  void logConnection(WifiNetwork n) {
    _add(TimelineEvent(
      type: TimelineEventType.connected,
      ssid: n.ssid, bssid: n.bssid,
      rssi: n.rssi, frequencyMhz: n.frequencyMhz,
      ts: DateTime.now(),
    ));
  }

  void _add(TimelineEvent e) {
    events.insert(0, e);
    if (events.length > _maxEvents) events.removeLast();
  }

  void clear() => events.clear();
}