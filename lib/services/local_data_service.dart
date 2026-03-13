import 'dart:convert';
import 'package:flutter/foundation.dart' show compute;
import 'package:flutter/services.dart';

/// Top-level function for isolate JSON parsing (must be top-level for compute)
Map<String, dynamic> _decodeJsonMap(String raw) =>
    json.decode(raw) as Map<String, dynamic>;
List<dynamic> _decodeJsonList(String raw) =>
    json.decode(raw) as List<dynamic>;

/// Local data service that reads JSON files from assets
/// Replaces the HTTP-based ApiService with local data
class LocalDataService {
  // Cache for loaded data
  static Map<String, dynamic>? _eventsCache;
  static final Map<String, Map<String, dynamic>> _calendarCache = {};

  // ─── Flattened result caches (avoid re-processing on every access) ───
  static List<Map<String, dynamic>>? _flattenedEventsCache;
  static final Map<String, List<Map<String, dynamic>>> _flattenedMonthCache = {};
  static final Map<String, Map<String, dynamic>> _flattenedDayCache = {};

  /// Pre-warm critical data at startup.
  /// Call from main() BEFORE runApp() so data is ready when widgets build.
  static Future<void> warmUp() async {
    final now = DateTime.now();
    // Fire all critical loads in parallel
    await Future.wait([
      _loadEventsMaster(),
      _loadCalendarMonth(now.year, now.month),
    ]);
    // Pre-flatten current month so first build is instant
    getCalendarMonth(now.year, now.month);
    // Pre-load adjacent months in background (non-blocking)
    prefetchAdjacentMonths(now.year, now.month);
  }

  /// Preload previous and next month data in background.
  /// Called automatically after month data loads so navigation is instant.
  static void prefetchAdjacentMonths(int year, int month) {
    // Previous month
    final prevMonth = month == 1 ? 12 : month - 1;
    final prevYear = month == 1 ? year - 1 : year;
    _loadCalendarMonth(prevYear, prevMonth);

    // Next month
    final nextMonth = month == 12 ? 1 : month + 1;
    final nextYear = month == 12 ? year + 1 : year;
    _loadCalendarMonth(nextYear, nextMonth);
  }

  /// Load and parse a JSON asset file as Map (parsed on isolate)
  static Future<Map<String, dynamic>> _loadJsonMap(String path) async {
    final raw = await rootBundle.loadString(path);
    return compute(_decodeJsonMap, raw);
  }

  /// Load and parse a JSON asset file as List (parsed on isolate)
  static Future<List<dynamic>> _loadJsonList(String path) async {
    final raw = await rootBundle.loadString(path);
    return compute(_decodeJsonList, raw);
  }

  /// Load events master data (cached)
  static Future<Map<String, dynamic>> _loadEventsMaster() async {
    _eventsCache ??= await _loadJsonMap('assets/data/events/events_master.json');
    return _eventsCache!;
  }

  /// Load calendar month data (cached)
  static Future<Map<String, dynamic>> _loadCalendarMonth(int year, int month) async {
    final key = '${year}_${month.toString().padLeft(2, '0')}';
    if (!_calendarCache.containsKey(key)) {
      try {
        _calendarCache[key] = await _loadJsonMap(
            'assets/data/calendar/$year/$key.json');
      } catch (_) {
        _calendarCache[key] = {'days': {}};
      }
    }
    return _calendarCache[key]!;
  }

  // ─── Calendar ──────────────────────────────────
  static Future<List<Map<String, dynamic>>> getCalendarMonth(int year, int month) async {
    final cacheKey = '${year}_${month.toString().padLeft(2, '0')}';
    // Return cached flattened result instantly
    if (_flattenedMonthCache.containsKey(cacheKey)) {
      return _flattenedMonthCache[cacheKey]!;
    }
    try {
      final data = await _loadCalendarMonth(year, month);
      final days = data['days'] as Map<String, dynamic>? ?? {};
      final result = days.entries
          .where((e) => e.value is Map)
          .map((e) {
            final day = Map<String, dynamic>.from(e.value as Map);
            day['date_key'] = e.key;
            final flat = _flattenDay(day);
            // Also populate per-day cache for getCalendarDay lookups
            _flattenedDayCache[e.key] = flat;
            return flat;
          })
          .toList()
        ..sort((a, b) => (a['gregorian_date'] ?? 0).compareTo(b['gregorian_date'] ?? 0));
      _flattenedMonthCache[cacheKey] = result;
      return result;
    } catch (_) {
      return [];
    }
  }

    /// Get raw (unflattened) calendar day data with all astrology/extra_labels
  static Future<Map<String, dynamic>?> getRawCalendarDay(String dateStr) async {
    try {
      final parts = dateStr.split('-');
      if (parts.length < 3) return null;
      final year = int.parse(parts[0]);
      final month = int.parse(parts[1]);
      final data = await _loadCalendarMonth(year, month);
      final days = data['days'] as Map<String, dynamic>? ?? {};
      final dayData = days[dateStr];
      if (dayData is Map) {
        final day = Map<String, dynamic>.from(dayData);
        day['date_key'] = dateStr;
        return day;
      }
    } catch (_) {}
    return null;
  }

  /// Get event by ID
  static Future<Map<String, dynamic>?> getEventById(String eventId) async {
    try {
      final master = await _loadEventsMaster();
      final byId = master['by_id'] as Map<String, dynamic>? ?? {};
      final event = byId[eventId];
      if (event is Map) {
        return _flattenEvent(Map<String, dynamic>.from(event));
      }
    } catch (_) {}
    return null;
  }

  /// Get multiple events by their IDs
  static Future<List<Map<String, dynamic>>> getEventsByIds(List<String> ids) async {
    final results = <Map<String, dynamic>>[];
    for (final id in ids) {
      final ev = await getEventById(id);
      if (ev != null) results.add(ev);
    }
    return results;
  }

  static Future<Map<String, dynamic>?> getCalendarDay(String dateStr) async {
    // Fast path: return from flattened cache (populated by getCalendarMonth/warmUp)
    if (_flattenedDayCache.containsKey(dateStr)) {
      return _flattenedDayCache[dateStr];
    }
    try {
      final parts = dateStr.split('-');
      if (parts.length < 3) return null;
      final year = int.parse(parts[0]);
      final month = int.parse(parts[1]);

      final data = await _loadCalendarMonth(year, month);
      final days = data['days'] as Map<String, dynamic>? ?? {};
      final dayData = days[dateStr];
      if (dayData is Map) {
        final day = Map<String, dynamic>.from(dayData);
        day['date_key'] = dateStr;
        final flat = _flattenDay(day);
        _flattenedDayCache[dateStr] = flat; // cache for next time
        return flat;
      }
    } catch (_) {}
    return null;
  }

  /// Flatten nested day structure to match what existing UI expects
  static Map<String, dynamic> _flattenDay(Map<String, dynamic> raw) {
    final gregorian = _asMap(raw['gregorian']);
    final tibetan = _asMap(raw['tibetan']);
    final content = _asMap(raw['content']);
    final visual = _asMap(raw['visual']);
    final flags = _asMap(raw['flags']);

    return {
      'date_key': raw['date_key'] ?? '',
      'gregorian_year': gregorian['year'],
      'gregorian_month': gregorian['month'],
      'gregorian_date': gregorian['day'],
      'day_name': gregorian['day_name_en'],
      'tibetan_year': tibetan['year'],
      'tibetan_month': tibetan['month'],
      'tibetan_day': tibetan['day'],
      'animal': tibetan['animal_month_en'] ?? 'Dragon',
    'animal_bo': tibetan['animal_month_bo'] ?? 'འབྲུག་ཟླ།',
      'lunar_phase': tibetan['lunar_status_en'] ?? 'NORMAL',
      'hero_image': visual['hero_image_key'],
      'element': visual['element_combo_en'] ?? 'Earth-Fire',
      'auspicious_day_info': content['auspicious_day_info_en'],
      'significance': content['significance_en'],
      'has_events': flags['has_events'] ?? false,
      'event_ids': raw['event_ids'] ?? [],
      'is_auspicious': flags['is_extremely_auspicious'] ?? false,
    };
  }

  // ─── Events ────────────────────────────────────
  /// Get all flattened events (cached). The full list is computed once.
  static Future<List<Map<String, dynamic>>> _getAllFlattenedEvents() async {
    if (_flattenedEventsCache != null) return _flattenedEventsCache!;
    final master = await _loadEventsMaster();
    final byId = master['by_id'] as Map<String, dynamic>? ?? {};
    _flattenedEventsCache = byId.values
        .whereType<Map>()
        .map((e) => _flattenEvent(Map<String, dynamic>.from(e)))
        .toList();
    return _flattenedEventsCache!;
  }

  static Future<List<Map<String, dynamic>>> getEvents({String? lineage, int? month}) async {
    try {
      final events = await _getAllFlattenedEvents();

      // Filter by month if provided
      if (month != null) {
        return events.where((e) {
          final dateKey = e['date_key'] as String? ?? '';
          if (dateKey.length >= 7) {
            final eventMonth = int.tryParse(dateKey.substring(5, 7));
            return eventMonth == month;
          }
          return false;
        }).toList();
      }

      return List.from(events); // return a copy so callers can't mutate cache
    } catch (_) {
      return [];
    }
  }

  /// Flatten event structure to match what existing UI expects
  static Map<String, dynamic> _flattenEvent(Map<String, dynamic> raw) {
    final title = _asMap(raw['title']);
    final details = _asMap(raw['details']);
    final category = _asMap(raw['category']);
    final assets = _asMap(raw['assets']);

    return {
      'id': raw['id'] ?? '',
      'date_key': raw['date_key'] ?? '',
      'western_date': raw['date_key'] ?? '',
      'title_en': title['en'] ?? '',
      'title_bo': title['bo'] ?? '',
      'details_en': details['en'] ?? '',
      'details_bo': details['bo'] ?? '',
      'description_en': details['en'] ?? '',
      'category_en': category['en'] ?? '',
      'category_bo': category['bo'] ?? '',
      'lineage': 'all',
      'image_path': _resolveImagePath(assets['thumbnail_key'] ?? assets['hero_key']),
    };
  }

  /// Cache for resolved image paths — avoids re-running string matching per call
  static final Map<String, String> _imagePathCache = {};

  /// Exact-match lookup table for image keys (O(1) instead of O(n) if-else)
  static const Map<String, String> _exactImageMap = {
    'losar': 'events_2/Losar.PNG',
    'sawa_dawa': 'Events_3/sawa_dawa.PNG',
    'img_1776': 'Birthday/IMG_1776.PNG',
    'img_1777': 'Birthday/IMG_1777.PNG',
    'img_1779': 'Birthday/IMG_1779.PNG',
    'img_1780': 'Birthday/IMG_1780.PNG',
    'img_1781': 'Birthday/IMG_1781.PNG',
    'img_1782': 'Birthday/IMG_1782.PNG',
    'img_1783': 'Birthday/IMG_1783.PNG',
    'img_1785': 'Birthday/IMG_1785.PNG',
    'img_1786': 'Birthday/IMG_1786.PNG',
    'img_1787': 'Birthday/IMG_1787.PNG',
    'img_1789': 'Birthday/IMG_1789.PNG',
    'img_1903': 'others/IMG_1903.JPG',
    'img_1904': 'others/IMG_1904.PNG',
    'guru': 'others/IMG_1904.PNG',
    'img_7180': 'others/IMG_7180.JPG',
  };

  /// Substring-match rules (checked only when exact match fails)
  static const List<MapEntry<String, String>> _substringImageRules = [
    MapEntry('chotrul', 'events_2/chotrul_duchen.webp'),
    MapEntry('chokhor', 'Events_3/Chokhor_Duchen.PNG'),
    MapEntry('monlam', 'Events_3/Monlam_Chenmo.PNG'),
    MapEntry('nine_bad', 'Events_3/Nine_Bad_Omens.PNG'),
    MapEntry('zangpo', 'Events_3/Zangpo_Chu_Dzom.PNG'),
    MapEntry('sawadawa', 'events_2/sawadawaduchen.webp'),
    MapEntry('incense', 'events_2/incense.PNG'),
    MapEntry('black_hat', 'events_2/Black_Hat_Vajra_Dance.PNG'),
    MapEntry('cham', 'events_2/Cham_Dance.PNG'),
    MapEntry('drubchen', 'events_2/Drubchen.PNG'),
    MapEntry('gutor', 'events_2/Gutor_Commencement.PNG'),
    MapEntry('krodhikali', 'events_2/Krodhikali_.PNG'),
    MapEntry('torma_repel', 'events_2/Torma_Repelling.PNG'),
    MapEntry('translated_words', 'events_2/Translated_Words_of_the_Buddha.PNG'),
    MapEntry('dungse_garab', 'Birthday/Birthday_of_Kyabje_Dungse_Garab_Rinpoche.PNG'),
    MapEntry('yangshi_dungse', 'Birthday/Birthday._of_Kyabje_Yangshi_Dungse_Gyana_ta_Rinpoche.PNG'),
    MapEntry('gold_medal', 'Birthday/gold_medal_westerndate.PNG'),
    MapEntry('yangsi_drub', 'Birthday/yangsi_Drubwang.webp'),
    MapEntry('odisha', 'others/OdishaDudjom.JPG'),
    MapEntry('d576094b', 'others/d576094b-5120-4556-9241-964905b095c2.jpg'),
    MapEntry('kyabjepenor', 'parinirvana/KyabjePenor.PNG'),
    MapEntry('parinirvana', 'parinirvana/KyabjePenor.PNG'),
    MapEntry('fullmoon', 'Auspicious_days/fullmoon.PNG'),
    MapEntry('vesak', 'Auspicious_days/fullmoon.PNG'),
    MapEntry('newmoon', 'Auspicious_days/newmoon.PNG'),
    MapEntry('dakini', 'Auspicious_days/dakini.PNG'),
    MapEntry('medicine', 'Auspicious_days/medicinebuddha.PNG'),
    MapEntry('dharma', 'Auspicious_days/dharmaprotector.PNG'),
    MapEntry('protector', 'Auspicious_days/dharmaprotector.PNG'),
    MapEntry('dudjomlingpa', 'parinirvana/DudjomLingpa.PNG'),
    MapEntry('dudjomrinpoche', 'parinirvana/DudjomRinpoche.PNG'),
    MapEntry('yangsidudjom', 'parinirvana/YangsiDudjom.PNG'),
    MapEntry('dudjom', 'parinirvana/DudjomRinpoche.PNG'),
    MapEntry('dilgokhyentse', 'parinirvana/DilgoKhyentse.PNG'),
    MapEntry('dilgo', 'parinirvana/DilgoKhyentse.PNG'),
    MapEntry('jamyang_khyentse', 'parinirvana/Jamyang_Khyentse_Wangpo_.PNG'),
    MapEntry('jamyang', 'parinirvana/Jamyang_Khyentse_Wangpo_.PNG'),
    MapEntry('longchenrabjam', 'parinirvana/LongchenRabjam.PNG'),
    MapEntry('longchen', 'parinirvana/LongchenRabjam.PNG'),
    MapEntry('jigmelingpa', 'parinirvana/JigmeLingpa-BookLaunch.PNG'),
    MapEntry('jigmeling', 'parinirvana/JigmeLingpa-BookLaunch.PNG'),
    MapEntry('chatralsangye', 'parinirvana/ChatralSangye.PNG'),
    MapEntry('chatral', 'parinirvana/ChatralSangye.PNG'),
    MapEntry('nyoshulkhen', 'parinirvana/NyoshulKhen.PNG'),
    MapEntry('nyoshul', 'parinirvana/NyoshulKhen.PNG'),
    MapEntry('jigmephuntsok', 'parinirvana/JigmePhuntsok.PNG'),
    MapEntry('jumipham', 'parinirvana/JuMipham.PNG'),
    MapEntry('minlingtrichen', 'parinirvana/MinlingTrichen.JPG'),
    MapEntry('minling', 'parinirvana/MinlingTrichen.JPG'),
    MapEntry('minlngterchen', 'parinirvana/MinlngTerchen.PNG'),
    MapEntry('rabjam_gyurme', 'parinirvana/Rabjam_Gyurme.PNG'),
    MapEntry('rabjam', 'parinirvana/Rabjam_Gyurme.PNG'),
    MapEntry('taklungtsetrul', 'parinirvana/TaklungTsetrul.PNG'),
    MapEntry('taklung', 'parinirvana/TaklungTsetrul.PNG'),
    MapEntry('tertonmingyur', 'parinirvana/TertonMingyur.PNG'),
    MapEntry('thinleynorbu', 'parinirvana/ThinleyNorbu.PNG'),
    MapEntry('thinley', 'parinirvana/ThinleyNorbu.PNG'),
    MapEntry('thulshekripoche', 'parinirvana/ThulshekRipoche.PNG'),
    MapEntry('thulshek', 'parinirvana/ThulshekRipoche.PNG'),
    MapEntry('yangthangrinpoche', 'parinirvana/YangthangRinpoche.PNG'),
    MapEntry('yangthang', 'parinirvana/YangthangRinpoche.PNG'),
    MapEntry('zhenphendawa', 'parinirvana/ZhenphenDawa.PNG'),
    MapEntry('dodrupchen', 'parinirvana/Dodrupchen.PNG'),
    MapEntry('birthday', 'Birthday/IMG_1780.PNG'),
    MapEntry('birth', 'Birthday/IMG_1780.PNG'),
    MapEntry('guru', 'others/IMG_1904.PNG'),
    MapEntry('saga', 'Auspicious_days/fullmoon.PNG'),
  ];

  /// Try to resolve image path from a key (cached + HashMap lookup)
  static String _resolveImagePath(dynamic key) {
    if (key == null) return 'others/guru.jpg';
    final keyStr = key.toString();
    // Check result cache first (O(1))
    final cached = _imagePathCache[keyStr];
    if (cached != null) return cached;

    final k = keyStr.toLowerCase().replaceAll(' ', '_');
    // 1. Exact match (O(1))
    final exact = _exactImageMap[k];
    if (exact != null) {
      _imagePathCache[keyStr] = exact;
      return exact;
    }
    // 2. Substring match (linear, but only for unknown keys)
    for (final rule in _substringImageRules) {
      if (k.contains(rule.key)) {
        _imagePathCache[keyStr] = rule.value;
        return rule.value;
      }
    }
    // 3. Default
    _imagePathCache[keyStr] = 'others/guru.jpg';
    return 'others/guru.jpg';
  }

  // ─── Auspicious Days ───────────────────────────
  static List<Map<String, dynamic>>? _auspiciousDaysCache;

  static Future<List<Map<String, dynamic>>> getAuspiciousDays() async {
    if (_auspiciousDaysCache != null) return _auspiciousDaysCache!;
    try {
      final items = await _loadJsonList('assets/data/raw/auspicious_days_reference.json');
      // Filter out null, header, and "Month" rows
      _auspiciousDaysCache = items
          .whereType<Map>()
          .where((e) {
            final name = e['English Name'];
            return name != null && name.toString().isNotEmpty &&
                   name != 'Manifestation Name (English)';
          })
          .map((e) => <String, dynamic>{
            'name_en': e['English Name']?.toString()?.trim() ?? '',
            'name_bo': e['Tibetan Name']?.toString() ?? '',
            'tibetan_day_number': e['Day'] is int ? e['Day'] : int.tryParse(e['Day']?.toString() ?? '') ?? 0,
            'tibetan_day_bo': e['Day (tibetan)']?.toString() ?? '',
            'month': e[' Month'],  // note: leading space in key
            'description_en': e['Short Description']?.toString() ?? '',
            'description_bo': e['Short Description (Tibetan)']?.toString() ?? '',
            'practices_en': e['English Description']?.toString() ?? '',
            'practices_bo': e['Tibetan Description']?.toString() ?? '',
          })
          .toList();
      return _auspiciousDaysCache!;
    } catch (_) {
      return [];
    }
  }

  static Future<Map<String, dynamic>?> getNextAuspiciousDay() async => null;

  // ─── Astrology ─────────────────────────────────
  static List<Map<String, dynamic>>? _hairCuttingCache;
  static final RegExp _hairDayRegex = RegExp(r'Day\s+(\d+):\s+(.+)');

  static Future<List<Map<String, dynamic>>> getHairCuttingDays() async {
    if (_hairCuttingCache != null) return _hairCuttingCache!;
    try {
      final items = await _loadJsonList('assets/data/raw/hair_cutting_days.json');
      final result = <Map<String, dynamic>>[];

      // Parse the special format: "Day N: meaning"
      for (final item in items) {
        if (item is! Map) continue;
        for (final key in [
          'HAIR CUTTING DAYS (Tra Yi - སྐྲ་ཡྱི་)',
          'Unnamed: 1',
          'Unnamed: 2'
        ]) {
          final val = item[key]?.toString() ?? '';
          final match = _hairDayRegex.firstMatch(val);
          if (match != null) {
            final dayNum = int.parse(match.group(1)!);
            final meaning = match.group(2)!.trim();
            final isGood = meaning.contains('Long life') ||
                meaning.contains('Wealth') ||
                meaning.contains('Auspicious') ||
                meaning.contains('Good') ||
                meaning.contains('Sharp') ||
                meaning.contains('Increase') ||
                meaning.contains('Radiant') ||
                meaning.contains('Great influence') ||
                meaning.contains('happy') ||
                meaning.contains('Virtue') ||
                meaning.contains('Goodness') ||
                meaning.contains('Strength');
            final isBad = meaning.contains('sickness') ||
                meaning.contains('Danger') ||
                meaning.contains('Fading') ||
                meaning.contains('Disputes') ||
                meaning.contains('Loss') ||
                meaning.contains('Infectious') ||
                meaning.contains('Conflict') ||
                meaning.contains('wandering') ||
                meaning.contains('deceased') ||
                meaning.contains('Problems');

            result.add({
              'tibetan_day': dayNum,
              'meaning_en': meaning,
              'recommendation': isGood ? 'Good' : (isBad ? 'Avoid' : 'Neutral'),
            });
          }
        }
      }
      result.sort((a, b) => (a['tibetan_day'] as int).compareTo(b['tibetan_day'] as int));
      _hairCuttingCache = result;
      return result;
    } catch (_) {
      return [];
    }
  }

  static Future<Map<String, dynamic>?> getGuruManifestation(int month) async => null;

  static Future<Map<String, dynamic>?> getNagaDays(int month) async {
    try {
      final items = await _loadJsonList('assets/data/raw/naga_days_klu_theb.json');
      // Data rows start at index 3 (after header rows), months 1-12
      final dataRows = items.where((e) {
        if (e is! Map) return false;
        final name = e['NAGA DAYS (ཟླ་བ།)']?.toString() ?? '';
        return name.contains('Dawa') || name.contains('Dawa');
      }).toList();

      // Month index (0-based in the filtered list)
      if (month < 1 || month > dataRows.length) return null;
      final row = dataRows[month - 1] as Map;
      return {
        'tibetan_month': month,
        'major_days': row['Unnamed: 1']?.toString() ?? '',
        'minor_days': row['Unnamed: 2']?.toString() ?? '',
      };
    } catch (_) {
      return null;
    }
  }

  static Future<Map<String, dynamic>?> getFlagAvoidance(int month) async {
    try {
      final items = await _loadJsonList('assets/data/raw/earth_lords_flag_days.json');
      // Data rows with numeric month start at index 3
      final dataRows = items.where((e) {
        if (e is! Map) return false;
        final monthVal = e['FLAG DAYS - AVOID HANGING PRAYER FLAGS (༈ ས་བདག་བ་དན།)'];
        return monthVal is int;
      }).toList();

      final row = dataRows.firstWhere(
        (e) => (e as Map)['FLAG DAYS - AVOID HANGING PRAYER FLAGS (༈ ས་བདག་བ་དན།)'] == month,
        orElse: () => null,
      );
      if (row == null) return null;

      return {
        'tibetan_month': month,
        'month_name': (row as Map)['Unnamed: 1']?.toString() ?? '',
        'avoid_days': row['Unnamed: 2']?.toString() ?? '',
      };
    } catch (_) {
      return null;
    }
  }

  static List<Map<String, dynamic>>? _dailyRestrictionsCache;

  static Future<List<Map<String, dynamic>>> getDailyRestrictions() async {
    if (_dailyRestrictionsCache != null) return _dailyRestrictionsCache!;
    try {
      final items = await _loadJsonList('assets/data/raw/restriction_activities.json');
      _dailyRestrictionsCache = items
          .whereType<Map>()
          .where((e) {
            final name = e['English Name'];
            return name != null && name.toString().isNotEmpty &&
                   name != 'མིང་བྱང་།';  // skip Tibetan header
          })
          .map((e) => <String, dynamic>{
            'days': e['Days']?.toString() ?? '',
            'name': e['English Name']?.toString() ?? '',
            'restriction': e['Restriction']?.toString() ?? '',
          })
          .toList();
      return _dailyRestrictionsCache!;
    } catch (_) {
      return [];
    }
  }

  // ─── Practices (local-only features) ─────────
  static final List<Map<String, dynamic>> _userPractices = [];

  static Future<Map<String, dynamic>?> getPracticeStats() async {
    return {
      "total": _userPractices.length,
    };
  }

  static Future<List<Map<String, dynamic>>> getUserPractices() async {
    return List<Map<String, dynamic>>.from(_userPractices);
  }

  static Future<bool> createUserPractice(Map<String, dynamic> practice) async {
    final newPractice = Map<String, dynamic>.from(practice);

    // ensure ID is always a string so UI + repositories read it consistently
    newPractice["id"] = DateTime.now().millisecondsSinceEpoch.toString();

    _userPractices.add(newPractice);
    return true;
  }

  static Future<bool> deleteUserPractice(int id) async {
    _userPractices.removeWhere((e) => e["id"] == id);
    return true;
  }

  static Future<bool> trackPractice(String name, String date, bool completed) async {
    return true;
  }

  static Future<bool> updatePractice(int id, Map<String, dynamic> data) async {
    final index = _userPractices.indexWhere((e) => e["id"] == id);
    if (index == -1) return false;

    _userPractices[index] = {..._userPractices[index], ...data};
    return true;
  }

  // ─── User Events (local-only) ──────────────

static final List<Map<String, dynamic>> _userEvents = [];

static Future<List<Map<String, dynamic>>> getUserEvents() async {
  return List<Map<String, dynamic>>.from(_userEvents);
}

static Future<bool> createUserEvent(Map<String, dynamic> event) async {
  final newEvent = Map<String, dynamic>.from(event);

  newEvent["id"] = DateTime.now().millisecondsSinceEpoch;

  _userEvents.add(newEvent);

  return true;
}

static Future<bool> deleteUserEvent(int id) async {
  _userEvents.removeWhere((e) => e["id"] == id);
  return true;
}

  // ─── Profile (local-only) ───────────────────
  static Map<String, dynamic>? _profile;

  static Future<Map<String, dynamic>?> getProfile() async {
    return _profile;
  }

  static Future<bool> updateProfile(Map<String, dynamic> data) async {
    _profile = {...?_profile, ...data};
    return true;
  }

  // ─── Bodhisattva Practices ─────────────────
  static Future<List<Map<String, dynamic>>> getBodhisattvaPractices() async => [];

  // ─── Helpers ───────────────────────────────
  static Map<String, dynamic> _asMap(dynamic v) {
    if (v is Map<String, dynamic>) return v;
    if (v is Map) return v.map((k, val) => MapEntry(k.toString(), val));
    return <String, dynamic>{};
  }
}