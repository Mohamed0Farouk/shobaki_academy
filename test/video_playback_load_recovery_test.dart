import 'package:flutter_test/flutter_test.dart';
import 'package:shobaki_academy/controller/bunny_webview_player_adapter.dart';
import 'package:shobaki_academy/controller/video_playback_controller.dart';

void main() {
  group('isFatalBunnyResourceError', () {
    test('a confirmed main-frame failure is fatal', () {
      expect(
        isFatalBunnyResourceError(isForMainFrame: true, errorCode: -2),
        isTrue,
      );
      expect(
        isFatalBunnyResourceError(isForMainFrame: true, errorCode: -1001),
        isTrue,
      );
    });

    test('subresource noise is never fatal', () {
      expect(
        isFatalBunnyResourceError(isForMainFrame: false, errorCode: -2),
        isFalse,
      );
    });

    test('unknown frame attribution (WebKit null) is not fatal', () {
      // The old behavior treated the null the same as a confirmed main-frame
      // failure and burned attempt after attempt while the embed ran fine.
      expect(
        isFatalBunnyResourceError(isForMainFrame: null, errorCode: -2),
        isFalse,
      );
    });

    test('a cancelled-by-navigation load (-999) is not fatal', () {
      // WKWebView reports -999 when a new navigation replaces an in-flight
      // one; the new document is exactly what the player is waiting for, so
      // this must never dead-end into the error path.
      expect(
        isFatalBunnyResourceError(isForMainFrame: true, errorCode: -999),
        isFalse,
      );
      expect(
        isFatalBunnyResourceError(isForMainFrame: null, errorCode: -999),
        isFalse,
      );
    });
  });

  group('loadTimeoutForAttempt', () {
    test('webview boot platforms use the slow ladder', () {
      expect(
        loadTimeoutForAttempt(attempt: 0, webViewBootPlatform: true),
        const Duration(seconds: 10),
      );
      expect(
        loadTimeoutForAttempt(attempt: 1, webViewBootPlatform: true),
        const Duration(seconds: 15),
      );
      expect(
        loadTimeoutForAttempt(attempt: 2, webViewBootPlatform: true),
        const Duration(seconds: 25),
      );
    });

    test('desktop platforms keep the fast ladder', () {
      expect(
        loadTimeoutForAttempt(attempt: 0, webViewBootPlatform: false),
        const Duration(seconds: 3),
      );
      expect(
        loadTimeoutForAttempt(attempt: 2, webViewBootPlatform: false),
        const Duration(seconds: 6),
      );
    });

    test('attempts past the last rung clamp to the largest budget', () {
      expect(
        loadTimeoutForAttempt(attempt: 99, webViewBootPlatform: true),
        const Duration(seconds: 25),
      );
      expect(
        loadTimeoutForAttempt(attempt: 99, webViewBootPlatform: false),
        const Duration(seconds: 6),
      );
    });
  });
}
