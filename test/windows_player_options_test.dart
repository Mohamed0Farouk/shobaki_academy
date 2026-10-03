import 'package:flutter_test/flutter_test.dart';
import 'package:shobaki_academy/controller/windows_player_options.dart';

void main() {
  group('kMdkPlayerOptions', () {
    test('every value is a String', () {
      // `fvp` types the player option map as `Map<String, String>` and passes
      // it straight to `Player.setProperty`; an int here would be a runtime
      // type error that never surfaces until the player is built.
      for (final entry in kMdkPlayerOptions.entries) {
        expect(entry.value, isA<String>(), reason: entry.key);
      }
    });

    test('every value is numeric or a numeric list/range', () {
      // FFmpeg accepts a scalar, a comma-separated list (reconnect_on_http_error)
      // or MDK's `min+max` range form (buffer.range). Anything else is a typo
      // that fvp forwards to MDK, which ignores it silently.
      for (final entry in kMdkPlayerOptions.entries) {
        final tokens = entry.value
            .split(RegExp(r'[+,]'))
            .map((t) => t.trim())
            .where((t) => t.isNotEmpty)
            .toList();
        expect(tokens, isNotEmpty, reason: entry.key);
        for (final token in tokens) {
          expect(
            int.tryParse(token),
            isNotNull,
            reason: '${entry.key}="${entry.value}" has a non-numeric token',
          );
        }
      }
    });

    test('read-ahead reserve is 120s', () {
      // The core fix: MDK's default reserve is a couple of seconds, which is
      // why a brief bandwidth dip froze a 90 minute lecture.
      final range = kMdkPlayerOptions['buffer.range'];
      expect(range, isNotNull);

      final parts = range!.split('+');
      expect(parts, hasLength(2));

      final min = int.parse(parts[0]);
      final max = int.parse(parts[1]);
      expect(min, greaterThan(0));
      expect(
        max,
        120000,
        reason: 'max read-ahead must stay at the agreed 120 seconds',
      );
      expect(max, greaterThan(min));
    });

    test('reconnects instead of tearing the media down', () {
      expect(kMdkPlayerOptions['avio.reconnect_streamed'], '1');
      expect(kMdkPlayerOptions['avio.reconnect_on_network_error'], '1');
    });

    test('caps reconnect backoff at 4s', () {
      // MDK's own default climbs to 7s, which the student sees as a dead
      // frame. Capping at 4s means recovery starts sooner.
      expect(int.parse(kMdkPlayerOptions['avio.reconnect_delay_max']!), 4);
    });

    test('network timeouts are stated in microseconds', () {
      // FFmpeg's avio.timeout and avio.low_speed_time are microseconds, not
      // milliseconds. A milliseconds value here would time out 1000x early.
      expect(int.parse(kMdkPlayerOptions['avio.timeout']!), 15000000);
      expect(int.parse(kMdkPlayerOptions['avio.low_speed_time']!), 10000000);
    });

    test('low speed limit is bytes per second', () {
      expect(int.parse(kMdkPlayerOptions['avio.low_speed_limit']!), 50000);
    });

    test('http error codes include the retryable ones', () {
      final codes = kMdkPlayerOptions['avio.reconnect_on_http_error']!
          .split(',')
          .map(int.parse)
          .toSet();
      expect(codes, containsAll([429, 500, 502, 503, 504]));
    });

    test('tolerates recoverable demux errors', () {
      expect(int.parse(kMdkPlayerOptions['demux.max_errors']!), 3);
    });

    test('contains no empty or malformed keys', () {
      for (final key in kMdkPlayerOptions.keys) {
        expect(key.trim(), key, reason: 'key has surrounding whitespace');
        expect(key, isNotEmpty);
        // FFmpeg option names are dotted namespaces with snake_case segments.
        // A bare word, or an underscore where a dot belongs, would be ignored.
        expect(key, matches(RegExp(r'^[a-z0-9]+(\.[a-z0-9_]+)+$')));
      }
    });

    test('does not contain duplicate keys', () {
      // A duplicated map entry is a silent last-one-wins bug.
      final keys = kMdkPlayerOptions.keys.toList();
      expect(keys.toSet().length, keys.length);
    });
  });

  group('buildWindowsFvpOptions', () {
    test('targets Windows only', () {
      // The package already auto-registers on Android and iOS; restricting the
      // explicit registration keeps their libmpv path untouched.
      expect(buildWindowsFvpOptions()['platforms'], ['windows']);
    });

    test('nests the player options under the player key', () {
      expect(buildWindowsFvpOptions()['player'], kMdkPlayerOptions);
    });

    test('returns a copy that callers cannot use to mutate the constant', () {
      final first = buildWindowsFvpOptions();
      (first['player'] as Map<String, String>)['buffer.range'] = 'mutated';
      expect(kMdkPlayerOptions['buffer.range'], isNot('mutated'));
    });

    test('does not override the decoder list', () {
      // fvp ships a tuned Windows decoder chain (MFT/D3D11/DXVA/... FFmpeg).
      // Replacing it to chase a decode-related theory risks breaking playback
      // on machines that need MFT, so the default is left alone.
      expect(buildWindowsFvpOptions().containsKey('video.decoders'), isFalse);
    });

    test('leaves the low latency path off', () {
      // lowLatency trades read-ahead for startup time, the opposite of what a
      // long lecture needs.
      expect(buildWindowsFvpOptions().containsKey('lowLatency'), isFalse);
    });
  });
}
