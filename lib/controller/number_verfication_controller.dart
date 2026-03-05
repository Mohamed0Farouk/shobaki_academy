import 'dart:async';
import 'dart:convert';
import 'package:get/get.dart';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:shobaki_academy/services/api.dart';
import 'package:shobaki_academy/services/locale_db.dart';
import 'package:shobaki_academy/services/statics.dart';

class NumberVerificationController extends GetxController {
  final LocalDB db = Get.find();
  late final String apiUrl;
  late final SharedPreferences? localDb;

  var phoneNumber = ''.obs;
  RxMap userData = {}.obs;
  var studentId = ''.obs;
  var otp = ''.obs;
  RxBool isVerified = false.obs;

  var timer = 0.obs;
  var canResend = true.obs;
  Timer? _countdownTimer;
  int resendAttempts = 0;

  @override
  void onInit() {
    super.onInit();
    localDb = db.sharedPref;
    final jsonUser = localDb?.getString('UserData');
    if (jsonUser != null) {
      final user = jsonDecode(jsonUser);
      userData.value = user;
      phoneNumber.value = user['phone_number'] ?? '';
      studentId.value = user['id']?.toString() ?? '';
    }
    dotenv
        .load(fileName: '.env')
        .then((_) {
          apiUrl = dotenv.get('ALSHOBAKI_API', fallback: '');
        })
        .then((_) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (!isVerified.value) {
              Future.microtask(() async {
                loadingDilog(Get.context);
                await sendOtp();
                Get.close(1);
              });
            }
          });
        });
  }

  Future<void> sendOtp() async {
    try {
      print(apiUrl);

      print(
        'Sending OTP to ${phoneNumber.value} for student ID ${studentId.value}',
      );
      await Dio().post(
        '${apiUrl}api/otp/send',
        data: {'id': studentId.value, 'phone': phoneNumber.value},
      );
      _startTimer();
      Get.snackbar(
        'تم الإرسال',
        'تم إرسال الرمز إلى ${phoneNumber.value}',
        backgroundColor: Colors.blue,
        snackPosition: SnackPosition.BOTTOM,
      );
    } catch (e) {
      print(e);
      Get.snackbar(
        'خطأ',
        'فشل إرسال الرمز',
        backgroundColor: Colors.red,
        snackPosition: SnackPosition.BOTTOM,
      );
    }
  }

  Future<void> verifyOtp() async {
    try {
      print(
        "respnose :  Verifying OTP ${otp.value} for student ID ${studentId.value}",
      );
      final response = await Dio().post(
        '${apiUrl}api/otp/verify',
        data: {'id': studentId.value, 'otp': otp.value},
      );
      print("respnose :  $response");
      final isSuccess = response.statusCode == 200;
      if (isSuccess) {
        isVerified.value = true;
        final ApiClient apiClient = ApiClient();
        await apiClient.updateData(
          'students',
          {'verified': true},
          {'id': studentId.value},
        );
        userData['verified'] = true;
        Get.snackbar(
          'تم التحقق',
          'تم التحقق من الرقم بنجاح',
          backgroundColor: Colors.green,
          snackPosition: SnackPosition.BOTTOM,
        );
        // navigate home after verification
        // Get.offAllNamed('/home');
      } else {
        _handleOtpError();
      }
    } catch (e) {
      print(e);
      _handleOtpError();
    }
  }

  void _handleOtpError() {
    otp.value = '';
    Get.snackbar(
      'خطأ',
      'رمز غير صالح، حاول مرة أخرى',
      backgroundColor: Colors.red,
      snackPosition: SnackPosition.BOTTOM,
    );
  }

  void _startTimer() {
    resendAttempts++;
    final duration = 30 * resendAttempts;
    timer.value = duration;
    canResend.value = false;

    _countdownTimer?.cancel();
    _countdownTimer = Timer.periodic(const Duration(seconds: 1), (t) {
      if (timer.value > 0) {
        timer.value--;
      } else {
        canResend.value = true;
        t.cancel();
      }
    });
  }

  @override
  void onClose() {
    _countdownTimer?.cancel();
    super.onClose();
  }
}
