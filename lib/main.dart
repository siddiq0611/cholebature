import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'screens/splash_screen.dart';
import 'services/notification_service.dart';
import 'theme/app_theme.dart';

// ── Theme persistence ──────────────────────────────────────────────────────────
// Persisted: reads from SharedPreferences on startup, saves on change.
const _kThemeKey = 'app_theme_mode';

ThemeMode _themeModeFromString(String? s) => switch (s) {
      'light' => ThemeMode.light,
      'dark' => ThemeMode.dark,
      _ => ThemeMode.system,
    };

String _themeModeToString(ThemeMode m) => switch (m) {
      ThemeMode.light => 'light',
      ThemeMode.dark => 'dark',
      _ => 'system',
    };

class ThemeModeNotifier extends StateNotifier<ThemeMode> {
  ThemeModeNotifier(ThemeMode initial) : super(initial);

  Future<void> setTheme(ThemeMode mode) async {
    state = mode;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_kThemeKey, _themeModeToString(mode));
  }

  void cycle() {
    final next = switch (state) {
      ThemeMode.system => ThemeMode.light,
      ThemeMode.light => ThemeMode.dark,
      ThemeMode.dark => ThemeMode.system,
    };
    setTheme(next);
  }
}

final themeModeProvider =
    StateNotifierProvider<ThemeModeNotifier, ThemeMode>(
  (ref) => ThemeModeNotifier(ThemeMode.system), // overridden in main()
);

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);

  // Load persisted theme before app starts
  final prefs = await SharedPreferences.getInstance();
  final savedTheme = _themeModeFromString(prefs.getString(_kThemeKey));

  await NotificationService.init();
  // Only request permissions once — tracked via a flag in SharedPreferences
  final permAsked = prefs.getBool('notif_perm_asked') ?? false;
  if (!permAsked) {
    await NotificationService.requestPermissions();
    await prefs.setBool('notif_perm_asked', true);
  }

  runApp(
    ProviderScope(
      overrides: [
        themeModeProvider.overrideWith(
            (ref) => ThemeModeNotifier(savedTheme)),
      ],
      child: const CholeBatureApp(),
    ),
  );
}

class CholeBatureApp extends ConsumerWidget {
  const CholeBatureApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final themeMode = ref.watch(themeModeProvider);
    return MaterialApp(
      title: 'CholeBature',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light,
      darkTheme: AppTheme.dark,
      themeMode: themeMode,
      home: const SplashScreen(),
    );
  }
}