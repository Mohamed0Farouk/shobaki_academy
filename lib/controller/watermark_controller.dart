import 'dart:async';
import 'dart:convert';
import 'dart:io';
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

  String? _ipAddress;

  @override
  void onInit() {
    super.onInit();
    _fetchIp();
    updateWatermark();
  }

  Future<void> _fetchIp() async {
    try {
      final interfaces = await NetworkInterface.list();
      for (final interface in interfaces) {
        for (final addr in interface.addresses) {
          if (addr.type == InternetAddressType.IPv4 && !addr.isLoopback) {
            _ipAddress = addr.address;
            return;
          }
        }
      }
      _ipAddress = 'No IP';
    } catch (e) {
      _ipAddress = 'Unknown IP';
    }
  }

  Future<void> updateWatermark() async {
    final localDb = services.sharedPref;
    final jsonUserData = localDb?.getString('UserData');

    if (jsonUserData != null) {
      final Map userData = jsonDecode(jsonUserData);
      if (userData['email'] == "guest@example.com") {
        waterMark.value = 'Al-Shobaki Academy';
        return;
      }
    }

    final now = DateTime.now();
    final currentDate =
        '${now.year}/${now.month.toString().padLeft(2, '0')}/${now.day.toString().padLeft(2, '0')}';

    if (_ipAddress == null) await _fetchIp();

    String name = '';
    String phone = '';
    if (jsonUserData != null) {
      final Map userData = jsonDecode(jsonUserData);
      name = userData['name'] ?? '';
      phone = userData['phone_number'] ?? '';
    }

    waterMark.value = [
      if (name.isNotEmpty) 'Name: $name',
      if (phone.isNotEmpty) 'Phone Number: $phone',
      'IP: ${_ipAddress ?? 'Unknown'}',
      'Date: $currentDate',
    ].join('\n');
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
              color: Colors.black.withValues(alpha: 0.7),
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
          color: Colors.black.withValues(alpha: 0.7),
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
