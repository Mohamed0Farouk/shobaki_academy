import 'package:flutter/material.dart';
import 'package:shobaki_academy/services/statics.dart';
import 'package:webview_flutter/webview_flutter.dart';

class WebviewModel extends StatefulWidget {
  final String url;
  const WebviewModel({super.key, required this.url});

  @override
  State<WebviewModel> createState() => _WebviewModelState();
}

class _WebviewModelState extends State<WebviewModel> {
  late final WebViewController controller;
  bool isFirstLoad = true; // Tracks if it's the first page load

  @override
  void initState() {
    super.initState();

    // Initialize the WebViewController
    controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setNavigationDelegate(
        NavigationDelegate(
          onPageFinished: (String url) {
            if (isFirstLoad) {
              // Hide the loading indicator after the first page is loaded
              setState(() {
                isFirstLoad = false;
              });
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
      body: SafeArea(
        child: Stack(
          children: [
            // WebView Widget
            WebViewWidget(controller: controller),

            // Loading Indicator (only on first load)
            if (isFirstLoad) Center(child: loading(context)),
          ],
        ),
      ),
    );
  }
}
