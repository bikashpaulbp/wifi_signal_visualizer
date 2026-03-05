import 'package:get/get.dart';
import 'package:wifi_signal_visualizer/app/data/local/session_store.dart';
import 'package:wifi_signal_visualizer/app/modules/scanner/controllers/scanner_controller.dart';

import '../controllers/heatmap_controller.dart';

class HeatmapBinding extends Bindings {
  @override
  void dependencies() {
  Get.lazyPut<HeatmapController>(
      () => HeatmapController(
        scanner:  Get.find<ScannerController>(),
        sessions: Get.find<SessionStore>(),
      ),
    );
  }
}
