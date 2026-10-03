import 'dart:async';
import 'dart:convert';
import 'dart:io' show Platform;
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:http/http.dart' as http;
import 'package:shobaki_academy/services/api.dart';
import 'package:shobaki_academy/services/locale_db.dart';
import 'package:shobaki_academy/services/statics.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:shobaki_academy/controller/player_adapter.dart';
import 'package:shobaki_academy/controller/media_kit_player_adapter.dart';
import 'package:shobaki_academy/controller/auto_quality_governor.dart';
import 'package:shobaki_academy/controller/session_tracker.dart';
import 'package:shobaki_academy/controller/stall_detector.dart';
import 'package:shobaki_academy/controller/video_player_adapter.dart';
import 'package:shobaki_academy/controller/video_quality.dart';
import 'package:shobaki_academy/services/player_messages.dart';

class VideoPlaybackController extends GetxController
    with WidgetsBindingObserver {
  final String videoUrl;
  final int maxSessionDurationSeconds;
  final api = ApiClient();

  static const int defaultMaxSessionSeconds = 10800;
  static const int defaultMaxPauseSeconds = 1800;

  VideoPlaybackController(
    this.videoUrl, {
    this.maxSessionDurationSeconds = defaultMaxSessionSeconds,
  });

  RxBool isLoading = true.obs;
  RxString errorMessage = ''.obs;

  late IPlayerAdapter player;

  late Map<String, dynamic> user;

  // Quality options
  final List<VideoQuality> qualities = [];

  /// Index of the rendition currently loaded. In auto mode this points at a
  /// concrete variant, never at [kAutoQualityIndex].
  final RxInt currentQualityIndex = kAutoQualityIndex.obs;

  /// Whether the app is managing the rendition. When false the student's
  /// choice in [showQualityDialog] is pinned until they pick "تلقائي" again.
  final RxBool autoQuality = true.obs;
  final RxBool qualitiesLoaded = false.obs;
  final RxBool lastPlayIntent = false.obs;

  /// True while playback is frozen on the same frame. Drives the stall overlay
  /// and gates the recovery ladder.
  final RxBool isStalled = false.obs;

  late final StallDetector _stall = StallDetector();

  final RxInt stallCount = 0.obs;

  final RxBool isFullScreen = false.obs;
  final RxInt playerGeneration = 0.obs;
  final RxBool isPlaying = false.obs;
  final RxDouble playbackSpeed = 1.0.obs;

  // View tracking
  final RxInt viewDurationSeconds = 0.obs;
  Timer? _durationTimer;
  Timer? _logTimer;

  bool _isPlaying = false;

  late final SessionTracker _session = SessionTracker(
    maxSessionDurationSeconds: maxSessionDurationSeconds,
    maxPauseSeconds: defaultMaxPauseSeconds,
  );

  bool logInitialized = false;
  int _lastLoggedDuration = 0;
  bool _thresholdReached = false;
  String? _logId;
  int? _videoDurationSeconds;

  StreamSubscription<bool>? _playingSub;
  StreamSubscription<Duration>? _durationSub;
  StreamSubscription<String?>? _errorSub;
  StreamSubscription<bool>? _completedSub;
  StreamSubscription<Duration>? _positionSub;
  StreamSubscription<bool>? _bufferingSub;

  /// True while a recovery action (seek / downgrade / reload) is in flight, to
  /// keep the 1 Hz sampler from stacking further actions on top of it.
  bool _recovering = false;

  /// Auto mode only downgrades once per stall. Without this the escalation
  /// ladder and the "2 stalls in 5 minutes" rule would both fire for one stall
  /// and drop two rungs at once.
  bool _downgradedForStall = false;

  /// True once the ladder has given up and the retry UI is showing. Sampling
  /// stops so the stall overlay cannot flicker back in underneath the error.
  bool _stallRecoveryExhausted = false;

  /// Decides when a degraded rendition has proved stable enough to climb back
  /// up. Separate from [StallDetector]: that one only watches for trouble,
  /// this one watches for the absence of it.
  final AutoQualityGovernor _governor = AutoQualityGovernor();

  /// Last reason a climb was refused, used to keep the log readable.
  UpgradeSkipReason? _lastUpgradeSkip;

  /// One-time "quality is automatic" notice. Deliberately only for real HLS
  /// sources; a non-HLS video has no ladder being managed.
  bool _introToastShown = false;

  static const int _maxLoadAttempts = 3;
  static const List<Duration> _loadTimeouts = [
    Duration(seconds: 3),
    Duration(seconds: 4),
    Duration(seconds: 6),
  ];
  // Slower networks & software rendering (e.g. Android emulators) need a much
  // more generous budget before a load is treated as stalled.
  static const List<Duration> _loadTimeoutsMobile = [
    Duration(seconds: 10),
    Duration(seconds: 15),
    Duration(seconds: 25),
  ];
  static const int _maxLoadWaitSeconds = 60;
  Duration get _loadTimeoutForAttempt {
    final list = (Platform.isAndroid || Platform.isIOS)
        ? _loadTimeoutsMobile
        : _loadTimeouts;
    return list[_loadAttempts.clamp(0, list.length - 1)];
  }

  int _loadAttempts = 0;
  int _loadWaitElapsed = 0;
  Timer? _loadWatchdog;
  Timer? _retryTimer;
  bool _loadFailurePending = false;
  String? _pendingUrl;
  Duration? _pendingStart;

  @override
  Future<void> onInit() async {
    super.onInit();
    WidgetsBinding.instance.addObserver(this);
    player = _createPlayer();
    _initStreams();
    await _loadUser();
    await _initializePlayer();
    await _createInitialLog();
    _startTracking();
  }

  IPlayerAdapter _createPlayer() {
    if (Platform.isMacOS) {
      return VideoPlayerAdapter();
    }
    if (Platform.isWindows) {
      // FVP backend: a network stream that fails to open can leave
      // initialize() pending forever, so fail fast and let the retry logic
      // (watchdog / _onLoadFailed) take over.
      return VideoPlayerAdapter(initializeTimeout: const Duration(seconds: 15));
    }
    return MediaKitPlayerAdapter();
  }

  void _initStreams() {
    _durationSub = player.onDurationChanged.listen((d) {
      if (d.inSeconds > 0) {
        _videoDurationSeconds ??= d.inSeconds;
        _onMediaLoaded();
      }
    });
    _playingSub = player.onPlayingChanged.listen((playing) {
      if (playing) {
        _onMediaLoaded();
        _onPlay();
      } else {
        _onPause();
      }
    });
    _completedSub = player.onCompleted.listen((completed) {
      if (completed) _onPause();
    });
    _positionSub = player.onPositionChanged.listen((position) {
      if (position > Duration.zero) {
        _onMediaLoaded();
      }
    });
    _errorSub = player.onError.listen((error) {
      if (error == null) return;
      projectLogger.e("Player error: $error");
      // On Windows/mpv a failed first load often stalls silently without a
      // proper error event. When an error does arrive before the media has
      // loaded, route it through the same retry path.
      if (_videoDurationSeconds == null) {
        _onLoadFailed();
      }
    });
    // Buffering was previously only readable as a polled bool, which made a
    // mid-lecture stall indistinguishable from normal playback. The flag is
    // logged here because it is what separates a network underrun from a
    // decoder that has wedged with a full buffer.
    _bufferingSub = player.onBufferingChanged.listen((buffering) {
      if (_disposed || !_videoDurationLoaded) return;
      projectLogger.d("Player buffering: $buffering");
    });
  }

  bool get _videoDurationLoaded => _videoDurationSeconds != null;

  /// Opens the video and automatically retries if the media fails to load
  /// (stalls, errors, or times out). Retries are automatic so the user is not
  /// left with a stuck player.
  Future<void> _beginLoad(String url, {Duration? start}) async {
    if (_disposed) return;
    _pendingUrl = url;
    _pendingStart = start;
    _loadFailurePending = false;
    _loadWaitElapsed = 0;
    errorMessage.value = '';
    isLoading.value = true;
    _loadWatchdog?.cancel();
    try {
      // Reset the player before opening a new source. On Android re-opening
      // over an actively-buffering stream detaches/re-attaches the video
      // surface and can end up with audio playing but a black video output.
      await player.stop();
      await player.open(url, start: start);
      _startLoadWatchdog();
    } catch (e) {
      projectLogger.e("Open error (attempt ${_loadAttempts + 1}): $e");
      _onLoadFailed();
    }
  }

  void _startLoadWatchdog() {
    _loadWatchdog?.cancel();
    _loadWatchdog = Timer(_loadTimeoutForAttempt, () {
      // A loaded media reports a duration or has a non-zero position.
      if (player.duration.inSeconds > 0 || player.position.inSeconds > 0) {
        _onMediaLoaded();
        return;
      }
      // The load may simply be slow (e.g. HLS on Android/emulators or a slow
      // network). Re-opening an actively-buffering stream is what causes the
      // "audio only / black video" issue on Android, so only fail & retry when
      // the stream is neither loaded nor making progress.
      if (player.isBuffering && _loadWaitElapsed < _maxLoadWaitSeconds) {
        _loadWaitElapsed += _loadTimeoutForAttempt.inSeconds;
        projectLogger.w(
          "Video still buffering, extending load wait (${_loadWaitElapsed}s)",
        );
        _startLoadWatchdog();
        return;
      }
      projectLogger.w(
        "Video load stalled, retrying (attempt ${_loadAttempts + 1}/$_maxLoadAttempts)",
      );
      _onLoadFailed();
    });
  }

  void _onMediaLoaded() {
    final wasLoading = isLoading.value;
    _loadWatchdog?.cancel();
    _retryTimer?.cancel();
    _loadFailurePending = false;
    _loadAttempts = 0;
    _loadWaitElapsed = 0;
    isLoading.value = false;
    // Announced once the loading overlay has actually cleared, so the notice
    // cannot cover a spinner the student is still waiting on. Guarded by
    // `_introToastShown`, so it appears once per video.
    if (wasLoading) _maybeShowAutoQualityToast();
  }

  void _onLoadFailed() {
    if (_disposed) return;
    _loadWatchdog?.cancel();
    if (_loadFailurePending) return;
    _loadAttempts++;
    if (_loadAttempts >= _maxLoadAttempts) {
      isLoading.value = false;
      errorMessage.value =
          'فشل تحميل الفيديو، يرجى التحقق من اتصال الإنترنت وإعادة المحاولة.';
      projectLogger.e("Video failed to load after $_maxLoadAttempts attempts");
      return;
    }
    _loadFailurePending = true;
    final url = _pendingUrl ?? videoUrl;
    final start = _pendingStart;
    _retryTimer?.cancel();
    _retryTimer = Timer(
      Duration(seconds: _loadAttempts),
      () => _beginLoad(url, start: start),
    );
  }

  /// Manually retry loading the video after a failure.
  Future<void> retry() async {
    errorMessage.value = '';
    _stallRecoveryExhausted = false;
    _loadAttempts = 0;
    _retryTimer?.cancel();
    if (!Platform.isMacOS) {
      // On Windows/Android/iOS a failed load can leave the underlying player
      // in a wedged state where audio plays but video output stays black.
      // Re-opening on top of that state does not fix it, so tear the whole
      // player down and build a fresh one with a brand-new video surface.
      _resetPlayer();
    }
    await _beginLoad(_pendingUrl ?? videoUrl, start: _pendingStart);
  }

  void _resetPlayer() {
    _playingSub?.cancel();
    _durationSub?.cancel();
    _completedSub?.cancel();
    _errorSub?.cancel();
    _positionSub?.cancel();
    _bufferingSub?.cancel();
    try {
      player.dispose();
    } catch (e) {
      projectLogger.w("Player dispose on reset failed: $e");
    }
    player = _createPlayer();
    _initStreams();
    playerGeneration.value++;
    _stall.reset();
    isStalled.value = false;
    _downgradedForStall = false;
    _stallRecoveryExhausted = false;
    _recovering = false;
    // Buffer is gone; stability has to be earned again before quality climbs.
    _governor.noteBufferCleared();
  }

  Future<void> _loadUser() async {
    final db = Get.find<LocalDB>();
    final jsonUser = db.sharedPref?.getString("UserData");
    if (jsonUser != null) {
      user = json.decode(jsonUser);
    }
  }

  Future<void> _fetchQualities() async {
    try {
      // Previously an `endsWith('.m3u8')` check, which never matched a signed
      // CDN URL such as `master.m3u8?token=...`. The whole quality menu was
      // silently dead for those videos and playback fell through to whatever
      // rendition the backend picked.
      if (!isHlsManifestUrl(videoUrl)) return;

      final response = await http.get(Uri.parse(videoUrl));
      if (response.statusCode != 200) return;

      final variants = parseHlsMasterPlaylist(
        response.body,
        Uri.parse(videoUrl),
      );
      if (variants.isEmpty) return;

      qualities.addAll(variants);
      // Index 0 is the "تلقائي" entry. Its URL is the master playlist, which is
      // never loaded: both backends lock to one rendition at open time and do
      // not switch during playback, so handing them the master buys nothing.
      qualities.insert(
        0,
        VideoQuality(label: PlayerMessages.autoQualityLabel, url: videoUrl),
      );
      qualitiesLoaded.value = true;
    } catch (e) {
      projectLogger.e("Quality fetch error: $e");
    }
  }

  Future<void> _initializePlayer() async {
    try {
      await _fetchQualities();

      if (qualities.length > 1) {
        autoQuality.value = true;
        currentQualityIndex.value = selectAutoQualityIndex(qualities);
        // The opening choice gets the same dwell as any later switch, so the
        // first possible climb lands after two minutes of clean playback rather
        // than at the very moment the student is settling in.
        _governor.noteQualityChanged();
      }

      await _beginLoad(currentPlayUrl);
    } catch (e) {
      errorMessage.value = "Failed to load video";
      projectLogger.e("Video init error: $e");
      isLoading.value = false;
    }
  }

  /// URL of the rendition to load. Falls back to the source URL when there is
  /// no usable master playlist.
  String get currentPlayUrl => resolvePlayUrl(
    sourceUrl: videoUrl,
    qualities: qualities,
    index: currentQualityIndex.value,
  );

  /// Label for the quality chip. Empty when there is nothing to choose.
  String get qualityChipLabel => buildQualityChipLabel(
    qualities: qualities,
    index: currentQualityIndex.value,
    autoQuality: autoQuality.value,
  );

  void showQualityDialog(BuildContext context) {
    if (qualities.length <= 1) return;
    showDialog(
      context: context,
      builder: (ctx) {
        final theme = Theme.of(ctx);
        return AlertDialog(
          title: const Text(PlayerMessages.qualityMenuTitle),
          content: SizedBox(
            width: double.maxFinite,
            // Observes the two selection values: the ladder can step while the
            // menu is open, and a checkmark frozen at the moment the dialog
            // appeared would tell the student about a rendition it no longer
            // holds.
            child: Obx(() {
              final selected = selectedQualityIndex(
                autoQuality: autoQuality.value,
                currentIndex: currentQualityIndex.value,
                qualityCount: qualities.length,
              );
              final effectiveLabel = autoQuality.value
                  ? qualities[currentQualityIndex.value].label
                  : null;
              return Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  ConstrainedBox(
                    constraints: const BoxConstraints(maxHeight: 360),
                    child: ListView.builder(
                      shrinkWrap: true,
                      itemCount: qualities.length,
                      itemBuilder: (ctx, i) {
                        final isAuto = i == kAutoQualityIndex;
                        return ListTile(
                          title: Text(qualities[i].label),
                          subtitle: isAuto
                              ? Text(
                                  PlayerMessages.autoQualityOptionSubtitle(
                                    effectiveLabel,
                                  ),
                                )
                              : null,
                          trailing: i == selected
                              ? const Icon(Icons.check)
                              : null,
                          onTap: () {
                            Navigator.pop(ctx);
                            if (isAuto) {
                              // Already automatic: re-picking it must do
                              // nothing. Re-deriving the conservative start
                              // would silently drop a rendition the ladder had
                              // already earned.
                              if (autoQuality.value) return;
                              // The rendition does not change, only the policy
                              // governing it, so this is a mode flip.
                              switchQuality(
                                currentQualityIndex.value,
                                auto: true,
                              );
                              return;
                            }
                            switchQuality(i, auto: false);
                          },
                        );
                      },
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    PlayerMessages.pinQualityHint,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.hintColor,
                    ),
                    // Matches the rows above it. Centering it put the hint on a
                    // different axis from the right-aligned titles and
                    // subtitle, so it read as a stray caption rather than as
                    // part of the same column.
                    textAlign: TextAlign.start,
                  ),
                ],
              );
            }),
          ),
        );
      },
    );
  }

  Future<void> switchQuality(int index, {bool auto = false}) async {
    if (qualities.length <= 1) return;
    if (index < 1 || index >= qualities.length) return;
    // Same rendition, only the governing policy changed: flipping a flag is
    // not worth tearing the stream down. Re-opening would cause a rebuffer the
    // student can see, for a change that does not affect what is decoded right
    // now.
    if (index == currentQualityIndex.value) {
      if (autoQuality.value == auto) return;
      _applyModeChange(auto);
      return;
    }

    _onPause();
    final position = player.position;
    final wasPlaying = player.isPlaying;

    _loadAttempts = 0;
    _loadFailurePending = false;

    try {
      // Recorded before the reload, not after it: if the load fails the
      // switch is still an event, and without this a broken rendition would
      // be retried every tick.
      _governor.noteQualityChanged();
      await _beginLoad(
        qualities[index].url,
        start: position > Duration.zero ? position : null,
      );

      if (wasPlaying) {
        await player.play();
      }

      lastPlayIntent.value = wasPlaying;
      currentQualityIndex.value = index;
      autoQuality.value = auto;
      _stall.reset();
      isStalled.value = false;
      _downgradedForStall = false;
      _stallRecoveryExhausted = false;
    } catch (e) {
      projectLogger.e("Quality switch error: $e");
    }
  }

  /// Flips auto mode while the rendition itself stays where it is.
  ///
  /// Only the policy changes here, deliberately so. A stable pinned rendition
  /// is not evidence that the next rung up is safe, and nothing should visibly
  /// reload in the second after a tap that did not ask for a quality change -
  /// so the governor's dwell clock starts over and the ladder keeps its hands
  /// off for the usual interval. Stall state is left alone: it describes the
  /// link, not the selection, and clearing it here would hide an active freeze
  /// behind a mode change. Recovery exhaustion is likewise untouched, since
  /// only [retry] owns that and it has to clear `errorMessage` with it.
  void _applyModeChange(bool auto) {
    autoQuality.value = auto;
    _governor.noteQualityChanged();
    projectLogger.d(
      "Quality mode -> ${auto ? 'auto' : 'pinned'} at "
      "${qualities[currentQualityIndex.value].label}",
    );
  }

  void setPlaybackSpeed(double speed) {
    playbackSpeed.value = speed;
    player.setRate(speed);
  }

  void seekRelative(int seconds) {
    final pos = player.position;
    final dur = player.duration;
    final target = pos + Duration(seconds: seconds);
    final clamped = target.isNegative
        ? Duration.zero
        : (target > dur ? dur : target);
    player.seek(clamped);
  }

  void showSpeedDialog(BuildContext context) {
    const speeds = [0.5, 0.75, 1.0, 1.25, 1.5, 2.0];
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Playback Speed'),
        content: SizedBox(
          width: double.maxFinite,
          child: ListView.builder(
            shrinkWrap: true,
            itemCount: speeds.length,
            itemBuilder: (ctx, i) {
              final s = speeds[i];
              return ListTile(
                title: Text('${s}x'),
                trailing: s == playbackSpeed.value
                    ? const Icon(Icons.check)
                    : null,
                onTap: () {
                  Navigator.pop(ctx);
                  setPlaybackSpeed(s);
                },
              );
            },
          ),
        ),
      ),
    );
  }

  void _onPlay() {
    _session.onPlay();
    if (_isPlaying != _session.isPlaying) {
      _isPlaying = _session.isPlaying;
      isPlaying.value = _session.isPlaying;
    }
  }

  void _onPause() {
    _session.onPause();
    if (_isPlaying != _session.isPlaying) {
      _isPlaying = _session.isPlaying;
      isPlaying.value = _session.isPlaying;
    }
    viewDurationSeconds.value = _session.viewDurationSeconds;
  }

  Future<void> _createInitialLog() async {
    try {
      final supabase = Supabase.instance.client;

      await supabase
          .from('logs')
          .update({'currently_log': false})
          .eq('user_id', user['id'])
          .eq('currently_log', true);

      final logData = {
        'user_id': user['id'],
        'type': 'video_view',
        'video_url': videoUrl,
        'view_duration_seconds': 0,
        'viewed': false,
        'currently_log': true,
        'video_total_duration_seconds': _videoDurationSeconds,
        'data': {
          'video_url': videoUrl,
          'view_duration_seconds': 0,
          'viewed': false,
          'video_total_duration_seconds': _videoDurationSeconds,
        },
      };

      final res = await supabase
          .from('logs')
          .insert(logData)
          .select('id')
          .single();

      _logId = res['id'].toString();
      logInitialized = true;

      projectLogger.i("Initial log created $_logId");
    } catch (e) {
      projectLogger.e("Initial log error: $e");
    }
  }

  void _startTracking() {
    _durationTimer = Timer.periodic(
      const Duration(seconds: 1),
      (_) => _tickDuration(),
    );
    _logTimer = Timer.periodic(
      const Duration(seconds: 60),
      (_) => _tickLogging(),
    );
  }

  void _tickDuration() {
    // Sampled before the session check: a freeze must still be detected and
    // recovered even if the session bookkeeping has already stopped.
    _sampleStall();
    // Deliberately second. If the stall sampler above just triggered a
    // downgrade, `isLoading` is now set and this returns without acting, so a
    // down-and-up pair can never be decided inside a single tick.
    _sampleUpgrade();
    if (!_ticking || _session.expired) return;

    if (_session.tick()) {
      _onSessionExpired(reason: _session.expiryReason!);
      return;
    }

    viewDurationSeconds.value = _session.viewDurationSeconds;
    _checkThreshold();
  }

  /// Feeds one observation to the stall detector and applies whatever recovery
  /// step it asks for. Runs once per second.
  void _sampleStall() {
    if (_disposed || isLoading.value || _recovering) return;
    if (_stallRecoveryExhausted) return;
    // No master playlist means no ladder to climb; a non-HLS source is played
    // exactly as before.
    if (qualities.length <= 1) return;
    if (!_ticking || _session.expired) return;

    _stall.sample(
      position: player.position,
      isBuffering: player.isBuffering,
      isPlaying: player.isPlaying && _session.isPlaying,
    );

    if (isStalled.value != _stall.isStalled) {
      isStalled.value = _stall.isStalled;
      if (_stall.isStalled) {
        projectLogger.w(
          "Stall detected at ${player.position.inSeconds}s "
          "(buffering: ${player.isBuffering}, ahead: "
          "${player.bufferedAhead.inSeconds}s)",
        );
      }
    }
    stallCount.value = _stall.stallCount;
    if (!_stall.isStalled) {
      _downgradedForStall = false;
      return;
    }

    // A link that stalls repeatedly but never long enough to trip a single
    // ladder step is still a link the student cannot watch on. Degrade early.
    if (_stall.shouldProactivelyDowngrade && !_downgradedForStall) {
      _actOnStall(StallRecoveryAction.downgradeQuality);
      return;
    }

    _actOnStall(_stall.action);
  }

  void _actOnStall(StallRecoveryAction action) {
    switch (action) {
      case StallRecoveryAction.none:
      case StallRecoveryAction.wait:
        return;
      case StallRecoveryAction.seek:
        _stall.markActionTaken(action);
        _recoverBySeek();
        return;
      case StallRecoveryAction.downgradeQuality:
        _stall.markActionTaken(action);
        _autoDowngrade();
        return;
      case StallRecoveryAction.reload:
        _stall.markActionTaken(action);
        _recoverByReload();
        return;
      case StallRecoveryAction.failed:
        _stall.markActionTaken(action);
        _onStallFailed();
        return;
    }
  }

  /// Steps auto quality back up a rung when the link has earned it.
  ///
  /// Runs once per second, immediately after [_sampleStall]. The inverse of
  /// [_autoDowngrade]: rather than needing trouble it needs the sustained
  /// absence of it, and it asks for proof in both directions - a clean stall
  /// window plus enough read-ahead to sustain the faster rendition.
  void _sampleUpgrade() {
    if (_disposed || isLoading.value || _recovering) return;
    if (_stallRecoveryExhausted) return;
    // No ladder means nothing to climb.
    if (qualities.length <= 1) return;
    if (!_ticking || _session.expired) return;

    _governor.sample(isStalled: _stall.isStalled);
    if (_stall.isStalled) return;

    final plan = _governor.planAutoUpgrade(
      qualities: qualities,
      currentIndex: currentQualityIndex.value,
      autoQuality: autoQuality.value,
      bufferedAhead: player.bufferedAhead,
    );
    if (!plan.shouldUpgrade) {
      _logUpgradeSkip(plan.skipReason!);
      return;
    }

    _lastUpgradeSkip = null;
    final label = qualities[plan.targetIndex!].label;
    projectLogger.i("Auto quality upgrade to $label");
    unawaited(switchQuality(plan.targetIndex!, auto: true));
  }

  /// Logs a refused climb only when the reason changes. Each reason holds for
  /// dozens of consecutive seconds, and one line per second would bury the log
  /// entry that a real upgrade eventually lands in.
  void _logUpgradeSkip(UpgradeSkipReason reason) {
    if (reason == _lastUpgradeSkip) return;
    _lastUpgradeSkip = reason;
    projectLogger.d("Auto upgrade skipped: ${reason.name}");
  }

  Future<void> _recoverBySeek() async {
    final resumeAt = _stall.stallPosition;
    if (resumeAt <= Duration.zero) return;
    projectLogger.i("Stall recovery: seeking to ${resumeAt.inSeconds}s");
    try {
      await player.seek(resumeAt);
    } catch (e) {
      projectLogger.e("Stall seek failed: $e");
    }
  }

  Future<void> _recoverByReload() async {
    if (_recovering) return;
    _recovering = true;
    final resumeAt = _stall.stallPosition;
    projectLogger.i("Stall recovery: reopening at ${resumeAt.inSeconds}s");
    try {
      // A wedged decoder survives a seek but not a fresh instance, so tear the
      // player down entirely - this is the same path as the manual retry.
      _resetPlayer();
      await _beginLoad(
        currentPlayUrl,
        start: resumeAt > Duration.zero ? resumeAt : null,
      );
    } catch (e) {
      projectLogger.e("Stall reload failed: $e");
    } finally {
      _recovering = false;
    }
  }

  void _onStallFailed() {
    if (_disposed) return;
    _stallRecoveryExhausted = true;
    isStalled.value = false;
    errorMessage.value = PlayerMessages.connectionLost;
    projectLogger.e("Stall recovery exhausted; surfacing retry UI");
  }

  /// Steps auto mode down one rendition, keeping the current position.
  Future<void> _autoDowngrade() async {
    if (_disposed) return;

    final plan = planAutoDowngrade(
      qualities: qualities,
      currentIndex: currentQualityIndex.value,
      autoQuality: autoQuality.value,
      alreadyDowngradedForStall: _downgradedForStall,
    );
    if (!plan.shouldDowngrade) {
      if (plan.skipReason != null) {
        projectLogger.d("Auto downgrade skipped: ${plan.skipReason!.name}");
      }
      return;
    }

    final label = qualities[plan.targetIndex!].label;
    _downgradedForStall = true;
    // The rung we are leaving is the one that could not keep up; remember it
    // so a later climb does not immediately return to it.
    _governor.noteRungFailed(currentQualityIndex.value);
    projectLogger.i("Auto quality downgrade to $label");
    await switchQuality(plan.targetIndex!, auto: true);
  }

  void _maybeShowAutoQualityToast() {
    if (_introToastShown) return;
    _introToastShown = true;
    // Requires a real rendition list as well as auto mode: for a non-HLS source
    // nothing is being managed, so telling the student quality is automatic
    // would be describing a feature that does not exist for that video.
    if (!shouldAnnounceAutoQuality(
      qualities: qualities,
      autoQuality: autoQuality.value,
    )) {
      return;
    }
    showSnackbar(
      PlayerMessages.autoQualityTitle,
      PlayerMessages.autoQualityBody,
    );
  }

  void _checkThreshold() {
    if (_videoDurationSeconds == null || _thresholdReached) return;
    final threshold = (_videoDurationSeconds! * 0.25).toInt();
    if (viewDurationSeconds.value >= threshold) {
      _thresholdReached = true;
      projectLogger.i(
        "25% threshold reached (${viewDurationSeconds.value}s / ${_videoDurationSeconds}s)",
      );
    }
  }

  Future<void> _tickLogging() async {
    if (!_ticking) return;
    try {
      if (!logInitialized || _logId == null) return;
      final sec = viewDurationSeconds.value;
      if (sec <= _lastLoggedDuration) return;

      final logData = {
        "user_id": user["id"],
        "type": "video_view",
        "video_url": videoUrl,
        "view_duration_seconds": sec,
        "viewed": _thresholdReached,
        "video_total_duration_seconds": _videoDurationSeconds,
        "data": {
          "video_url": videoUrl,
          "view_duration_seconds": sec,
          "viewed": _thresholdReached,
          "video_total_duration_seconds": _videoDurationSeconds,
        },
      };

      await api.updateData("logs", logData, {"id": _logId!});
      _lastLoggedDuration = sec;
      projectLogger.i("Logged $sec seconds (id: $_logId)");
    } catch (e) {
      projectLogger.e("Error while logging view: $e");
    }
  }

  void _onSessionExpired({String reason = 'انتهت مدة الجلسة'}) {
    if (!_session.expired) {
      _session.expire(reason);
    }
    _ticking = false;
    _durationTimer?.cancel();
    _logTimer?.cancel();

    player.pause();
    _onPause();

    Get.dialog(
      AlertDialog(
        title: const Text('انتهت الجلسة'),
        content: Text(reason),
        actions: [
          TextButton(
            onPressed: () {
              Get.back();
              Get.back();
            },
            child: const Text('حسناً'),
          ),
        ],
      ),
      barrierDismissible: false,
    );
  }

  bool _ticking = true;
  bool _disposed = false;

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    switch (state) {
      case AppLifecycleState.paused:
      case AppLifecycleState.hidden:
      case AppLifecycleState.detached:
        _session.onBackground();
        if (_isPlaying != _session.isPlaying) {
          _isPlaying = _session.isPlaying;
          isPlaying.value = _session.isPlaying;
        }
        viewDurationSeconds.value = _session.viewDurationSeconds;
        break;
      case AppLifecycleState.resumed:
        if (_session.tick()) {
          _onSessionExpired(reason: _session.expiryReason!);
          return;
        }
        viewDurationSeconds.value = _session.viewDurationSeconds;
        _checkThreshold();
        if (player.isPlaying && !_session.isPlaying) {
          _session.onPlay();
          _isPlaying = true;
          isPlaying.value = true;
        }
        break;
      case AppLifecycleState.inactive:
        break;
    }
  }

  void stopTracking() {
    _ticking = false;
    _durationTimer?.cancel();
    _logTimer?.cancel();
    _loadWatchdog?.cancel();
    _retryTimer?.cancel();
    _playingSub?.cancel();
    _durationSub?.cancel();
    _completedSub?.cancel();
    _errorSub?.cancel();
    _positionSub?.cancel();
    _bufferingSub?.cancel();
    try {
      player.stop();
    } catch (_) {}
  }

  void cleanup() {
    if (_disposed) return;
    _disposed = true;
    stopTracking();
    try {
      player.dispose();
    } catch (e) {
      projectLogger.e("Cleanup error: $e");
    }
  }

  @override
  void onClose() {
    WidgetsBinding.instance.removeObserver(this);
    _session.onClose();

    final finalDuration = _session.accumulatedSeconds;

    if (logInitialized &&
        _logId != null &&
        finalDuration > _lastLoggedDuration) {
      try {
        final finalData = {
          "user_id": user["id"],
          "type": "video_view",
          "video_url": videoUrl,
          "view_duration_seconds": finalDuration,
          "viewed": _thresholdReached,
          "video_total_duration_seconds": _videoDurationSeconds,
          "data": {
            "video_url": videoUrl,
            "view_duration_seconds": finalDuration,
            "viewed": _thresholdReached,
            "video_total_duration_seconds": _videoDurationSeconds,
          },
        };
        api.updateData("logs", finalData, {"id": _logId!});
        projectLogger.i("Final log update: ${finalDuration}s (id: $_logId)");
      } catch (e) {
        projectLogger.e("Error on final log update: $e");
      }
    }

    cleanup();
    super.onClose();
  }
}
