import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:permission_handler/permission_handler.dart';
// ignore: depend_on_referenced_packages
import 'package:universal_html/html.dart' as html;
import 'dart:io';
// ignore: depend_on_referenced_packages
import 'package:path_provider/path_provider.dart';
// ignore: depend_on_referenced_packages
import 'package:http/http.dart' as http;

class PdfController extends GetxController {
  final RxBool isDownloading = false.obs;
  final RxDouble downloadProgress = 0.0.obs;

  Future<void> downloadPdf(String url, String filename) async {
    try {
      isDownloading.value = true;
      downloadProgress.value = 0.0;

      if (GetPlatform.isWeb) {
        _downloadWeb(url, filename);
        return;
      }

      final status = await _requestStoragePermission();
      Get.log('Storage permission status: $status');

      if (!status.isGranted) {
        if (status.isPermanentlyDenied) {
          // Show dialog and open app settings
          Get.defaultDialog(
            title: 'صلاحيات مطلوبة',
            middleText:
                'التطبيق بحاجة إلى صلاحية الوصول إلى التخزين لحفظ الملف. افتح إعدادات التطبيق ومنح الصلاحية.',
            textConfirm: 'فتح الإعدادات',
            onConfirm: () {
              openAppSettings();
              Get.back();
            },
            textCancel: 'إلغاء',
          );
        } else {
          Get.snackbar(
            'خطأ',
            'يرجى منح صلاحية الوصول إلى التخزين ثم حاول مرة أخرى',
            backgroundColor: Colors.red,
            snackPosition: SnackPosition.BOTTOM,
          );
        }
        return;
      }

      final directory = await _getDownloadDirectory();
      final filepath = '${directory.path}/$filename';

      final response = await http.Client().get(Uri.parse(url));
      if (response.statusCode == 200) {
        final file = File(filepath);
        // ensure directory exists
        if (!await file.parent.exists()) {
          await file.parent.create(recursive: true);
        }
        await file.writeAsBytes(response.bodyBytes);

        Get.snackbar(
          'تم التحميل',
          'تم حفظ الملف: $filepath',
          backgroundColor: Colors.green,
          snackPosition: SnackPosition.BOTTOM,
          duration: const Duration(seconds: 6),
        );
      } else {
        throw Exception('Failed to download PDF');
      }
    } catch (e) {
      Get.snackbar(
        'خطأ في التحميل',
        '$e',
        backgroundColor: Colors.red,
        snackPosition: SnackPosition.BOTTOM,
      );
    } finally {
      isDownloading.value = false;
      downloadProgress.value = 0.0;
    }
  }

  Future<PermissionStatus> _requestStoragePermission() async {
    if (GetPlatform.isAndroid) {
      // Try MANAGE_EXTERNAL_STORAGE first (Android 11+). If it succeeds, return it.
      try {
        final manageStatus = await Permission.manageExternalStorage.status;
        if (manageStatus.isGranted) return manageStatus;

        final reqManage = await Permission.manageExternalStorage.request();
        if (reqManage.isGranted) return reqManage;
      } catch (_) {
        // ignore if platform doesn't support manageExternalStorage
      }

      // Fallback to regular storage permission
      final storageStatus = await Permission.storage.request();
      return storageStatus;
    } else if (GetPlatform.isIOS) {
      // Saving to app documents doesn't need Photos permission.
      return PermissionStatus.granted;
    }

    // For other platforms (macOS, Windows, Linux, Web) assume granted
    return PermissionStatus.granted;
  }

  Future<Directory> _getDownloadDirectory() async {
    if (GetPlatform.isAndroid) {
      return Directory('/storage/emulated/0/Download');
    } else if (GetPlatform.isIOS) {
      return await getApplicationDocumentsDirectory();
    } else if (GetPlatform.isMacOS) {
      return Directory('${Platform.environment['HOME']}/Downloads');
    } else if (GetPlatform.isWindows) {
      return Directory('${Platform.environment['USERPROFILE']}\\Downloads');
    } else if (GetPlatform.isLinux) {
      return Directory('${Platform.environment['HOME']}/Downloads');
    }
    return await getApplicationDocumentsDirectory();
  }

  void _downloadWeb(String url, String filename) {
    html.AnchorElement(href: url)
      ..setAttribute('download', filename)
      ..click();
  }
}
