import 'package:flutter/material.dart';
import 'package:wifi_signal_visualizer/app/constant/app_colors.dart';


enum SignalQuality { excellent, good, fair, poor, unusable }
enum FrequencyBand { ghz2_4, ghz5, ghz6, unknown }

abstract final class SignalUtils {
  static SignalQuality qualityFromRssi(int dBm) => switch (dBm) {
        >= -50 => SignalQuality.excellent,
        >= -67 => SignalQuality.good,
        >= -80 => SignalQuality.fair,
        >= -90 => SignalQuality.poor,
        _      => SignalQuality.unusable,
      };

  static double signalRatio(int dBm) =>
      ((dBm + 100) / 70.0).clamp(0.0, 1.0);

  static FrequencyBand bandFromMhz(int mhz) => switch (mhz) {
        >= 5925 => FrequencyBand.ghz6,
        >= 5000 => FrequencyBand.ghz5,
        >= 2400 => FrequencyBand.ghz2_4,
        _       => FrequencyBand.unknown,
      };

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