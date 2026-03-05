import 'package:get/get.dart';
import 'package:wifi_signal_visualizer/app/modules/app_camera/controllers/app_camera_controller.dart';
import 'package:wifi_signal_visualizer/app/services/rssi_history_service.dart';
import 'package:wifi_signal_visualizer/app/services/sensor_service.dart';
import 'package:wifi_signal_visualizer/app/services/wifi_service.dart';

import '../controllers/scanner_controller.dart';

class ScannerBinding extends Bindings {
  @override
  void dependencies() {
    Get.lazyPut<AppCameraController>(() => AppCameraController());
    Get.lazyPut<ScannerController>(
      () => ScannerController(
        wifi:    Get.find<WifiService>(),
        sensors: Get.find<SensorService>(),
        history: Get.find<RssiHistoryService>(),
      ),
      fenix: true,
    );
  }
}
