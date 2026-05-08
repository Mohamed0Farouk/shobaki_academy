import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:shobaki_academy/services/api.dart';
import 'package:shobaki_academy/services/statics.dart';

class ForgotPasswordPage extends StatelessWidget {
  ForgotPasswordPage({super.key});

  final phoneNumberController = TextEditingController();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final size = MediaQuery.of(context).size;

    return Scaffold(
      appBar: AppBar(title: const Text('استعادة كلمة المرور')),
      body: Directionality(
        textDirection: TextDirection.rtl,
        child: Stack(
        children: [
          Positioned(
            left: -size.width * 0.3,
            top: -size.width * 0.2,
            child: Container(
              width: size.width * 0.6,
              height: size.width * 0.6,
              decoration: BoxDecoration(
                gradient: RadialGradient(
                  colors: [
                    theme.colorScheme.primary.withValues(alpha: 0.1),
                    theme.colorScheme.primary.withValues(alpha: 0.0),
                  ],
                ),
                shape: BoxShape.circle,
              ),
            ),
          ),
          SafeArea(
            child: Center(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 400),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        'يرجى إدخال رقم هاتفك المحمول المرتبط بحسابك.\nسنرسل لك رمز التحقق لاستعادة كلمة المرور الخاصة بك.',
                        style: theme.textTheme.bodyMedium,
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 32),
                      TextField(
                        controller: phoneNumberController,
                        decoration: const InputDecoration(
                          hintText: 'رقم الهاتف المحمول',
                        ),
                        keyboardType: TextInputType.phone,
                      ),
                      const SizedBox(height: 24),
                      ValueListenableBuilder(
                        valueListenable: phoneNumberController,
                        builder: (context, value, _) {
                          return SizedBox(
                            width: double.infinity,
                            child: ElevatedButton(
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
                                              Get.offAllNamed(
                                                '/otp_forgot_password',
                                                arguments: response[0],
                                              );
                                            } else {
                                              showSnackbar(
                                                'خطأ',
                                                'لا يوجد مستخدم مرتبط بهذا الرقم.',
                                                snackPosition: SnackPosition.BOTTOM,
                                                backgroundColor: theme.colorScheme.error,
                                              );
                                            }
                                          })
                                          .catchError((error) {
                                            showSnackbar(
                                              'خطأ',
                                              'حدث خطأ أثناء جلب المستخدم: $error',
                                              snackPosition: SnackPosition.BOTTOM,
                                              backgroundColor: theme.colorScheme.error,
                                            );
                                          });
                                    }
                                  : null,
                              child: Text('اكمال', style: theme.textTheme.bodyLarge),
                            ),
                          );
                        },
                      ),
          ],
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

  String add971Prefix(String phone) {
    phone = phone.replaceAll(RegExp(r'[^0-9]'), '');
    if (phone.startsWith('971')) return phone;
    phone = phone.replaceFirst(RegExp(r'^0+'), '');
    return '971$phone';
  }
}
