import 'dart:io';
import 'package:get/get.dart';
import 'package:path_provider/path_provider.dart';
import 'package:wifi_signal_visualizer/app/data/models/saved_session.dart';
import '../../data/models/path_point.dart';

/// Persists heatmap sessions as JSON files in app documents directory.
class SessionStore extends GetxService {
  final sessions   = <SavedSession>[].obs;

  Future<SessionStore> init() async {
    await _loadAll();
    return this;
  }

  Future<Directory> get _dir async {
    final d = await getApplicationDocumentsDirectory();
    final sub = Directory('${d.path}/sessions');
    if (!sub.existsSync()) sub.createSync(recursive: true);
    return sub;
  }

  Future<void> save(String ssid, List<PathPoint> points) async {
    if (points.isEmpty) return;
    final session = SavedSession(
      id:      DateTime.now().millisecondsSinceEpoch.toString(),
      ssid:    ssid,
      savedAt: DateTime.now(),
      points:  List.from(points),
    );
    final dir  = await _dir;
    final file = File('${dir.path}/${session.id}.json');
    await file.writeAsString(session.toJsonString());
    sessions.insert(0, session);
  }

  Future<void> delete(String id) async {
    final dir  = await _dir;
    final file = File('${dir.path}/$id.json');
    if (file.existsSync()) file.deleteSync();
    sessions.removeWhere((s) => s.id == id);
  }

  Future<void> _loadAll() async {
    try {
      final dir   = await _dir;
      final files = dir.listSync()
          .whereType<File>()
          .where((f) => f.path.endsWith('.json'))
          .toList();
      final loaded = <SavedSession>[];
      for (final f in files) {
        try {
          loaded.add(SavedSession.fromJsonString(await f.readAsString()));
        } catch (_) {}
      }
      loaded.sort((a, b) => b.savedAt.compareTo(a.savedAt));
      sessions.value = loaded;
    } catch (_) {}
  }
}