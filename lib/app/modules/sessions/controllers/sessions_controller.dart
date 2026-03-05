import 'package:get/get.dart';
import 'package:wifi_signal_visualizer/app/data/local/heatmap_store.dart';
import 'package:wifi_signal_visualizer/app/data/local/session_store.dart';
import 'package:wifi_signal_visualizer/app/data/models/saved_session.dart';
import '../../../data/models/path_point.dart';

class SessionsController extends GetxController {
  SessionsController({
    required SessionStore  store,
    required HeatmapStore  heatmap,
  }) : _store = store, _heatmap = heatmap;

  final SessionStore _store;
  final HeatmapStore _heatmap;

  List<SavedSession> get sessions => _store.sessions;

  final comparingA    = Rx<SavedSession?>(null);
  final comparingB    = Rx<SavedSession?>(null);
  final isCompareMode = false.obs;
  final isDeleting    = false.obs;

  void enterCompareMode() => isCompareMode.value = true;
  void exitCompareMode()  {
    isCompareMode.value = false;
    comparingA.value = null;
    comparingB.value = null;
  }

  void selectForCompare(SavedSession s) {
    if (comparingA.value == null)      { comparingA.value = s; return; }
    if (comparingA.value?.id == s.id)  { comparingA.value = null; return; }
    if (comparingB.value?.id == s.id)  { comparingB.value = null; return; }
    comparingB.value = s;
  }

  bool isSelectedA(String id) => comparingA.value?.id == id;
  bool isSelectedB(String id) => comparingB.value?.id == id;
  bool get canCompare => comparingA.value != null && comparingB.value != null;

  void openComparison() {
    if (!canCompare) return;
    Get.toNamed('/compare', arguments: {
      'a': comparingA.value,
      'b': comparingB.value,
    });
  }

  Future<void> loadIntoHeatmap(SavedSession s) async {
    _heatmap.clear();
    for (final p in s.points) _heatmap.addPoint(p);
    Get.back(); // close sessions
    Get.toNamed('/heatmap');
  }

  Future<void> deleteSession(String id) async {
    await _store.delete(id);
  }
}