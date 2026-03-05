import 'package:get/get.dart';
import 'package:wifi_signal_visualizer/app/data/local/session_store.dart';
import 'package:wifi_signal_visualizer/app/modules/scanner/controllers/scanner_controller.dart';

import '../controllers/sessions_controller.dart';

class SessionsBinding extends Bindings {
  @override
  void dependencies() {
   Get.lazyPut<SessionsController>(() => SessionsController(
      store:   Get.find<SessionStore>(),
      heatmap: Get.find<ScannerController>().heatmap,
    ));
  }
}
