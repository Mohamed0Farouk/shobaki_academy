import 'package:file_saver/file_saver.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:http/http.dart' as http;

class PdfController extends GetxController {
  final RxBool isDownloading = false.obs;
  final RxDouble downloadProgress = 0.0.obs;

  Future<void> downloadPdf(String url, String filename, bool saveAs) async {
    try {
      isDownloading.value = true;
      downloadProgress.value = 0.0;

      // Strip .pdf extension from filename if present — file_saver appends ext itself
      final name = filename.endsWith('.pdf')
          ? filename.substring(0, filename.length - 4)
          : filename;

      final response = await http.Client().get(Uri.parse(url));

      if (response.statusCode != 200) {
        throw Exception('فشل تحميل الملف (${response.statusCode})');
      }

      if (saveAs) {
        await FileSaver.instance.saveAs(
          name: _sanitizeForSaveAs(name),
          bytes: response.bodyBytes,
          fileExtension: 'pdf',
          mimeType: MimeType.pdf,
        );
      } else {
        await FileSaver.instance.saveFile(
          name: name,
          bytes: response.bodyBytes,
          fileExtension: 'pdf',
          mimeType: MimeType.pdf,
        );
        Get.snackbar(
          'تم التحميل',
          'تم حفظ الملف بنجاح',
          backgroundColor: Colors.green,
          colorText: Colors.white,
          snackPosition: SnackPosition.BOTTOM,
          duration: const Duration(seconds: 4),
        );
      }
    } catch (e) {
      Get.snackbar(
        'خطأ في التحميل',
        '$e',
        backgroundColor: Colors.red,
        colorText: Colors.white,
        snackPosition: SnackPosition.BOTTOM,
      );
    } finally {
      isDownloading.value = false;
      downloadProgress.value = 0.0;
    }
  }

  String _sanitizeForSaveAs(String filename) {
    final sanitized = filename
        .replaceAll(RegExp(r'[\u0600-\u06FF]'), '') // strip Arabic characters
        .replaceAll(RegExp(r'\s+'), '_')
        .replaceAll(RegExp(r'[^\w\-.]'), '')
        .trim();

    return sanitized.isEmpty
        ? 'document_${DateTime.now().millisecondsSinceEpoch}'
        : sanitized;
  }
}
