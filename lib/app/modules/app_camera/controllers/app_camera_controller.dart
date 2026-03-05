import 'dart:ui';

import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';

/// Manages the CameraController lifecycle, including:
///  • proper pause/resume when the app goes to background (WidgetsBindingObserver)
///  • safe disposal that avoids the "Long monitor contention" crash on close
class AppCameraController extends GetxController with WidgetsBindingObserver {
  CameraController? cameraController;

  final isReady = false.obs;
  final hasError = false.obs;
  String errorMessage = '';

  @override
  void onInit() {
    super.onInit();
    WidgetsBinding.instance.addObserver(this);
    _init();
  }

  @override
  void onClose() {
    WidgetsBinding.instance.removeObserver(this);
    _safeDispose();
    super.onClose();
  }

  // ── App lifecycle ─────────────────────────────────────────────────────────
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    final ctrl = cameraController;
    if (ctrl == null || !ctrl.value.isInitialized) return;

    switch (state) {
      case AppLifecycleState.inactive:
      case AppLifecycleState.paused:
      case AppLifecycleState.detached:
        // Gracefully pause the camera — prevents ERROR_CAMERA_DEVICE on resume
        _safeDispose();
        break;
      case AppLifecycleState.resumed:
        // Re-initialise after returning to foreground
        _init();
        break;
      default:
        break;
    }
  }

  // ── Initialisation ────────────────────────────────────────────────────────
  Future<void> _init() async {
    isReady.value = false;
    try {
      final cams = await availableCameras();
      if (cams.isEmpty) {
        _fail('No camera found.');
        return;
      }

      final cam = cams.firstWhere((c) => c.lensDirection == CameraLensDirection.back, orElse: () => cams.first);

      final ctrl = CameraController(
        cam,
        ResolutionPreset.medium, // balanced quality vs memory
        enableAudio: false,
        imageFormatGroup: ImageFormatGroup.jpeg,
      );

      await ctrl.initialize();

      // Only assign if we weren't disposed in the meantime
      if (!isClosed) {
        cameraController = ctrl;
        isReady.value = true;
        hasError.value = false;
      } else {
        await ctrl.dispose();
      }
    } catch (e) {
      if (!isClosed) _fail(e.toString());
    }
  }

  // ── Safe dispose ──────────────────────────────────────────────────────────
  /// Disposes on a microtask to avoid blocking the platform thread
  /// (prevents the 431ms monitor contention seen on Xiaomi/MIUI).
  void _safeDispose() {
    final ctrl = cameraController;
    cameraController = null;
    isReady.value = false;
    if (ctrl != null && ctrl.value.isInitialized) {
      // Schedule disposal off the current call stack so the camera HAL
      // has time to flush pending frames before we close the device.
      Future.microtask(() async {
        try {
          await ctrl.dispose();
        } catch (_) {}
      });
    }
  }

  void _fail(String msg) {
    errorMessage = msg;
    hasError.value = true;
  }
}
