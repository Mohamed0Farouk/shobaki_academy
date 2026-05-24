import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:http/http.dart' as http;
import 'package:shobaki_academy/services/api.dart';
import 'package:shobaki_academy/services/locale_db.dart';
import 'package:shobaki_academy/services/statics.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:video_player/video_player.dart';
import 'package:chewie/chewie.dart';

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

  VideoPlayerController? videoController;
  final Rx<ChewieController?> chewieController = Rx<ChewieController?>(null);

  late Map<String, dynamic> user;

  // Quality options
  final List<VideoQuality> qualities = [];
  final RxInt currentQualityIndex = 0.obs;
  final RxBool qualitiesLoaded = false.obs;

  final RxBool isFullScreen = false.obs;

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

  @override
  Future<void> onInit() async {
    super.onInit();
    await _loadUser();
    await _initializePlayer();
    _startTracking();
    if (!logInitialized) await _createInitialLog();
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
            final parts = currentResolution!.split('x');
            width = int.tryParse(parts[0]);
            height = int.tryParse(parts[1]);
            label = '${height}p';
          }

          qualities.add(VideoQuality(
            label: label,
            url: variantUrl,
            bandwidth:
                currentBandwidth != null ? int.parse(currentBandwidth) : null,
            width: width,
            height: height,
          ));

          currentBandwidth = null;
          currentResolution = null;
        }
      }

      if (qualities.isNotEmpty) {
        qualities.sort((a, b) => (b.height ?? 0).compareTo(a.height ?? 0));
        qualities.insert(
          0,
          VideoQuality(label: 'Auto', url: videoUrl),
        );
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

      videoController = VideoPlayerController.networkUrl(
        Uri.parse(playUrl),
      );
      await videoController!.initialize();

      if (videoController!.value.duration.inSeconds > 0) {
        _videoDurationSeconds = videoController!.value.duration.inSeconds;
      }

      chewieController.value = ChewieController(
        videoPlayerController: videoController!,
        autoPlay: true,
        looping: false,
        allowFullScreen: true,
        allowMuting: true,
        progressIndicatorDelay: const Duration(milliseconds: 500),
        showControls: true,
        deviceOrientationsOnEnterFullScreen: [
          DeviceOrientation.landscapeLeft,
          DeviceOrientation.landscapeRight,
        ],
        deviceOrientationsAfterFullScreen: [
          DeviceOrientation.portraitUp,
        ],
        placeholder: const Center(child: CircularProgressIndicator()),
        errorBuilder: (context, errorMessage) {
          return Center(child: Text(errorMessage));
        },
        additionalOptions: qualitiesLoaded.value
            ? (context) => [
                  OptionItem(
                    iconData: Icons.high_quality,
                    title: 'Quality',
                    subtitle: qualities[currentQualityIndex.value].label,
                    onTap: (ctx) => showQualityDialog(ctx),
                  ),
                ]
            : null,
      );

      chewieController.value!.addListener(_onFullscreenChanged);

      videoController!.addListener(_onPlayerStateChanged);
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
    showModalBottomSheet(
      context: context,
      builder: (ctx) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Padding(
                padding: const EdgeInsets.all(16),
                child: Text(
                  'Select Quality',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
              ),
              ...List.generate(qualities.length, (i) {
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
              }),
              const SizedBox(height: 8),
            ],
          ),
        );
      },
    );
  }

  Future<void> switchQuality(int index) async {
    if (index < 0 ||
        index >= qualities.length ||
        index == currentQualityIndex.value) return;

    _onPause();
    final position = videoController?.value.position;
    final wasPlaying = _isPlaying;

    videoController?.removeListener(_onPlayerStateChanged);
    final oldController = videoController;
    final oldChewie = chewieController.value;

    try {
      videoController = VideoPlayerController.networkUrl(
        Uri.parse(qualities[index].url),
      );
      await videoController!.initialize();

      if (position != null && position.inSeconds > 0) {
        await videoController!.seekTo(position);
      }

      videoController!.addListener(_onPlayerStateChanged);

      chewieController.value = oldChewie?.copyWith(
        videoPlayerController: videoController!,
      );
      chewieController.value?.addListener(_onFullscreenChanged);

      currentQualityIndex.value = index;

      if (wasPlaying) {
        videoController!.play();
      }
    } catch (e) {
      videoController = oldController;
      videoController?.addListener(_onPlayerStateChanged);
      chewieController.value = oldChewie;
      projectLogger.e("Quality switch error: $e");
    } finally {
      oldController?.dispose();
    }
  }

  void _onPlayerStateChanged() {
    final v = videoController!.value;

    if (v.duration.inSeconds > 0) {
      _videoDurationSeconds ??= v.duration.inSeconds;
    }

    if (v.isPlaying) {
      _onPlay();
    } else {
      _onPause();
    }
  }

  void _onFullscreenChanged() {
    final chewie = chewieController.value;
    if (chewie == null) return;
    isFullScreen.value = chewie.isFullScreen;
  }

  void _onPlay() {
    if (!_isPlaying) {
      _isPlaying = true;
      _sessionStart ??= DateTime.now();
      if (!logInitialized) _createInitialLog();
    }
  }

  void _onPause() {
    if (_isPlaying) {
      _isPlaying = false;
      if (_sessionStart != null) {
        final sessionSeconds =
            DateTime.now().difference(_sessionStart!).inSeconds;
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

  @override
  void onClose() {
    if (_sessionStart != null) {
      final sessionSeconds =
          DateTime.now().difference(_sessionStart!).inSeconds;
      _accumulatedSeconds += sessionSeconds;
      _sessionStart = null;
      viewDurationSeconds.value = _accumulatedSeconds;
    }

    if (logInitialized &&
        _logId != null &&
        viewDurationSeconds.value > _lastLoggedDuration) {
      try {
        final finalData = {
          "user_id": user["id"],
          "type": "video_view",
          "video_url": videoUrl,
          "view_duration_seconds": viewDurationSeconds.value,
          "viewed": _thresholdReached,
          "video_total_duration_seconds": _videoDurationSeconds,
          "data": {
            "video_url": videoUrl,
            "view_duration_seconds": viewDurationSeconds.value,
            "viewed": _thresholdReached,
            "video_total_duration_seconds": _videoDurationSeconds,
          },
        };
        api.updateData("logs", finalData, {"id": _logId!});
        projectLogger.i(
          "Final log update: ${viewDurationSeconds.value}s (id: $_logId)",
        );
      } catch (e) {
        projectLogger.e("Error on final log update: $e");
      }
    }

    _durationTimer?.cancel();
    _logTimer?.cancel();
    chewieController.value?.removeListener(_onFullscreenChanged);
    videoController?.dispose();
    chewieController.value?.dispose();
    super.onClose();
  }
}
