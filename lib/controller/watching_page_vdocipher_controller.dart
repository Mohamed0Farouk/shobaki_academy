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
  final api = ApiClient();

  VideoPlaybackController(this.videoUrl);

  RxBool isLoading = true.obs;
  RxString errorMessage = ''.obs;

  late final IPlayerAdapter player;

  late Map<String, dynamic> user;

  // Quality options
  final List<VideoQuality> qualities = [];
  final RxInt currentQualityIndex = 0.obs;
  final RxBool qualitiesLoaded = false.obs;

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

  StreamSubscription<bool>? _playingSub;
  StreamSubscription<Duration>? _durationSub;
  StreamSubscription<String?>? _errorSub;
  StreamSubscription<bool>? _completedSub;

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
    _startTracking();
    if (!logInitialized) _createInitialLog();
  }

  void _initStreams() {
    _durationSub = player.onDurationChanged.listen((d) {
      if (d.inSeconds > 0) {
        _videoDurationSeconds ??= d.inSeconds;
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
      if (error != null) projectLogger.e("Player error: $error");
    });
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

      await player.open(playUrl);

      if (!logInitialized) {
        isLoading.value = false;
      }
    } catch (e) {
      errorMessage.value = "Failed to load video";
      projectLogger.e("Video init error: $e");
    } finally {
      if (logInitialized) {
        isLoading.value = false;
      }
    }
  }

  void showQualityDialog(BuildContext context) {
    if (isFullScreen.value) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('exit fullscreen to control the quality')),
      );
      return;
    }

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

    try {
      await player.open(
        qualities[index].url,
        start: position > Duration.zero ? position : null,
      );

      currentQualityIndex.value = index;

      if (wasPlaying) {
        await player.play();
      }
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
    if (!_isPlaying) {
      _isPlaying = true;
      isPlaying.value = true;
      _sessionStart ??= DateTime.now();
      if (!logInitialized) _createInitialLog();
    }
  }

  void _onPause() {
    if (_isPlaying) {
      _isPlaying = false;
      isPlaying.value = false;
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
    } finally {
      isLoading.value = false;
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
    if (!_ticking) return;
    final activeSessionSeconds = (_sessionStart != null && _isPlaying)
        ? DateTime.now().difference(_sessionStart!).inSeconds
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

  bool _ticking = true;
  bool _disposed = false;

  void stopTracking() {
    _ticking = false;
    _durationTimer?.cancel();
    _logTimer?.cancel();
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
        projectLogger.i(
          "Final log update: ${finalDuration}s (id: $_logId)",
        );
      } catch (e) {
        projectLogger.e("Error on final log update: $e");
      }
    }

    cleanup();
    super.onClose();
  }
}
