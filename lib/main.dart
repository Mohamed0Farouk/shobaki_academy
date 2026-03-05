import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_windowmanager_plus/flutter_windowmanager_plus.dart';
import 'package:get/get.dart';
import 'package:shobaki_academy/controller/network_controller.dart';
import 'package:shobaki_academy/controller/watermark_controller.dart';
import 'package:shobaki_academy/services/locale_db.dart';
import 'package:shobaki_academy/services/router.dart';
import 'package:shobaki_academy/theme.dart';
import 'package:shobaki_academy/view/sub/watermark.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:no_screenshot/no_screenshot.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await dotenv.load(fileName: '.env');
  await Supabase.initialize(
    url: dotenv.env['SUPABASE_URL']!,
    anonKey: dotenv.env['SUPABASE_ANON']!,
  );
  await Get.putAsync(() async => await LocalDB().init(), permanent: true);
  runApp(const MyApp());
  WidgetsBinding.instance.addPostFrameCallback((timeStamp) async {
    // This flag works for Android devices.
    FlutterWindowManagerPlus.addFlags(FlutterWindowManagerPlus.FLAG_SECURE);
    final noScreenshot = NoScreenshot.instance;

    // Disable screenshots & screen recording
    await noScreenshot.screenshotOff();
  });
}

class GlobalBindings extends Bindings {
  @override
  void dependencies() {
    Get.put(WatermarkController(), permanent: true);
    Get.put(NetworkController(), permanent: true);
  }
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return GetMaterialApp(
      initialBinding: GlobalBindings(),
      debugShowCheckedModeBanner: false,
      getPages: AppRouter.routes,
      theme: AppTheme.mainTheme,
      title: 'Al Shobaki Academy',
      builder: (context, child) {
        return Stack(children: [child!, const PermanentWatermark()]);
      },
    );
  }
}
