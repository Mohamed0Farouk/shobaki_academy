import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:media_kit/media_kit.dart';
import 'package:flutter_windowmanager_plus/flutter_windowmanager_plus.dart';
import 'package:get/get.dart';
import 'package:shobaki_academy/controller/auth_controller.dart';
import 'package:shobaki_academy/controller/network_controller.dart';
import 'package:shobaki_academy/controller/security_controller.dart';
import 'package:shobaki_academy/controller/watermark_controller.dart';
import 'package:shobaki_academy/services/device_guard.dart';
import 'package:shobaki_academy/services/locale_db.dart';
import 'package:shobaki_academy/services/router.dart';
import 'package:shobaki_academy/theme.dart';
import 'package:shobaki_academy/view/sub/protection_overlay.dart';
import 'package:shobaki_academy/view/sub/watermark.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:no_screenshot/no_screenshot.dart';
import 'package:window_manager/window_manager.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  MediaKit.ensureInitialized();

  await dotenv.load(fileName: '.env');

  await Supabase.initialize(
    url: dotenv.env['SUPABASE_URL']!,
    anonKey: dotenv.env['SUPABASE_ANON']!,
  );

  await Get.putAsync(() async => await LocalDB().init(), permanent: true);

  if (Platform.isWindows || Platform.isMacOS) {
    // Initialize window manager BEFORE runApp
    await windowManager.ensureInitialized();
  }

  // Android secure flag
  FlutterWindowManagerPlus.addFlags(FlutterWindowManagerPlus.FLAG_SECURE);

  final noScreenshot = NoScreenshot.instance;

  // Enable screenshot prevention
  await noScreenshot.screenshotOff();

  if (Platform.isMacOS) {
    // Start detection
    await noScreenshot.startScreenRecordingListening();
    await noScreenshot.startScreenshotListening();

    var recordingWasActive = false;

    noScreenshot.screenshotStream.listen((snapshot) async {
      final controllerReady = Get.isRegistered<SecurityController>();
      final controller = controllerReady
          ? Get.find<SecurityController>()
          : null;

      // Windows: minimize window on recording (detection handled by MethodChannel)
      if (snapshot.isScreenRecording && Platform.isWindows) {
        await windowManager.minimize();
      }

      // Screenshot detection (macOS + mobile)
      if (snapshot.wasScreenshotTaken &&
          !Platform.isWindows &&
          controller != null) {
        controller.onScreenshotDetected(snapshot.sourceApp);
      }

      // Screen recording detection (macOS + mobile)
      if (!Platform.isWindows && controller != null) {
        if (snapshot.isScreenRecording && !recordingWasActive) {
          recordingWasActive = true;
          controller.onRecordingDetected(
            snapshot.sourceApp,
            isMobile: !Platform.isMacOS,
          );
          if (Platform.isMacOS) {
            await windowManager.minimize();
          }
        } else if (!snapshot.isScreenRecording && recordingWasActive) {
          recordingWasActive = false;
          controller.onRecordingCleared();
        }
      }
    });
  }

  runApp(const MyApp());
}

class GlobalBindings extends Bindings {
  @override
  void dependencies() {
    Get.put(WatermarkController(), permanent: true);
    Get.put(NetworkController(), permanent: true);
    Get.put(DeviceGuardController(), permanent: true);
    Get.put(AuthController(), permanent: true);
  }
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    final securityController = Get.put(SecurityController(), permanent: true);

    return GetMaterialApp(
      initialBinding: GlobalBindings(),
      debugShowCheckedModeBanner: false,
      getPages: AppRouter.routes,
      theme: AppTheme.mainTheme,
      title: 'Al Shobaki Academy',

      builder: (context, child) {
        return Stack(
          children: [
            // Main app
            child!,

            // Your watermark
            const PermanentWatermark(),

            // Security overlay
            Obx(() {
              if (securityController.isScreenshotDetected.value) {
                return const ScreenshotAlertBanner();
              }
              if (!securityController.isRecordingDetected.value) {
                return const SizedBox.shrink();
              }
              return RecordingDetectedOverlay(controller: securityController);
            }),
          ],
        );
      },
    );
  }
}
