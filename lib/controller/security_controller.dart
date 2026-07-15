import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:shobaki_academy/controller/auth_controller.dart';
import 'package:shobaki_academy/services/api.dart';
import 'package:shobaki_academy/services/statics.dart';
import 'package:shobaki_academy/services/whatsapp_notification.dart';

enum DetectionType { none, recording, screenshot }

class SecurityController extends GetxController {
  static const _channel = MethodChannel('shobaki/security');

  final detectionType = DetectionType.none.obs;
  final isRecordingDetected = false.obs;
  final isScreenshotDetected = false.obs;
  final detectedApps = <String>[].obs;
  final countdown = 60.obs;
  final isFlickering = false.obs;
  final isMobileRecording = false.obs;

  Timer? _countdownTimer;
  Timer? _timer;
  Timer? _flickerTimer;
  bool _wasDetected = false;
  int _currentStage = -1;
  final Set<int> _stagesExecuted = {};
  DateTime? _detectionTime;
  bool _pendingBlock = false;

  void onRecordingDetected(List<String> apps, {bool isMobile = false}) {
    if (isRecordingDetected.value) {
      detectedApps.assignAll(apps);
      return;
    }
    detectedApps.assignAll(apps);
    isRecordingDetected.value = true;
    detectionType.value = DetectionType.recording;
    isMobileRecording.value = isMobile;
    _detectionTime = DateTime.now();
    _currentStage = -1;
    _stagesExecuted.clear();
    _startCountdown();
  }

  void onRecordingCleared() {
    _pendingBlock = false;
    isRecordingDetected.value = false;
    detectionType.value = DetectionType.none;
    isFlickering.value = false;
    _flickerTimer?.cancel();
    _flickerTimer = null;
    _cancelCountdown();
    countdown.value = 60;
    _currentStage = -1;
    _stagesExecuted.clear();
  }

  void onScreenshotDetected(String appName) {
    detectedApps.assignAll([appName]);
    isScreenshotDetected.value = true;
    detectionType.value = DetectionType.screenshot;
    _detectionTime = DateTime.now();
    _sendScreenshotAlert();
    _showScreenshotAlert();
    Future.delayed(const Duration(seconds: 5), () {
      if (detectionType.value == DetectionType.screenshot) {
        onScreenshotCleared();
      }
    });
  }

  void onScreenshotCleared() {
    isScreenshotDetected.value = false;
    detectionType.value = DetectionType.none;
  }

  void _startCountdown() {
    _cancelCountdown();
    countdown.value = 60;
    _currentStage = -1;
    _countdownTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (countdown.value > 0) {
        countdown.value--;
      }
      _checkStageTransition();
    });
  }

  void _checkStageTransition() {
    final stage = _warningStage(countdown.value);
    if (stage != _currentStage) {
      _currentStage = stage;
      if (!_stagesExecuted.contains(stage)) {
        _stagesExecuted.add(stage);
        _executeStageAction(stage);
      }
    }
  }

  int _warningStage(int seconds) {
    if (seconds > 30) return 0;
    if (seconds > 15) return 1;
    if (seconds > 5) return 2;
    return 3;
  }

  Future<void> _executeStageAction(int stage) async {
    switch (stage) {
      case 0:
        await _sendRecordingAlert();
        break;
      case 1:
        _navigateToHome();
        break;
      case 2:
        break;
      case 3:
        _startFlicker();
        _pendingBlock = true;
        while (_pendingBlock && countdown.value > 0) {
          await Future.delayed(const Duration(milliseconds: 100));
        }
        if (!_pendingBlock) return;
        _pendingBlock = false;
        await _blockAndLogout();
        _flickerTimer?.cancel();
        _flickerTimer = null;
        isFlickering.value = false;
        break;
    }
  }

  /// Send initial recording detection alert (stage 0)
  Future<void> _sendRecordingAlert() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString('UserData');
      if (raw == null) return;
      final user = jsonDecode(raw) as Map<String, dynamic>;
      if (user['email']?.toString() == 'guest@example.com') return;

      final message = WhatsAppNotification.buildScreenshotAlertMessage(
        student: user,
        detectedApp: detectedApps.join('، '),
        detectionTime: _detectionTime ?? DateTime.now(),
      );
      await WhatsAppNotification.sendAdminMessage(message);
    } catch (_) {}
  }

  /// Send screenshot detection alert
  Future<void> _sendScreenshotAlert() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString('UserData');
      if (raw == null) return;
      final user = jsonDecode(raw) as Map<String, dynamic>;
      if (user['email']?.toString() == 'guest@example.com') return;

      final message = WhatsAppNotification.buildScreenshotAlertMessage(
        student: user,
        detectedApp: detectedApps.isNotEmpty ? detectedApps.first : 'غير معروف',
        detectionTime: _detectionTime ?? DateTime.now(),
      );
      await WhatsAppNotification.sendAdminMessage(message);
    } catch (_) {}
  }

  /// Send block notification when 60s countdown ends (before disabling account)
  Future<void> _sendBlockNotification(Map<String, dynamic> user) async {
    try {
      if (user['email']?.toString() == 'guest@example.com') return;

      final message = WhatsAppNotification.buildBlockMessage(
        student: user,
        detectedApps: detectedApps.toList(),
        detectionTime: _detectionTime ?? DateTime.now(),
      );
      await WhatsAppNotification.sendAdminMessage(message);
    } catch (_) {}
  }

  void _navigateToHome() {
    Get.offAllNamed('/home');
  }

  void _startFlicker() {
    isFlickering.value = true;
    _flickerTimer?.cancel();
    _flickerTimer = Timer.periodic(const Duration(milliseconds: 150), (_) {
      isFlickering.value = !isFlickering.value;
    });
  }

  Future<void> _blockAndLogout() async {
    _cancelCountdown();
    _timer?.cancel();
    _timer = null;

    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString('UserData');
      if (raw != null) {
        final user = jsonDecode(raw) as Map<String, dynamic>;
        if (user['email']?.toString() == 'guest@example.com') {
          await AuthController.to.signout(reason: 'blocked_by_security');
          return;
        }

        // Send block notification BEFORE disabling the account
        await _sendBlockNotification(user);

        final api = ApiClient();
        await api.updateData(
          'students',
          {'disabled': true},
          {'id': user['id']},
        );
      }
    } catch (_) {}
    await AuthController.to.signout(reason: 'blocked_by_security');
  }

  Future<void> closeDetectedApp(String appName) async {
    try {
      await _channel.invokeMethod('closeDetectedApp', appName);
    } catch (_) {}
  }

  Future<void> closeAllDetectedApps() async {
    try {
      await _channel.invokeMethod('closeAllDetectedApps');
    } catch (_) {}
  }

  void _showScreenshotAlert() {
    showSnackbar(
      'تنبيه',
      'تم اكتشاف محاولة تصوير للشاشة\nتم توثيق هذه المحاولة وإرسال تنبيه للمشرف',
      backgroundColor: const Color(0xFFE53935),
    );
  }

  void _cancelCountdown() {
    _countdownTimer?.cancel();
    _countdownTimer = null;
  }

  @override
  void onInit() {
    super.onInit();
    if (Platform.isWindows || Platform.isMacOS || Platform.isIOS) {
      _startMonitoring();
    }
  }

  void _startMonitoring() {
    _timer = Timer.periodic(const Duration(seconds: 1), (_) async {
      try {
        final apps = (await _channel.invokeMethod<List<dynamic>>('getDetectedApps') ?? [])
            .cast<String>();

        if (apps.isNotEmpty && !_wasDetected) {
          onRecordingDetected(apps);
        } else if (apps.isNotEmpty && _wasDetected) {
          detectedApps.assignAll(apps);
        } else if (apps.isEmpty && _wasDetected) {
          onRecordingCleared();
        }

        _wasDetected = apps.isNotEmpty;
      } catch (_) {}
    });
  }

  @override
  void onClose() {
    _timer?.cancel();
    _flickerTimer?.cancel();
    _cancelCountdown();
    super.onClose();
  }
}