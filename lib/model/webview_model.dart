import 'dart:io';
import 'package:flutter/material.dart';

// Mobile + macOS
import 'package:webview_flutter/webview_flutter.dart';

// Windows only
import 'package:webview_windows/webview_windows.dart';

class WebviewModel extends StatefulWidget {
  final String url;
  const WebviewModel({super.key, required this.url});

  @override
  State<WebviewModel> createState() => _WebviewModelState();
}

class _WebviewModelState extends State<WebviewModel> {
  /// Windows controller
  final WebviewController _windowsController = WebviewController();

  /// Mobile & macOS controller
  WebViewController? _mobileController;

  bool _loading = true;

  @override
  void initState() {
    super.initState();

    if (Platform.isWindows) {
      _initWindows();
    } else {
      _initMobile();
    }
  }

  /* ---------------- WINDOWS ---------------- */

  Future<void> _initWindows() async {
    await _windowsController.initialize();
    await _windowsController.loadUrl(widget.url);

    _windowsController.url.listen((_) {
      if (mounted) {
        setState(() => _loading = false);
      }
    });
  }

  /* ------------- MOBILE + macOS ------------ */

  void _initMobile() {
    _mobileController = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setNavigationDelegate(
        NavigationDelegate(
          onPageFinished: (_) {
            if (mounted) {
              setState(() => _loading = false);
            }
          },
        ),
      )
      ..loadRequest(Uri.parse(widget.url));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(),
      body: Stack(
        children: [
          _buildWebView(),
          if (_loading) const Center(child: CircularProgressIndicator()),
        ],
      ),
    );
  }

  Widget _buildWebView() {
    if (Platform.isWindows) {
      return Webview(_windowsController);
    }

    if (_mobileController != null) {
      return WebViewWidget(controller: _mobileController!);
    }

    return const Center(child: Text("Unsupported platform"));
  }
}
