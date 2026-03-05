import 'package:flutter/material.dart';

import 'package:get/get.dart';

import '../controllers/app_camera_controller.dart';

class AppCameraView extends GetView<AppCameraController> {
  const AppCameraView({super.key});
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('AppCameraView'),
        centerTitle: true,
      ),
      body: const Center(
        child: Text(
          'AppCameraView is working',
          style: TextStyle(fontSize: 20),
        ),
      ),
    );
  }
}
