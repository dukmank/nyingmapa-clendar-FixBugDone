import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../data/datasources/json_loader.dart';
import '../../../core/localization/language_provider.dart';

// ═══════════════════════════════════════════════════════
// ASTROLOGY DATA PROVIDERS — properly parsed per JSON
// ═══════════════════════════════════════════════════════

Future<List<dynamic>> _loadRawList(String filename) =>
    loadJsonList('assets/data/raw/$filename');


String _mainKey(Map m) => m.keys.first.toString();

// Detect Tibetan characters anywhere in a row
bool _containsTibetan(Map item) {
  final tibetanRegex = RegExp(r'[\u0F00-\u0FFF]');
  for (final v in item.values) {
    if (v != null && tibetanRegex.hasMatch(v.toString())) {
      return true;
    }
  }
  return false;
}

// Helper to remove Tibetan characters from a string
String _stripTibetan(String s) {
  return s.replaceAll(RegExp(r'[\u0F00-\u0FFF]'), '').trim();
}

// ──────────────────────────────────────
// 1. Hair Cutting Days (WORKING)
// ──────────────────────────────────────
final hairCuttingProvider = FutureProvider<List<Map<String, dynamic>>>((ref) async {
  final items = await _loadRawList('hair_cutting_days.json');
  final result = <Map<String, dynamic>>[];
  for (final item in items) {
    if (item is! Map) continue;
    if (_containsTibetan(item)) continue;
    for (final key in item.keys) {
      final val = item[key]?.toString() ?? '';
      final match = RegExp(r'Day\s+(\d+):\s+(.+)').firstMatch(val);
      if (match != null) {
        final dayNum = int.parse(match.group(1)!);
        final meaning = _stripTibetan(match.group(2)!.trim());
        final isGood = meaning.contains('Long life') || meaning.contains('Wealth') ||
            meaning.contains('Auspicious') || meaning.contains('Good') ||
            meaning.contains('Sharp') || meaning.contains('Increase') ||
            meaning.contains('Radiant') || meaning.contains('Virtue') ||
            meaning.contains('Goodness') || meaning.contains('Strength');
        final isBad = meaning.contains('sickness') || meaning.contains('Danger') ||
            meaning.contains('Fading') || meaning.contains('Disputes') ||
            meaning.contains('Loss') || meaning.contains('Infectious') ||
            meaning.contains('Conflict') || meaning.contains('wandering') ||
            meaning.contains('deceased') || meaning.contains('Problems');
        result.add({
          'day': dayNum,
          'meaning': meaning,
          'recommendation': isGood ? 'Good' : (isBad ? 'Avoid' : 'Neutral'),
        });
      }
    }
  }
  result.sort((a, b) => (a['day'] as int).compareTo(b['day'] as int));
  return result;
});

// ──────────────────────────────────────
// 2. Naga Days (WORKING)
// ──────────────────────────────────────
final nagaDaysProvider = FutureProvider<List<Map<String, dynamic>>>((ref) async {
  final items = await _loadRawList('naga_days_klu_theb.json');
  final result = <Map<String, dynamic>>[];
  for (final item in items) {
    if (item is! Map) continue;
    if (_containsTibetan(item)) continue;
    final name = item[_mainKey(item)]?.toString().trim() ?? '';
    final major = item['Unnamed: 1']?.toString().trim() ?? '';
    final minor = item['Unnamed: 2']?.toString().trim() ?? '';
    if (name.isEmpty || major.isEmpty || minor.isEmpty) continue;
    if (name.toLowerCase().contains('month')) continue;
    result.add({
      'month_name': name,
      'major_days': major,
      'minor_days': minor,
    });
  }
  return result;
});

// ──────────────────────────────────────
// 3. Flag Avoidance / Earth Lords (WORKING)
// ──────────────────────────────────────
final flagAvoidanceProvider = FutureProvider<List<Map<String, dynamic>>>((ref) async {
  final items = await _loadRawList('earth_lords_flag_days.json');
  final result = <Map<String, dynamic>>[];
  for (final item in items) {
    if (item is! Map) continue;
    if (_containsTibetan(item)) continue;
    final monthVal = item[_mainKey(item)]?.toString().trim() ?? '';
    final monthName = item['Unnamed: 1']?.toString().trim() ?? '';
    final avoidDays = item['Unnamed: 2']?.toString().trim() ?? '';
    if (monthVal.isEmpty || monthName.isEmpty || avoidDays.isEmpty) continue;
    result.add({
      'month': monthVal,
      'month_name': monthName,
      'avoid_days': avoidDays,
    });
  }
  return result;
});

// ──────────────────────────────────────
// 4. Restriction Activities (WORKING)
// ──────────────────────────────────────
final restrictionProvider = FutureProvider<List<Map<String, dynamic>>>((ref) async {
  final items = await _loadRawList('restriction_activities.json');
  final result = <Map<String, dynamic>>[];

  for (final item in items) {
    if (item is! Map) continue;
    if (_containsTibetan(item)) continue;

    final name = item['English Name']?.toString() ?? '';
    if (name.isEmpty) continue;

    result.add({
      'days': item['Days']?.toString() ?? '',
      'name': name,
      'restriction': item['Restriction']?.toString() ?? '',
    });
  }

  return result;
});

// ──────────────────────────────────────
// 5. Auspicious Timing
// Row 0 = description, Row 1 = header, Rows 2+ = data
// ──────────────────────────────────────
final auspiciousTimingProvider = FutureProvider<List<Map<String, dynamic>>>((ref) async {
  final items = await _loadRawList('auspicious_timing.json');
  final result = <Map<String, dynamic>>[];
  for (final item in items) {
    if (item is! Map) continue;
    if (_containsTibetan(item)) continue;
    final mainKey = _mainKey(item);
    final val = item[mainKey]?.toString().trim() ?? '';
    final c1 = item['Unnamed: 1']?.toString().trim() ?? '';
    final c2 = item['Unnamed: 2']?.toString().trim() ?? '';
    if (val.isEmpty || c1.isEmpty || c2.isEmpty) continue;
    if (val.contains('Day of Week') || val == 'Day') continue;
    result.add({
      'day_of_week': val,
      'daytime': c1,
      'nighttime': c2,
    });
  }
  return result;
});

// ──────────────────────────────────────
// 6. Fire Ritual (Fire Deity)
// Row 0-2 = descriptions, Row 3 = header (Tibetan Month/Auspicious Dates/Total Days)
// ──────────────────────────────────────
final fireRitualProvider = FutureProvider<List<Map<String, dynamic>>>((ref) async {
  final items = await _loadRawList('fire_rituals.json');
  final result = <Map<String, dynamic>>[];
  for (final item in items) {
    if (item is! Map) continue;
    if (_containsTibetan(item)) continue;
    final mainKey = _mainKey(item);
    final month = item[mainKey]?.toString().trim() ?? '';
    final dates = item['Unnamed: 1']?.toString().trim() ?? '';
    final total = item['Unnamed: 2']?.toString().trim() ?? '';
    if (month.isEmpty || dates.isEmpty || total.isEmpty) continue;
    if (month.contains('Tibetan Month')) continue;
    result.add({
      'month': month,
      'auspicious_dates': dates,
      'total_days': total,
    });
  }
  return result;
});

// ──────────────────────────────────────
// 7. Empty Vase (Bumtong) (WORKING)
// ──────────────────────────────────────
final emptyVaseProvider = FutureProvider<List<Map<String, dynamic>>>((ref) async {
  final items = await _loadRawList('empty_vase_bumtong.json');
  final result = <Map<String, dynamic>>[];
  for (final item in items) {
    if (item is! Map) continue;
    if (_containsTibetan(item)) continue;
    final month = item[_mainKey(item)]?.toString().trim() ?? '';
    final startingDay = item['Unnamed: 1']?.toString().trim() ?? '';
    final direction = item['Unnamed: 2']?.toString().trim() ?? '';
    if (month.isEmpty || startingDay.isEmpty || direction.isEmpty) continue;
    result.add({
      'month': month,
      'starting_day': startingDay,
      'direction': direction,
    });
  }
  return result;
});

// ──────────────────────────────────────
// 8. Life Force Male
// Row 3 = header ("Date 1-10", "Date 11-20", "Date 21-30")
// Rows 4+ = data like "1: Big toe", "11: Forearm", "21: Ribs"
// ──────────────────────────────────────
final lifeForceMaleProvider = FutureProvider<List<Map<String, dynamic>>>((ref) async {
  final items = await _loadRawList('life_force_male.json');
  return _parseLifeForce(items);
});

final lifeForceFemaleProvider = FutureProvider<List<Map<String, dynamic>>>((ref) async {
  final items = await _loadRawList('life_force_female.json');
  return _parseLifeForce(items);
});

List<Map<String, dynamic>> _parseLifeForce(List<dynamic> items) {
  final result = <Map<String, dynamic>>[];
  for (final item in items) {
    if (item is! Map) continue;
    if (_containsTibetan(item)) continue;
    final mainKey = _mainKey(item);
    final col1 = _stripTibetan(item[mainKey]?.toString().trim() ?? '');
    final col2 = _stripTibetan(item['Unnamed: 1']?.toString().trim() ?? '');
    final col3 = _stripTibetan(item['Unnamed: 2']?.toString().trim() ?? '');
    if (col1.isEmpty || col2.isEmpty || col3.isEmpty) continue;
    if (col1.contains('Date 1') || col1.contains('Day')) continue;
    result.add({
      'date_1_10': col1,
      'date_11_20': col2,
      'date_21_30': col3,
    });
  }
  return result;
}

// ──────────────────────────────────────
// 10. Horse Death (Ta Shi)
// Row 2 = header ("Lunar Day", "Meaning", "Status")
// Row 3+ = "1,7,13,19,25" / "Goddess Palthang" / "extremely auspicious"
// ──────────────────────────────────────
final horseDeathProvider = FutureProvider<List<Map<String, dynamic>>>((ref) async {
  final items = await _loadRawList('horse_death_ta_shi.json');
  final result = <Map<String, dynamic>>[];
  for (final item in items) {
    if (item is! Map) continue;
    if (_containsTibetan(item)) continue;
    final mainKey = _mainKey(item);
    final days = item[mainKey]?.toString().trim() ?? '';
    final meaning = item['Unnamed: 1']?.toString().trim() ?? '';
    final status = item['Unnamed: 2']?.toString().trim() ?? '';
    if (days.isEmpty || meaning.isEmpty || status.isEmpty) continue;
    if (days == 'Lunar Day') continue;
    result.add({
      'lunar_days': days,
      'meaning': meaning,
      'status': status,
    });
  }
  return result;
});

// ──────────────────────────────────────
// 11. Gu Mig
// Row 3 = header ("Category", "Ages Affected...", "Total Ages")
// Rows 4-7 = EN data, Row 9-13 = BO data
// ──────────────────────────────────────
final guMigProvider = FutureProvider<List<Map<String, dynamic>>>((ref) async {
  final items = await _loadRawList('gu_mig.json');
  final result = <Map<String, dynamic>>[];
  for (final item in items) {
    if (item is! Map) continue;
    if (_containsTibetan(item)) continue;
    final mainKey = _mainKey(item);
    final category = item[mainKey]?.toString().trim() ?? '';
    final ages = item['Unnamed: 1']?.toString().trim() ?? '';
    final total = item['Unnamed: 2']?.toString().trim() ?? '';
    if (category.isEmpty || ages.isEmpty || total.isEmpty) continue;
    if (category.contains('Category') || category.contains('དབྱེ་བ')) continue;
    result.add({
      'category': category,
      'ages_affected': ages,
      'total': total,
    });
  }
  return result;
});

// ──────────────────────────────────────
// 12. Fatal Weekdays
// Row 3 = header ("Birth Sign", "Soul & Life-Force (auspicious)", "Fatal Day (Inauspicious)")
// ──────────────────────────────────────
final fatalWeekdaysProvider = FutureProvider<List<Map<String, dynamic>>>((ref) async {
  final items = await _loadRawList('fatal_weekdays.json');
  final result = <Map<String, dynamic>>[];
  for (final item in items) {
    if (item is! Map) continue;
    if (_containsTibetan(item)) continue;
    final mainKey = _mainKey(item);
    final birthSign = item[mainKey]?.toString().trim() ?? '';
    final soulDay = item['Unnamed: 1']?.toString().trim() ?? '';
    final fatalDay = item['Unnamed: 2']?.toString().trim() ?? '';
    if (birthSign.isEmpty || soulDay.isEmpty || fatalDay.isEmpty) continue;
    if (birthSign.contains('Birth Sign') || birthSign.contains('སྐྱེ་བའི')) continue;
    result.add({
      'birth_sign': birthSign,
      'soul_day': soulDay,
      'fatal_day': fatalDay,
    });
  }
  return result;
});

// ──────────────────────────────────────
// 13. Torma Offering (WORKING)
// ──────────────────────────────────────
final tormaOfferingProvider = FutureProvider<List<Map<String, dynamic>>>((ref) async {
  final items = await _loadRawList('torma_offering.json');
  final result = <Map<String, dynamic>>[];
  for (final item in items) {
    if (item is! Map) continue;
    if (_containsTibetan(item)) continue;
    final mainKey = _mainKey(item);
    final month = item[mainKey]?.toString().trim() ?? '';
    final direction = item['Unnamed: 1']?.toString().trim() ?? '';
    final bearing = item['Unnamed: 2']?.toString().trim() ?? '';
    if (month.isEmpty || direction.isEmpty || bearing.isEmpty) continue;
    if (month.contains('Tibetan Month')) continue;
    result.add({
      'month': month,
      'direction': direction,
      'bearing': bearing,
    });
  }
  return result;
});

// ──────────────────────────────────────
// 14. Tibetan Astrology (comprehensive)
// Row 0 = header mapping, Rows 1+ = data
// ──────────────────────────────────────
final tibetanAstrologyProvider = FutureProvider<List<Map<String, dynamic>>>((ref) async {
  final items = await _loadRawList('tibetan_astrology.json');
  final result = <Map<String, dynamic>>[];
  for (int i = 1; i < items.length; i++) {
    final item = items[i];
    if (item is! Map) continue;
    final mainKey = _mainKey(item);
    final name = item[mainKey]?.toString() ?? '';
    if (name.isEmpty || name == 'null') continue;
    result.add({
      'name_en': _stripTibetan(name),
      'description_en': _stripTibetan(item['Unnamed: 4']?.toString() ?? ''),
      'notes_en': _stripTibetan(item['Unnamed: 12']?.toString() ?? ''),
      'image': item['Unnamed: 2']?.toString() ?? '',
    });
  }
  return result;
});

// ──────────────────────────────────────
// 15. Daily Astrological Cards (9)
// ──────────────────────────────────────
final dailyAstroCardsProvider = FutureProvider<List<Map<String, dynamic>>>((ref) async {
  final items = await _loadRawList('9_daily_astrological_cards.json');
  return items.whereType<Map>().map((e) => e.cast<String, dynamic>()).toList();
});
