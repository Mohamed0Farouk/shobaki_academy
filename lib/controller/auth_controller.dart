import 'dart:convert';
import 'package:local_auth/local_auth.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:shobaki_academy/controller/watermark_controller.dart';
import 'package:shobaki_academy/services/api.dart';
import 'package:shobaki_academy/services/device_fingerprint.dart';
import 'package:shobaki_academy/services/device_guard.dart';
import 'package:shobaki_academy/services/locale_db.dart';
import 'package:shobaki_academy/services/statics.dart';
import 'package:uuid/uuid.dart';

class AuthController extends GetxController {
  static AuthController get to => Get.find();

  final ApiClient api = ApiClient();
  final LocalDB db = Get.find();
  final WatermarkController watermarkController =
      Get.find<WatermarkController>();

  RxBool isGuestMode = false.obs;
  RxBool isLoggedIn = false.obs;
  RxBool isVerified = false.obs;
  RxBool inReview = false.obs; // new flag for reviewer accounts

  // dropdown lists (can be adjusted)
  final List<String> educationStages = [
    'الصف الثاني عشر المتقدم',
    'الصف الثاني عشر العام',
    'الصف الحادي عشر المتقدم',
  ];

  final List<String> uaeStates = [
    'أبوظبي',
    'العين',
    'دبي',
    'الشارقة',
    'عجمان',
    'أم القيوين',
    'رأس الخيمة',
    'اخرى',
  ];

  // selected values for signup form
  RxString selectedStage = ''.obs;
  RxString selectedUae = ''.obs;

  // special test reviewer account id/email prefix
  static const reviewerEmailPrefix =
      'appletestaccount#97111111111111@gmail.com';

  @override
  void onInit() {
    super.onInit();
    final localDb = db.sharedPref;

    isGuestMode.value = localDb?.getBool('isGuestMode') ?? false;
    isLoggedIn.value = localDb?.getBool('isLoggedIn') ?? false;
    inReview.value = localDb?.getBool('inReview') ?? false;
  }

  // simple setters for UI
  void setStage(String? v) => selectedStage.value = v ?? '';
  void setUae(String? v) => selectedUae.value = v ?? '';
  //void setSubscription(String? v) => selectedSubscription.value = v ?? '';

  // persist user locally (now includes inReview)
  Future<void> saveUserLocally(
    Map<String, dynamic> userData, {
    bool loggedIn = true,
    bool reviewer = false,
  }) async {
    final localDb = db.sharedPref;
    localDb?.setString('UserData', jsonEncode(userData));
    localDb?.setBool('isLoggedIn', loggedIn);
    localDb?.setBool('inReview', reviewer);
    isLoggedIn.value = loggedIn;
    inReview.value = reviewer;
  }

  // unified error handler
  void _handleError(Object e) {
    Get.close(1);
    final msg = e.toString().startsWith('Exception: ')
        ? e.toString().substring(11)
        : e.toString();
    showSnackbar(
      'خطأ',
      msg,
      backgroundColor: Colors.red,
      snackPosition: SnackPosition.BOTTOM,
    );
  }

  final LocalAuthentication _localAuth = LocalAuthentication();

  // Note: we use a stable device signature (DeviceFingerprint.getFingerprint())
  // as the single identifier stored in DB (students.device_fingerprint).
  // Biometric prompts are performed locally via local_auth; no biometric keys/signatures
  // are stored locally in this app.

  // Perform a local biometric authentication and return true/false.
  Future<bool> _authenticateBiometrics({
    String reason = 'Please authenticate',
  }) async {
    try {
      final isSupported = await _localAuth.isDeviceSupported();
      print('Biometric support: $isSupported');
      if (!isSupported) return false;
      final canCheck = await _localAuth.canCheckBiometrics;
      print('Can check biometrics: $canCheck');
      if (!canCheck) return false;
      return await _localAuth.authenticate(
        localizedReason: reason,
        biometricOnly: true,
      );
    } catch (_) {
      return false;
    }
  }

  /// Gather a stable device fingerprint after a local biometric verification.
  /// Returns the device signature string or null on failure.
  Future<String?> gatherFingerprint() async {
    final ok = await _authenticateBiometrics(reason: 'قم بتأكيد البصمة للربط');
    if (!ok) {
      showSnackbar(
        'تنبيه',
        'فشل التحقق بالبصمة.',
        backgroundColor: Colors.orange,
        snackPosition: SnackPosition.BOTTOM,
      );
      return null;
    }
    final deviceSig = await DeviceFingerprint.getFingerprint();
    return deviceSig;
  }

  // ---------------------------------------------------
  //  LOGIN WITH FINGERPRINT (local_auth based)
  // ---------------------------------------------------
  /// Authenticate biometrically, get device signature and lookup student by
  /// students.device_fingerprint. If found, sign in with stored email/password.
  Future<void> loginWithFingerprint() async {
    try {
      final ctx = Get.context;
      if (ctx != null) loadingDilog(ctx);

      final authOk = await _authenticateBiometrics(
        reason: 'تأكيد تسجيل الدخول بالبصمة',
      );
      if (!authOk) {
        if (ctx != null) Get.close(1);
        showSnackbar(
          'تنبيه',
          'فشل التحقق بالبصمة أو لم يتم التفعيل.',
          snackPosition: SnackPosition.BOTTOM,
          backgroundColor: Colors.orange,
        );
        return;
      }

      final deviceSig = await DeviceFingerprint.getFingerprint();
      if (deviceSig.isEmpty) {
        if (ctx != null) Get.close(1);
        showSnackbar('خطأ', 'غير قادر على الحصول على بصمة الجهاز.');
        return;
      }

      // find user by device_fingerprint
      final users = await api.fetchWithConditions(
        'students',
        filters: {'device_fingerprint': deviceSig},
      );

      if (ctx != null) Get.close(1);

      if (users.isEmpty) {
        showSnackbar(
          'تنبيه',
          'لم يتم العثور على حساب مرتبط بهذا الجهاز. الرجاء تسجيل الدخول يدوياً لربط الجهاز بالحساب.',
          backgroundColor: Colors.orange,
        );
        return;
      }

      final user = Map<String, dynamic>.from(users[0] as Map);
      final email = user['email'] as String?;
      final password = user['password'] as String?;
      if (email == null || password == null) {
        showSnackbar('خطأ', 'بيانات الحساب غير كافية لتسجيل الدخول بالبصمة.');
        return;
      }

      if (ctx != null) loadingDilog(ctx);

      final userData = await api.signIn(email, password);

      if (userData.isEmpty) {
        throw Exception('User record not found after sign-in');
      }

      (userData as Map<String, dynamic>).addAll({'password': password});
      final bool isReviewer = email == reviewerEmailPrefix;

      await saveUserLocally(userData, loggedIn: true, reviewer: isReviewer);

      if (ctx != null) Get.close(1);

      if (userData['disabled'] == true) {
        showSnackbar(
          'مشكلة فنية',
          'لقد تم حجبك تواصل مع الدعم لحل المشكلة',
          backgroundColor: Colors.yellow,
          snackPosition: SnackPosition.BOTTOM,
        );
        return;
      }

      watermarkController.updateWatermark();

      if (isReviewer) {
        db.sharedPref?.setBool('isGuestMode', false);
        isGuestMode.value = false;
        Get.offAllNamed('/home', parameters: {'inReview': 'true'});
        return;
      }

      Get.offAllNamed('/home');
    } catch (e) {
      if (Get.context != null) Get.close(1);
      _handleError(e);
    }
  }

  Future<bool> login(
    BuildContext context,
    String phoneNumber,
    String password,
  ) async {
    try {
      //loadingDilog(context);

      final fetched = await api.fetchWithConditions(
        'students',
        filters: {'phone_number': phoneNumber},
      );
      final email = fetched.isNotEmpty
          ? fetched[0]['email'] as String
          : phoneNumber;

      final userData = await api.signIn(email, password);

      if (userData.isEmpty) throw Exception('User record not found');

      // device fingerprint check
      final currentFingerprint = await DeviceFingerprint.getFingerprint();
      final dbFingerprint = userData['device_fingerprint'];
      if (email != reviewerEmailPrefix) {
        if (dbFingerprint == null || (dbFingerprint as String).isEmpty) {
          // If the account has no device_fingerprint, set it now to lock account to this device.
          await api.updateData(
            'students',
            {'device_fingerprint': currentFingerprint},
            {'id': userData['id']},
          );
          userData['device_fingerprint'] = currentFingerprint;
        } else if (dbFingerprint != currentFingerprint) {
          Get.close(1);
          userData['email'] = 'guest@example.com'; // downgrade to guest locally
          (userData as Map<String, dynamic>).addAll({'password': password});
          db.sharedPref?.getBool('isGuestMode') == false
              ? db.sharedPref?.setBool('isGuestMode', true)
              : null;
          await saveUserLocally(userData, loggedIn: false, reviewer: false);
          showSnackbar(
            'خطأ في تسجيل الدخول',
            'لا يمكن تسجيل الدخول من هذا الجهاز. يرجى استخدام الجهاز الذي تم إنشاء الحساب عليه',
            backgroundColor: Colors.red,
            snackPosition: SnackPosition.BOTTOM,
          );
          await api.signOut();
          return false;
        }
      }

      // attach password and determine reviewer flag
      (userData as Map<String, dynamic>).addAll({'password': password});
      final bool isReviewer = email == reviewerEmailPrefix;

      // save locally and include inReview flag for reviewer
      await saveUserLocally(userData, loggedIn: true, reviewer: isReviewer);

      db.sharedPref?.getBool('isGuestMode') == true
          ? db.sharedPref?.setBool('isGuestMode', false)
          : null;

      Get.close(1);

      if (userData['disabled'] == true) {
        showSnackbar(
          'مشكلة فنية',
          'لقد تم حجبك تواصل مع الدعم لحل المشكلة',
          backgroundColor: Colors.yellow,
          snackPosition: SnackPosition.BOTTOM,
        );
        return false;
      }

      // navigation:
      // - reviewer account -> navigate to home with inReview parameter
      // - if verified -> home (no param)
      // - else -> number verification
      watermarkController.updateWatermark();

      if (isReviewer) {
        // ensure guest mode flag cleared for reviewer
        db.sharedPref?.setBool('isGuestMode', false);
        isGuestMode.value = false;

        Get.offAllNamed('/home', parameters: {'inReview': 'true'});
        return true;
      }

      isVerified.value = userData['verified'];

      if (isVerified.value) {
        final DeviceGuardController guard = Get.find();

        await guard.start(
          userId: userData['id'],
          localFingerprint: currentFingerprint,
        );

        Get.offAllNamed('/home');
        return true;
      } else {
        Get.toNamed('/otp', arguments: {'userId': userData['id']});
        return true;
      }
    } catch (e) {
      _handleError(e);
    }
    return false;
  }

  Future<void> signup(
    BuildContext context, {
    required String name,
    required String schoolName,
    required String password,
    required String studentPhoneNumber,
  }) async {
    try {
      loadingDilog(context);

      final exists = await api.fetchWithConditions(
        'students',
        filters: {'phone_number': studentPhoneNumber},
      );
      if (exists.isNotEmpty) {
        Get.close(1);
        showSnackbar(
          'خطأ',
          'لدينا حساب يحتوي على نفس رقم الهاتف هذا، حاول تسجيل الدخول بدلاً من ذلك',
          backgroundColor: Colors.red,
          snackPosition: SnackPosition.BOTTOM,
        );
        return;
      }

      final email = '${name.replaceAll(' ', '')}#$studentPhoneNumber@gmail.com';

      final deviceFingerprint = await DeviceFingerprint.getFingerprint();

      final Map<String, dynamic> userData = {
        'id': Uuid().v4(),
        'name': name,
        'email': email,
        'password': password,
        'school_name': schoolName,
        'phone_number': studentPhoneNumber,
        'stage': selectedStage.value,
        'goverment': selectedUae.value,
        'device_fingerprint': deviceFingerprint,
      };

      await api.insertData('students', userData);

      await saveUserLocally(userData, loggedIn: true, reviewer: false);
      Get.close(1);

      // navigate to number verification (single number)

      watermarkController.updateWatermark();

      Get.offAllNamed('/otp');
    } catch (e) {
      _handleError(e);
    }
  }

  Future<void> signout() async {
    final localDb = db.sharedPref;
    localDb?.remove('UserData');
    localDb?.setBool('isGuestMode', false);
    localDb?.setBool('isLoggedIn', false);
    localDb?.setBool('inReview', false);
    isGuestMode.value = false;
    isLoggedIn.value = false;
    isVerified.value = false;
    inReview.value = false;
    await api.signOut();
    Get.offAllNamed('/login');
  }

  Future<void> enterGuestMode() async {
    final localDb = db.sharedPref;
    final jsonUserData = localDb!.getString('UserData');

    final Map<String, dynamic>? userData = jsonUserData != null
        ? jsonDecode(jsonUserData)
        : null;

    if (isGuestMode.value &&
        userData != null &&
        userData['email'] == 'guest@example.com') {
      Get.offAllNamed('/home', parameters: {'guest': 'true'});

      return;
    }
    if (userData != null && userData['email'] != 'guest@example.com') {
      await localDb.remove('UserData');
      await localDb.setBool('isGuestMode', false);
      await localDb.setBool('isLoggedIn', false);
      await localDb.setBool('inReview', false);
      isGuestMode.value = false;
      isLoggedIn.value = false;
      inReview.value = false;
    }
    final guestUser = {
      'id': Uuid().v4(),
      'name': 'طالبنا العزيز',
      'email': 'guest@example.com',
      'school_name': 'الشوبكي أكاديمي',
      'phone_number': 'لا يوجد رقم هاتف',
      'stage': null,
      'goverment': '-----------',
      //'subscription': 'منصة فقط',
      'disabled': false,
      'password': 'guest_password',
    };

    await saveUserLocally(guestUser, loggedIn: true, reviewer: false);
    localDb.setBool('isGuestMode', true);
    isGuestMode.value = true;
    watermarkController.updateWatermark();
    Get.offAllNamed('/home', parameters: {'guest': 'true'});
  }

  Future<void> exitGuestMode() async {
    final localDb = db.sharedPref;
    isGuestMode.value = false;
    isLoggedIn.value = false;
    inReview.value = false;
    await localDb?.setBool('isGuestMode', false);
    await localDb?.setBool('isLoggedIn', false);
    await localDb?.setBool('inReview', false);
    await localDb?.remove('UserData');
    Get.offAllNamed('/login');
  }

  Future<void> deleteAccount() async {
    try {
      final localDb = db.sharedPref;
      final jsonUser = localDb?.getString('UserData');
      if (jsonUser == null) return;
      final user = json.decode(jsonUser);
      await api.deleteAccount(id: user['id']);
      localDb?.remove('UserData');
      Get.offAllNamed('/login');
    } catch (e) {
      showSnackbar(
        'خطأ',
        'فشل حذف الحساب',
        backgroundColor: Colors.red,
        snackPosition: SnackPosition.BOTTOM,
      );
    }
  }
}
