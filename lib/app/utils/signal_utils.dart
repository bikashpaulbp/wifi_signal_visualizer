import 'package:flutter/material.dart';
import 'package:wifi_signal_visualizer/app/constant/app_colors.dart';

enum SignalQuality { excellent, good, fair, poor, unusable }
enum FrequencyBand { ghz2_4, ghz5, ghz6, unknown }
enum SecurityLevel { open, wep, wpa, wpa2, wpa3 }

abstract final class SignalUtils {
  // ── Signal ────────────────────────────────────────────────────────────────
  static SignalQuality qualityFromRssi(int dBm) => switch (dBm) {
        >= -50 => SignalQuality.excellent,
        >= -67 => SignalQuality.good,
        >= -80 => SignalQuality.fair,
        >= -90 => SignalQuality.poor,
        _      => SignalQuality.unusable,
      };

  static double signalRatio(int dBm) => ((dBm + 100) / 70.0).clamp(0.0, 1.0);

  // ── Band ──────────────────────────────────────────────────────────────────
  static FrequencyBand bandFromMhz(int mhz) => switch (mhz) {
        >= 5925 => FrequencyBand.ghz6,
        >= 5000 => FrequencyBand.ghz5,
        >= 2400 => FrequencyBand.ghz2_4,
        _       => FrequencyBand.unknown,
      };

  // ── Channel (used for radar + congestion detection) ───────────────────────
  static int channelFromMhz(int mhz) {
    if (mhz >= 2412 && mhz <= 2472) return ((mhz - 2412) ~/ 5) + 1;
    if (mhz == 2484) return 14;
    if (mhz >= 5180 && mhz <= 5825) return (mhz - 5000) ~/ 5;
    if (mhz >= 5955 && mhz <= 7115) return ((mhz - 5955) ~/ 5) + 1;
    return 0;
  }

  /// Channels that interfere with each other (non-overlapping sets for 2.4 GHz: 1,6,11)
  static bool channelsInterfere(int a, int b) {
    if (a == 0 || b == 0) return false;
    return (a - b).abs() < 5;
  }

  // ── Security ──────────────────────────────────────────────────────────────
  static SecurityLevel securityFromCapabilities(String caps) {
    final c = caps.toUpperCase();
    if (c.contains('WPA3')) return SecurityLevel.wpa3;
    if (c.contains('WPA2')) return SecurityLevel.wpa2;
    if (c.contains('WPA'))  return SecurityLevel.wpa;
    if (c.contains('WEP'))  return SecurityLevel.wep;
    return SecurityLevel.open;
  }

  static Color securityColor(SecurityLevel s) => switch (s) {
        SecurityLevel.open  => AppColors.danger,
        SecurityLevel.wep   => const Color(0xFFFF8C00),
        SecurityLevel.wpa   => AppColors.sigFair,
        SecurityLevel.wpa2  => AppColors.sigGood,
        SecurityLevel.wpa3  => AppColors.sigExcellent,
      };

  static String securityLabel(SecurityLevel s) => switch (s) {
        SecurityLevel.open  => 'OPEN',
        SecurityLevel.wep   => 'WEP',
        SecurityLevel.wpa   => 'WPA',
        SecurityLevel.wpa2  => 'WPA2',
        SecurityLevel.wpa3  => 'WPA3',
      };

  static bool isSecurityWarning(SecurityLevel s) =>
      s == SecurityLevel.open || s == SecurityLevel.wep;

  // ── Default/factory SSID detection ───────────────────────────────────────
  static const _defaultPrefixes = [
    'TP-LINK_', 'NETGEAR', 'DIRECT-', 'Linksys', 'dlink', 'D-Link',
    'XFINITY', 'BELL_', 'SHAW_', 'SKY_', 'BT-', 'VIRGIN',
    'HUAWEI-', 'ZTE-', 'VODAFONE-', 'TELSTRA', 'OPTUS',
    'SPECTRUM', 'COX-', 'ATT-WIFI', 'COMCAST',
  ];

  static bool isDefaultSsid(String ssid) {
    final upper = ssid.toUpperCase();
    return _defaultPrefixes.any((p) => upper.startsWith(p.toUpperCase()));
  }

  // ── Estimated range (path-loss model, indoor n=2.7) ──────────────────────
  /// Returns estimated distance in metres from AP given RSSI.
  static double estimatedRangeMetres(int rssi, FrequencyBand band) {
    final txPower = band == FrequencyBand.ghz5 ? 23.0 : 20.0;
    const n = 2.7;
    final exp = (txPower - rssi) / (10 * n);
    return (pow10(exp)).clamp(0.5, 100.0);
  }

  static double pow10(double x) => _pow10(x);
  static double _pow10(double x) {
    // 10^x = e^(x * ln10)
    const ln10 = 2.302585093;
    return _exp(x * ln10);
  }
  static double _exp(double x) {
    // Taylor series approximation — accurate enough for small x
    double result = 1, term = 1;
    for (int i = 1; i <= 20; i++) {
      term *= x / i;
      result += term;
    }
    return result;
  }

  // ── Colours / labels (unchanged) ─────────────────────────────────────────
  static Color qualityColor(SignalQuality q) => switch (q) {
        SignalQuality.excellent => AppColors.sigExcellent,
        SignalQuality.good      => AppColors.sigGood,
        SignalQuality.fair      => AppColors.sigFair,
        SignalQuality.poor      => AppColors.sigPoor,
        SignalQuality.unusable  => AppColors.sigUnusable,
      };

  static Color bandColor(FrequencyBand b) => switch (b) {
        FrequencyBand.ghz2_4  => AppColors.band2_4,
        FrequencyBand.ghz5    => AppColors.band5,
        FrequencyBand.ghz6    => AppColors.band6,
        FrequencyBand.unknown => AppColors.bandUnknown,
      };

  static String qualityLabel(SignalQuality q) => switch (q) {
        SignalQuality.excellent => 'Excellent',
        SignalQuality.good      => 'Good',
        SignalQuality.fair      => 'Fair',
        SignalQuality.poor      => 'Poor',
        SignalQuality.unusable  => 'No Signal',
      };

  static String bandLabel(FrequencyBand b) => switch (b) {
        FrequencyBand.ghz2_4  => '2.4 GHz',
        FrequencyBand.ghz5    => '5 GHz',
        FrequencyBand.ghz6    => '6 GHz',
        FrequencyBand.unknown => 'N/A',
      };

  static int qualityBars(int dBm) => switch (dBm) {
        >= -55 => 4,
        >= -67 => 3,
        >= -78 => 2,
        >= -90 => 1,
        _      => 0,
      };
}