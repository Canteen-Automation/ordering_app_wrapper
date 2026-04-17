import 'package:flutter/material.dart';
import 'package:webview_flutter/webview_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';
import 'dart:ui';
import 'dart:io';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Android Project Portal',
      theme: ThemeData(
        brightness: Brightness.light,
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.blue),
        useMaterial3: true,
      ),
      darkTheme: ThemeData(
        brightness: Brightness.dark,
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.blue, brightness: Brightness.dark),
        useMaterial3: true,
      ),
      themeMode: ThemeMode.system,
      debugShowCheckedModeBanner: false,
      home: const ProjectPortal(),
    );
  }
}

class ProjectPortal extends StatefulWidget {
  const ProjectPortal({super.key});

  @override
  State<ProjectPortal> createState() => _ProjectPortalState();
}

class _ProjectPortalState extends State<ProjectPortal> {
  WebViewController? _controller;
  final _urlController = TextEditingController();
  bool _isInitialized = false;
  String _currentUrl = 'http://10.0.2.2:3000'; 
  bool _isLoading = false;
  bool _showSettings = false;

  @override
  void initState() {
    super.initState();
    if (Platform.isAndroid || Platform.isIOS) {
      _initWebView();
    }
  }

  Future<void> _initWebView() async {
    final prefs = await SharedPreferences.getInstance();
    _currentUrl = prefs.getString('saved_url') ?? 'http://10.0.2.2:3000';
    _urlController.text = _currentUrl;

    final controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setNavigationDelegate(
        NavigationDelegate(
          onPageStarted: (url) => setState(() => _isLoading = true),
          onPageFinished: (url) => setState(() => _isLoading = false),
          onWebResourceError: (error) => debugPrint(error.description),
        ),
      )
      ..loadRequest(Uri.parse(_currentUrl));

    setState(() {
      _controller = controller;
      _isInitialized = true;
    });
  }

  Future<void> _saveAndLoadUrl() async {
    String url = _urlController.text.trim();
    if (url.isEmpty) return;
    if (!url.startsWith('http')) url = 'http://$url';

    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('saved_url', url);
    setState(() {
      _currentUrl = url;
      _showSettings = false;
    });
    _controller?.loadRequest(Uri.parse(url));
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    
    // Check if we are on a supported platform
    if (!Platform.isAndroid && !Platform.isIOS) {
      return Scaffold(
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(20.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.warning_amber_rounded, size: 60, color: Colors.orange),
                const SizedBox(height: 20),
                const Text(
                  'Wrong Platform Detected',
                  style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 10),
                const Text(
                  'This "android_wrapper" is exclusively for Android/iOS.\n\nPlease use "webview_explorer" for Windows Desktop.',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Colors.grey),
                ),
                const SizedBox(height: 30),
                ElevatedButton(
                  onPressed: () => exit(0),
                  child: const Text('Close App'),
                ),
              ],
            ),
          ),
        ),
      );
    }

    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        child: Stack(
          children: [
            if (_isInitialized && _controller != null)
              RefreshIndicator(
                onRefresh: () async {
                  await _controller?.reload();
                },
                child: Stack(
                  children: [
                    WebViewWidget(
                      controller: _controller!,
                      gestureRecognizers: {
                        Factory<VerticalDragGestureRecognizer>(
                          () => VerticalDragGestureRecognizer(),
                        ),
                      },
                    ),
                    // Invisible scrollable overlay to ensure RefreshIndicator triggers
                    SingleChildScrollView(
                      physics: const AlwaysScrollableScrollPhysics(),
                      child: Container(
                        height: 0.1, // Near-zero height
                        color: Colors.transparent,
                      ),
                    ),
                  ],
                ),
              )
            else
              const Center(child: CircularProgressIndicator()),

            // URL Pill
            Positioned(
              top: 10,
              left: 0,
              right: 0,
              child: Center(
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  decoration: BoxDecoration(
                    color: theme.colorScheme.surface.withOpacity(0.85),
                    borderRadius: BorderRadius.circular(20),
                    boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.2), blurRadius: 8)],
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (_isLoading)
                        const Padding(
                          padding: EdgeInsets.only(right: 8),
                          child: SizedBox(width: 12, height: 12, child: CircularProgressIndicator(strokeWidth: 2)),
                        ),
                      Text(
                        _currentUrl.replaceFirst('http://', '').replaceFirst('https://', ''),
                        style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(width: 10),
                      IconButton(
                        constraints: const BoxConstraints(),
                        padding: EdgeInsets.zero,
                        icon: const Icon(Icons.refresh, size: 18),
                        onPressed: () => _controller?.reload(),
                      ),
                    ],
                  ),
                ),
              ),
            ),

            // Edge Toggle
            AnimatedPositioned(
              duration: const Duration(milliseconds: 300),
              right: _showSettings ? 300 : -5,
              top: MediaQuery.of(context).size.height / 2 - 40,
              child: GestureDetector(
                onTap: () => setState(() => _showSettings = !_showSettings),
                child: Container(
                  width: 35,
                  height: 70,
                  decoration: BoxDecoration(
                    color: theme.colorScheme.primary.withOpacity(0.9),
                    borderRadius: const BorderRadius.horizontal(left: Radius.circular(20)),
                  ),
                  child: Icon(_showSettings ? Icons.chevron_right : Icons.chevron_left, color: Colors.white, size: 24),
                ),
              ),
            ),

            // Settings Panel
            AnimatedPositioned(
              duration: const Duration(milliseconds: 400),
              curve: Curves.easeOutQuart,
              right: _showSettings ? 15 : -320,
              top: 100,
              bottom: 100,
              width: 280,
              child: Container(
                decoration: BoxDecoration(
                  color: theme.colorScheme.surface.withOpacity(0.75),
                  borderRadius: BorderRadius.circular(25),
                  boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.3), blurRadius: 25)],
                  border: Border.all(color: Colors.white.withOpacity(0.1)),
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(25),
                  child: BackdropFilter(
                    filter: ImageFilter.blur(sigmaX: 15, sigmaY: 15),
                    child: Padding(
                      padding: const EdgeInsets.all(25),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('Portal Settings', style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
                          const SizedBox(height: 35),
                          const Text('TARGET URL', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, letterSpacing: 1.2)),
                          const SizedBox(height: 12),
                          TextField(
                            controller: _urlController,
                            style: const TextStyle(fontSize: 13),
                            decoration: InputDecoration(
                              filled: true,
                              fillColor: theme.colorScheme.onSurface.withOpacity(0.05),
                              border: OutlineInputBorder(borderRadius: BorderRadius.circular(15), borderSide: BorderSide.none),
                              prefixIcon: const Icon(Icons.link, size: 18),
                            ),
                          ),
                          const SizedBox(height: 25),
                          ElevatedButton(
                            onPressed: _saveAndLoadUrl,
                            child: const Text('Update & Launch'),
                          ),
                          const Spacer(),
                          ListTile(
                            contentPadding: EdgeInsets.zero,
                            leading: const Icon(Icons.cleaning_services_rounded, size: 20),
                            title: const Text('Clear Web Cache', style: TextStyle(fontSize: 14)),
                            onTap: () async {
                              await _controller?.clearCache();
                              if (mounted) setState(() => _showSettings = false);
                            },
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
