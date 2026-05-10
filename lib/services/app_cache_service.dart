import 'package:shared_preferences/shared_preferences.dart';

class CachedBody {
  final String body;
  final DateTime checkedAt;
  final DateTime updatedAt;

  const CachedBody({
    required this.body,
    required this.checkedAt,
    required this.updatedAt,
  });
}

class AppCacheService {
  static SharedPreferences? _prefs;
  static final Map<String, CachedBody> _memory = {};

  static Future<void> init() async {
    _prefs ??= await SharedPreferences.getInstance();
  }

  static Future<CachedBody?> read(String key) async {
    await init();

    final memoryValue = _memory[key];
    if (memoryValue != null) return memoryValue;

    final prefs = _prefs!;
    final body = prefs.getString(_bodyKey(key));
    final checkedAt = prefs.getString(_checkedKey(key));
    final updatedAt = prefs.getString(_updatedKey(key));
    if (body == null || checkedAt == null || updatedAt == null) return null;

    try {
      final cached = CachedBody(
        body: body,
        checkedAt: DateTime.parse(checkedAt),
        updatedAt: DateTime.parse(updatedAt),
      );
      _memory[key] = cached;
      return cached;
    } catch (_) {
      return null;
    }
  }

  static Future<String?> readBody(String key) async {
    return (await read(key))?.body;
  }

  static Future<bool> isFresh(String key, Duration maxAge) async {
    final cached = await read(key);
    if (cached == null) return false;
    return DateTime.now().difference(cached.checkedAt) <= maxAge;
  }

  static Future<bool> upsertBody(String key, String body) async {
    await init();

    final now = DateTime.now();
    final current = await read(key);
    final changed = current == null || current.body != body;
    final next = CachedBody(
      body: body,
      checkedAt: now,
      updatedAt: changed ? now : current.updatedAt,
    );

    _memory[key] = next;
    final prefs = _prefs!;
    await prefs.setString(_bodyKey(key), next.body);
    await prefs.setString(_checkedKey(key), next.checkedAt.toIso8601String());
    await prefs.setString(_updatedKey(key), next.updatedAt.toIso8601String());
    return changed;
  }

  static Future<void> clear(String key) async {
    await init();
    _memory.remove(key);
    final prefs = _prefs!;
    await prefs.remove(_bodyKey(key));
    await prefs.remove(_checkedKey(key));
    await prefs.remove(_updatedKey(key));
  }

  static String _bodyKey(String key) => 'app_cache.$key.body';
  static String _checkedKey(String key) => 'app_cache.$key.checkedAt';
  static String _updatedKey(String key) => 'app_cache.$key.updatedAt';
}
