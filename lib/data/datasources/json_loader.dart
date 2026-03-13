import 'package:flutter/services.dart';
import 'dart:convert';

/// In-memory cache for decoded JSON assets.
/// Prevents redundant rootBundle.loadString + json.decode on repeated access.
final Map<String, dynamic> _jsonCache = {};

/// Load a JSON asset and return raw decoded data (cached)
Future<dynamic> loadJsonAsset(String path) async {
  if (_jsonCache.containsKey(path)) return _jsonCache[path];
  final raw = await rootBundle.loadString(path);
  final decoded = json.decode(raw);
  _jsonCache[path] = decoded;
  return decoded;
}

/// Load JSON asset as Map (cached)
Future<Map<String, dynamic>> loadJsonMap(String path) async {
  final data = await loadJsonAsset(path);
  if (data is Map<String, dynamic>) return data;
  if (data is Map) return data.cast<String, dynamic>();
  return <String, dynamic>{};
}

/// Load JSON asset as List (cached)
Future<List<dynamic>> loadJsonList(String path) async {
  final data = await loadJsonAsset(path);
  if (data is List) return data;
  return [];
}

/// Static class for backward compatibility
class JsonLoader {
  static Future<dynamic> load(String path) => loadJsonAsset(path);
  static Future<Map<String, dynamic>> loadMap(String path) => loadJsonMap(path);
  static Future<List<dynamic>> loadList(String path) => loadJsonList(path);

  /// Clear all cached JSON data (useful for testing or memory pressure)
  static void clearCache() => _jsonCache.clear();
}