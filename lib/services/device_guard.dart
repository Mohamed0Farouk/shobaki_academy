import 'dart:async';
import 'dart:convert';
import 'dart:io' show Platform;
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:shobaki_academy/controller/auth_controller.dart';
import 'package:shobaki_academy/services/statics.dart';
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
            .select('device_fingerprint, disabled')
            .eq('id', _userId!)
            .single();

        if (response['disabled'] == true) {
          showSnackbar(
            'تم حجب الحساب',
            'لقد تم حجب حسابك. تواصل مع الدعم.',
            backgroundColor: Colors.redAccent,
            snackPosition: SnackPosition.BOTTOM,
            duration: const Duration(seconds: 5),
          );
          await _forceLogout(reason: 'blocked');
          _isChecking = false;
          return;
        }

        final serverFingerprint = response['device_fingerprint'];
        print(
          '[DeviceGuard] Server fingerprint: $serverFingerprint, Local fingerprint: $_localFingerprint',
        );

        if (serverFingerprint != _localFingerprint) {
          showSnackbar(
            'الجهاز غير مطابق',
            'لقد تم تعديل الجهاز المستخدم في تسجيل الدخول من مكان آخر. تم تسجيل خروجك.',
            backgroundColor: Colors.redAccent,
            snackPosition: SnackPosition.BOTTOM,
            duration: const Duration(seconds: 5),
          );
          await _forceLogout(reason: 'device_changed');
        }
      } catch (e) {
        showSnackbar(
          'تم تسجيل خروجك',
          'تم تسجيل خروجك لوجود مشكلة في الاتصال.',
          backgroundColor: Colors.redAccent,
          snackPosition: SnackPosition.BOTTOM,
          duration: const Duration(seconds: 5),
        );
        await _forceLogout(reason: 'server_connection_error , ${e.toString()}');
      }

      _isChecking = false;
    });
  }

  Future<void> _forceLogout({String reason = 'blocked'}) async {
    final auth = Get.put(AuthController());

    String? userName;
    try {
      final jsonUser = auth.db.sharedPref?.getString('UserData');
      if (jsonUser != null) {
        final user = jsonDecode(jsonUser);
        userName = user['name'];
      }
    } catch (_) {}

    try {
      await _client.from('logs').insert({
        'user_id': _userId,
        'type': 'login_blocked',
        'data': {
          'device_fingerprint': _localFingerprint,
          'platform': Platform.operatingSystem,
          'name': userName ?? '',
          'reason': reason,
        },
      });
    } catch (_) {}

    _subscription?.cancel();
    await auth.signout(reason: reason);
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
          .select('device_fingerprint, disabled')
          .eq('id', _userId!)
          .single();

      if (response['disabled'] == true) {
        showSnackbar(
          'تم حجب الحساب',
          'لقد تم حجب حسابك. تواصل مع الدعم.',
          backgroundColor: Colors.redAccent,
          snackPosition: SnackPosition.BOTTOM,
          duration: const Duration(seconds: 5),
        );
        await _forceLogout(reason: 'blocked');
        return false;
      }

      final serverFingerprint = response['device_fingerprint'];

      if (serverFingerprint != _localFingerprint) {
        showSnackbar(
          'الجهاز غير مطابق',
          'لقد تم تعديل الجهاز المستخدم في تسجيل الدخول من مكان آخر. تم تسجيل خروجك.',
          backgroundColor: Colors.redAccent,
          snackPosition: SnackPosition.BOTTOM,
          duration: const Duration(seconds: 5),
        );
        await _forceLogout(reason: 'device_changed');
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
