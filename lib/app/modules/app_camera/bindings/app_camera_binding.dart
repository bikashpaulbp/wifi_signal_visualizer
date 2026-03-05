import 'package:get/get.dart';

import '../controllers/app_camera_controller.dart';

class AppCameraBinding extends Bindings {
  @override
  void dependencies() {
    Get.lazyPut<AppCameraController>(
      () => AppCameraController(),
    );
  }
}
