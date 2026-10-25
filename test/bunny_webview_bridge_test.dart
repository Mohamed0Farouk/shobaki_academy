import 'package:flutter_test/flutter_test.dart';
import 'package:shobaki_academy/controller/bunny_webview_player_adapter.dart';

void main() {
  group('asScriptValue / asScriptMap / asScriptBool', () {
    test('passes parsed values through untouched (Windows/iOS shapes)', () {
      expect(asScriptValue(true), true);
      expect(asScriptValue(false), false);
      expect(asScriptValue(null), isNull);
      expect(asScriptValue(<String, dynamic>{'p': 1.5}), {'p': 1.5});
      expect(asScriptValue(42), 42);
    });

    test('decodes the JSON text Android hands back for an object', () {
      // Android's evaluateJavascript returns the captured JSON text, so a
      // JS object arrives as a Dart String.
      final map = asScriptMap('{"p":12.5,"d":60,"playing":true}');
      expect(map, isNotNull);
      expect(map!['p'], 12.5);
      expect(map['d'], 60);
      expect(map['playing'], true);
    });

    test('decodes a double-encoded payload (WebView2 string result)', () {
      // WebView2's ExecuteScript JSON-encodes its result once, so a JS
      // string holding JSON arrives quoted: '"{\"p\":1}"'.
      final map = asScriptMap('"{\\"p\\":1,\\"playing\\":false}"');
      expect(map, isNotNull);
      expect(map!['p'], 1);
      expect(map['playing'], false);
    });

    test('treats JSON null text as no value', () {
      expect(asScriptMap('null'), isNull);
      expect(asScriptValue('null'), isNull);
      expect(asScriptBool('null'), isNull);
    });

    test('returns null for garbage instead of throwing', () {
      expect(asScriptValue('not json at all'), 'not json at all');
      expect(asScriptMap('not json at all'), isNull);
      expect(asScriptBool('not json at all'), isNull);
      expect(asScriptMap(42), isNull);
      expect(asScriptBool(<String, dynamic>{}), isNull);
    });

    test('asScriptBool accepts every encoding of a boolean', () {
      expect(asScriptBool(true), isTrue);
      expect(asScriptBool(false), isFalse);
      expect(asScriptBool('true'), isTrue);
      expect(asScriptBool('false'), isFalse);
      expect(asScriptBool('"true"'), isTrue);
      expect(asScriptBool(1), isTrue);
      expect(asScriptBool(0), isFalse);
      expect(asScriptBool('1'), isTrue);
      expect(asScriptBool('0'), isFalse);
      expect(asScriptBool(null), isNull);
    });
  });

  group('kBridgeScript transport', () {
    test('carries a fallback for the official plugin channel', () {
      // Without this the top document drops every message on Android/iOS/
      // macOS (there is no chrome.webview), the session tracker never sees a
      // play event, and view_duration_seconds stays at 0.
      expect(kBridgeScript, contains('window.BunnyBridge'));
      expect(kBridgeScript, contains('BunnyBridge.postMessage(JSON.stringify(msg))'));
      expect(kBridgeScript, contains('chrome.webview.postMessage'));
    });

    test('forwards child-frame reports over whichever host exists', () {
      // The top document re-posts child-frame messages; on mobile that must
      // go through the channel, not only through chrome.webview.
      expect(kBridgeScript, contains("data.source === 'shobaki'"));
      expect(
        kBridgeScript,
        contains('BunnyBridge.postMessage(JSON.stringify(data))'),
      );
    });

    test('still scans shadow roots and re-attaches after mounts', () {
      expect(kBridgeScript, contains('shadowRoot'));
      expect(kBridgeScript, contains('setInterval(scan, 1000)'));
      expect(kBridgeScript, contains("window.__shobakiBridge"));
    });

    test('throttles timeupdate to once per second', () {
      expect(kBridgeScript, contains('now - lastTimePost < 1000'));
    });
  });

  group('kProbeScript', () {
    test('walks shadow roots for the Media Chrome video', () {
      expect(kProbeScript, contains('shadowRoot'));
      expect(kProbeScript, contains("'video'"));
    });

    test('reports position, duration and playing flag', () {
      expect(kProbeScript, contains('v.currentTime'));
      expect(kProbeScript, contains('isFinite(v.duration)'));
      expect(kProbeScript, contains('!v.paused && !v.ended'));
    });
  });

  group('isAllowedBunnyNavigation', () {
    test('allows the embed host and the CDN the embed may jump to', () {
      expect(
        isAllowedBunnyNavigation(
          'https://player.mediadelivery.net/embed/abc?libraryId=1',
        ),
        isTrue,
      );
      expect(
        isAllowedBunnyNavigation('https://vz-123.b-cdn.net/playlist.m3u8'),
        isTrue,
      );
      expect(isAllowedBunnyNavigation('about:blank'), isTrue);
    });

    test('blocks everything else, including cleartext and look-alikes', () {
      expect(isAllowedBunnyNavigation('https://evil.example.com/'), isFalse);
      expect(isAllowedBunnyNavigation('http://player.mediadelivery.net/'), isFalse);
      expect(
        isAllowedBunnyNavigation('https://player.mediadelivery.net.evil.com/'),
        isFalse,
      );
      expect(isAllowedBunnyNavigation('javascript:alert(1)'), isFalse);
      expect(isAllowedBunnyNavigation(''), isFalse);
    });
  });
}
