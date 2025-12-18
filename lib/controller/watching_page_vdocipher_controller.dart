import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:webview_flutter/webview_flutter.dart';
import 'package:vdocipher_flutter/vdocipher_flutter.dart';
import 'package:get/get.dart';

import 'package:shobaki_academy/services/api.dart';
import 'package:shobaki_academy/services/locale_db.dart';
import 'package:shobaki_academy/services/statics.dart';

class VdoWatchingController extends GetxController {
  final String videoId;
  final api = ApiClient();
  late final String apiUrl;

  VdoWatchingController(this.videoId);

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

  bool _logInitialized = false;
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
        data: {"videoId": videoId, "ttl": 30, "userId": user["id"]},
      );

      final otp = otpResponse.data["otp"];
      final playbackInfo = otpResponse.data["playbackInfo"];

      embedInfo = EmbedInfo.streaming(
        otp: otp,
        playbackInfo: playbackInfo,
        embedInfoOptions: const EmbedInfoOptions(autoplay: true),
      );

      if (!kIsWeb &&
          (Platform.isLinux || Platform.isMacOS || Platform.isWindows)) {
        webController = WebViewController()
          ..setJavaScriptMode(JavaScriptMode.unrestricted)
          ..addJavaScriptChannel(
            "FlutterEvents",
            onMessageReceived: (msg) => _onWebEvent(msg.message),
          )
          ..loadHtmlString(_webViewHtml(otp, playbackInfo));
      }
    } catch (e) {
      errorMessage.value = "Failed to load video";
      projectLogger.e("Video init error: $e");
    } finally {
      isLoading.value = false;
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

  void _onWebEvent(String event) {
    if (event == "play") {
      _onPlay();
    } else if (event == "pause") {
      _onPause();
    }
  }

  void _onPlay() {
    if (!_isPlaying) {
      _isPlaying = true;
      // start a new play session
      _sessionStart ??= DateTime.now();
      // if we haven't created the initial log yet, do it now
      if (!_logInitialized) _createInitialLog();
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

  String _webViewHtml(String otp, String playbackInfo) {
    return """
<html>
  <body style="margin:0;background:black;height:100%;width:100%">
    <div id="vdo" style="width:100%;height:100%"></div>
    <script src="https://player.vdocipher.com/v2/api.js"></script>
    <script>
      var player = new VdoPlayer({
        otp: "$otp",
        playbackInfo: "$playbackInfo",
        container: document.getElementById("vdo")
      });
      player.on("play", ()=>FlutterEvents.postMessage("play"));
      player.on("pause", ()=>FlutterEvents.postMessage("pause"));
    </script>
  </body>
</html>
""";
  }

  Future<void> _createInitialLog() async {
    try {
      final logData = {
        "user_id": user["id"],
        "type": "video_view",
        "video_url": videoId,
        "view_duration_seconds": 0,
        "viewed": false,
        "video_total_duration_seconds": _videoDurationSeconds,
        "data": {
          "video_url": videoId,
          "view_duration_seconds": 0,
          "viewed": false,
          "video_total_duration_seconds": _videoDurationSeconds,
        },
      };

      final res = await api.insertData("logs", logData);
      if (res.containsKey("id")) {
        _logId = res["id"].toString();
      } else if (res.keys.isNotEmpty) {
        // fallback: try to stringify first key
        _logId = res.values.first.toString();
      }
      _logInitialized = true;
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
      if (!_logInitialized || _logId == null) return;
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
    if (_logInitialized &&
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
