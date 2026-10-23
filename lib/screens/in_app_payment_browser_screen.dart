import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:logger/logger.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:webview_flutter/webview_flutter.dart';

/// In-app browser screen for Chapa checkout.
/// Monitors navigation for any URL containing 'receipt' in its path,
/// and automatically returns the user upon detection.
class InAppPaymentBrowserScreen extends StatefulWidget {
  final String checkoutUrl;
  final String? txRef;

  const InAppPaymentBrowserScreen({
    super.key,
    required this.checkoutUrl,
    this.txRef,
  });

  @override
  State<InAppPaymentBrowserScreen> createState() =>
      _InAppPaymentBrowserScreenState();
}

class _InAppPaymentBrowserScreenState extends State<InAppPaymentBrowserScreen> {
  WebViewController? _controller;
  bool _isLoading = true;
  double _progress = 0.0;
  bool _hasReturned = false;
  bool _isWebViewSupported = true;

  @override
  void initState() {
    super.initState();
    _initWebView();
  }

  void _initWebView() {
    // webview_flutter officially supports Android, iOS, macOS
    final isMobileOrMac = !kIsWeb &&
        (Platform.isAndroid || Platform.isIOS || Platform.isMacOS);

    if (!isMobileOrMac) {
      setState(() => _isWebViewSupported = false);
      _launchExternalFallback();
      return;
    }

    try {
      final controller = WebViewController()
        ..setJavaScriptMode(JavaScriptMode.unrestricted)
        ..setBackgroundColor(Colors.white)
        ..setNavigationDelegate(
          NavigationDelegate(
            onProgress: (int progress) {
              if (mounted) {
                setState(() {
                  _progress = progress / 100.0;
                  _isLoading = progress < 100;
                });
              }
            },
            onPageStarted: (String url) {
              if (mounted) {
                setState(() => _isLoading = true);
              }
              _checkForReceiptRedirect(url);
            },
            onPageFinished: (String url) {
              if (mounted) {
                setState(() => _isLoading = false);
              }
              _checkForReceiptRedirect(url);
            },
            onUrlChange: (UrlChange change) {
              if (change.url != null) {
                _checkForReceiptRedirect(change.url!);
              }
            },
            onNavigationRequest: (NavigationRequest request) {
              if (_checkForReceiptRedirect(request.url)) {
                return NavigationDecision.prevent;
              }
              return NavigationDecision.navigate;
            },
            onWebResourceError: (WebResourceError error) {
              Logger().w('WebView Resource Error: ${error.description}');
            },
          ),
        );

      final uri = Uri.tryParse(widget.checkoutUrl);
      if (uri != null) {
        controller.loadRequest(uri);
      }
      _controller = controller;
    } catch (e) {
      Logger().e('Failed to initialize in-app webview: $e');
      setState(() => _isWebViewSupported = false);
      _launchExternalFallback();
    }
  }

  Future<void> _launchExternalFallback() async {
    final uri = Uri.tryParse(widget.checkoutUrl);
    if (uri != null && await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }

  /// Checks if the target URL contains 'receipt' in its path or query.
  /// If detected, automatically returns the user with result = true.
  bool _checkForReceiptRedirect(String url) {
    if (_hasReturned) return true;

    final uri = Uri.tryParse(url);
    final path = (uri?.path ?? '').toLowerCase();
    final fullUrl = url.toLowerCase();

    // Check if the redirection URL contains 'receipt' in its path
    if (path.contains('receipt') ||
        path.contains('/receipt') ||
        fullUrl.contains('/checkout/payment-receipt') ||
        fullUrl.contains('receipt')) {
      Logger().i('🎯 Receipt redirection detected: $url. Automatically returning user.');
      _hasReturned = true;

      // Small delay for UI smoothness before closing
      Future.delayed(const Duration(milliseconds: 300), () {
        if (mounted && Navigator.canPop(context)) {
          Get.back(result: true);
        }
      });
      return true;
    }
    return false;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    if (!_isWebViewSupported) {
      return Scaffold(
        appBar: AppBar(
          title: const Text('Payment Checkout'),
          leading: IconButton(
            icon: const Icon(Icons.arrow_back_rounded),
            onPressed: () => Get.back(result: false),
          ),
        ),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.open_in_browser_rounded,
                    size: 64, color: theme.colorScheme.primary),
                const SizedBox(height: 20),
                const Text(
                  'External Checkout Window Opened',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 10),
                const Text(
                  'Please complete your payment in the browser window, then return here.',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Colors.grey),
                ),
                const SizedBox(height: 24),
                ElevatedButton(
                  onPressed: () => Get.back(result: true),
                  child: const Text('I Have Completed Payment'),
                ),
              ],
            ),
          ),
        ),
      );
    }

    return PopScope(
      canPop: true,
      onPopInvoked: (_) {},
      child: Scaffold(
        appBar: AppBar(
          title: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Complete Payment',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
              if (widget.txRef != null)
                Text(
                  'Ref: ${widget.txRef}',
                  style: const TextStyle(fontSize: 11, color: Colors.grey),
                ),
            ],
          ),
          leading: IconButton(
            icon: const Icon(Icons.close_rounded),
            onPressed: () => Get.back(result: false),
          ),
          actions: [
            IconButton(
              icon: const Icon(Icons.refresh_rounded),
              onPressed: () => _controller?.reload(),
            ),
          ],
        ),
        body: Stack(
          children: [
            if (_controller != null)
              WebViewWidget(controller: _controller!),
            if (_isLoading)
              LinearProgressIndicator(
                value: _progress > 0 ? _progress : null,
                backgroundColor: Colors.transparent,
                valueColor: AlwaysStoppedAnimation<Color>(
                  theme.colorScheme.primary,
                ),
              ),
          ],
        ),
      ),
    );
  }
}
