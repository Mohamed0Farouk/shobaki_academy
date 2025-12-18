import 'dart:convert';

import 'package:get/get.dart';
import 'package:shobaki_academy/controller/auth_controller.dart';
import 'package:shobaki_academy/services/locale_db.dart';

enum AuthStatus { loggedIn, inReview, guest, notLogged, notVerified }

class SplashController extends GetxController {
  final status = Rxn<AuthStatus>(); // Reactive status value

  @override
  void onInit() {
    super.onInit();
    _checkAuth(Get.context);
  }

  // Check local auth state using AuthController (reads shared prefs via AuthController)
  Future<void> _checkAuth(context) async {
    // small delay to allow AuthController.onInit to run and populate values
    await Future.delayed(const Duration(milliseconds: 200));
    final authController = Get.put(AuthController());

    final LocalDB db = Get.find();
    final localDb = db.sharedPref;
    final Map userData = jsonDecode(localDb?.getString('UserData') ?? '{}');
    bool notBlocked = true;
    if (userData.isNotEmpty && userData['email'] != 'guest@example.com') {
      notBlocked = await authController.login(
        context,
        userData['phone_number'],
        userData['password'],
      );
    }

    final isGuest = localDb?.getBool('isGuestMode') ?? false;
    final isLoggedIn = localDb?.getBool('isLoggedIn') ?? false;
    final isVerified = localDb?.getBool('isVerified') ?? false;
    final isInReview = localDb?.getBool('inReview') ?? false;

    print(
      'Auth Check - isGuest: $isGuest, isLoggedIn: $isLoggedIn, isVerified: $isVerified, isInReview: $isInReview',
    );

    if (isGuest) {
      status.value = AuthStatus.guest;
      return;
    }

    if (isInReview) {
      status.value = AuthStatus.inReview;
      return;
    }
    if (!isLoggedIn || !notBlocked) {
      notBlocked == true
          ? status.value = AuthStatus.guest
          : status.value = AuthStatus.notLogged;
      return;
    }

    if (!isVerified) {
      status.value = AuthStatus.notVerified;
      return;
    }

    if (isLoggedIn && isVerified) {
      status.value = AuthStatus.loggedIn;
      return;
    }
  }
}
