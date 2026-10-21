import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:shobaki_academy/services/api.dart';
import 'package:shobaki_academy/services/app_version.dart';
import 'package:shobaki_academy/services/statics.dart';
import 'package:url_launcher/url_launcher.dart';

class VersionController extends GetxController {
  RxBool updateRequired = false.obs;
  RxString currentVersion = ''.obs;
  RxString dbVersion = ''.obs;

  /// Multi-line "what's new" text for this platform, from
  /// `application_manfist.platforms_versions`. Empty when the dashboard has
  /// none, in which case the section is hidden.
  RxString whatsNew = ''.obs;

  final ApiClient _apiClient = ApiClient();
  Timer? _bottomSheetMonitorTimer;
  bool _isMonitoring = false;

  @override
  void onInit() {
    super.onInit();
    _initializeVersionCheck();
  }

  @override
  void onClose() {
    _bottomSheetMonitorTimer?.cancel();
    super.onClose();
  }

  Future<void> _initializeVersionCheck() async {
    // Get current app version
    final packageInfo = await PackageInfo.fromPlatform();
    currentVersion.value = packageInfo.version;

    // Check version on app start
    await _checkVersionUpdate();

    // Optionally, check version periodically (e.g., every 5 minutes)
    // TODO: Uncomment if you want periodic checks
    // Timer.periodic(const Duration(minutes: 5), (_) async {
    //   await _checkVersionUpdate();
    // });
  }

  Future<void> _checkVersionUpdate() async {
    try {
      final manifestData = await _apiClient.fetchData('application_manfist');
      if (manifestData.isEmpty) return;

      final entry = parsePlatformVersionEntry(
        manifestData[0]['platforms_versions'],
        platform: Platform.operatingSystem,
      );
      // No entry for this platform means nothing is being forced here.
      if (entry == null) return;

      dbVersion.value = entry.version;
      projectLogger.i(
        'Current Version: ${currentVersion.value}, '
        'required for ${Platform.operatingSystem}: ${entry.version}',
      );

      if (!isVersionAtLeast(currentVersion.value, entry.version)) {
        whatsNew.value = entry.whatsNew ?? '';
        updateRequired.value = true;
        _showUpdateBottomSheet();
      }
    } catch (e) {
      projectLogger.w('Error checking version: $e');
    }
  }

  String _getStoreUrl() {
    if (Platform.isAndroid) {
      // Replace with your actual Google Play package ID
      return 'https://play.google.com/store/apps/details?id=com.mohamedfarouk.shobaki_academy';
    } else if (Platform.isIOS) {
      // Replace with your actual App Store app ID
      return 'https://apps.apple.com/us/app/alshobaki-academy/id6759484066';
    } else if (Platform.isWindows) {
      // Replace with your actual Microsoft Store app ID
      return 'https://apps.microsoft.com/detail/9N6B7HWQC1NC';
    } else if (Platform.isMacOS) {
      // Replace with your actual Mac App Store app ID
      return 'https://apps.apple.com/us/app/alshobaki-academy/id6759484066?platform=mac';
    }
    return '';
  }

  Future<void> _launchAppStore() async {
    final url = _getStoreUrl();
    if (url.isEmpty) return;

    try {
      if (await canLaunchUrl(Uri.parse(url))) {
        await launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
      } else {
        Get.snackbar(
          'خطأ',
          'لا يمكن فتح متجر التطبيقات',
          snackPosition: SnackPosition.BOTTOM,
        );
      }
    } catch (e) {
      Get.snackbar(
        'خطأ',
        'حدث خطأ أثناء محاولة فتح متجر التطبيقات',
        snackPosition: SnackPosition.BOTTOM,
      );
    }
  }

  /// The forced-update sheet. Built once and reused by both the initial show
  /// and the 500 ms re-show monitor, which used to carry an identical copy of
  /// this widget tree.
  Widget _buildUpdateSheet() {
    final primaryColor = Theme.of(Get.context!).primaryColor;
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.system_update, size: 100, color: primaryColor),
          const SizedBox(height: 20),
          Text(
            'تحديث متاح',
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: Colors.black,
            ),
          ),
          const SizedBox(height: 10),
          Text(
            'يرجى تحديث التطبيق إلى الإصدار الأحدث',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 14, color: Colors.grey[700]),
          ),
          if (whatsNew.value.isNotEmpty) ...[
            const SizedBox(height: 16),
            // Explicitly right-aligned: the label must sit on the right even
            // though the surrounding sheet has no RTL Directionality.
            const Align(
              alignment: Alignment.centerRight,
              child: Text(
                'ما الجديد',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: Colors.black,
                ),
              ),
            ),
            const SizedBox(height: 8),
            // Constrained + scrollable: the changelog is authored in the
            // dashboard and can be arbitrarily long; without this it would
            // push the update button off the sheet.
            ConstrainedBox(
              constraints: const BoxConstraints(maxHeight: 200),
              child: SingleChildScrollView(
                child: Text(
                  whatsNew.value,
                  textDirection: TextDirection.rtl,
                  textAlign: TextAlign.right,
                  style: TextStyle(fontSize: 14, color: Colors.grey[800]),
                ),
              ),
            ),
          ],
          const SizedBox(height: 20),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: _launchAppStore,
              style: ElevatedButton.styleFrom(
                backgroundColor: primaryColor,
                padding: const EdgeInsets.symmetric(vertical: 12),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
              child: const Text(
                'تحديث الآن',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _showUpdateBottomSheet() {
    Get.bottomSheet(
      _buildUpdateSheet(),
      isDismissible: false, // User cannot dismiss this bottom sheet
      enableDrag: false, // Disable dragging the bottom sheet
      backgroundColor: Colors.transparent,
    );

    // Start monitoring to ensure bottom sheet is always shown
    if (!_isMonitoring) {
      _isMonitoring = true;
      _startBottomSheetMonitoring();
    }
  }

  void _startBottomSheetMonitoring() {
    // Check every 500ms if bottom sheet is still open
    _bottomSheetMonitorTimer = Timer.periodic(
      const Duration(milliseconds: 500),
      (_) {
        if (updateRequired.value && !_isBottomSheetOpen()) {
          // Reshow the bottom sheet
          Get.bottomSheet(
            _buildUpdateSheet(),
            isDismissible: false,
            enableDrag: false,
            backgroundColor: Colors.transparent,
          );
        }
      },
    );
  }

  bool _isBottomSheetOpen() {
    // Check if any bottomsheet is currently open by looking at the route stack
    try {
      return Get.isBottomSheetOpen ?? false;
    } catch (e) {
      return false;
    }
  }
}
