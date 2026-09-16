class SessionTracker {
  SessionTracker({
    required this.maxSessionDurationSeconds,
    required this.maxPauseSeconds,
    DateTime Function()? clock,
  }) : _clock = clock ?? DateTime.now;

  static const String pauseExpiredMessage =
      'تم تجاوز مدة الإيقاف المؤقت (30 دقيقة)';
  static const String sessionExpiredMessage = 'انتهت مدة الجلسة (3 ساعات)';

  final int maxSessionDurationSeconds;
  final int maxPauseSeconds;
  final DateTime Function() _clock;

  int accumulatedSeconds = 0;
  int viewDurationSeconds = 0;
  bool expired = false;
  String? expiryReason;

  bool _isPlaying = false;
  DateTime? _sessionStart;
  DateTime? _watchSessionStart;
  DateTime? _pauseStart;

  bool get isPlaying => _isPlaying;

  void onPlay() {
    if (expired) return;
    if (_isPlaying) return;
    _isPlaying = true;
    _watchSessionStart ??= _clock();
    _sessionStart ??= _clock();
    _pauseStart = null;
  }

  void onPause() {
    if (expired) return;
    if (!_isPlaying) return;
    _pauseStart ??= _clock();
    _isPlaying = false;
    _accumulate();
  }

  void onBackground() {
    if (expired) return;
    if (!_isPlaying) return;
    _isPlaying = false;
    _accumulate();
  }

  bool tick() {
    if (expired) return false;
    final now = _clock();

    if (_pauseStart != null && !_isPlaying) {
      final pauseSeconds = now.difference(_pauseStart!).inSeconds;
      if (pauseSeconds >= maxPauseSeconds) {
        expire(pauseExpiredMessage);
        return true;
      }
    }

    if (_watchSessionStart != null) {
      final sessionSeconds = now.difference(_watchSessionStart!).inSeconds;
      if (sessionSeconds >= maxSessionDurationSeconds) {
        expire(sessionExpiredMessage);
        return true;
      }
    }

    final activeSeconds = (_sessionStart != null && _isPlaying)
        ? now.difference(_sessionStart!).inSeconds
        : 0;
    viewDurationSeconds = accumulatedSeconds + activeSeconds;
    return false;
  }

  void expire(String reason) {
    if (expired) return;
    expired = true;
    expiryReason = reason;
    _isPlaying = false;
    _accumulate();
    if (accumulatedSeconds > maxSessionDurationSeconds) {
      accumulatedSeconds = maxSessionDurationSeconds;
    }
    viewDurationSeconds = accumulatedSeconds;
  }

  void onClose() {
    if (expired) return;
    _accumulate();
  }

  void _accumulate() {
    if (_sessionStart == null) return;
    accumulatedSeconds += _clock().difference(_sessionStart!).inSeconds;
    _sessionStart = null;
    viewDurationSeconds = accumulatedSeconds;
  }
}