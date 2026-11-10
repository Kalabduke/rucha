import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:webview_flutter/webview_flutter.dart';
import 'package:webview_flutter_android/webview_flutter_android.dart';

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
    return MaterialApp(
      title: 'RUCHA',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        brightness: Brightness.dark,
        scaffoldBackgroundColor: const Color(0xFF0C1017),
        colorScheme: const ColorScheme.dark(
          primary: Color(0xFF0E8A6A),
          surface: Color(0xFF151B26),
        ),
      ),
      home: const RuchaWebViewScreen(),
    );
  }
}

class RuchaWebViewScreen extends StatefulWidget {
  const RuchaWebViewScreen({super.key});

  @override
  State<RuchaWebViewScreen> createState() => _RuchaWebViewScreenState();
}

class _RuchaWebViewScreenState extends State<RuchaWebViewScreen> {
  late final WebViewController _controller;
  bool _isLoading = true;
  double _loadingProgress = 0.0;
  bool _hasError = false;

  static const String liveAppUrl = 'https://ruchaa.ethiodeploy.app';
  static const String offlineAssetPath = 'assets/www/index.html';

  @override
  void initState() {
    super.initState();
    _initWebView();
  }

  void _initWebView() {
    late final PlatformWebViewControllerCreationParams params;
    if (WebViewPlatform.instance is AndroidWebViewPlatform) {
      params = AndroidWebViewControllerCreationParams();
    } else {
      params = const PlatformWebViewControllerCreationParams();
    }

    final WebViewController controller =
        WebViewController.fromPlatformCreationParams(params);

    controller
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setBackgroundColor(const Color(0xFF0C1017))
      ..setNavigationDelegate(
        NavigationDelegate(
          onProgress: (int progress) {
            if (mounted) {
              setState(() {
                _loadingProgress = progress / 100.0;
              });
            }
          },
          onPageStarted: (String url) {
            if (mounted) {
              setState(() {
                _isLoading = true;
                _hasError = false;
              });
            }
          },
          onPageFinished: (String url) {
            if (mounted) {
              setState(() {
                _isLoading = false;
              });
            }
          },
          onWebResourceError: (WebResourceError error) {
            // If offline, load bundled local asset
            if (mounted && error.isForMainFrame == true) {
              _loadOfflineFallback();
            }
          },
        ),
      );

    // Android-specific configuration for hardware-accelerated canvas and Geolocation
    if (controller.platform is AndroidWebViewController) {
      final androidController = controller.platform as AndroidWebViewController;
      androidController.setGeolocationPermissionsPromptCallbacks(
        onShowPrompt: (request) async {
          return const GeolocationPermissionsResponse(
            allow: true,
            retain: true,
          );
        },
      );
    }

    _controller = controller;
    _loadApp();
  }

  Future<void> _loadApp() async {
    try {
      await _controller.loadRequest(Uri.parse(liveAppUrl));
    } catch (_) {
      _loadOfflineFallback();
    }
  }

  Future<void> _loadOfflineFallback() async {
    if (mounted) {
      setState(() {
        _hasError = false;
      });
    }
    try {
      await _controller.loadFlutterAsset(offlineAssetPath);
    } catch (_) {
      if (mounted) {
        setState(() => _hasError = true);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) async {
        if (didPop) return;
        if (await _controller.canGoBack()) {
          await _controller.goBack();
        } else {
          SystemNavigator.pop();
        }
      },
      child: Scaffold(
        backgroundColor: const Color(0xFF0C1017),
        body: SafeArea(
          bottom: false,
          child: Stack(
            children: [
              WebViewWidget(controller: _controller),
              if (_isLoading)
                LinearProgressIndicator(
                  value: _loadingProgress > 0 ? _loadingProgress : null,
                  backgroundColor: const Color(0xFF151B26),
                  color: const Color(0xFF0E8A6A),
                  minHeight: 2.5,
                ),
              if (_hasError)
                Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24.0),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.cloud_off, size: 56, color: Color(0xFFE8A700)),
                        const SizedBox(height: 16),
                        const Text(
                          'Could not connect',
                          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white),
                        ),
                        const SizedBox(height: 8),
                        const Text(
                          'Check your connection or tap below to load offline mode.',
                          textAlign: TextAlign.center,
                          style: TextStyle(color: Color(0xFF94A3B8), fontSize: 13),
                        ),
                        const SizedBox(height: 20),
                        ElevatedButton.icon(
                          onPressed: _loadOfflineFallback,
                          icon: const Icon(Icons.refresh),
                          label: const Text('Load Offline RUCHA'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF0E8A6A),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
