/// libmdk (FVP) tuning for Windows.
///
/// Extracted from `main()` so the values can be asserted by unit tests; a typo
/// in an option key is silent at runtime because `fvp` forwards every entry to
/// `Player.setProperty` and ignores the result
/// (`fvp/lib/src/video_player_mdk.dart:307`).
library;

/// Options applied to every MDK player instance.
///
/// Values must all be `String`: `fvp` types the map as `Map<String, String>`
/// and passes it straight through to MDK. Every value is an FFmpeg `AVOption`
/// except `buffer.range`, which is MDK's own read-ahead control
/// (`min_ms+max_ms`).
const Map<String, String> kMdkPlayerOptions = {
  // Read-ahead reserve, in milliseconds. MDK's default is a couple of seconds,
  // which is why a momentary dip in bandwidth empties the buffer and freezes a
  // 90-minute lecture. A 120 second reserve is long enough to ride out the
  // kind of jitter students hit on shared home connections, and the buffer is
  // RAM only - nothing is written to disk.
  'buffer.range': '10000+120000',

  // Network timeout, microseconds. 15s is generous for a single HLS segment
  // and stops MDK from waiting indefinitely on a half-open socket.
  'avio.timeout': '15000000',

  // Abort a read that falls below 50 KB/s for 10s. Both are FFmpeg defaults,
  // stated explicitly so the intent survives an FFmpeg upgrade changing them.
  'avio.low_speed_limit': '50000',
  'avio.low_speed_time': '10000000',

  // Resume a dropped connection instead of tearing the media down. MDK's
  // default reconnect backoff climbs to 7s, which the student experiences as
  // the picture sitting dead on the same frame.
  'avio.reconnect_streamed': '1',
  'avio.reconnect_on_network_error': '1',
  'avio.reconnect_on_http_error': '429,500,502,503,504',
  'avio.reconnect_delay_max': '4',

  // Keep going after recoverable demux errors instead of aborting the media.
  'demux.max_errors': '3',
};

/// The options object handed to `fvp.registerWith` on Windows.
Map<String, dynamic> buildWindowsFvpOptions() => {
  'platforms': ['windows'],
  'player': Map<String, String>.from(kMdkPlayerOptions),
};
