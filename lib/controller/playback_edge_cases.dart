/// Pure decision helpers for the video adapters.
///
/// Extracted so the two subtle rules in `VideoPlayerAdapter` - how much media
/// is buffered ahead, and whether a `completed` event is real - can be tested
/// without a platform binding.
library;

/// A buffered range reported by the platform.
typedef BufferedRange = ({Duration start, Duration end});

/// How much media is available ahead of [position].
///
/// Only ranges that actually contain the playhead count: a playlist routinely
/// reports stale ranges from before a seek, and counting those would report a
/// healthy buffer while the playhead sits in a hole.
Duration computeBufferedAhead(
  Iterable<BufferedRange> ranges,
  Duration position,
) {
  var end = position;
  for (final range in ranges) {
    if (range.start <= position && range.end > end) {
      end = range.end;
    }
  }
  final ahead = end - position;
  return ahead > Duration.zero ? ahead : Duration.zero;
}

/// What to do about a playback backend reporting "completed".
enum CompletionVerdict {
  /// The media really did finish; report it to the app.
  genuineEnd,

  /// The backend stopped mid-lecture; seek back to the last good position and
  /// keep playing.
  resumeFromLastPosition,

  /// A resume is already in flight for this position; do nothing and let it
  /// play out.
  suppress,
}

/// Decides whether a reported end-of-media is real.
///
/// `video_player` reacts to any `completed` event by pausing and seeking to
/// `value.duration` (`video_player.dart:663`), and `fvp` emits `completed` for
/// MDK's `PlaybackState.stopped` (`video_player_mdk.dart:111`) which is also
/// what a network failure settles into. Without this check a mid-lecture
/// disconnect throws the student to the end of a 1.5 hour video.
///
/// [maxPosition] is the furthest point the media actually reached and
/// [lastRecoveryAttemptPosition] the point a previous resume was attempted
/// from (null when no attempt has been made yet). Once a resume has been tried
/// and the playhead still has not moved, there is nothing more to try here and
/// the stall ladder takes over.
CompletionVerdict classifyCompletion({
  required Duration maxPosition,
  required Duration duration,
  required bool recoveryInFlight,
  required Duration? lastRecoveryAttemptPosition,
  Duration slack = const Duration(seconds: 5),
}) {
  if (recoveryInFlight) return CompletionVerdict.suppress;
  // An unknown duration cannot be judged; stay quiet rather than guessing.
  if (duration <= Duration.zero) return CompletionVerdict.suppress;
  if (maxPosition >= duration - slack) return CompletionVerdict.genuineEnd;
  // Null means "never attempted". A zero sentinel would be indistinguishable
  // from "attempted at position 0" and would mark a video that never played as
  // finished.
  if (lastRecoveryAttemptPosition != null &&
      maxPosition <= lastRecoveryAttemptPosition) {
    return CompletionVerdict.genuineEnd;
  }
  return CompletionVerdict.resumeFromLastPosition;
}
