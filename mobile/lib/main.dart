import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:geolocator/geolocator.dart';
import 'package:provider/provider.dart';

import 'core/constants.dart';
import 'core/theme.dart';
import 'screens/auth_screen.dart';
import 'screens/main_navigation.dart';
import 'services/activity_store.dart';
import 'services/api_service.dart';
import 'services/auth_service.dart';
import 'services/community_store.dart';
import 'services/settings_service.dart';
import 'services/smartwatch_service.dart';
import 'services/tracking_service.dart';
import 'widgets/osm_map_widget.dart';
import 'widgets/rucha_logo.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
    statusBarColor: Colors.transparent,
    statusBarIconBrightness: Brightness.light,
    systemNavigationBarColor: RuchaTheme.background,
    systemNavigationBarIconBrightness: Brightness.light,
  ));

  // ── GPS permission ────────────────────────────────────────────────────────
  // Request at startup so the map already has a fix when Record tab opens.
  try {
    var perm = await Geolocator.checkPermission();
    if (perm == LocationPermission.denied) {
      perm = await Geolocator.requestPermission();
    }
  } catch (_) {}

  // ── Pre-warm map tiles ────────────────────────────────────────────────────
  // Kick off background tile downloads for Addis Ababa at zoom 14 so the
  // Record screen map is never blank on first open, even before GPS fires.
  _prewarmTiles();

  runApp(const RuchaApp());
}

/// Downloads the 9 centre tiles around Addis Ababa at zoom 14 in the background.
/// Each tile is ~20–50 KB; total ~450 KB on first run, cached forever after.
void _prewarmTiles() {
  const lat = RuchaConstants.cities;
  // Addis Ababa tile at z=14: roughly tile (12048, 7804)
  const z = 14;
  const cx = 12048;
  const cy = 7804;
  for (int dx = -1; dx <= 1; dx++) {
    for (int dy = -1; dy <= 1; dy++) {
      OsmTileCache.prefetch(z, cx + dx, cy + dy);
    }
  }
}

class RuchaApp extends StatelessWidget {
  const RuchaApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider<AuthService>(create: (_) => AuthService()),
        ChangeNotifierProvider<ActivityStore>(create: (_) => ActivityStore()),
        ChangeNotifierProvider<CommunityStore>(create: (_) => CommunityStore()),
        ChangeNotifierProvider<SettingsService>(
          create: (_) => SettingsService()..load(),
        ),
        ProxyProvider<AuthService, ApiService>(
          update: (_, auth, previous) {
            final api = previous ?? ApiService();
            api.configure(baseUrl: auth.baseUrl, token: auth.sessionToken);
            return api;
          },
        ),
        ChangeNotifierProvider<SmartwatchService>(
            create: (_) => SmartwatchService()),
        ChangeNotifierProvider<TrackingService>(
            create: (_) => TrackingService()),
      ],
      child: Consumer<SettingsService>(
        builder: (context, settings, _) => MaterialApp(
          title: 'RUCHA - Ethiopian Run & Ride Tracker',
          debugShowCheckedModeBanner: false,
          theme: RuchaTheme.darkTheme,
          locale: Locale(settings.language),
          supportedLocales: const [Locale('en'), Locale('am')],
          localizationsDelegates: const [
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          home: Consumer<AuthService>(
            builder: (context, auth, _) {
              if (!auth.isInitialized) {
                return const _StartupScreen();
              }
              if (auth.canUseApp) {
                return const MainNavigationScreen();
              }
              return const AuthScreen(isGate: true);
            },
          ),
        ),
      ),
    );
  }
}

class _StartupScreen extends StatelessWidget {
  const _StartupScreen();

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            RuchaLogo(size: 72, showText: true, showFlag: true),
            SizedBox(height: 22),
            SizedBox(
              width: 22,
              height: 22,
              child: CircularProgressIndicator(strokeWidth: 2.4),
            ),
          ],
        ),
      ),
    );
  }
}
