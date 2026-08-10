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
import 'package:shobaki_academy/controller/macos_player_adapter.dart';

class VideoQuality {
  final String label;
  final String url;
  final int? bandwidth;
  final int? width;
  final int? height;

  VideoQuality({
    required this.label,
    required this.url,
    this.bandwidth,
    this.width,
    this.height,
  });
}

class VideoPlaybackController extends GetxController {
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

  late final IPlayerAdapter player;

  late Map<String, dynamic> user;

  // Quality options
  final List<VideoQuality> qualities = [];
  final RxInt currentQualityIndex = 0.obs;
  final RxBool qualitiesLoaded = false.obs;
  final RxBool lastPlayIntent = false.obs;

  final RxBool isFullScreen = false.obs;
  final RxBool isPlaying = false.obs;
  final RxDouble playbackSpeed = 1.0.obs;

  // View tracking
  final RxInt viewDurationSeconds = 0.obs;
  Timer? _durationTimer;
  Timer? _logTimer;

  bool _isPlaying = false;

  int _accumulatedSeconds = 0;
  DateTime? _sessionStart;

  bool logInitialized = false;
  int _lastLoggedDuration = 0;
  bool _thresholdReached = false;
  String? _logId;
  int? _videoDurationSeconds;

  DateTime? _watchSessionStart;
  DateTime? _pauseStart;
  bool _sessionExpired = false;

  StreamSubscription<bool>? _playingSub;
  StreamSubscription<Duration>? _durationSub;
  StreamSubscription<String?>? _errorSub;
  StreamSubscription<bool>? _completedSub;

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
    if (Platform.isMacOS) {
      player = MacOSPlayerAdapter();
    } else {
      player = MediaKitPlayerAdapter();
    }
    _initStreams();
    await _loadUser();
    await _initializePlayer();
    await _createInitialLog();
    _startTracking();
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
        _onPlay();
      } else {
        _onPause();
      }
    });
    _completedSub = player.onCompleted.listen((completed) {
      if (completed) _onPause();
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
  }

  /// Opens the video and automatically retries if the media fails to load
  /// (stalls, errors, or times out). Retries are automatic so the user is not
  /// left with a stuck player.
  Future<void> _beginLoad(String url, {Duration? start}) async {
    if (_disposed) return;
    _pendingUrl = url;
    _pendingStart = start;
    _loadFailurePending = false;
    _loadWaitElapsed = 0;
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
    _loadWatchdog?.cancel();
    _retryTimer?.cancel();
    _loadFailurePending = false;
    _loadAttempts = 0;
    _loadWaitElapsed = 0;
    isLoading.value = false;
  }

  void _onLoadFailed() {
    if (_disposed) return;
    _loadWatchdog?.cancel();
    if (_loadFailurePending) return;
    _loadAttempts++;
    if (_loadAttempts >= _maxLoadAttempts) {
      isLoading.value = false;
      errorMessage.value = 'فشل تحميل الفيديو، يرجى التحقق من اتصال الإنترنت وإعادة المحاولة.';
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
    _loadAttempts = 0;
    _retryTimer?.cancel();
    await _beginLoad(_pendingUrl ?? videoUrl, start: _pendingStart);
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
      if (!videoUrl.endsWith('.m3u8')) return;

      final response = await http.get(Uri.parse(videoUrl));
      if (response.statusCode != 200) return;

      final body = response.body;
      if (!body.startsWith('#EXTM3U')) return;

      final lines = body.split('\n');
      String? currentBandwidth;
      String? currentResolution;
      final baseUrl = Uri.parse(videoUrl);

      for (final line in lines) {
        final trimmed = line.trim();
        if (trimmed.isEmpty) continue;

        if (trimmed.startsWith('#EXT-X-STREAM-INF:')) {
          final params = trimmed.substring('#EXT-X-STREAM-INF:'.length);

          final bandMatch = RegExp(r'BANDWIDTH=(\d+)').firstMatch(params);
          currentBandwidth = bandMatch?.group(1);

          final resMatch = RegExp(r'RESOLUTION=(\d+)x(\d+)').firstMatch(params);
          if (resMatch != null) {
            currentResolution = '${resMatch.group(1)}x${resMatch.group(2)}';
          }
        } else if (!trimmed.startsWith('#') && trimmed.isNotEmpty) {
          final variantUrl = baseUrl.resolve(trimmed).toString();

          String label = 'Auto';
          int? width;
          int? height;

          if (currentResolution != null) {
            final parts = currentResolution.split('x');
            width = int.tryParse(parts[0]);
            height = int.tryParse(parts[1]);
            label = '${height}p';
          }

          qualities.add(
            VideoQuality(
              label: label,
              url: variantUrl,
              bandwidth: currentBandwidth != null
                  ? int.parse(currentBandwidth)
                  : null,
              width: width,
              height: height,
            ),
          );

          currentBandwidth = null;
          currentResolution = null;
        }
      }

      if (qualities.isNotEmpty) {
        qualities.sort((a, b) => (b.height ?? 0).compareTo(a.height ?? 0));
        qualities.insert(0, VideoQuality(label: 'Auto', url: videoUrl));
        qualitiesLoaded.value = true;
      }
    } catch (e) {
      projectLogger.e("Quality fetch error: $e");
    }
  }

  Future<void> _initializePlayer() async {
    try {
      await _fetchQualities();

      if (qualities.length > 1) {
        currentQualityIndex.value = 1;
      }

      final playUrl = qualities.isNotEmpty
          ? qualities[currentQualityIndex.value].url
          : videoUrl;

      await _beginLoad(playUrl);
    } catch (e) {
      errorMessage.value = "Failed to load video";
      projectLogger.e("Video init error: $e");
      isLoading.value = false;
    }
  }

  void showQualityDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          title: const Text('Select Quality'),
          content: SizedBox(
            width: double.maxFinite,
            child: ListView.builder(
              shrinkWrap: true,
              itemCount: qualities.length,
              itemBuilder: (ctx, i) {
                return ListTile(
                  title: Text(qualities[i].label),
                  trailing: i == currentQualityIndex.value
                      ? const Icon(Icons.check)
                      : null,
                  onTap: () {
                    Navigator.pop(ctx);
                    switchQuality(i);
                  },
                );
              },
            ),
          ),
        );
      },
    );
  }

  Future<void> switchQuality(int index) async {
    if (index < 0 ||
        index >= qualities.length ||
        index == currentQualityIndex.value) {
      return;
    }

    _onPause();
    final position = player.position;
    final wasPlaying = player.isPlaying;

    _loadAttempts = 0;
    _loadFailurePending = false;

    try {
      await _beginLoad(
        qualities[index].url,
        start: position > Duration.zero ? position : null,
      );

      if (wasPlaying) {
        await player.play();
      }

      lastPlayIntent.value = wasPlaying;
      currentQualityIndex.value = index;
    } catch (e) {
      projectLogger.e("Quality switch error: $e");
    }
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
    if (_sessionExpired) return;
    if (!_isPlaying) {
      _isPlaying = true;
      isPlaying.value = true;
      _watchSessionStart ??= DateTime.now();
      _sessionStart ??= DateTime.now();
      _pauseStart = null;
    }
  }

  void _onPause() {
    if (_sessionExpired) return;
    if (_isPlaying) {
      _isPlaying = false;
      isPlaying.value = false;
      _pauseStart ??= DateTime.now();
      if (_sessionStart != null) {
        final sessionSeconds = DateTime.now()
            .difference(_sessionStart!)
            .inSeconds;
        _accumulatedSeconds += sessionSeconds;
        _sessionStart = null;
        viewDurationSeconds.value = _accumulatedSeconds;
      }
    }
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
    if (!_ticking || _sessionExpired) return;

    final now = DateTime.now();

    if (_pauseStart != null && !_isPlaying) {
      final pauseSeconds = now.difference(_pauseStart!).inSeconds;
      if (pauseSeconds >= defaultMaxPauseSeconds) {
        _onSessionExpired(reason: 'تم تجاوز مدة الإيقاف المؤقت (30 دقيقة)');
        return;
      }
    }

    if (_watchSessionStart != null) {
      final sessionSeconds = now.difference(_watchSessionStart!).inSeconds;
      if (sessionSeconds >= maxSessionDurationSeconds) {
        _onSessionExpired(reason: 'انتهت مدة الجلسة (3 ساعات)');
        return;
      }
    }

    final activeSessionSeconds = (_sessionStart != null && _isPlaying)
        ? now.difference(_sessionStart!).inSeconds
        : 0;
    final total = _accumulatedSeconds + activeSessionSeconds;
    viewDurationSeconds.value = total;
    _checkThreshold();
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
    if (_sessionExpired) return;
    _sessionExpired = true;
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
    if (_sessionStart != null) {
      final sessionSeconds = DateTime.now()
          .difference(_sessionStart!)
          .inSeconds;
      _accumulatedSeconds += sessionSeconds;
      _sessionStart = null;
    }

    final finalDuration = _accumulatedSeconds;

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
