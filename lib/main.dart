import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'screens/home_shell.dart';
import 'theme/app_theme.dart';
import 'services/theme_provider.dart';
import 'services/local_data_service.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();

  // Pre-warm critical data BEFORE the first widget builds.
  // By the time CalendarHomeScreen.initState() fires, all JSON is
  // already decoded and sitting in the in-memory cache → instant UI.
  LocalDataService.warmUp();

  runApp(const ProviderScope(child: NyingmaCalendarApp()));
}

class NyingmaCalendarApp extends ConsumerStatefulWidget {
  const NyingmaCalendarApp({super.key});

  @override
  ConsumerState<NyingmaCalendarApp> createState() => _NyingmaCalendarAppState();
}

class _NyingmaCalendarAppState extends ConsumerState<NyingmaCalendarApp> {
  bool _imagesPrecached = false;

  /// Precache the most frequently displayed images so they appear instantly.
  /// Runs once after the first frame to avoid blocking startup.
  void _precacheImages(BuildContext context) {
    if (_imagesPrecached) return;
    _imagesPrecached = true;

    // Critical images that appear on the home screen immediately
    const criticalImages = [
      'assets/images/others/logo.PNG',
      'assets/images/others/astrology_logo.webp',
      // Header images (hero card rotates these)
      'assets/images/header_images/1.webp',
      'assets/images/header_images/2.webp',
      'assets/images/header_images/3.webp',
      'assets/images/header_images/4.webp',
      'assets/images/header_images/5.webp',
      'assets/images/header_images/6.webp',
      'assets/images/header_images/7.jpg',
      'assets/images/header_images/8.webp',
      // Astrology grid icons (15 items on home screen)
      'assets/images/astrology/auspicious_time.PNG',
      'assets/images/astrology/parkha.PNG',
      'assets/images/astrology/fire_deity.PNG',
      'assets/images/astrology/empty_vase.PNG',
      'assets/images/astrology/bla_men_eng.PNG',
      'assets/images/astrology/bla_women_eng.PNG',
      'assets/images/astrology/horse_death.webp',
      'assets/images/astrology/gu_mik.PNG',
      'assets/images/astrology/earth-lords(flag).PNG',
      'assets/images/astrology/Naga-major.webp',
      'assets/images/astrology/torma.PNG',
      'assets/images/astrology/IMG_1807.PNG',
      'assets/images/astrology/Hair_cut.PNG',
      'assets/images/astrology/IMG_1851.PNG',
      // Auspicious day images (frequently visited)
      'assets/images/Auspicious_days/fullmoon.PNG',
      'assets/images/Auspicious_days/newmoon.PNG',
      'assets/images/Auspicious_days/dakini.PNG',
      'assets/images/Auspicious_days/medicinebuddha.PNG',
      'assets/images/Auspicious_days/dharmaprotector.PNG',
    ];

    // Precache all in parallel (non-blocking)
    Future.wait(
      criticalImages.map((path) =>
        precacheImage(AssetImage(path), context).catchError((_) {}),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final themeMode = ref.watch(themeNotifierProvider);

    // Schedule image precaching after first frame
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _precacheImages(context);
    });

    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Nyingma Calendar',
      theme: AppTheme.lightTheme(),
      darkTheme: AppTheme.darkTheme(),
      themeMode: themeMode,
      home: const HomeShell(),
    );
  }
}
