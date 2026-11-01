import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:loading_indicator/loading_indicator.dart';
import 'package:logger/logger.dart';
import 'package:shobaki_academy/services/diagnostic_log.dart';

final projectLogger = Logger(
  // DevelopmentFilter is assert-based: it silences *every* level in a
  // release build, which would leave the diagnostics console empty on the
  // shipped diagnostics edition (a release build). The flag comes from
  // `.env` (DIAG_EDITION=1) and is set in main() before anything logs;
  // top-level finals initialize lazily on first access, so the choice is
  // always made after that. Regular builds keep the stock behavior.
  filter: diagnosticsEnabled ? ProductionFilter() : DevelopmentFilter(),
  printer: CapturingPrettyPrinter(
    methodCount: 2, // Number of method calls to be displayed
    errorMethodCount: 8, // Number of method calls if stacktrace is provided
    lineLength: 120, // Width of the output
    colors: true, // Colorful log messages
    printEmojis: true, // Print an emoji for each log message
    // Should each log print contain a timestamp
    dateTimeFormat: DateTimeFormat.onlyTimeAndSinceStart,
  ),
);

void loadingDilog(context) {
  Get.dialog(
    SizedBox(
      child: Center(
        child: SizedBox(
          height: 50,
          width: 50,
          child: LoadingIndicator(
            indicatorType: Indicator.lineScale,
            strokeWidth: 4,
            colors: [Theme.of(context).colorScheme.primary],
          ),
        ),
      ),
    ),
    barrierDismissible: false,
    transitionCurve: Curves.elasticInOut,
    transitionDuration: const Duration(milliseconds: 600),
  );
}

void showSnackbar(
  String title,
  String message, {
  Color? backgroundColor,
  Color? colorText,
  SnackPosition? snackPosition,
  Duration? duration,
}) {
  Get.rawSnackbar(
    titleText: Directionality(
      textDirection: TextDirection.rtl,
      child: Text(
        title,
        style: TextStyle(
          color: colorText ?? Colors.white,
          fontWeight: FontWeight.bold,
        ),
      ),
    ),
    messageText: Directionality(
      textDirection: TextDirection.rtl,
      child: Text(
        message,
        style: TextStyle(color: colorText ?? Colors.white),
      ),
    ),
    backgroundColor: backgroundColor ?? Colors.black87,
    snackPosition: snackPosition ?? SnackPosition.BOTTOM,
    duration: duration ?? const Duration(seconds: 3),
  );
}

Widget loading(context) {
  return SizedBox(
    child: Center(
      child: SizedBox(
        height: 50,
        width: 50,
        child: LoadingIndicator(
          indicatorType: Indicator.lineScale,
          strokeWidth: 4,
          colors: [Theme.of(context).colorScheme.primary],
        ),
      ),
    ),
  );
}
