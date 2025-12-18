import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:pinput/pinput.dart';
import 'package:shobaki_academy/controller/number_verfication_controller.dart';
import 'package:shobaki_academy/services/api.dart';
import 'package:shobaki_academy/services/statics.dart';

class OtpPage extends StatelessWidget {
  OtpPage({super.key, this.isForgotPassword = false});

  final NumberVerificationController controller = Get.put(
    NumberVerificationController(),
  );

  final bool isForgotPassword;
  final newPasswordController = TextEditingController();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    // Reusable PIN theme
    final defaultPinTheme = PinTheme(
      width: 60,
      height: 60,
      textStyle: TextStyle(
        fontSize: 22,
        color: theme.colorScheme.primary,
        fontWeight: FontWeight.w600,
      ),
      decoration: BoxDecoration(
        color: Colors.grey.withOpacity(0.25),
        borderRadius: BorderRadius.circular(12),
      ),
    );

    final focusedPinTheme = defaultPinTheme.copyWith(
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: theme.colorScheme.primary, width: 2),
        boxShadow: [
          BoxShadow(
            color: theme.colorScheme.primary.withOpacity(0.15),
            blurRadius: 6,
            offset: const Offset(0, 3),
          ),
        ],
      ),
    );

    final submittedPinTheme = defaultPinTheme.copyWith(
      decoration: BoxDecoration(
        color: theme.colorScheme.secondary.withOpacity(0.2),
        borderRadius: BorderRadius.circular(12),
      ),
    );

    Widget buildPhoneVerification() {
      return Obx(
        () => Column(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Text("رقم هاتفك", style: theme.textTheme.headlineSmall),
            const SizedBox(height: 8),
            Text(
              controller.phoneNumber.value,
              style: theme.textTheme.bodyLarge,
            ),
            const SizedBox(height: 16),
            if (!controller.isVerified.value)
              Directionality(
                textDirection: TextDirection.ltr,
                child: Pinput(
                  length: 6,
                  defaultPinTheme: defaultPinTheme,
                  focusedPinTheme: focusedPinTheme,
                  submittedPinTheme: submittedPinTheme,
                  showCursor: true,
                  cursor: Column(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      Container(
                        width: 22,
                        height: 2,
                        color: theme.colorScheme.primary,
                      ),
                    ],
                  ),
                  onChanged: (val) => controller.otp.value = val,
                  onCompleted: (val) async => await controller.verifyOtp(),
                ),
              )
            else
              Icon(Icons.verified, size: 48, color: theme.colorScheme.primary),
            const SizedBox(height: 12),
            if (!controller.isVerified.value)
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text("لم تستلم الرمز؟", style: theme.textTheme.bodySmall),
                  const SizedBox(width: 4),
                  controller.canResend.value
                      ? GestureDetector(
                          onTap: () async {
                            loadingDilog(context);
                            await controller.sendOtp();
                            Get.close(1);
                          },
                          child: Text(
                            "إعادة الإرسال",
                            style: TextStyle(
                              color: theme.colorScheme.primary,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        )
                      : Text(
                          "يمكنك الإرسال بعد ${controller.timer.value} ث",
                          style: TextStyle(color: theme.colorScheme.secondary),
                        ),
                ],
              ),
            const SizedBox(height: 28),
          ],
        ),
      );
    }

    return Scaffold(
      backgroundColor: theme.colorScheme.surface,
      body: SafeArea(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const SizedBox(height: 32),
            Text(
              "التحقق",
              style: theme.textTheme.headlineMedium?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              "أدخل الرمز المرسل إلى رقمك",
              style: theme.textTheme.bodyMedium,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 32),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 15),
              child: buildPhoneVerification(),
            ),
            const SizedBox(height: 16),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 15),
              child: isForgotPassword
                  ? Obx(
                      () => controller.isVerified.value
                          ? SizedBox(
                              width: double.infinity,
                              child: ElevatedButton(
                                onPressed: () {
                                  Get.dialog(
                                    barrierDismissible: true,

                                    AlertDialog(
                                      title: const Text(
                                        'كلمة المرور الخاصة بك',
                                      ),
                                      content: Row(
                                        children: [
                                          Text(
                                            // ignore: invalid_use_of_protected_member
                                            '${controller.userData.value['password'] ?? 'غير متوفرة'}',
                                          ),
                                          IconButton(
                                            onPressed: () {
                                              Clipboard.setData(
                                                ClipboardData(
                                                  text:
                                                      controller
                                                          .userData['password'] ??
                                                      '',
                                                ),
                                              );
                                              Get.snackbar(
                                                'تم النسخ',
                                                'تم نسخ كلمة المرور إلى الحافظة',
                                                snackPosition:
                                                    SnackPosition.BOTTOM,
                                              );
                                            },
                                            icon: Icon(Icons.copy),
                                          ),
                                          IconButton(
                                            onPressed: () {
                                              Get.close(1);
                                              Get.dialog(
                                                AlertDialog(
                                                  title: const Text(
                                                    'تعديل كلمة المرور',
                                                  ),
                                                  content: TextField(
                                                    controller:
                                                        newPasswordController,
                                                    decoration:
                                                        const InputDecoration(
                                                          labelText:
                                                              'كلمة المرور الجديدة',
                                                        ),
                                                  ),
                                                  actions: [
                                                    TextButton(
                                                      onPressed: () {
                                                        Get.back();
                                                      },
                                                      child: const Text(
                                                        'إلغاء',
                                                      ),
                                                    ),
                                                    TextButton(
                                                      onPressed: () async {
                                                        final api = ApiClient();
                                                        await api
                                                            .updateData(
                                                              'students',
                                                              {
                                                                "password":
                                                                    newPasswordController
                                                                        .text,
                                                              },
                                                              {
                                                                'id': controller
                                                                    .userData['id'],
                                                              },
                                                            )
                                                            .then((value) {
                                                              Get.close(1);
                                                              Get.offAllNamed(
                                                                '/login',
                                                              );
                                                              Get.snackbar(
                                                                'تم التحديث',
                                                                'تم تحديث كلمة المرور بنجاح',
                                                                snackPosition:
                                                                    SnackPosition
                                                                        .BOTTOM,
                                                              );
                                                            })
                                                            .catchError((
                                                              error,
                                                            ) {
                                                              Get.close(1);
                                                              Get.snackbar(
                                                                'خطأ',
                                                                'حدث خطأ أثناء تحديث كلمة المرور: $error',
                                                                snackPosition:
                                                                    SnackPosition
                                                                        .BOTTOM,
                                                              );
                                                            });
                                                      },
                                                      child: const Text('حفظ'),
                                                    ),
                                                  ],
                                                ),
                                              );
                                            },
                                            icon: Icon(Icons.edit),
                                          ),
                                        ],
                                      ),
                                      actions: [
                                        TextButton(
                                          onPressed: () =>
                                              Get.offAllNamed('/login'),
                                          child: const Text(
                                            'العودة لتسجيل الدخول',
                                          ),
                                        ),
                                      ],
                                    ),
                                  );
                                },
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: theme.colorScheme.primary,
                                  foregroundColor: Colors.white,
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 32,
                                    vertical: 16,
                                  ),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                ),
                                child: Text(
                                  "اظهار كلمة السر",
                                  style: theme.textTheme.headlineMedium!
                                      .copyWith(color: Colors.white),
                                ),
                              ),
                            )
                          : ElevatedButton(
                              onPressed: () {
                                // navigate to home (use named route)
                                Get.offAllNamed('/login');
                              },
                              style: ElevatedButton.styleFrom(
                                backgroundColor: theme.colorScheme.primary,
                                foregroundColor: Colors.white,
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 32,
                                  vertical: 16,
                                ),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                              ),
                              child: Text(
                                "العودة الى صفحة تسجيل الدخول",
                                style: theme.textTheme.headlineMedium!.copyWith(
                                  color: Colors.white,
                                ),
                              ),
                            ),
                    )
                  : Obx(
                      () => controller.isVerified.value
                          ? SizedBox(
                              width: double.infinity,
                              child: ElevatedButton(
                                onPressed: () {
                                  // navigate to home (use named route)
                                  Get.offAllNamed('/home');
                                },
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: theme.colorScheme.primary,
                                  foregroundColor: Colors.white,
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 32,
                                    vertical: 16,
                                  ),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                ),
                                child: Text(
                                  "متابعة الى الصفحة الرئيسية",
                                  style: theme.textTheme.headlineMedium!
                                      .copyWith(color: Colors.white),
                                ),
                              ),
                            )
                          : ElevatedButton(
                              onPressed: () {
                                // navigate to home (use named route)
                                Get.offAllNamed('/login');
                              },
                              style: ElevatedButton.styleFrom(
                                backgroundColor: theme.colorScheme.primary,
                                foregroundColor: Colors.white,
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 32,
                                  vertical: 16,
                                ),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                              ),
                              child: Text(
                                "العودة الى صفحة تسجيل الدخول",
                                style: theme.textTheme.headlineMedium!.copyWith(
                                  color: Colors.white,
                                ),
                              ),
                            ),
                    ),
            ),
          ],
        ),
      ),
    );
  }
}
