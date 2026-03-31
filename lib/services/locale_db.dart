import 'dart:io';
import 'package:get/get.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:path_provider/path_provider.dart';

class LocalDB extends GetxService {
  SharedPreferences? sharedPref;

  Future<LocalDB> init() async {
    sharedPref = await SharedPreferences.getInstance();

    await _handleFirstRun();

    return this;
  }

  Future<void> _handleFirstRun() async {
    final dirSupport = await getApplicationSupportDirectory();
    final dirCache = await getApplicationCacheDirectory();

    final markerFile = File('${dirSupport.path}/install_marker');

    final hasMarker = await markerFile.exists();
    final hasPrefsFlag = sharedPref?.getBool('initialized') ?? false;

    // Extra safety: check if directories actually contain data
    final supportExists = await dirSupport.exists();
    final cacheExists = await dirCache.exists();

    final isInconsistentState =
        (!hasMarker && hasPrefsFlag) || // reinstall case
        (hasMarker && !hasPrefsFlag) || // corrupted prefs
        (!supportExists && hasPrefsFlag) || // partially deleted
        (!cacheExists && hasPrefsFlag);

    if (isInconsistentState) {
      // 🔥 Clean everything safely
      await sharedPref?.clear();

      // Optional: delete leftover files if any
      try {
        if (await dirSupport.exists()) {
          await dirSupport.delete(recursive: true);
        }
        if (await dirCache.exists()) {
          await dirCache.delete(recursive: true);
        }
      } catch (_) {
        // ignore errors (important for stability)
      }
    }

    // Ensure marker + flag are always restored
    try {
      await markerFile.writeAsString('installed');
    } catch (_) {
      // ignore write errors (no crash)
    }

    await sharedPref?.setBool('initialized', true);
  }
}
