/// Pure stall detection and recovery escalation logic.
///
/// Fed one sample per second by `VideoPlaybackController`, it decides *that*
/// playback has frozen and *what* should be done about it. Holds no plugin or
/// Flutter references so the whole escalation ladder is unit testable.
library;

/// The recovery step a stalled player should take next.
enum StallRecoveryAction {
  /// Not stalled, or still inside the grace period. Do nothing.
  none,

  /// Just wait — a short dip is absorbed by the read-ahead buffer.
  wait,

  /// Re-seek to the last known good position to force a fresh segment window.
  seek,

  /// Step down one rendition.
  downgradeQuality,

  /// Tear the player down and reopen the media at the last good position.
  reload,

  /// Nothing left to try; surface the error UI.
  failed,
}

class StallDetector {
  StallDetector({
    this.seekAfter = const Duration(seconds: 10),
    this.downgradeAfter = const Duration(seconds: 20),
    this.reloadAfter = const Duration(seconds: 35),
    this.failureAfter = const Duration(seconds: 60),
    this.stallWindow = const Duration(minutes: 5),
    this.autoDowngradeStalls = 2,
    int frozenTicksBeforeStall = 2,
    DateTime Function()? clock,
  }) : frozenTicksBeforeStall = frozenTicksBeforeStall < 1
           ? 1
           : frozenTicksBeforeStall,
       _clock = clock ?? DateTime.now;

  final Duration seekAfter;
  final Duration downgradeAfter;
  final Duration reloadAfter;
  final Duration failureAfter;
  final Duration stallWindow;

  /// Stalls within [stallWindow] that trigger a proactive downgrade.
  final int autoDowngradeStalls;

  /// Consecutive frozen samples required before declaring a stall. A single
  /// tick of no movement is ordinary scheduling jitter, not a freeze.
  final int frozenTicksBeforeStall;

  final DateTime Function() _clock;

  bool _isStalled = false;
  bool _hasLastPosition = false;
  bool _lastWasPlaying = false;
  bool _lastWasBuffering = false;
  Duration _lastPosition = Duration.zero;
  Duration _stallPosition = Duration.zero;
  DateTime? _stallStart;
  StallRecoveryAction _lastActionTaken = StallRecoveryAction.none;
  int _frozenTicks = 0;
  int _stallCount = 0;
  final List<DateTime> _stallStarts = [];

  bool get isStalled => _isStalled;

  /// How long the current stall has lasted; zero when not stalled.
  Duration get stalledFor {
    final start = _stallStart;
    if (!_isStalled || start == null) return Duration.zero;
    return _clock().difference(start);
  }

  /// The last position known to have played, used to resume without rewinding
  /// the student.
  Duration get stallPosition => _stallPosition;

  /// Total stalls seen since construction.
  int get stallCount => _stallCount;

  /// Whether the most recent sample reported the player as buffering. Kept for
  /// diagnostics: it distinguishes a network underrun from a wedged decoder.
  bool get lastWasBuffering => _lastWasBuffering;

  /// Whether the most recent sample reported the player as playing.
  bool get lastWasPlaying => _lastWasPlaying;

  /// Stalls whose start time falls inside [stallWindow]. Drives the proactive
  /// downgrade so a link that is merely marginal degrades before it freezes.
  int get stallsInWindow {
    _pruneStallStarts();
    return _stallStarts.length;
  }

  /// True once a link has proven marginal and auto mode should step down.
  bool get shouldProactivelyDowngrade => stallsInWindow >= autoDowngradeStalls;

  /// The action to take for the current stall.
  StallRecoveryAction get action {
    if (!_isStalled) return StallRecoveryAction.none;
    final elapsed = stalledFor;
    final action = elapsed >= failureAfter
        ? StallRecoveryAction.failed
        : elapsed >= reloadAfter
        ? StallRecoveryAction.reload
        : elapsed >= downgradeAfter
        ? StallRecoveryAction.downgradeQuality
        : elapsed >= seekAfter
        ? StallRecoveryAction.seek
        : StallRecoveryAction.wait;
    // Never repeat an action for the same stall: re-seeking every second would
    // pin the player at the frozen frame and prevent it from ever recovering.
    if (action != StallRecoveryAction.none && action == _lastActionTaken) {
      return StallRecoveryAction.wait;
    }
    return action;
  }

  /// Records that the caller performed [action], so it is not repeated.
  void markActionTaken(StallRecoveryAction action) {
    _lastActionTaken = action;
  }

  /// Feeds one observation of the player.
  ///
  /// [isPlaying] should reflect *intent* to be playing, not just the platform
  /// flag: a player that reports not-playing mid-rebuffer is still stalled from
  /// the student's point of view.
  void sample({
    required Duration position,
    required bool isBuffering,
    required bool isPlaying,
  }) {
    final now = _clock();
    _lastWasBuffering = isBuffering;

    if (!isPlaying) {
      // Paused, or the session expired. Any in-flight stall is over.
      _clearStall();
      _frozenTicks = 0;
      _record(position, isPlaying);
      return;
    }

    final advanced = _hasLastPosition && position > _lastPosition;

    if (advanced) {
      _clearStall();
      _frozenTicks = 0;
      _stallPosition = position;
    } else {
      _frozenTicks++;
      // A single frozen tick is scheduling jitter, not a freeze.
      if (_frozenTicks >= frozenTicksBeforeStall) _beginStall(position, now);
    }

    _record(position, isPlaying);
  }

  /// Clears all state, e.g. when the media is reloaded.
  void reset() {
    _clearStall();
    _hasLastPosition = false;
    _lastPosition = Duration.zero;
    _stallPosition = Duration.zero;
    _frozenTicks = 0;
    _lastActionTaken = StallRecoveryAction.none;
    _stallCount = 0;
    _stallStarts.clear();
  }

  void _beginStall(Duration position, DateTime now) {
    if (_isStalled) return;
    _isStalled = true;
    _stallStart = now;
    // Resume from the last position that actually played, so recovery never
    // rewinds the student.
    _stallPosition = _hasLastPosition && _lastPosition > Duration.zero
        ? _lastPosition
        : position;
    _stallCount++;
    _stallStarts.add(now);
    _pruneStallStarts();
    _lastActionTaken = StallRecoveryAction.none;
  }

  void _clearStall() {
    if (!_isStalled) return;
    _isStalled = false;
    _stallStart = null;
    _frozenTicks = 0;
    _lastActionTaken = StallRecoveryAction.none;
  }

  void _record(Duration position, bool isPlaying) {
    _hasLastPosition = true;
    _lastPosition = position;
    _lastWasPlaying = isPlaying;
  }

  void _pruneStallStarts() {
    final cutoff = _clock().subtract(stallWindow);
    _stallStarts.removeWhere((t) => t.isBefore(cutoff));
  }
}
