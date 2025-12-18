import 'dart:async';
import 'dart:convert';
import 'package:awesome_video_player/awesome_video_player.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:shobaki_academy/services/api.dart';
import 'package:shobaki_academy/services/locale_db.dart';
import 'package:shobaki_academy/services/statics.dart';

class WatchingController extends GetxController {
  final String videoUrl;
  BetterPlayerController? betterPlayerController;
  final RxBool isLoading = true.obs;
  final RxString errorMessage = ''.obs;
  final RxBool isLive = false.obs;
  late Map<String, dynamic> user;

  // View duration tracking
  final RxInt viewDurationSeconds = 0.obs;
  Timer? _viewTrackingTimer;
  Timer? _logSaveTimer;
  bool _isVideoPlaying = false;
  DateTime? _sessionStartTime;

  // Log tracking
  final api = ApiClient();
  int _lastLoggedDuration = 0;
  String? _currentLogId; // Store the log ID for updates

  // Video duration & view threshold tracking
  int? _videoDurationSeconds;
  bool _viewThresholdReached = false;
  bool _logInitialized = false; // Track if initial log was created

  WatchingController(this.videoUrl);

  @override
  void onInit() {
    super.onInit();
    _initialize();
    _startViewTracking();
  }

  Future<void> _initialize() async {
    final db = Get.find<LocalDB>();
    final localDb = db.sharedPref;
    final jsonUser = localDb?.getString('UserData');
    if (jsonUser == null) return;
    user = json.decode(jsonUser);

    try {
      try {
        await _initializeVideo();
      } finally {}
    } catch (e) {
      rethrow;
    } finally {
      isLoading.value = false;
    }
  }

  Future<void> _initializeVideo() async {
    if (isLive.value) {
      await _initializeLiveStream();
    } else {
      await _initializeRegularVideo();
    }
  }

  Future<void> _initializeLiveStream() async {
    betterPlayerController = BetterPlayerController(
      BetterPlayerConfiguration(
        autoPlay: true,
        allowedScreenSleep: false,
        controlsConfiguration: BetterPlayerControlsConfiguration(
          enableFullscreen: true,
          enablePlayPause: false,
          enablePlaybackSpeed: false,
          enableQualities: true,
          enableAudioTracks: false,
          enableMute: true,
          enableSubtitles: false,
          progressBarHandleColor: Colors.red,
          progressBarPlayedColor: Colors.red,
          progressBarBufferedColor: Colors.red[300]!,
          loadingWidget: Builder(builder: (context) => loading(context)),
        ),
        deviceOrientationsAfterFullScreen: [DeviceOrientation.portraitUp],
      ),
      betterPlayerDataSource: BetterPlayerDataSource.network(
        videoUrl,
        videoFormat: BetterPlayerVideoFormat.hls,
        liveStream: true,
      ),
    );
    _attachPlayerListeners();
  }

  Future<void> _initializeRegularVideo() async {
    betterPlayerController = BetterPlayerController(
      BetterPlayerConfiguration(
        autoPlay: false,
        allowedScreenSleep: false,
        controlsConfiguration: BetterPlayerControlsConfiguration(
          enableFullscreen: true,
          enablePlayPause: true,
          enablePlaybackSpeed: true,
          enableQualities: true, // Enable quality selection
          enableAudioTracks: false,
          enableMute: false,
          enableSubtitles: false,
          progressBarHandleColor: Colors.red,
          progressBarPlayedColor: Colors.red,
          progressBarBufferedColor: Colors.red[300]!,
          loadingWidget: Builder(builder: (context) => loading(context)),
        ),
        deviceOrientationsAfterFullScreen: [DeviceOrientation.portraitUp],
        placeholder: Center(
          child: Builder(
            builder: (context) {
              return loading(context);
            },
          ),
        ),
      ),
      betterPlayerDataSource: BetterPlayerDataSource.network(
        videoUrl,
        cacheConfiguration: BetterPlayerCacheConfiguration(
          useCache: true,
          preCacheSize: 10 * 1024 * 1024, // 10MB pre-cache
          maxCacheSize: 100 * 1024 * 1024, // 100MB max cache
          maxCacheFileSize: 10 * 1024 * 1024, // 10MB per file
        ),
        videoFormat: BetterPlayerVideoFormat.hls,
      ),
    );
    _attachPlayerListeners();
  }

  /// Attach listeners to track play/pause state and video duration
  void _attachPlayerListeners() {
    if (betterPlayerController == null) return;

    betterPlayerController!.addEventsListener((event) {
      if (event.betterPlayerEventType == BetterPlayerEventType.play) {
        _isVideoPlaying = true;
        _sessionStartTime ??= DateTime.now();

        // Create initial log on first play
        if (!_logInitialized) {
          _createInitialLog();
        }
        projectLogger.i('Video playing');
      } else if (event.betterPlayerEventType == BetterPlayerEventType.pause) {
        _isVideoPlaying = false;
        projectLogger.i('Video paused');
      } else if (event.betterPlayerEventType ==
          BetterPlayerEventType.initialized) {
        _videoDurationSeconds = betterPlayerController!
            .videoPlayerController
            ?.value
            .duration
            ?.inSeconds;
        projectLogger.i('Video duration: ${_videoDurationSeconds}s');
      }
    });
  }

  /// Create initial log entry when video starts playing
  Future<void> _createInitialLog() async {
    try {
      final logData = {
        'user_id': user['id'],
        'type': 'video_view',
        'video_url': videoUrl,
        'view_duration_seconds': 0,
        'viewed': false,
        'video_total_duration_seconds': _videoDurationSeconds,
        'data': {
          'video_url': videoUrl,
          'view_duration_seconds': 0,
          'viewed': false,
          'video_total_duration_seconds': _videoDurationSeconds,
        },
      };

      final response = await api.insertData('logs', logData);
      _logInitialized = true;

      // Extract log ID from response
      if (response.containsKey('id')) {
        _currentLogId = response['id'].toString();
        projectLogger.i('Initial log created with ID: $_currentLogId');
      }
    } catch (e) {
      projectLogger.e('Error creating initial log: $e');
    }
  }

  /// Start tracking view duration every second
  void _startViewTracking() {
    _viewTrackingTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (_isVideoPlaying && _sessionStartTime != null) {
        final elapsed = DateTime.now().difference(_sessionStartTime!).inSeconds;
        viewDurationSeconds.value = elapsed;
        _checkViewThreshold();
      }
    });

    // Update log every 4 seconds instead of creating new ones
    _logSaveTimer = Timer.periodic(const Duration(seconds: 4), (_) {
      if (_isVideoPlaying &&
          viewDurationSeconds.value > _lastLoggedDuration &&
          _currentLogId != null) {
        _updateViewLog();
      }
    });
  }

  /// Check if user has watched more than 25% of the video
  void _checkViewThreshold() {
    if (_videoDurationSeconds == null || _videoDurationSeconds == 0) return;
    if (_viewThresholdReached) return;

    final threshold = (_videoDurationSeconds! * 0.25).toInt();
    if (viewDurationSeconds.value >= threshold) {
      _viewThresholdReached = true;
      projectLogger.i(
        'View threshold reached! User watched 25% of video (${viewDurationSeconds.value}s / ${_videoDurationSeconds}s)',
      );
    }
  }

  /// Update existing log by ID every 4 seconds
  Future<void> _updateViewLog() async {
    try {
      if (_currentLogId == null) return;

      final currentDuration = viewDurationSeconds.value;
      if (currentDuration <= _lastLoggedDuration) return;

      final logData = {
        'user_id': user['id'],
        'type': 'video_view',
        'video_url': videoUrl,
        'view_duration_seconds': currentDuration,
        'viewed': _viewThresholdReached,
        'video_total_duration_seconds': _videoDurationSeconds,
        'data': {
          'video_url': videoUrl,
          'view_duration_seconds': currentDuration,
          'viewed': _viewThresholdReached,
          'video_total_duration_seconds': _videoDurationSeconds,
        },
      };

      // Update log by ID
      await api.updateData('logs', logData, {'id': _currentLogId!});

      _lastLoggedDuration = currentDuration;
      projectLogger.i(
        'Log updated (ID: $_currentLogId): ${currentDuration}s (viewed: ${_viewThresholdReached})',
      );
    } catch (e) {
      projectLogger.e('Error updating view log: $e');
    }
  }

  @override
  void onClose() {
    _viewTrackingTimer?.cancel();
    _logSaveTimer?.cancel();
    betterPlayerController?.dispose();
    super.onClose();
  }
}
