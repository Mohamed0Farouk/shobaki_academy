import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:shobaki_academy/controller/auth_controller.dart';
import 'package:shobaki_academy/services/api.dart';

class ForgotPasswordPage extends StatelessWidget {
  ForgotPasswordPage({super.key});

  final phoneNumberController = TextEditingController();
  final AuthController authController = Get.find();
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('استعادة كلمة المرور')),
      body: SafeArea(
        child: Padding(
          padding: EdgeInsets.symmetric(horizontal: 16.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            spacing: 20,
            children: [
              Text(
                'يرجى إدخال رقم هاتفك المحمول المرتبط بحسابك. \nسنرسل لك رمز التحقق لاستعادة كلمة المرور الخاصة بك.',
                style: TextStyle(fontSize: 16),
                textAlign: TextAlign.center,
              ),
              // Add your phone number input field and submit button here
              TextField(
                controller: phoneNumberController,
                decoration: InputDecoration(
                  labelText: 'رقم الهاتف المحمول',
                  border: OutlineInputBorder(),
                ),
                keyboardType: TextInputType.phone,
              ),
              ValueListenableBuilder(
                valueListenable: phoneNumberController,
                builder: (context, value, _) {
                  return ElevatedButton(
                    onPressed: phoneNumberController.text.isNotEmpty
                        ? () {
                            final api = ApiClient();
                            api
                                .fetchWithConditions(
                                  'students',
                                  filters: {
                                    'phone_number': add971Prefix(
                                      phoneNumberController.text.trim(),
                                    ),
                                  },
                                )
                                .then((response) async {
                                  if (response.isNotEmpty) {
                                    await authController
                                        .saveUserLocally(response[0])
                                        .then(
                                          (value) => Get.offAllNamed(
                                            '/otp_forgot_password',
                                          ),
                                        );
                                    debugPrint('User found: $response');
                                  } else {
                                    Get.snackbar(
                                      'خطأ',
                                      'لا يوجد مستخدم مرتبط بهذا الرقم.',
                                      snackPosition: SnackPosition.BOTTOM,
                                      backgroundColor: Colors.orange,
                                    );
                                  }
                                })
                                .catchError((error) {
                                  Get.snackbar(
                                    'خطأ',
                                    'حدث خطأ أثناء جلب المستخدم: $error',
                                    snackPosition: SnackPosition.BOTTOM,
                                    backgroundColor: Colors.red,
                                  );
                                });
                          }
                        : null,
                    child: Padding(
                      padding: const EdgeInsets.all(8.0),
                      child: Text(
                        'اكمال',
                        style: Theme.of(context).textTheme.headlineMedium!
                            .copyWith(color: Colors.white),
                      ),
                    ),
                  );
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  String add971Prefix(String phone) {
    // Remove spaces and any non-digit characters
    phone = phone.replaceAll(RegExp(r'[^0-9]'), '');

    // If number already starts with 971 → keep it as is
    if (phone.startsWith('971')) {
      return phone;
    }

    // Remove leading zeros (e.g., 0501234567 → 501234567)
    phone = phone.replaceFirst(RegExp(r'^0+'), '');

    // Add 971 prefix
    return '971$phone';
  }
}
