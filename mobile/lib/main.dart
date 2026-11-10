import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'core/theme.dart';
import 'services/api_service.dart';
import 'services/auth_service.dart';
import 'services/tracking_service.dart';
import 'screens/auth_screen.dart';
import 'screens/main_navigation.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();

  // Dark Ethiopian theme system bars
  SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
    statusBarColor: Colors.transparent,
    statusBarIconBrightness: Brightness.light,
    systemNavigationBarColor: Color(0xFF0C1017),
    systemNavigationBarIconBrightness: Brightness.light,
  ));

  runApp(const RuchaApp());
}

class RuchaApp extends StatelessWidget {
  const RuchaApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        Provider<ApiService>(create: (_) => ApiService()),
        ChangeNotifierProvider<AuthService>(create: (_) => AuthService()),
        ChangeNotifierProvider<TrackingService>(create: (_) => TrackingService()),
      ],
      child: MaterialApp(
        title: 'RUCHA - Ethiopian Run & Ride Tracker',
        debugShowCheckedModeBanner: false,
        theme: RuchaTheme.darkTheme,
        // Authentication Gate: Users CANNOT access the app without creating an account and completing their profile!
        home: Consumer<AuthService>(
          builder: (context, auth, _) {
            if (auth.isAuthenticated && (auth.currentUser?.profileComplete ?? false)) {
              return const MainNavigationScreen();
            }
            return const AuthScreen(isGate: true);
          },
        ),
      ),
    );
  }
}
