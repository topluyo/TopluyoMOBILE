import 'package:flutter/material.dart';

import 'screens/webview_screen.dart';
import 'services/foreground_service.dart';

/// Topluyo Mobile App entry point.
///
/// Initializes the foreground task service and sets up global error handling
/// that reports errors to the frontend via Route.api (channel 33591).
void main() {
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize foreground service configuration
  ForegroundServiceManager.initialize();

  // Global Flutter error handler — reports to frontend when WebView is available
  FlutterError.onError = (FlutterErrorDetails details) {
    debugPrint('[Topluyo] Flutter error: ${details.exceptionAsString()}');
    // Error will be reported to frontend via JS when WebView is ready.
    // Store error for deferred reporting if WebView isn't loaded yet.
    pendingErrors.add(
      '[Flutter] ${details.exceptionAsString()}\n${details.stack?.toString().split('\n').take(5).join('\\n') ?? ''}',
    );
  };

  runApp(const TopluyoApp());
}

/// Stores Flutter errors that occurred before the WebView was ready.
/// These get reported once the WebView loads and JS is injected.
final List<String> pendingErrors = [];

/// Root application widget.
class TopluyoApp extends StatelessWidget {
  const TopluyoApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Topluyo',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.blue),
        useMaterial3: true,
      ),
      home: const WebViewScreen(),
    );
  }
}
