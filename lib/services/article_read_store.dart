import 'package:shared_preferences/shared_preferences.dart';

/// « Déjà ouvert » local — pas un réseau social, juste un point de lecture.
class ArticleReadStore {
  static const _kOpened = 'dvcr_articles_opened_ids_v1';
  static const _kProgressPrefix = 'dvcr_article_progress_';

  static Set<String> _opened = {};
  static bool _loaded = false;

  static Future<void> ensureLoaded() async {
    if (_loaded) return;
    final prefs = await SharedPreferences.getInstance();
    _opened = (prefs.getStringList(_kOpened) ?? const []).toSet();
    _loaded = true;
  }

  static bool isOpened(String id) => _opened.contains(id);

  static Future<void> markOpened(String id) async {
    if (id.isEmpty || _opened.contains(id)) return;
    await ensureLoaded();
    _opened.add(id);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(_kOpened, _opened.toList(growable: false));
  }

  static Future<void> saveProgress(String id, double progress) async {
    if (id.isEmpty) return;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setDouble(
      '$_kProgressPrefix$id',
      progress.clamp(0.0, 1.0),
    );
    if (progress >= 0.72) {
      await markOpened(id);
    }
  }

  static Future<double> progressOf(String id) async {
    if (id.isEmpty) return 0;
    final prefs = await SharedPreferences.getInstance();
    return (prefs.getDouble('$_kProgressPrefix$id') ?? 0).clamp(0.0, 1.0);
  }
}
