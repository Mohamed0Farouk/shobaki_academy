/// Suppresses repeated values from a polling/event stream.
///
/// `video_player` notifies its listeners on every position poll (~10Hz) and on
/// every buffered-range update. Forwarding each of those as a stream event
/// makes downstream state-reconciliation logic run 10 times a second for
/// values that have not changed.
library;

class ValueDeduplicator<T> {
  /// Distinguishes "nothing emitted yet" from an emitted null, so that null is
  /// a first-class value rather than being silently swallowed on first use.
  static const Object _unset = Object();

  Object? _last = _unset;

  /// Returns true the first time [value] is seen and again only once it
  /// changes. Records [value] when it returns true.
  bool shouldEmit(T value) {
    if (identical(_last, _unset)) {
      _last = value;
      return true;
    }
    if (_last == value) return false;
    _last = value;
    return true;
  }

  /// Forgets the last value, so the next [shouldEmit] passes unconditionally.
  ///
  /// Required whenever the underlying source is replaced. Without it, a new
  /// media whose reported values happen to match the previous media's - which
  /// is exactly what happens when switching between renditions of the same
  /// lecture, since duration and position are identical - emits nothing at all,
  /// and any load-completion logic driven by those events never runs.
  void reset() => _last = _unset;

  /// Whether anything has been emitted since the last [reset].
  bool get hasValue => !identical(_last, _unset);

  /// The last value seen, or null if nothing has been emitted yet.
  T? get last => hasValue ? _last as T? : null;
}
