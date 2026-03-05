import 'dart:async';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:shobaki_academy/controller/auth_controller.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class DeviceGuardController extends GetxController {
  final _client = Supabase.instance.client;

  StreamSubscription? _subscription;
  bool _isChecking = false;

  String? _userId;
  String? _localFingerprint;

  /// Call this after login
  Future<void> start({
    required String userId,
    required String localFingerprint,
  }) async {
    _userId = userId;
    _localFingerprint = localFingerprint;
    print(
      '[DeviceGuard] Started for user $_userId with fingerprint $_localFingerprint',
    );

    _startPolling();
  }

  void _startPolling() {
    _subscription = Stream.periodic(const Duration(seconds: 15)).listen((
      _,
    ) async {
      if (_isChecking || _userId == null) return;

      print('[DeviceGuard] Checking device fingerprint for user $_userId');

      _isChecking = true;

      try {
        final response = await _client
            .from('students')
            .select('device_fingerprint')
            .eq('id', _userId!)
            .single();

        final serverFingerprint = response['device_fingerprint'];
        print(
          '[DeviceGuard] Server fingerprint: $serverFingerprint, Local fingerprint: $_localFingerprint',
        );

        if (serverFingerprint != _localFingerprint) {
          Get.snackbar(
            'الجهاز غير مطابق',
            'لقد تم تعديل الجهاز المستخدم في تسجيل الدخول من مكان آخر. تم تسجيل خروجك.',
            backgroundColor: Colors.redAccent,
            snackPosition: SnackPosition.BOTTOM,
            duration: const Duration(seconds: 5),
          );
          await _forceLogout();
        }
      } catch (e) {
        // Optional: handle network errors
      }

      _isChecking = false;
    });
  }

  Future<void> _forceLogout() async {
    final auth = Get.put(AuthController());

    _subscription?.cancel();
    await auth.signout();
    stop();
  }

  void stop() {
    print(
      '[DeviceGuard] Stopping for user $_userId with fingerprint $_localFingerprint',
    );

    _subscription?.cancel();
  }

  Future<bool> checkNow() async {
    if (_isChecking || _userId == null) return true;
    print('[DeviceGuard] Checking device fingerprint for user $_userId');

    _isChecking = true;

    try {
      final response = await _client
          .from('students')
          .select('device_fingerprint')
          .eq('id', _userId!)
          .single();

      final serverFingerprint = response['device_fingerprint'];

      if (serverFingerprint != _localFingerprint) {
        Get.snackbar(
          'الجهاز غير مطابق',
          'لقد تم تعديل الجهاز المستخدم في تسجيل الدخول من مكان آخر. تم تسجيل خروجك.',
          backgroundColor: Colors.redAccent,
          snackPosition: SnackPosition.BOTTOM,
          duration: const Duration(seconds: 5),
        );
        await _forceLogout();
        return false;
      }

      return true;
    } catch (e) {
      // If network error, we don't logout immediately
      return true;
    } finally {
      _isChecking = false;
    }
  }

  @override
  void onClose() {
    _subscription?.cancel();
    super.onClose();
  }
}
