import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:get/get.dart';
import 'package:shobaki_academy/controller/book_controller.dart';
import 'package:syncfusion_flutter_pdfviewer/pdfviewer.dart';
import 'package:shobaki_academy/services/statics.dart';

class PdfModel extends StatefulWidget {
  final String? pdfUrl;
  final String? filename;

  const PdfModel({super.key, this.pdfUrl, this.filename});

  @override
  State<PdfModel> createState() => _PdfModelState();
}

class _PdfModelState extends State<PdfModel> {
  late final PdfController controller = Get.put(PdfController());
  late String _pdfUrl;
  late String _filename;
  final ScrollController _scrollController = ScrollController();
  final RxBool _showAppBar = true.obs;
  final RxBool _isLoadingPdf = true.obs;
  late PdfViewerController _pdfViewerController;

  @override
  void initState() {
    super.initState();
    _pdfUrl =
        widget.pdfUrl ??
        'https://www.w3.org/WAI/ER/tests/xhtml/testfiles/resources/pdf/dummy.pdf';
    _filename = widget.filename ?? 'document.pdf';
    _pdfViewerController = PdfViewerController();

    _scrollController.addListener(_handleScroll);
  }

  void _handleScroll() {
    if (_scrollController.position.userScrollDirection ==
        ScrollDirection.reverse) {
      _showAppBar.value = false;
    } else if (_scrollController.position.userScrollDirection ==
        ScrollDirection.forward) {
      _showAppBar.value = true;
    }
  }

  @override
  void dispose() {
    _scrollController.removeListener(_handleScroll);
    _scrollController.dispose();
    _pdfViewerController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: PreferredSize(
        preferredSize: const Size.fromHeight(60),
        child: Obx(() {
          return AnimatedSlide(
            offset: _showAppBar.value ? Offset.zero : const Offset(0, -1),
            duration: const Duration(milliseconds: 300),
            child: AppBar(
              title: Text(
                _filename,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              centerTitle: true,
              elevation: 2,
              backgroundColor: Theme.of(context).colorScheme.primary,
              foregroundColor: Colors.white,
              actions: [
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  child: Obx(() {
                    return controller.isDownloading.value
                        ? const Padding(
                            padding: EdgeInsets.symmetric(vertical: 12),
                            child: SizedBox(
                              width: 24,
                              height: 24,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                valueColor: AlwaysStoppedAnimation<Color>(
                                  Colors.white,
                                ),
                              ),
                            ),
                          )
                        : IconButton(
                            icon: const Icon(Icons.download),
                            onPressed: () {
                              if (Platform.isWindows ||
                                  Platform.isLinux ||
                                  Platform.isMacOS) {
                                _showDownloadDialog(context);
                              } else {
                                controller.downloadPdf(
                                  _pdfUrl,
                                  _filename,
                                  true,
                                );
                              }
                            },
                            tooltip: 'تحميل PDF',
                          );
                  }),
                ),
              ],
            ),
          );
        }),
      ),
      body: SafeArea(child: _buildPdfViewer()),
    );
  }

  void _showDownloadDialog(BuildContext context) {
    Get.dialog(
      AlertDialog(
        title: const Text('تحميل PDF'),
        content: const Text(
          'اختر طريقة حفظ الملف: \n\n- Save: حفظ مباشر في مجلد التنزيلات.\n- Save As...: اختيار موقع الحفظ عبر نافذة الحفظ.',
        ),
        actions: [
          TextButton(
            onPressed: () {
              Get.back();
              controller.downloadPdf(_pdfUrl, _filename, false); // saveFile
            },
            child: const Text('Save'),
          ),
          ElevatedButton(
            onPressed: () {
              controller.downloadPdf(_pdfUrl, _filename, true); // saveAs dialog
              Get.back();
            },
            child: const Text('Save As...'),
          ),
        ],
      ),
    );
  }

  Widget _buildPdfViewer() {
    return Obx(() {
      return Stack(
        children: [
          SfPdfViewer.network(
            _pdfUrl,
            controller: _pdfViewerController,
            pageSpacing: 8,
            onDocumentLoaded: (details) {
              _isLoadingPdf.value = false;
            },
            canShowScrollHead: true,
            enableTextSelection: true,
            interactionMode: PdfInteractionMode.selection,
          ),

          _isLoadingPdf.value
              ? Container(
                  color: Colors.grey[200],
                  child: Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        loading(context),
                        const SizedBox(height: 16),
                        Text(
                          'جاري تحميل الملف...',
                          style: Theme.of(context).textTheme.bodyMedium,
                        ),
                      ],
                    ),
                  ),
                )
              : const SizedBox.shrink(),
        ],
      );
    });
  }
}
