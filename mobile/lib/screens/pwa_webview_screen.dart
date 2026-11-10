import 'dart:io' show Platform;
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:webview_flutter/webview_flutter.dart';
import 'package:webview_flutter_android/webview_flutter_android.dart';
import '../core/theme.dart';

/// Screen that embeds the PWA web app when running on Android or iOS.
/// On desktop (Fedora Linux, macOS, Windows) or Web, gracefully falls back
/// to launching the live app in the default system browser to prevent
/// missing platform implementation crashes (`WebViewPlatform.instance != null`).
class PwaWebViewScreen extends StatefulWidget {
  const PwaWebViewScreen({super.key});

  @override
  State<PwaWebViewScreen> createState() => _PwaWebViewScreenState();
}

class _PwaWebViewScreenState extends State<PwaWebViewScreen> {
  WebViewController? _controller;
  bool _isLoading = true;
  double _loadingProgress = 0.0;
  bool _hasError = false;

  static const String liveAppUrl = 'https://ruchaa.ethiodeploy.app';
  static const String offlineAssetPath = 'assets/www/index.html';

  bool get _isWebViewSupported {
    if (kIsWeb) return false;
    try {
      return Platform.isAndroid || Platform.isIOS;
    } catch (_) {
      return false;
    }
  }

  @override
  void initState() {
    super.initState();
    if (_isWebViewSupported) {
      _initWebView();
    }
  }

  void _initWebView() {
    try {
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
                setState(() => _loadingProgress = progress / 100.0);
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
                setState(() => _isLoading = false);
              }
            },
            onWebResourceError: (WebResourceError error) {
              if (mounted && error.isForMainFrame == true) {
                _loadOfflineFallback();
              }
            },
            onNavigationRequest: (NavigationRequest request) {
              final url = request.url;
              if (url.startsWith('https://t.me/') ||
                  url.startsWith('tg://') ||
                  url.startsWith('intent:') ||
                  url.startsWith('mailto:') ||
                  url.startsWith('tel:')) {
                launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
                return NavigationDecision.prevent;
              }
              return NavigationDecision.navigate;
            },
          ),
        );

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
    } catch (e) {
      debugPrint('WebView initialization failed: $e');
    }
  }

  Future<void> _loadApp() async {
    try {
      await _controller?.loadRequest(Uri.parse(liveAppUrl));
    } catch (_) {
      _loadOfflineFallback();
    }
  }

  Future<void> _loadOfflineFallback() async {
    if (mounted) {
      setState(() => _hasError = false);
    }
    try {
      await _controller?.loadFlutterAsset(offlineAssetPath);
    } catch (_) {
      if (mounted) {
        setState(() => _hasError = true);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!_isWebViewSupported || _controller == null) {
      return Scaffold(
        appBar: AppBar(
          title: const Text('RUCHA PWA Web Viewer'),
        ),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: RuchaTheme.accentGreen.withOpacity(0.12),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.language, size: 54, color: RuchaTheme.accentGreen),
                ),
                const SizedBox(height: 20),
                const Text(
                  'Live PWA Web Deployment',
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.white),
                ),
                const SizedBox(height: 10),
                const Text(
                  'On Linux Desktop, the native Flutter app runs with 100% of all features, OpenStreetMap, and Ghost of Legends.\n\nTo view or inspect the live PWA web app in your browser:',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: RuchaTheme.textSecondary, fontSize: 13, height: 1.5),
                ),
                const SizedBox(height: 24),
                ElevatedButton.icon(
                  onPressed: () => launchUrl(
                    Uri.parse(liveAppUrl),
                    mode: LaunchMode.externalApplication,
                  ),
                  icon: const Icon(Icons.open_in_browser),
                  label: const Text('Open https://ruchaa.ethiodeploy.app'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: RuchaTheme.accentGreen,
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    }

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) async {
        if (didPop) return;
        if (await _controller!.canGoBack()) {
          await _controller!.goBack();
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
              WebViewWidget(controller: _controller!),
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
