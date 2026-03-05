import 'dart:async';
import 'dart:math';
import 'package:get/get.dart';
import 'package:sensors_plus/sensors_plus.dart';

class SensorService extends GetxService {
  final azimuth   = 0.0.obs;  // 0–360° magnetic North
  final stepCount = 0.obs;    // cumulative

  static const stepLengthM = 0.72; // avg adult step

  double _gx = 0, _gy = 0, _gz = -9.8;
  bool     _onPeak   = false;
  DateTime _lastStep = DateTime.fromMillisecondsSinceEpoch(0);

  StreamSubscription<AccelerometerEvent>? _accelSub;
  StreamSubscription<MagnetometerEvent>?  _magSub;

  Future<SensorService> init() async => this;

  void startListening() {
    _accelSub = accelerometerEventStream(
      samplingPeriod: SensorInterval.normalInterval,
    ).listen(_onAccel, onError: (_) {});

    _magSub = magnetometerEventStream(
      samplingPeriod: SensorInterval.normalInterval,
    ).listen(_onMag, onError: (_) {});
  }

  void stopListening() {
    _accelSub?.cancel();
    _magSub?.cancel();
  }

  void resetSteps() => stepCount.value = 0;

  @override
  void onClose() { stopListening(); super.onClose(); }

  void _onAccel(AccelerometerEvent e) {
    _gx = e.x; _gy = e.y; _gz = e.z;
    final mag = sqrt(e.x * e.x + e.y * e.y + e.z * e.z);
    // Hysteresis step detection
    if (!_onPeak && mag > 11.2) {
      _onPeak = true;
    } else if (_onPeak && mag < 8.8) {
      _onPeak = false;
      final now = DateTime.now();
      if (now.difference(_lastStep).inMilliseconds >= 300) {
        stepCount.value++;
        _lastStep = now;
      }
    }
  }

  void _onMag(MagnetometerEvent e) {
    final norm = sqrt(_gx * _gx + _gy * _gy + _gz * _gz);
    if (norm < 0.1) return;

    // Tilt-compensated compass (Freescale AN4248)
    final ax = _gx / norm, ay = _gy / norm, az = _gz / norm;
    final pitch = asin(-ax);
    final roll  = atan2(ay, az);
    final mxh   = e.x * cos(pitch) + e.z * sin(pitch);
    final myh   = e.x * sin(roll) * sin(pitch)
                + e.y * cos(roll)
                - e.z * sin(roll) * cos(pitch);

    double raw = atan2(-myh, mxh) * (180 / pi);
    if (raw < 0) raw += 360;

    // Low-pass filter with wrap-safe shortest-path delta
    const alpha = 0.10;
    final cur   = azimuth.value;
    double delta = raw - cur;
    if (delta >  180) delta -= 360;
    if (delta < -180) delta += 360;
    azimuth.value = (cur + alpha * delta + 360) % 360;
  }
}