import 'package:get/get.dart';

import '../modules/app_camera/bindings/app_camera_binding.dart';
import '../modules/app_camera/views/app_camera_view.dart';
import '../modules/heatmap/bindings/heatmap_binding.dart';
import '../modules/heatmap/views/heatmap_view.dart';
import '../modules/home/bindings/home_binding.dart';
import '../modules/home/views/home_view.dart';
import '../modules/scanner/bindings/scanner_binding.dart';
import '../modules/scanner/views/scanner_view.dart';
import '../modules/sessions/bindings/sessions_binding.dart';
import '../modules/sessions/views/sessions_view.dart';

part 'app_routes.dart';

class AppPages {
  AppPages._();

  static const INITIAL = Routes.SCANNER;

  static final routes = [
    GetPage(
      name: _Paths.HOME,
      page: () => const HomeView(),
      binding: HomeBinding(),
    ),
    GetPage(
      name: _Paths.SCANNER,
      page: () => const ScannerView(),
      binding: ScannerBinding(),
    ),
    GetPage(
      name: _Paths.HEATMAP,
      page: () => const HeatmapView(),
      binding: HeatmapBinding(),
    ),
    GetPage(
      name: _Paths.APP_CAMERA,
      page: () => const AppCameraView(),
      binding: AppCameraBinding(),
    ),
    GetPage(
      name: _Paths.SESSIONS,
      page: () => const SessionsView(),
      binding: SessionsBinding(),
    ),
  ];
}
