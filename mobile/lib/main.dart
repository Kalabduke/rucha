import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'core/theme.dart';
import 'services/api_service.dart';
import 'services/tracking_service.dart';
import 'screens/main_navigation.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const RuchaApp());
}

class RuchaApp extends StatelessWidget {
  const RuchaApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        Provider<ApiService>(create: (_) => ApiService()),
        ChangeNotifierProvider<TrackingService>(create: (_) => TrackingService()),
      ],
      child: MaterialApp(
        title: 'RUCHA',
        debugShowCheckedModeBanner: false,
        theme: RuchaTheme.darkTheme,
        home: const MainNavigationScreen(),
      ),
    );
  }
}
