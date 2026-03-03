import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:shobaki_academy/services/browse_picker.dart';
import 'package:webview_flutter/webview_flutter.dart';
import 'package:vdocipher_flutter/vdocipher_flutter.dart';
import 'package:get/get.dart';
import 'package:path_provider/path_provider.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:shobaki_academy/services/api.dart';
import 'package:shobaki_academy/services/locale_db.dart';
import 'package:shobaki_academy/services/statics.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

//import 'package:webview_windows/webview_windows.dart';

class VdoWatchingController extends GetxController {
  final String videoId;
  final api = ApiClient();
  late final String apiUrl;

  VdoWatchingController(this.videoId);
  //final WebviewController windowsController = WebviewController();

  RxBool isLoading = true.obs;
  RxString errorMessage = ''.obs;

  EmbedInfo? embedInfo;
  WebViewController? webController;

  late Map<String, dynamic> user;

  // View tracking
  final RxInt viewDurationSeconds = 0.obs;
  Timer? _durationTimer;
  Timer? _logTimer;

  bool _isPlaying = false;

  // accumulate played seconds across play/pause sessions
  int _accumulatedSeconds = 0;
  DateTime? _sessionStart; // set when play starts, cleared on pause

  bool logInitialized = false;
  int _lastLoggedDuration = 0;
  bool _thresholdReached = false;
  String? _logId;
  int? _videoDurationSeconds;

  VdoPlayerController? _mobilePlayerController;

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

  Future<void> _initializePlayer() async {
    try {
      await dotenv.load(fileName: '.env').then((_) {
        apiUrl = dotenv.get('ALSHOBAKI_API', fallback: '');
      });
      final otpResponse = await Dio().post(
        "${apiUrl}api/vdocipher/otp",
        data: {
          "videoId": videoId,
          "ttl": 30,
          "userId": user["id"],
          "platform": kIsWeb
              ? "web"
              : Platform.isAndroid
              ? "android"
              : Platform.isIOS
              ? "ios"
              : Platform.isWindows
              ? "windows"
              : Platform.isMacOS
              ? "macos"
              : Platform.isLinux
              ? "linux"
              : "unknown",
        },
      );

      final otp = otpResponse.data["otp"];
      final playbackInfo = otpResponse.data["playbackInfo"];

      embedInfo = EmbedInfo.streaming(
        otp: otp,
        playbackInfo: playbackInfo,
        embedInfoOptions: const EmbedInfoOptions(autoplay: true),
      );
    } catch (e) {
      errorMessage.value = "Failed to load video";
      projectLogger.e("Video init error: $e");
    } finally {
      if (logInitialized) {
        isLoading.value = false;
      }
    }
  }

  void onPlayerCreated(VdoPlayerController? controller) {
    _mobilePlayerController = controller;
    controller?.addListener(() {
      final v = controller.value;

      // Update duration if available
      if (v.duration.inSeconds > 0) {
        _videoDurationSeconds ??= v.duration.inSeconds;
      }

      // Play state handling
      if (v.isPlaying) {
        _onPlay();
      } else {
        _onPause();
      }
    });
  }

  void onFullscreenChange(bool isFullscreen) {}

  void onVdoError(VdoError err) {
    errorMessage.value = "Player error: ${err.message}";
    projectLogger.e("VdoPlayer error: ${err.message}");
  }

  void _onPlay() {
    if (!_isPlaying) {
      _isPlaying = true;
      // start a new play session
      _sessionStart ??= DateTime.now();
      // if we haven't created the initial log yet, do it now
      if (!logInitialized) _createInitialLog();
    }
  }

  void _onPause() {
    if (_isPlaying) {
      _isPlaying = false;
      // accumulate the current session if it exists
      if (_sessionStart != null) {
        final sessionSeconds = DateTime.now()
            .difference(_sessionStart!)
            .inSeconds;
        _accumulatedSeconds += sessionSeconds;
        _sessionStart = null;
        // update observable viewDurationSeconds immediately on pause
        viewDurationSeconds.value = _accumulatedSeconds;
      }
    }
  }

  Future<void> _createInitialLog() async {
    try {
      final supabase = Supabase.instance.client;

      // 1️⃣ Close any previous active logs for this user
      await supabase
          .from('logs')
          .update({'currently_log': false})
          .eq('user_id', user['id'])
          .eq('currently_log', true);

      // 2️⃣ Insert new log
      final logData = {
        'user_id': user['id'],
        'type': 'video_view',
        'video_url': videoId,
        'view_duration_seconds': 0,
        'viewed': false,
        'currently_log': true,
        'video_total_duration_seconds': _videoDurationSeconds,
        'data': {
          'video_url': videoId,
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
      const Duration(seconds: 4),
      (_) => _tickLogging(),
    );
  }

  void _tickDuration() {
    // compute current view duration as accumulated + active session
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
        "video_url": videoId,
        "view_duration_seconds": sec,
        "viewed": _thresholdReached,
        "video_total_duration_seconds": _videoDurationSeconds,
        "data": {
          "video_url": videoId,
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

  String buildVdoHtml({
    required String otp,
    required String playbackInfo,
    required String logId,
    required String userId,
    required String apiEndpoint,
    required int totalDurationSeconds,
    required String videoId,
  }) {
    return '''
<!DOCTYPE html>
<html lang="en">
<head>
  <meta charset="UTF-8">
  <title>Secure Player</title>
  <meta name="viewport" content="width=device-width, initial-scale=1.0">

  <style>
    html, body {
      margin: 0;
      padding: 0;
      height: 100%;
      background: #000;
      color: #fff;
      font-family: Arial, sans-serif;
      overflow: hidden;
    }

    #embedBox {
      width: 100%;
      height: 100%;
    }

    #expired, #concurrent-warning {
      display: none;
      height: 100%;
      align-items: center;
      justify-content: center;
      text-align: center;
      flex-direction: column;
    }

    .message-icon {
      font-size: 48px;
      margin-bottom: 20px;
    }

    #concurrent-warning {
      background: rgba(0, 0, 0, 0.95);
      position: absolute;
      top: 0;
      left: 0;
      width: 100%;
      z-index: 1000;
    }
  </style>
</head>

<body>

<div id="embedBox"></div>

<div id="expired">
  <div>
    <div class="message-icon">⏱️</div>
    <h2>Session Expired</h2>
    <p>Please return to the app to continue watching.</p>
  </div>
</div>

<div id="concurrent-warning">
  <div>
    <div class="message-icon">⚠️</div>
    <h2>Another Video is Playing</h2>
    <p>You are watching another video elsewhere. This session has been stopped.</p>
  </div>
</div>

<!-- VdoCipher Player SDK -->
<script src="https://player.vdocipher.com/v2/api.js"></script>

<script>
(function () {
  'use strict';

  const SESSION_DURATION = 3 * 60 * 60 * 1000; // 3 hours
  const TRACKING_INTERVAL = 10 * 1000; // Track every 10 seconds
  const CONCURRENT_CHECK_INTERVAL = 2 * 1000; // Check every 5 seconds
  const API_ENDPOINT = "$apiEndpoint";
  
  const otp = decodeURIComponent("${Uri.encodeComponent(otp)}");
  const playbackInfo = decodeURIComponent("${Uri.encodeComponent(playbackInfo)}");
  const logId = "$logId";
  const userId = "$userId";
  const videoId = "$videoId";
  const totalDurationSeconds = $totalDurationSeconds;

  const embedBox = document.getElementById("embedBox");
  const expiredDiv = document.getElementById("expired");
  const concurrentWarning = document.getElementById("concurrent-warning");
  
  let sessionStartTime = Date.now();
  let sessionTimer = null;
  let player = null;
  let iframe = null;
  let trackingInterval = null;
  let concurrentCheckInterval = null;
  let lastTrackedSeconds = 0;
  let isConcurrentSession = false;
  let isPlayerReady = false;

  function showExpired(message = null) {
    // Remove iframe
    if (iframe && iframe.parentNode) {
      iframe.parentNode.removeChild(iframe);
      iframe = null;
    }
    
    player = null;
    isPlayerReady = false;
    
    embedBox.style.display = "none";
    expiredDiv.style.display = "flex";
    concurrentWarning.style.display = "none";
    
    if (message) {
      expiredDiv.querySelector('p').textContent = message;
    }

    cleanup();
  }

  function showConcurrentWarning() {
    if (!isConcurrentSession) {
      isConcurrentSession = true;
      
      console.log('⚠️ Concurrent session detected - removing player');
      
      // Remove the iframe completely
      if (iframe && iframe.parentNode) {
        iframe.parentNode.removeChild(iframe);
        iframe = null;
      }
      
      player = null;
      isPlayerReady = false;
      
      // Show warning and stop checking
      embedBox.style.display = "none";
      concurrentWarning.style.display = "flex";
      
      // Stop all intervals since session is over
      cleanup();
    }
  }

  function checkSessionExpiry() {
    const elapsed = Date.now() - sessionStartTime;
    if (elapsed >= SESSION_DURATION) {
      showExpired('Please return to the app to continue watching.');
    }
  }

  async function checkCurrentlyWatching() {
    if (isConcurrentSession) return; // Don't check anymore if already detected
    
    try {
      const response = await fetch(`\${API_ENDPOINT}api/videos/check-log/\${logId}`, {
        method: 'GET',
        headers: {
          'Content-Type': 'application/json',
        }
      });

      if (response.ok) {
        const data = await response.json();
        
        console.log('Concurrent check response:', data);
        console.log('Currently_log status:', data.data.currently_log);
        
        // Check if currently_log flag is false
        if (data.data.currently_log === false) {
          showConcurrentWarning();
        }
      } else {
        console.error('Failed to check concurrent session:', response.status);
      }
    } catch (error) {
      console.error('❌ Error checking concurrent session:', error);
    }
  }

  async function trackViewDuration() {
    if (!player || !isPlayerReady || isConcurrentSession) {
      console.log('⏭️ Skipping tracking - player not ready or concurrent session');
      return;
    }

    try {
      const totalPlayed = await player.api.getTotalPlayed();
      const currentSeconds = Math.floor(totalPlayed);
      
      console.log(`⏱️ Current progress: \${currentSeconds}s / \${totalDurationSeconds}s`);
      
      // Only send if there's meaningful progress (at least 1 second difference)
      if (currentSeconds > lastTrackedSeconds && currentSeconds > 0) {
        lastTrackedSeconds = currentSeconds;
        
        // Calculate if threshold reached (e.g., 80% of video)
        const thresholdReached = totalDurationSeconds > 0 && 
          (currentSeconds / totalDurationSeconds) >= 0.8;

        const logData = {
          id: logId,
          user_id: userId,
          type: "video_view",
          video_url: videoId,
          view_duration_seconds: currentSeconds,
          viewed: thresholdReached,
          video_total_duration_seconds: totalDurationSeconds,
          data: {
            video_url: videoId,
            view_duration_seconds: currentSeconds,
            viewed: thresholdReached,
            video_total_duration_seconds: totalDurationSeconds,
            timestamp: new Date().toISOString()
          },
        };

        console.log('📤 Sending log data:', logData);

        // Send to API
        const response = await fetch(`\${API_ENDPOINT}api/videos/track-view`, {
          method: 'POST',
          headers: {
            'Content-Type': 'application/json',
          },
          body: JSON.stringify(logData)
        });

        if (response.ok) {
          console.log(`💾 View duration tracked successfully: \${currentSeconds}s (\${thresholdReached ? 'COMPLETED' : 'IN PROGRESS'})`);
        } else {
          console.error('Failed to track view duration:', response.status);
        }
      }
    } catch (error) {
      console.error('❌ Error tracking view duration:', error);
    }
  }

  function cleanup() {
    if (sessionTimer) clearTimeout(sessionTimer);
    if (trackingInterval) clearInterval(trackingInterval);
    if (concurrentCheckInterval) clearInterval(concurrentCheckInterval);
    
    try {
      localStorage.clear();
      sessionStorage.clear();
    } catch (_) {}
  }

  // Initialize VdoCipher Player
  window.addEventListener('load', function() {
    try {
      // Create iframe with VdoCipher player URL
      iframe = document.createElement('iframe');
      iframe.id = 'vdo-player-iframe';
      iframe.src = `https://player.vdocipher.com/v2/?otp=\${otp}&playbackInfo=\${playbackInfo}&theme=9ae8bbe8dd964ddc9bdb932cca1cb59a`;
      iframe.style.border = '0';
      iframe.style.width = '100%';
      iframe.style.height = '100%';
      iframe.allow = 'encrypted-media';
      iframe.allowFullscreen = true;
      embedBox.appendChild(iframe);

      console.log('🎬 VdoCipher iframe created');
      console.log(`📊 Video total duration: \${totalDurationSeconds}s`);

      // Wait for iframe to load completely
      iframe.onload = function() {
        console.log('📺 Iframe loaded, getting player instance...');
        
        // Wait for VdoCipher API to be ready
        setTimeout(() => {
          try {
            player = VdoPlayer.getInstance(iframe);
            isPlayerReady = true;
            console.log('✅ Player instance obtained and ready');
            
            // Track immediately
            trackViewDuration();
            
          } catch (error) {
            console.error('❌ Error getting player instance:', error);
            // Retry after delay
            setTimeout(() => {
              try {
                player = VdoPlayer.getInstance(iframe);
                isPlayerReady = true;
                console.log('✅ Player instance obtained (retry)');
                trackViewDuration();
              } catch (e) {
                console.error('❌ Retry failed:', e);
              }
            }, 2000);
          }
        }, 2000);
      };

      // Start tracking view duration every 10 seconds
      trackingInterval = setInterval(trackViewDuration, TRACKING_INTERVAL);

      // Start checking for concurrent sessions every 5 seconds
      concurrentCheckInterval = setInterval(checkCurrentlyWatching, CONCURRENT_CHECK_INTERVAL);

      // Start session expiration timer
      sessionTimer = setTimeout(() => {
        showExpired('Please return to the app to continue watching.');
      }, SESSION_DURATION);

      console.log('✅ Tracking intervals started');

    } catch (error) {
      console.error('❌ Failed to initialize player:', error);
      showExpired('Failed to initialize video player.');
    }
  });

  // Cleanup on page close
  window.addEventListener('beforeunload', () => {
    // Send final tracking update
    if (player && isPlayerReady && !isConcurrentSession) {
      trackViewDuration();
    }
    cleanup();
  });

  // Handle visibility change
  let hiddenTime = null;
  document.addEventListener('visibilitychange', () => {
    if (document.hidden) {
      hiddenTime = Date.now();
      // Track when user leaves
      if (player && isPlayerReady && !isConcurrentSession) {
        trackViewDuration();
      }
    } else if (hiddenTime) {
      const timeHidden = Date.now() - hiddenTime;
      // If away for more than 30 minutes, expire session
      if (timeHidden > 30 * 60 * 1000) {
        showExpired('Session expired due to inactivity.');
      }
      hiddenTime = null;
    }
  });

  // Check session every minute
  setInterval(checkSessionExpiry, 60 * 1000);

})();
</script>

</body>
</html>
''';
  }

  Future<void> openVdoCipherDesktopPlayer({
    required String otp,
    required String playbackInfo,
  }) async {
    if (!(Platform.isWindows || Platform.isMacOS || Platform.isLinux)) {
      return;
    }

    print('logId for desktop player: $_logId');

    final html = buildVdoHtml(
      otp: otp,
      playbackInfo: playbackInfo,
      logId: _logId!,
      userId: user["id"],
      apiEndpoint: apiUrl,
      totalDurationSeconds: _videoDurationSeconds ?? 0,
      videoId: videoId,
    );

    final dir = await getTemporaryDirectory();
    final file = File('${dir.path}/vdo_player.html');

    await file.writeAsString(html, flush: true);

    final uri = Uri.file(file.path);

    if (Platform.isWindows) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);

      Future.delayed(const Duration(minutes: 3), () {
        if (file.existsSync()) {
          file.deleteSync();
        }
      });
    }
    if (Platform.isMacOS) {
      // use the method channel
      await BrowserPicker.open(file.path);
      Future.delayed(const Duration(minutes: 3), () {
        if (file.existsSync()) {
          file.deleteSync();
        }
      });
    }
  }

  /// Called when controller is being closed. Ensure we accumulate any active session and send a final update.
  @override
  void onClose() {
    // If a session is ongoing, accumulate it
    if (_sessionStart != null) {
      final sessionSeconds = DateTime.now()
          .difference(_sessionStart!)
          .inSeconds;
      _accumulatedSeconds += sessionSeconds;
      _sessionStart = null;
      viewDurationSeconds.value = _accumulatedSeconds;
    }

    // Do a final log update if needed
    if (logInitialized &&
        _logId != null &&
        viewDurationSeconds.value > _lastLoggedDuration) {
      try {
        final finalData = {
          "user_id": user["id"],
          "type": "video_view",
          "video_url": videoId,
          "view_duration_seconds": viewDurationSeconds.value,
          "viewed": _thresholdReached,
          "video_total_duration_seconds": _videoDurationSeconds,
          "data": {
            "video_url": videoId,
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
    _mobilePlayerController?.dispose();
    super.onClose();
  }
}
