import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../features/auspicious/providers/auspicious_days_provider.dart';
import '../services/local_data_service.dart';
import '../services/theme_provider.dart';
import '../services/translations.dart';
import '../theme/app_theme.dart';
import 'day_details_screen.dart';

class AuspiciousDaysScreen extends ConsumerStatefulWidget {
  const AuspiciousDaysScreen({super.key});

  @override
  ConsumerState<AuspiciousDaysScreen> createState() => _AuspiciousDaysScreenState();
}

class _AuspiciousDaysScreenState extends ConsumerState<AuspiciousDaysScreen> {
  DateTime _selectedDate = DateTime.now();
  // cache: lunar day -> solar date for the current visible range
  final Map<int, DateTime> _lunarSolarCache = {};

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final lang = ref.watch(languageProvider);
    final isBo = lang == 'bo';
    final daysAsync = ref.watch(auspiciousDaysFutureProvider);

    return Scaffold(
      backgroundColor: isDark ? AppColors.darkBg : const Color(0xFFF7F2EC),
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: () => ref.refresh(auspiciousDaysFutureProvider.future),
          color: AppColors.maroon,
          child: CustomScrollView(
            physics: const BouncingScrollPhysics(),
            slivers: [
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
                  child: Row(
                    children: [
                      Text(
                        T.t('auspicious_days', isBo),
                        style: TextStyle(
                          fontSize: 28,
                          fontWeight: FontWeight.w800,
                          color: isDark ? Colors.white : AppColors.navy,
                        ),
                      ),
                      const Spacer(),
                      _iconBtn(
                        Icons.notifications_outlined,
                        onTap: () {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text(
                                isBo
                                    ? 'དགོངས་དག། ལས་འགུལ་འདི་ད་དུང་བསྒྲུབ་བཞིན་ཡོད། མྱུར་དུ་གསར་སྒྱུར་འོང་།'
                                    : 'This feature is under development and will be available soon.',
                              ),
                              backgroundColor: AppColors.maroon,
                              behavior: SnackBarBehavior.floating,
                            ),
                          );
                        },
                      ),
                      const SizedBox(width: 8),
                      _iconBtn(
                        Icons.search,
                        onTap: () {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text(
                                isBo
                                    ? 'དགོངས་དག། འཚོལ་ཞིབ་ལས་འགུལ་ད་དུང་བསྒྲུབ་བཞིན་ཡོད། མྱུར་དུ་གསར་སྒྱུར་འོང་།'
                                    : 'Search feature is currently under development and will be available soon.',
                              ),
                              backgroundColor: AppColors.maroon,
                              behavior: SnackBarBehavior.floating,
                            ),
                          );
                        },
                      ),
                    ],
                  ),
                ),
              ),
              SliverToBoxAdapter(
                child: _buildMilestoneCard(isDark, isBo, context, daysAsync, _selectedDate),
              ),
              SliverToBoxAdapter(
                child: _buildDateSlider(isDark, isBo, _selectedDate),
              ),
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(20, 18, 20, 8),
                  child: Text(
                    T.t('significant_dates', isBo),
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 1.6,
                      color: AppColors.lightTextSecondary,
                    ),
                  ),
                ),
              ),
              daysAsync.when(
                loading: () => const SliverToBoxAdapter(
                  child: Center(
                    child: Padding(
                      padding: EdgeInsets.all(40),
                      child: CircularProgressIndicator(color: AppColors.maroon),
                    ),
                  ),
                ),
                error: (e, _) => SliverToBoxAdapter(
                  child: Center(
                    child: Padding(
                      padding: const EdgeInsets.all(40),
                      child: Text('Error: $e', style: const TextStyle(color: AppColors.maroon)),
                    ),
                  ),
                ),
                data: (days) {
                  final dateKey = DateFormat('yyyy-MM-dd').format(_selectedDate);

                  return FutureBuilder<Map<String, dynamic>?>(
                    future: LocalDataService.getCalendarDay(dateKey),
                    builder: (context, snap) {
                      final tibDayRaw = snap.data?['tibetan_day'];
                      final currentDay = tibDayRaw is int
                          ? tibDayRaw
                          : int.tryParse('$tibDayRaw') ?? 1;

                      final sortedDays = _sortDaysForDisplay(days);
                      const mainLunarDays = [8, 10, 15, 25, 29];

                      // Keep only canonical lunar auspicious days
                      final canonical = sortedDays.where((d) => mainLunarDays.contains(d.day)).toList();

                      // Collapse duplicates by lunar day
                      final Map<int, AuspiciousDayEntity> uniqueDays = {};
                      for (final d in canonical) {
                        uniqueDays.putIfAbsent(d.day, () => d);
                      }

                      final daysList = uniqueDays.values.toList();

                      // Split into upcoming and next-cycle days
                      // order canonical lunar days relative to current lunar day
                      final ordered = [...daysList]..sort((a, b) => a.day.compareTo(b.day));

                      final pivotIndex = ordered.indexWhere((d) => d.day >= currentDay);

                      final displayDays = pivotIndex == -1
                          ? ordered
                          : [
                              ...ordered.sublist(pivotIndex),
                              ...ordered.sublist(0, pivotIndex),
                            ];

                      return SliverList(
                        delegate: SliverChildBuilderDelegate(
                          (ctx, i) => _buildDayTile(displayDays[i], isDark, isBo, ctx),
                          childCount: displayDays.length,
                        ),
                      );
                    },
                  );
                },
              ),
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.all(20),
                  child: Center(
                    child: Text(
                      isBo
                          ? 'ཕུག་པའི་ལུགས་ཀྱིས་བརྩིས་པ།'
                          : 'DATES CALCULATED BY PHUGPA TRADITION',
                      style: TextStyle(
                        fontSize: 9,
                        letterSpacing: 1.5,
                        fontWeight: FontWeight.w700,
                        color: AppColors.lightTextSecondary,
                      ),
                    ),
                  ),
                ),
              ),
              const SliverToBoxAdapter(child: SizedBox(height: 80)),
            ],
          ),
        ),
      ),
    );
  }

  Widget _iconBtn(IconData icon, {VoidCallback? onTap}) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        customBorder: const CircleBorder(),
        child: Container(
          width: 36,
          height: 36,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: AppColors.maroon.withOpacity(0.08),
          ),
          child: Icon(icon, size: 18, color: AppColors.maroon),
        ),
      ),
    );
  }

  Widget _buildMilestoneCard(
    bool isDark,
    bool isBo,
    BuildContext context,
    AsyncValue<List<AuspiciousDayEntity>> daysAsync,
    DateTime selectedDate,
  ) {
    final allDays = _sortDaysForDisplay(daysAsync.valueOrNull ?? []);
    const mainLunarDays = [8, 10, 15, 25, 29];
    final days = allDays.where((d) => mainLunarDays.contains(d.day)).toList()
      ..sort((a, b) => a.day.compareTo(b.day));

    final dateKey = DateFormat('yyyy-MM-dd').format(selectedDate);

    return FutureBuilder<Map<String, dynamic>?>(
      future: LocalDataService.getCalendarDay(dateKey),
      builder: (context, snap) {
        final tibDay = snap.data?['tibetan_day'] ?? 0;
        final selectedLunarDay = tibDay is int ? tibDay : int.tryParse('$tibDay') ?? 0;
        AuspiciousDayEntity? nextDay;

    if (days.isNotEmpty) {
      final ordered = [...days]..sort((a, b) => a.day.compareTo(b.day));

      // pick the NEXT lunar milestone strictly after the current lunar day
      final idx = ordered.indexWhere((d) => d.day > selectedLunarDay);

      nextDay = idx == -1 ? ordered.first : ordered[idx];
    }

        final hasData = nextDay != null && nextDay.day > 0;
        final name = hasData
            ? (isBo ? (nextDay!.nameBo.isNotEmpty ? nextDay!.nameBo : nextDay!.nameEn) : nextDay!.nameEn)
            : (isBo ? 'གལ་ཆེའི་ཉིན་མེད།' : 'No upcoming milestone');
        final desc = hasData
            ? (isBo
                ? (nextDay!.shortDescriptionBo.isNotEmpty ? nextDay!.shortDescriptionBo : nextDay!.shortDescriptionEn)
                : nextDay!.shortDescriptionEn)
            : '';
        int daysLeft = 0;

        if (hasData) {
          // compute days remaining in the lunar cycle (Phugpa-style cycle wrap)
          final diff = nextDay!.day - selectedLunarDay;
          daysLeft = diff > 0 ? diff : diff + 30;
        }

        return Padding(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.fromLTRB(20, 22, 20, 22),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(18),
              gradient: const LinearGradient(
                colors: [Color(0xFF5A0000), Color(0xFF7A0000)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFF8C0000).withOpacity(0.28),
                  blurRadius: 18,
                  offset: const Offset(0, 8),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.15),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        isBo ? 'རྗེས་མའི་དུས་ཆེན།' : 'NEXT MILESTONE',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 9,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 0.6,
                        ),
                      ),
                    ),
                    const Spacer(),
                    Text(
                      isBo ? 'ཉིན་ $daysLeft ནང་' : 'In $daysLeft Days',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 18),
                Text(
                  name,
                  style: const TextStyle(
                    fontSize: 26,
                    fontWeight: FontWeight.w800,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 6),
                if (hasData)
                  FutureBuilder<Map<String, dynamic>?>(
                    future: _findSolarDateForLunarDay(nextDay!.day).then((date) {
                      if (date == null) return null;
                      return LocalDataService.getCalendarDay(DateFormat('yyyy-MM-dd').format(date));
                    }),
                    builder: (context, lunarSnap) {
                      final tibMonthRaw = lunarSnap.data?['tibetan_month'];
                      final tibMonth = tibMonthRaw is int ? tibMonthRaw : int.tryParse('$tibMonthRaw');

                      final label = tibMonth != null
                          ? (isBo
                              ? 'ཚེས་ ${nextDay!.day} · ཟླ་བ $tibMonth'
                              : 'Day ${nextDay!.day} · Lunar Month $tibMonth')
                          : (isBo ? 'ཚེས་ ${nextDay!.day}' : 'Day ${nextDay!.day}');

                      return Text(
                        label,
                        style: const TextStyle(
                          color: Colors.white70,
                          fontSize: 13,
                          fontWeight: FontWeight.w500,
                        ),
                      );
                    },
                  ),
                if (desc.isNotEmpty) ...[
                  const SizedBox(height: 10),
                  Text(
                    desc,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 13,
                      height: 1.4,
                    ),
                  ),
                ],
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      child: GestureDetector(
                        onTap: hasData
                            ? () async {
                                final result = await _findSolarDateForLunarDay(nextDay!.day);
                                if (!mounted) return;

                                if (result != null) {
                                  Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (_) => DayDetailsScreen(date: result),
                                    ),
                                  );
                                }
                              }
                            : null,
                        child: Container(
                          height: 38,
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(color: Colors.white70),
                          ),
                          alignment: Alignment.center,
                          child: Text(
                            isBo ? 'ཉིན་གྱི་ཞིབ་ཕྲ།' : 'View Day Details',
                            style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.w700,
                              fontSize: 12,
                            ),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: GestureDetector(
                        onTap: () {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text(
                                isBo ? 'དྲན་སྐུལ་ལས་འགུལ་འདི་མི་འགོ་བཙུགས།' : 'Reminder feature coming soon',
                              ),
                              backgroundColor: AppColors.maroon,
                              behavior: SnackBarBehavior.floating,
                            ),
                          );
                        },
                        child: Container(
                          height: 38,
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(10),
                            color: Colors.white,
                          ),
                          alignment: Alignment.center,
                          child: Text(
                            isBo ? 'དྲན་སྐུལ་བཀོད།' : 'Set Reminder',
                            style: const TextStyle(
                              color: Color(0xFF8C0000),
                              fontWeight: FontWeight.w700,
                              fontSize: 12,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildDateSlider(bool isDark, bool isBo, DateTime selectedDate) {
    final startOfWeek = selectedDate.subtract(Duration(days: selectedDate.weekday - 1));
    final days = List.generate(7, (i) => startOfWeek.add(Duration(days: i)));

    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 14, 0, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 4),
          const SizedBox(height: 12),
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              SizedBox(
                height: 72,
                child: Center(
                  child: IconButton(
                    icon: const Icon(Icons.chevron_left, size: 20),
                    color: AppColors.maroon,
                    onPressed: () {
                      setState(() {
                        _selectedDate = _selectedDate.subtract(const Duration(days: 7));
                        _lunarSolarCache.clear();
                      });
                    },
                  ),
                ),
              ),
              // REPLACEMENT: fixed 7 day tiles, no scrolling
              Expanded(
                child: SizedBox(
                  height: 72,
                  child: Row(
                    children: List.generate(7, (i) {
                      final d = days[i];
                      final isSelected = d.year == _selectedDate.year &&
                          d.month == _selectedDate.month &&
                          d.day == _selectedDate.day;

                      // These markers are visual only; Tibetan lunar dates come from calendar JSON in DayDetailsScreen
                      final isAuspicious = false; // removed incorrect solar markers; lunar markers handled by Tibetan calendar data

                      return Expanded(
                        child: GestureDetector(
                          onTap: () {
                            setState(() {
                              _selectedDate = DateTime(d.year, d.month, d.day);
                              _lunarSolarCache.clear();
                            });
                          },
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 180),
                            margin: const EdgeInsets.only(right: 6),
                            decoration: BoxDecoration(
                              color: isSelected
                                  ? const Color(0xFF7A0000)
                                  : (isAuspicious ? const Color(0xFFFFF3F3) : Colors.white),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: isSelected
                                    ? const Color(0xFF7A0000)
                                    : AppColors.maroon.withOpacity(0.15),
                              ),
                              boxShadow: isSelected
                                  ? [
                                      BoxShadow(
                                        color: AppColors.maroon.withOpacity(0.25),
                                        blurRadius: 10,
                                        offset: const Offset(0, 4),
                                      ),
                                    ]
                                  : null,
                            ),
                            child: FutureBuilder<Map<String, dynamic>?>(
                              future: LocalDataService.getCalendarDay(DateFormat('yyyy-MM-dd').format(d)),
                              builder: (context, snap) {
                                final tibDay = snap.data?['tibetan_day'];
                                final tibMonth = snap.data?['tibetan_month'];

                                final dayLabel = tibDay != null ? '$tibDay' : '';
                                final monthLabel = tibMonth != null
                                    ? (isBo ? 'ཟླ་ $tibMonth' : 'M$tibMonth')
                                    : '';

                                return Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Text(
                                      monthLabel,
                                      style: TextStyle(
                                        fontSize: 10,
                                        fontWeight: FontWeight.w700,
                                        color: isSelected
                                            ? Colors.white.withOpacity(0.82)
                                            : AppColors.lightTextSecondary,
                                      ),
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      dayLabel,
                                      style: TextStyle(
                                        fontSize: 22,
                                        fontWeight: FontWeight.w800,
                                        color: isSelected
                                            ? Colors.white
                                            : (isDark ? Colors.white : AppColors.navy),
                                      ),
                                    ),
                                    const SizedBox(height: 4),
                                    Container(
                                      width: 6,
                                      height: 6,
                                      decoration: BoxDecoration(
                                        color: Colors.transparent,
                                        shape: BoxShape.circle,
                                      ),
                                    ),
                                  ],
                                );
                              },
                            ),
                          ),
                        ),
                      );
                    }),
                  ),
                ),
              ),
              SizedBox(
                height: 72,
                child: Center(
                  child: IconButton(
                    icon: const Icon(Icons.chevron_right, size: 20),
                    color: AppColors.maroon,
                    onPressed: () {
                      setState(() {
                        _selectedDate = _selectedDate.add(const Duration(days: 7));
                        _lunarSolarCache.clear();
                      });
                    },
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildDayTile(AuspiciousDayEntity day, bool isDark, bool isBo, BuildContext ctx) {
    final name = isBo ? (day.nameBo.isNotEmpty ? day.nameBo : day.nameEn) : day.nameEn;
    String displayName = name;
    final lower = day.nameEn.toLowerCase();
    if (day.day == 10 || lower.contains('guru')) {
      displayName = isBo ? 'གུ་རུ་རིན་པོ་ཆེའི་ཉིན།' : 'Guru Rinpoche Day';
    }
    final desc = isBo
        ? (day.shortDescriptionBo.isNotEmpty ? day.shortDescriptionBo : day.shortDescriptionEn)
        : day.shortDescriptionEn;
    // Use displayName for image lookup to ensure normalization
    final imgPath = _auspiciousImageFor(displayName.toLowerCase());

    return GestureDetector(
      onTap: () async {
        _lunarSolarCache.clear();
        final solarDate = await _findSolarDateForLunarDay(day.day);
        if (!mounted) return;

        if (solarDate != null) {
          Navigator.push(
            ctx,
            MaterialPageRoute(
              builder: (_) => DayDetailsScreen(date: solarDate),
            ),
          );
        }
      },
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: isDark ? AppColors.darkCard : Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: AppColors.maroon.withOpacity(0.08),
            width: 1,
          ),
          boxShadow: [
            BoxShadow(color: Colors.black.withOpacity(0.035), blurRadius: 12, offset: const Offset(0, 3)),
          ],
        ),
        child: Row(
          children: [
            Container(
              width: 52,
              height: 52,
              decoration: BoxDecoration(
                color: AppColors.maroon.withOpacity(0.08),
                borderRadius: BorderRadius.circular(12),
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(10),
                child: Image.asset(
                  imgPath,
                  fit: BoxFit.cover,
                  gaplessPlayback: true,
                  cacheWidth: 104,
                  filterQuality: FilterQuality.low,
                  errorBuilder: (_, __, ___) => Container(
                    color: AppColors.maroon.withOpacity(0.08),
                    child: const Icon(Icons.auto_awesome, color: AppColors.maroon, size: 20),
                  ),
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    displayName,
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      color: isDark ? Colors.white : AppColors.navy,
                    ),
                  ),
                  const SizedBox(height: 6),
                  FutureBuilder<DateTime?>(
                    future: _findSolarDateForLunarDay(day.day),
                    builder: (context, snap) {
                      final solar = snap.data;
                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              const Text(
                                'SOLAR CALENDAR',
                                style: TextStyle(
                                  fontSize: 9,
                                  letterSpacing: 1.2,
                                  fontWeight: FontWeight.w700,
                                  color: AppColors.lightTextSecondary,
                                ),
                              ),
                              const SizedBox(width: 8),
                              Text(
                                solar != null
                                    ? DateFormat('MMM dd, yyyy').format(solar)
                                    : '—',
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                  color: isDark ? Colors.white : AppColors.navy,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 2),
                          FutureBuilder<Map<String, dynamic>?>(
                            future: solar != null
                                ? LocalDataService.getCalendarDay(DateFormat('yyyy-MM-dd').format(solar))
                                : Future.value(null),
                            builder: (context, lunarSnap) {
                              final tibMonthRaw = lunarSnap.data?['tibetan_month'];
                              final tibMonth = tibMonthRaw is int ? tibMonthRaw : int.tryParse('$tibMonthRaw');

                              final label = tibMonth != null
                                  ? (isBo
                                      ? 'ཟླ་བ $tibMonth · ཚེས་ ${day.day}'
                                      : 'Lunar Month $tibMonth · Day ${day.day}')
                                  : (isBo ? 'ཚེས་ ${day.day}' : 'Day ${day.day}');

                              return Row(
                                children: [
                                  const Text(
                                    'LUNAR CALENDAR',
                                    style: TextStyle(
                                      fontSize: 9,
                                      letterSpacing: 1.2,
                                      fontWeight: FontWeight.w700,
                                      color: AppColors.lightTextSecondary,
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  Text(
                                    label,
                                    style: TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w600,
                                      color: isDark ? Colors.redAccent : AppColors.maroon,
                                    ),
                                  ),
                                ],
                              );
                            },
                          ),
                        ],
                      );
                    },
                  ),
                ],
              ),
            ),
            const Icon(Icons.chevron_right, size: 18, color: AppColors.lightTextSecondary),
          ],
        ),
      ),
    );
  }

  void _showDayDetail(BuildContext context, AuspiciousDayEntity day, bool isDark, bool isBo) {
    final name = isBo ? (day.nameBo.isNotEmpty ? day.nameBo : day.nameEn) : day.nameEn;
    final desc = isBo
        ? (day.descriptionBo.isNotEmpty ? day.descriptionBo : day.descriptionEn)
        : day.descriptionEn;
    final shortDesc = isBo
        ? (day.shortDescriptionBo.isNotEmpty ? day.shortDescriptionBo : day.shortDescriptionEn)
        : day.shortDescriptionEn;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => DraggableScrollableSheet(
        initialChildSize: 0.92,
        maxChildSize: 0.96,
        minChildSize: 0.7,
        builder: (ctx2, controller) => Container(
          decoration: BoxDecoration(
            color: isDark ? AppColors.darkSurface : Colors.white,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
          ),
          child: ListView(
            controller: controller,
            padding: const EdgeInsets.all(20),
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.grey.withOpacity(0.3),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Center(
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                  decoration: BoxDecoration(
                    color: AppColors.maroon.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    isBo ? 'ཚེས་ ${day.day} · ཟླ་བ ${day.month}' : 'Day ${day.day} · Month ${day.month}',
                    style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: AppColors.maroon),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              if (isBo && day.nameBo.isNotEmpty)
                Center(
                  child: Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: AppColors.maroon.withOpacity(0.05),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      day.nameBo,
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.w700,
                        color: isDark ? Colors.white : AppColors.navy,
                      ),
                    ),
                  ),
                ),
              const SizedBox(height: 12),
              Text(
                name,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.w800,
                  color: isDark ? Colors.white : AppColors.navy,
                ),
              ),
              if (shortDesc.isNotEmpty) ...[
                const SizedBox(height: 12),
                Text(
                  shortDesc,
                  textAlign: TextAlign.center,
                  style: const TextStyle(fontSize: 14, color: AppColors.lightTextSecondary, height: 1.5),
                ),
              ],
              if (desc.isNotEmpty) ...[
                const SizedBox(height: 20),
                Text(
                  T.t('description', isBo),
                  style: const TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 1.5,
                    color: AppColors.maroon,
                  ),
                ),
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: isDark ? AppColors.darkCard : AppColors.creamLight,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    desc,
                    style: TextStyle(
                      fontSize: 14,
                      height: 1.7,
                      color: isDark ? AppColors.darkText : AppColors.lightText,
                    ),
                  ),
                ),
              ],
              const SizedBox(height: 16),
              Text(
                T.t('practices_for_day', isBo),
                style: const TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 1.5,
                  color: AppColors.maroon,
                ),
              ),
              const SizedBox(height: 8),
              ..._practicesForDay(day, isBo),
              const SizedBox(height: 24),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () {
                        ScaffoldMessenger.of(ctx2).showSnackBar(
                          SnackBar(
                            content: Text(isBo ? '✅ དྲན་སྐུལ་བཀོད་ཟིན།' : '✅ Reminder set!'),
                            backgroundColor: AppColors.maroon,
                            behavior: SnackBarBehavior.floating,
                          ),
                        );
                      },
                      icon: const Icon(Icons.alarm, size: 16, color: AppColors.maroon),
                      label: Text(T.t('set_reminder', isBo), style: const TextStyle(color: AppColors.maroon)),
                      style: OutlinedButton.styleFrom(
                        side: const BorderSide(color: AppColors.maroon),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        padding: const EdgeInsets.symmetric(vertical: 12),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () => Navigator.of(ctx2).pop(),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.maroon,
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      child: Text(T.t('close', isBo), style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700)),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  List<Widget> _practicesForDay(AuspiciousDayEntity day, bool isBo) {
    final practices = <Map<String, String>>[];
    final name = day.nameEn.toLowerCase();

    if (name.contains('medicine')) {
      practices.addAll([
        {'icon': '💊', 'en': 'Medicine Buddha Mantra (Tayata Om...)', 'bo': 'སྨན་བླའི་སྔགས།'},
        {'icon': '🙏', 'en': 'Seven-line Prayer', 'bo': 'ཚིག་བདུན་གསོལ་འདེབས།'},
      ]);
    } else if (name.contains('guru')) {
      practices.addAll([
        {'icon': '🔥', 'en': 'Guru Rinpoche Tsok Offering', 'bo': 'གུ་རུའི་ཚོགས་མཆོད།'},
        {'icon': '📿', 'en': 'Vajra Guru Mantra (Om Ah Hum...)', 'bo': 'རྡོ་རྗེའི་བླ་མའི་སྔགས།'},
      ]);
    } else if (name.contains('full moon')) {
      practices.addAll([
        {'icon': '🌕', 'en': 'Sojong (Eight Precepts)', 'bo': 'སོ་སྦྱོང་། (བསླབ་པ་བརྒྱད)'},
        {'icon': '🕯️', 'en': 'Butter Lamp Offerings', 'bo': 'མར་མེ་མཆོད་པ།'},
      ]);
    } else if (name.contains('dakini')) {
      practices.addAll([
        {'icon': '✨', 'en': 'Dakini Tsok Offering', 'bo': 'མཁའ་འགྲོའི་ཚོགས་མཆོད།'},
        {'icon': '📿', 'en': 'Vajra Yogini Practice', 'bo': 'རྡོ་རྗེ་རྣལ་འབྱོར་མའི་སྒྲུབ་ཐབས།'},
      ]);
    } else {
      practices.addAll([
        {'icon': '🙏', 'en': 'General Merit Accumulation', 'bo': 'བསོད་ནམས་བསགས་པ།'},
        {'icon': '📿', 'en': 'Mantra Recitation', 'bo': 'སྔགས་བཟླས།'},
      ]);
    }

    return practices
        .map(
          (p) => Container(
            padding: const EdgeInsets.all(12),
            margin: const EdgeInsets.only(bottom: 6),
            decoration: BoxDecoration(
              color: AppColors.maroon.withOpacity(0.04),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Row(
              children: [
                Text(p['icon']!, style: const TextStyle(fontSize: 20)),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    isBo ? p['bo']! : p['en']!,
                    style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
                  ),
                ),
              ],
            ),
          ),
        )
        .toList();
  }

  String _lunarRecurrenceLabel(AuspiciousDayEntity day, bool isBo) {
    final monthNumber = day.monthNumber;
    final monthValue = (monthNumber != null && monthNumber > 0) ? monthNumber : day.month;

    // If month is 0 or invalid, treat as recurring monthly day and hide the month text
    if (monthValue == 0) {
      return isBo
          ? 'ཚེས་ ${day.day}'
          : 'Day ${day.day}';
    }

    return isBo
        ? 'ཟླ་བ $monthValue · ཚེས་ ${day.day}'
        : 'Lunar Month $monthValue · Day ${day.day}';
  }

  List<AuspiciousDayEntity> _sortDaysForDisplay(List<AuspiciousDayEntity> days) {
    final sorted = [...days];

    // Sort purely by lunar day (1–30). Upcoming logic is handled elsewhere
    // using the Tibetan calendar day from LocalDataService.
    sorted.sort((a, b) => a.day.compareTo(b.day));

    return sorted;
  }


  String _auspiciousImageFor(String lowerName) {
    // Use canonical mapping so images always appear correctly
    if (lowerName.contains('medicine')) {
      return 'assets/images/Auspicious_days/medicinebuddha.PNG';
    }

    if (lowerName.contains('dakini')) {
      return 'assets/images/Auspicious_days/dakini.PNG';
    }

    if (lowerName.contains('guru')) {
      return 'assets/images/Guru_Rinpoche_12_manefistation/augguru.PNG';
    }

    if (lowerName.contains('full')) {
      return 'assets/images/Auspicious_days/fullmoon.PNG';
    }

    if (lowerName.contains('new')) {
      return 'assets/images/Auspicious_days/newmoon.PNG';
    }

    // safe fallback so images never disappear
    return 'assets/images/Auspicious_days/fullmoon.PNG';
  }

  String _monthName(int m) {
    const names = [
      '',
      'January',
      'February',
      'March',
      'April',
      'May',
      'June',
      'July',
      'August',
      'September',
      'October',
      'November',
      'December',
    ];
    return names[m];
  }

  String _monthShortName(int m) {
    const names = ['', 'JAN', 'FEB', 'MAR', 'APR', 'MAY', 'JUN', 'JUL', 'AUG', 'SEP', 'OCT', 'NOV', 'DEC'];
    return names[m];
  }

  Future<DateTime?> _findSolarDateForLunarDay(int lunarDay) async {
    final base = _selectedDate;

    // check cache first
    if (_lunarSolarCache.containsKey(lunarDay)) {
      return _lunarSolarCache[lunarDay];
    }

    // search forward first (nearest upcoming occurrence)
    for (int i = 0; i <= 60; i++) {
      final date = base.add(Duration(days: i));

      final data = await LocalDataService.getCalendarDay(
        DateFormat('yyyy-MM-dd').format(date),
      );

      if (data == null) continue;

      final tibDayRaw = data['tibetan_day'];
      final tibDay = tibDayRaw is int ? tibDayRaw : int.tryParse('$tibDayRaw');

      if (tibDay == lunarDay) {
        _lunarSolarCache[lunarDay] = date;
        return date;
      }
    }

    // fallback: search backwards
    for (int i = 1; i <= 60; i++) {
      final date = base.subtract(Duration(days: i));

      final data = await LocalDataService.getCalendarDay(
        DateFormat('yyyy-MM-dd').format(date),
      );

      if (data == null) continue;

      final tibDayRaw = data['tibetan_day'];
      final tibDay = tibDayRaw is int ? tibDayRaw : int.tryParse('$tibDayRaw');

      if (tibDay == lunarDay) {
        _lunarSolarCache[lunarDay] = date;
        return date;
      }
    }

    return null;
  }
}

class _AuspiciousSearchDelegate extends SearchDelegate<AuspiciousDayEntity?> {
  _AuspiciousSearchDelegate({
    required this.isBo,
    required this.allDays,
    required this.onSelected,
  });

  final bool isBo;
  final List<AuspiciousDayEntity> allDays;
  final ValueChanged<AuspiciousDayEntity> onSelected;

  @override
  List<Widget>? buildActions(BuildContext context) {
    return [
      if (query.isNotEmpty)
        IconButton(
          onPressed: () => query = '',
          icon: const Icon(Icons.clear),
        ),
    ];
  }

  @override
  Widget? buildLeading(BuildContext context) {
    return IconButton(
      onPressed: () => close(context, null),
      icon: const Icon(Icons.arrow_back),
    );
  }

  @override
  Widget buildResults(BuildContext context) => _buildList(context);

  @override
  Widget buildSuggestions(BuildContext context) => _buildList(context);

  Widget _buildList(BuildContext context) {
    final q = query.trim().toLowerCase();
    final results = q.isEmpty
        ? allDays
        : allDays.where((day) {
            final hay = '${day.nameEn} ${day.nameBo} ${day.shortDescriptionEn} ${day.shortDescriptionBo}'.toLowerCase();
            return hay.contains(q);
          }).toList();

    if (results.isEmpty) {
      return Center(child: Text(isBo ? 'མ་རྙེད།' : 'No results found'));
    }

    return ListView.separated(
      itemCount: results.length,
      separatorBuilder: (_, __) => const Divider(height: 1),
      itemBuilder: (context, index) {
        final day = results[index];
        final title = isBo ? (day.nameBo.isNotEmpty ? day.nameBo : day.nameEn) : day.nameEn;
        final subtitle = isBo
            ? 'ཚེས་ ${day.day} · ཟླ་བ ${day.monthNumber ?? day.month}'
            : 'Day ${day.day} · Lunar Month ${day.monthNumber ?? day.month}';
        return ListTile(
          title: Text(title),
          subtitle: Text(subtitle),
          onTap: () {
            onSelected(day);
            close(context, day);
          },
        );
      },
    );
  }
}