import 'dart:convert';
import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_foreground_task/flutter_foreground_task.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import 'package:app_links/app_links.dart';
import 'package:device_info_plus/device_info_plus.dart';

import '../main.dart';
import '../services/foreground_service.dart';
import '../services/js_bridge.dart';
import '../utils/permissions.dart';
import 'package:url_launcher/url_launcher.dart';

/// Main WebView screen that loads topluyo.com and manages the voice call lifecycle.
///
/// Responsibilities:
/// - Loads topluyo.com in an InAppWebView
/// - Injects JavaScript for signal interception, error reporting, and compat checks
/// - Listens for Cable WebSocket signal events (connected/disconnected/kicked)
/// - Manages foreground service (start/stop) based on call state
/// - Handles notification button actions (mic toggle, leave call)
/// - Grants microphone and camera permissions to the WebView
class WebViewScreen extends StatefulWidget {
  const WebViewScreen({super.key});

  @override
  State<WebViewScreen> createState() => _WebViewScreenState();
}

class _WebViewScreenState extends State<WebViewScreen> with WidgetsBindingObserver {
  InAppWebViewController? _webViewController;
  bool _micEnabled = true;
  bool _isInCall = false;
  String _initialUrl = 'https://topluyo.com';
  String? _pendingUrl;

  late AppLinks _appLinks;
  StreamSubscription<Uri>? _linkSubscription;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    // Required in v8 to receive data from the foreground task isolate
    FlutterForegroundTask.initCommunicationPort();
    FlutterForegroundTask.addTaskDataCallback(_onReceiveTaskData);
    _initDeepLinks();
  }

  void _initDeepLinks() {
    _appLinks = AppLinks();

    _linkSubscription = _appLinks.uriLinkStream.listen((uri) {
      _handleDeepLink(uri);
    });

    _appLinks.getInitialLink().then((uri) {
      if (uri != null) {
        _handleDeepLink(uri);
      }
    });
  }

  void _handleDeepLink(Uri uri) {
    if (uri.scheme == 'topluyo' || uri.scheme == 'https' || uri.scheme == 'http') {
      if (uri.scheme == 'topluyo' || uri.host == 'topluyo.com') {
        String targetUrl;
        if (uri.scheme == 'topluyo') {
          targetUrl = uri.toString().replaceFirst(RegExp(r'^topluyo:(//)?/*'), 'https://topluyo.com/');
        } else {
          targetUrl = uri.toString();
        }

        if (_webViewController != null) {
          _webViewController?.loadUrl(
            urlRequest: URLRequest(url: WebUri(targetUrl)),
          );
        } else {
          _pendingUrl = targetUrl;
          setState(() {
            _initialUrl = targetUrl;
          });
        }
      }
    }
  }

  void _onReceiveTaskData(dynamic data) {
    if (data is String) {
      _handleNotificationAction(data);
    }
  }

  /// Handle notification button actions from the persistent notification.
  void _handleNotificationAction(String actionId) {
    switch (actionId) {
      case 'toggle_mic':
        _toggleMicrophone();
        break;
      case 'leave_call':
        _leaveCall();
        break;
    }
  }

  /// Toggle microphone state and update both the WebView and notification.
  Future<void> _toggleMicrophone() async {
    final controller = _webViewController;
    if (controller == null) return;

    setState(() {
      _micEnabled = !_micEnabled;
    });

    // Call Topluyo.Microphone(bool) in the frontend
    await controller.evaluateJavascript(
      source: 'Topluyo.Microphone($_micEnabled)',
    );

    // Update notification text
    await ForegroundServiceManager.updateNotification(micEnabled: _micEnabled);
  }

  Future<void> _leaveCall() async {
    final controller = _webViewController;
    
    // Always stop the notification immediately to ensure it closes,
    // regardless of what happens in the WebView.
    setState(() {
      _isInCall = false;
      _micEnabled = true;
    });
    await ForegroundServiceManager.stopService();

    if (controller == null) return;

    try {
      // Tell frontend to leave the call
      await controller.evaluateJavascript(
        source: 'if(typeof Topluyo !== "undefined" && Topluyo.ExitVoiceChannel) { Topluyo.ExitVoiceChannel(); } else { console.warn("Topluyo.ExitVoiceChannel is not defined"); }',
      );
    } catch (e) {
      debugPrint('[Topluyo] Error executing ExitVoiceChannel: $e');
    }
  }

  /// Register JavaScript handlers on the WebView controller.
  void _registerJsHandlers(InAppWebViewController controller) {
    // Foreground Service Controller
    controller.addJavaScriptHandler(
      handlerName: 'EnableInBackgroundMicrophone',
      callback: (args) {
        if (args.isEmpty) return;
        final enable = args[0] as bool;
        if (enable) {
          _startPersistentNotification();
        } else {
          _stopPersistentNotification();
        }
      },
    );

    // Compatibility check handler
    controller.addJavaScriptHandler(
      handlerName: 'onCompatCheck',
      callback: (args) {
        if (args.isEmpty) return;
        try {
          final info = jsonDecode(args[0] as String) as Map<String, dynamic>;
          final supported = info['supported'] as Map<String, dynamic>?;
          if (supported != null) {
            debugPrint('[Topluyo] Compat: platform=${info['platform']}, '
                'version=${info['version']}, '
                'foregroundService=${supported['foregroundService']}, '
                'mic=${supported['microphone']}, '
                'camera=${supported['camera']}');
          }
        } catch (e) {
          debugPrint('[Topluyo] Compat parse error: $e');
        }
      },
    );
  }

  /// Start the persistent notification
  Future<void> _startPersistentNotification() async {
    if (_isInCall) return;

    setState(() {
      _isInCall = true;
      _micEnabled = true;
    });

    await ForegroundServiceManager.startService(micEnabled: _micEnabled);
    debugPrint('[Topluyo] Foreground service activated by frontend.');
  }

  /// Stop the persistent notification
  Future<void> _stopPersistentNotification() async {
    if (!_isInCall) return;

    setState(() {
      _isInCall = false;
      _micEnabled = true;
    });

    await ForegroundServiceManager.stopService();
    debugPrint('[Topluyo] Foreground service deactivated by frontend.');
  }

  /// Report a native error to the frontend via JS injection.
  Future<void> _reportNativeError(String message) async {
    final controller = _webViewController;
    if (controller == null) return;

    try {
      String osInfo = Platform.operatingSystem;
      try {
        final deviceInfo = DeviceInfoPlugin();
        if (Platform.isAndroid) {
          final androidInfo = await deviceInfo.androidInfo;
          osInfo = 'Android ${androidInfo.version.release} (SDK ${androidInfo.version.sdkInt})';
        } else if (Platform.isIOS) {
          final iosInfo = await deviceInfo.iosInfo;
          osInfo = 'iOS ${iosInfo.systemVersion}';
        }
      } catch (_) {}

      final detailedMessage = '[$osInfo] $message';
      await JsBridge.reportNativeError(controller, detailedMessage);
    } catch (_) {
      // WebView might not be ready yet
    }
  }

  /// Flushes any pending Flutter errors that occurred before the WebView was ready
  Future<void> _flushPendingErrors() async {
    if (pendingErrors.isEmpty) return;
    
    // Copy and clear to prevent concurrent modification
    final errorsToReport = List<String>.from(pendingErrors);
    pendingErrors.clear();

    for (final err in errorsToReport) {
      await _reportNativeError(err);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: InAppWebView(
            initialUrlRequest: URLRequest(
              url: WebUri(_initialUrl),
            ),
            initialSettings: InAppWebViewSettings(
              useShouldOverrideUrlLoading: true,
              // JavaScript & media
              javaScriptEnabled: true,
              mediaPlaybackRequiresUserGesture: false,

              // iOS-specific WebView settings
              allowsInlineMediaPlayback: true,
              allowsAirPlayForMediaPlayback: true,
              sharedCookiesEnabled: true, // Fix iOS session drops

              // Performance & compatibility
              hardwareAcceleration: true,
              useHybridComposition: false,
              domStorageEnabled: true,
              databaseEnabled: true,
              cacheEnabled: true,
              thirdPartyCookiesEnabled: true, // Fix Android session drops
              supportZoom: false,
              verticalScrollBarEnabled: false,
              horizontalScrollBarEnabled: false,
              preferredContentMode: UserPreferredContentMode.MOBILE,

              // Mixed content (for WebSocket connections)
              mixedContentMode: MixedContentMode.MIXED_CONTENT_ALWAYS_ALLOW,

              // Custom User Agent to bypass Google's "disallowed_useragent" error
              userAgent: 'Mozilla/5.0 (Linux; Android 13; SM-G998B) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/119.0.0.0 Mobile Safari/537.36',
              // User agent suffix to identify mobile app
              applicationNameForUserAgent: 'Topluyo-Mobile/1.0',
            ),
            onWebViewCreated: (controller) {
              _webViewController = controller;
              _registerJsHandlers(controller);
              if (_pendingUrl != null) {
                controller.loadUrl(
                  urlRequest: URLRequest(url: WebUri(_pendingUrl!)),
                );
                _pendingUrl = null;
              }
            },
            onLoadStop: (controller, url) async {
              // Force cookie flush on page load
              try {
                await CookieManager.instance().flush();
              } catch (_) {}
              // Inject all JS blocks after page load
              await JsBridge.injectAll(controller);
              debugPrint('[Topluyo] JS injected on: $url');
              // Report any errors that happened before load
              await _flushPendingErrors();
            },
            onUpdateVisitedHistory: (controller, url, isReload) async {
              // Force cookie flush when client-side router changes URL
              try {
                await CookieManager.instance().flush();
              } catch (_) {}
            },
            onPermissionRequest: (controller, request) async {
              // Request native permissions when the site requests them (e.g., when iframe connects to WebRTC)
              await PermissionManager.requestCallPermissions();
              
              return PermissionResponse(
                resources: request.resources,
                action: PermissionResponseAction.GRANT,
              );
            },
            onConsoleMessage: (controller, consoleMessage) {
              debugPrint('[WebView Console] ${consoleMessage.message}');
            },
            onReceivedError: (controller, request, error) {
              debugPrint('[WebView Error] ${error.description} on ${request.url}');
              if (request.isForMainFrame ?? false) {
                _reportNativeError(
                  'WebView load error [${error.type}]: ${error.description} on ${request.url}',
                );
              }
            },
            shouldOverrideUrlLoading: (controller, navigationAction) async {
              final uri = navigationAction.request.url;
              if (uri != null) {
                final host = uri.host;
                
                // Allow OAuth and login domains to load inside the WebView
                final isOAuthDomain = host.contains('google.com') || 
                                      host.contains('google.co') || // e.g. google.com.tr
                                      host.contains('youtube.com') || // Google auth redirects to accounts.youtube.com
                                      host.contains('kick.com') ||
                                      host.contains('discord.com') ||
                                      host.contains('twitter.com') ||
                                      host.contains('apple.com');

                if (!host.contains('topluyo.com') && host.isNotEmpty && !isOAuthDomain) {
                  if (await canLaunchUrl(uri)) {
                    await launchUrl(uri, mode: LaunchMode.externalApplication);
                    return NavigationActionPolicy.CANCEL;
                  }
                }
              }
              return NavigationActionPolicy.ALLOW;
            },
          ),
        ),
    );
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused || 
        state == AppLifecycleState.inactive || 
        state == AppLifecycleState.hidden || 
        state == AppLifecycleState.detached) {
      // Force write cookies to disk when app goes to background
      try {
        CookieManager.instance().flush();
      } catch (e) {
        debugPrint('[Topluyo] Error flushing cookies: $e');
      }
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _linkSubscription?.cancel();
    FlutterForegroundTask.removeTaskDataCallback(_onReceiveTaskData);
    // Ensure foreground service is stopped when the screen is disposed
    if (_isInCall) {
      ForegroundServiceManager.stopService();
    }
    super.dispose();
  }
}
