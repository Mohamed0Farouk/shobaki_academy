import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter/services.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:get/get.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:shobaki_academy/controller/auth_controller.dart';
import 'package:shobaki_academy/services/api.dart';
import 'package:shobaki_academy/services/statics.dart';

enum DetectionType { none, recording, screenshot }

class SecurityController extends GetxController {
  static const _channel = MethodChannel('shobaki/security');

  final detectionType = DetectionType.none.obs;
  final isRecordingDetected = false.obs;
  final isScreenshotDetected = false.obs;
  final detectedApp = ''.obs;
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

  void onRecordingDetected(String appName, {bool isMobile = false}) {
    if (isRecordingDetected.value) return;
    detectedApp.value = appName;
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
    detectedApp.value = appName;
    isScreenshotDetected.value = true;
    detectionType.value = DetectionType.screenshot;
    _detectionTime = DateTime.now();
    _sendWhatsAppAlert();
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
        await _sendWhatsAppAlert();
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

  Future<void> _sendWhatsAppAlert() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString('UserData');
      if (raw != null) {
        final user = jsonDecode(raw);
        if (user['email']?.toString() == 'guest@example.com') return;
      }

      String studentName = 'غير معروف';
      String studentPhone = 'غير معروف';
      if (raw != null) {
        final user = jsonDecode(raw);
        studentName = user['name']?.toString() ?? 'غير معروف';
        studentPhone = user['phone_number']?.toString() ?? 'غير معروف';
      }

      final apiUrl = dotenv.get('ALSHOBAKI_API', fallback: '');
      final adminPhone = dotenv.get('ADMIN_WHATSAPP', fallback: '');
      final ts = _detectionTime ?? DateTime.now();
      final timestamp =
          '${ts.hour}:${ts.minute.toString().padLeft(2, '0')} ${ts.day}/${ts.month}/${ts.year}';

      final message =
          '🚨 تنبيه أمان - محاولة تسجيل شاشة\n'
          'الطالب: $studentName\n'
          'رقم الهاتف: $studentPhone\n'
          'البرنامج المكتشف: ${detectedApp.value}\n'
          'الوقت: $timestamp';

      print('Sending alert: $message');

      await Dio().post(
        '$apiUrl/api/send-message',
        data: {'phone_number': adminPhone, 'message': message},
      );
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
        final user = jsonDecode(raw);
        if (user['email']?.toString() == 'guest@example.com') {
          await AuthController.to.signout();
          return;
        }
        final api = ApiClient();
        await api.updateData(
          'students',
          {'disabled': true},
          {'id': user['id']},
        );
      }
    } catch (_) {}
    await AuthController.to.signout();
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
    if (Platform.isWindows || Platform.isMacOS || Platform.isIOS || Platform.isAndroid) {
      _startMonitoring();
    }
  }

  void _startMonitoring() {
    _timer = Timer.periodic(const Duration(seconds: 1), (_) async {
      try {
        final detected =
            await _channel.invokeMethod<bool>('isRecordingDetected') ?? false;

        if (detected && !_wasDetected) {
          final app =
              await _channel.invokeMethod<String>('getDetectedApp') ?? '';
          onRecordingDetected(app);
        } else if (!detected && _wasDetected) {
          onRecordingCleared();
        }

        _wasDetected = detected;
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
