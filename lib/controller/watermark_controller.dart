import 'dart:async';
import 'dart:convert';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:shobaki_academy/services/locale_db.dart';

class WatermarkController extends GetxController {
  RxBool showWatermark = false.obs;
  final LocalDB services = Get.find();
  final Random _random = Random();

  final left = 0.0.obs;
  final top = 0.0.obs;

  Timer? _timer;

  RxString waterMark = 'watermark'.obs;

  @override
  void onInit() {
    super.onInit();
    // Load watermark details from local storage.
    final localDb = services.sharedPref;
    final jsonUserData = localDb?.getString('UserData');

    if (jsonUserData != null) {
      final Map userData = jsonDecode(jsonUserData);
      if (userData['email'] == "guest@example.com") {
        waterMark.value = 'Al-Shobaki Academy';
      } else {
        waterMark.value = '${userData['name']}\n${userData['phone_number']}';
      }
    } else {
      waterMark.value =
          'Al-Shobaki Academy'; // fallback for first launch or missing data
    }
  }

  /// Shows the watermark as a dialog popup.
  void showWatermarkDialog() {
    Get.dialog(
      Center(
        child: Material(
          color: Colors.transparent,
          child: Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Colors.black.withOpacity(0.7),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Text(
              waterMark.value,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ),
      ),
      barrierDismissible: false,
    );
  }

  /// Shows the watermark as a bottom sheet.
  void showWatermarkBottomSheet() {
    Get.bottomSheet(
      Container(
        width: double.infinity,
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: Colors.black.withOpacity(0.7),
          borderRadius: const BorderRadius.only(
            topLeft: Radius.circular(15),
            topRight: Radius.circular(15),
          ),
        ),
        child: Text(
          waterMark.value,
          textAlign: TextAlign.center,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
      backgroundColor: Colors.transparent,
      isScrollControlled: false,
    );
  }

  /// Example method to toggle watermark state if needed.
  void updateWaterMarkState(bool value) {
    showWatermark.value = value;
  }

  void start() {
    _timer ??= Timer.periodic(const Duration(seconds: 4), (_) {
      left.value = _random.nextDouble() * 0.7;
      top.value = _random.nextDouble() * 0.7;
    });
  }

  void stop() {
    _timer?.cancel();
    _timer = null;
  }

  @override
  void onClose() {
    stop();
    super.onClose();
  }
}
