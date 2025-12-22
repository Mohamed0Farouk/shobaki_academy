import 'dart:io';

import 'package:animate_do/animate_do.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:shobaki_academy/controller/auth_controller.dart';
import 'package:shobaki_academy/services/statics.dart';
import 'package:typewritertext/typewritertext.dart';

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final TextEditingController phoneController = TextEditingController();
  final TextEditingController passwordController = TextEditingController();
  final _formKey = GlobalKey<FormState>();
  final authController = Get.put(AuthController());

  @override
  void dispose() {
    phoneController.dispose();
    passwordController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final primary = Theme.of(context).primaryColor;
    final size = MediaQuery.of(context).size;

    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: Theme.of(context).scaffoldBackgroundColor,
        // allow scaffold to resize when keyboard appears so the scroll view can work
        resizeToAvoidBottomInset: true,
        body: Stack(
          children: [
            // top-left circle
            Positioned(
              left: -size.width * 0.25,
              top: -size.width * 0.25,
              child: Container(
                width: size.width * 0.6,
                height: size.width * 0.6,
                decoration: BoxDecoration(
                  color: primary,
                  shape: BoxShape.circle,
                ),
              ),
            ),

            // bottom-right circle
            Positioned(
              right: -size.width * 0.25,
              bottom: -size.width * 0.25,
              child: Container(
                width: size.width * 0.6,
                height: size.width * 0.6,
                decoration: BoxDecoration(
                  color: primary,
                  shape: BoxShape.circle,
                ),
              ),
            ),

            // content (scrolls when keyboard appears)
            Positioned.fill(
              child: SafeArea(
                child: Center(
                  child: SingleChildScrollView(
                    padding: EdgeInsets.fromLTRB(
                      30,
                      30,
                      30,
                      MediaQuery.of(context).viewInsets.bottom + 30,
                    ),
                    child: Center(
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 420),
                        child: Form(
                          key: _formKey,
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const SizedBox(height: 24),
                              // replaced static headline with typewritertext
                              TypeWriter.text(
                                'اهلا بك في  Al-Shobaki Academy',
                                style: Theme.of(
                                  context,
                                ).textTheme.headlineLarge,
                                duration: const Duration(milliseconds: 80),

                                repeat: false,
                                textAlign: TextAlign.center,
                              ),
                              const SizedBox(height: 8),
                              Text(
                                'طريقك نحو التفوق و التميز',
                                textAlign: TextAlign.center,
                                style: Theme.of(context).textTheme.bodyMedium
                                    ?.copyWith(
                                      color: Colors.grey[600],
                                      fontSize: 14,
                                      fontWeight: FontWeight.w500,
                                    ),
                              ),
                              const SizedBox(height: 40),

                              FadeInUp(
                                duration: const Duration(milliseconds: 800),
                                from: 75,
                                child: Column(
                                  children: [
                                    // phone field
                                    TextFormField(
                                      controller: phoneController,
                                      style: Theme.of(
                                        context,
                                      ).textTheme.bodyMedium,
                                      keyboardType: TextInputType.phone,

                                      validator: (v) => (v == null || v.isEmpty)
                                          ? 'الرجاء ادخال رقم الهاتف'
                                          : null,
                                      decoration: InputDecoration(
                                        hintText: 'رقم الهاتف',
                                        prefixIcon: Padding(
                                          padding: const EdgeInsets.all(8.0),
                                          child: Row(
                                            mainAxisSize: MainAxisSize.min,
                                            children: [
                                              const Icon(Icons.phone_android),
                                              SizedBox(width: 4),
                                              Text(
                                                '+971 ',
                                                style: Theme.of(
                                                  context,
                                                ).textTheme.bodyMedium,
                                              ),
                                            ],
                                          ),
                                        ),
                                        filled: true,
                                        fillColor: Colors.grey[200],
                                        contentPadding:
                                            const EdgeInsets.symmetric(
                                              horizontal: 16,
                                              vertical: 16,
                                            ),
                                        border: OutlineInputBorder(
                                          borderRadius: BorderRadius.circular(
                                            12,
                                          ),
                                          borderSide: BorderSide.none,
                                        ),
                                      ),
                                    ),
                                    const SizedBox(height: 16),

                                    // password field
                                    TextFormField(
                                      controller: passwordController,
                                      style: Theme.of(
                                        context,
                                      ).textTheme.bodyMedium,

                                      obscureText: true,
                                      validator: (v) => (v == null || v.isEmpty)
                                          ? 'الرجاء ادخال كلمة المرور'
                                          : null,
                                      decoration: InputDecoration(
                                        hintText: 'كلمة السر',
                                        prefixIcon: const Icon(
                                          Icons.lock_outline,
                                        ),
                                        filled: true,
                                        fillColor: Colors.grey[200],
                                        contentPadding:
                                            const EdgeInsets.symmetric(
                                              horizontal: 16,
                                              vertical: 16,
                                            ),
                                        border: OutlineInputBorder(
                                          borderRadius: BorderRadius.circular(
                                            12,
                                          ),
                                          borderSide: BorderSide.none,
                                        ),
                                      ),
                                    ),
                                    const SizedBox(height: 12),

                                    Row(
                                      mainAxisAlignment:
                                          MainAxisAlignment.spaceBetween,
                                      children: [
                                        InkWell(
                                          onTap: () {
                                            Get.toNamed('/signup');
                                          },
                                          child: Text(
                                            'انشاء حساب جديد',
                                            style: TextStyle(
                                              color: Colors.grey[700],
                                            ),
                                          ),
                                        ),
                                        InkWell(
                                          onTap: () {
                                            Get.toNamed('/forgot_password');
                                          },
                                          child: Text(
                                            'نسيت كلمة المرور؟',
                                            style: TextStyle(
                                              decoration:
                                                  TextDecoration.underline,
                                              color: Colors.grey[700],
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 20),

                                    Row(
                                      mainAxisAlignment:
                                          MainAxisAlignment.center,
                                      children: [
                                        SizedBox(
                                          height: 48,
                                          child: ElevatedButton(
                                            onPressed: () async {
                                              if (_formKey.currentState
                                                      ?.validate() ??
                                                  false) {
                                                loadingDilog(context);
                                                await authController.login(
                                                  context,

                                                  add971Prefix(
                                                    phoneController.text.trim(),
                                                  ),

                                                  passwordController.text,
                                                );
                                              }
                                            },
                                            style: ElevatedButton.styleFrom(
                                              backgroundColor: primary,
                                              shape: RoundedRectangleBorder(
                                                borderRadius:
                                                    BorderRadius.circular(12),
                                              ),
                                            ),
                                            child: Text(
                                              'تسجيل الدخول',
                                              style: Theme.of(context)
                                                  .textTheme
                                                  .bodyLarge
                                                  ?.copyWith(
                                                    color: Colors.white,
                                                  ),
                                            ),
                                          ),
                                        ),

                                        Platform.isWindows ||
                                                Platform.isMacOS ||
                                                Platform.isLinux
                                            ? const SizedBox.shrink()
                                            : IconButton(
                                                icon: const Icon(
                                                  Icons.fingerprint,
                                                  size: 28,
                                                ),
                                                onPressed: () async {
                                                  await authController
                                                      .loginWithFingerprint();
                                                },
                                              ),
                                      ],
                                    ),
                                    const SizedBox(height: 16),
                                    InkWell(
                                      child: Text(
                                        'الاكمال كضيف',
                                        style: Theme.of(context)
                                            .textTheme
                                            .bodyMedium!
                                            .copyWith(color: Colors.grey[700]),
                                      ),
                                      onTap: () =>
                                          authController.enterGuestMode(),
                                    ),
                                    const SizedBox(height: 24),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
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
