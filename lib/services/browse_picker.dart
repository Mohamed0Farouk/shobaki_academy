import 'package:flutter/services.dart';

class BrowserPicker {
  static const MethodChannel _channel = MethodChannel('browser_picker');

  static Future<void> open(String path) async {
    await _channel.invokeMethod('openWithPicker', {'path': path});
  }
}
