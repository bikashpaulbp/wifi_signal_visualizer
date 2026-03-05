import 'package:camera/camera.dart';
import 'package:get/get.dart';

class AppCameraController extends GetxController {
  CameraController? cameraController;
  final isReady  = false.obs;
  final hasError = false.obs;
  String errorMessage = '';

  @override
  void onInit() { super.onInit(); _init(); }

  @override
  void onClose() { cameraController?.dispose(); super.onClose(); }

  Future<void> _init() async {
    try {
      final cams = await availableCameras();
      if (cams.isEmpty) { _fail('No camera found.'); return; }
      final cam = cams.firstWhere(
        (c) => c.lensDirection == CameraLensDirection.back,
        orElse: () => cams.first,
      );
      cameraController = CameraController(
        cam,
        ResolutionPreset.medium,
        enableAudio: false,
        imageFormatGroup: ImageFormatGroup.jpeg,
      );
      await cameraController!.initialize();
      isReady.value = true;
    } catch (e) { _fail(e.toString()); }
  }

  void _fail(String msg) { errorMessage = msg; hasError.value = true; }
}