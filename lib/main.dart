import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:wifi_signal_visualizer/app/data/local/session_store.dart';
import 'package:wifi_signal_visualizer/app/services/network_timeline_service.dart';
import 'package:wifi_signal_visualizer/app/services/rssi_history_service.dart';
import 'package:wifi_signal_visualizer/app/services/sensor_service.dart';
import 'package:wifi_signal_visualizer/app/services/wifi_health_service.dart';
import 'package:wifi_signal_visualizer/app/services/wifi_service.dart';
import 'app/routes/app_pages.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
  SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
    statusBarColor:          Colors.transparent,
    statusBarIconBrightness: Brightness.light,
    systemNavigationBarColor:      Colors.black,
  ));

  await [Permission.camera, Permission.locationWhenInUse].request();

  await Get.putAsync<WifiService>(
      () => WifiService().init(), permanent: true);
  await Get.putAsync<SensorService>(
      () => SensorService().init(), permanent: true);
  await Get.putAsync<RssiHistoryService>(
      () => RssiHistoryService().init(), permanent: true);
  await Get.putAsync<SessionStore>(
      () => SessionStore().init(), permanent: true);
  await Get.putAsync<WifiHealthService>(
      () => WifiHealthService().init(), permanent: true);
  await Get.putAsync<NetworkTimelineService>(
      () => NetworkTimelineService().init(), permanent: true);

  runApp(const _App());
}

class _App extends StatelessWidget {
  const _App();
  @override
  Widget build(BuildContext context) => GetMaterialApp(
    title:                      'WiFi Visualizer',
    debugShowCheckedModeBanner: false,
    theme: ThemeData(
      useMaterial3:            true,
      brightness:              Brightness.dark,
      scaffoldBackgroundColor: const Color(0xFF04080F),
      colorScheme: const ColorScheme.dark(
        primary: Color(0xFF00E5FF),
        surface: Color(0xFF0A1220),
      ),
    ),
    initialRoute:      AppPages.INITIAL,
    getPages:          AppPages.routes,
    defaultTransition: Transition.fadeIn,
  );
}