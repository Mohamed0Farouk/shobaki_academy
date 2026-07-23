import 'dart:io';

import 'package:animate_do/animate_do.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:shobaki_academy/controller/auth_controller.dart';
import 'package:shobaki_academy/services/statics.dart';

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
  bool isObscure = true;

  @override
  void dispose() {
    phoneController.dispose();
    passwordController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final size = MediaQuery.of(context).size;

    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: theme.scaffoldBackgroundColor,
        resizeToAvoidBottomInset: true,
        body: Stack(
          children: [
            // subtle gradient orbs (top-left, bottom-right)
            Positioned(
              left: -size.width * 0.3,
              top: -size.width * 0.3,
              child: Container(
                width: size.width * 0.65,
                height: size.width * 0.65,
                decoration: BoxDecoration(
                  gradient: RadialGradient(
                    colors: [
                      theme.colorScheme.primary.withValues(alpha: 0.15),
                      theme.colorScheme.primary.withValues(alpha: 0.0),
                    ],
                  ),
                  shape: BoxShape.circle,
                ),
              ),
            ),
            Positioned(
              right: -size.width * 0.3,
              bottom: -size.width * 0.3,
              child: Container(
                width: size.width * 0.65,
                height: size.width * 0.65,
                decoration: BoxDecoration(
                  gradient: RadialGradient(
                    colors: [
                      theme.colorScheme.primary.withValues(alpha: 0.12),
                      theme.colorScheme.primary.withValues(alpha: 0.0),
                    ],
                  ),
                  shape: BoxShape.circle,
                ),
              ),
            ),

            Positioned.fill(
              child: SafeArea(
                child: Center(
                  child: SingleChildScrollView(
                    padding: EdgeInsets.fromLTRB(
                      24,
                      24,
                      24,
                      MediaQuery.of(context).viewInsets.bottom + 24,
                    ),
                    child: Center(
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 400),
                        child: Form(
                          key: _formKey,
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const SizedBox(height: 24),

                              Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  ClipRRect(
                                    borderRadius: BorderRadius.circular(20),
                                    child: Image.asset(
                                      'assets/app_icon_1024.png',
                                      width: 80,
                                      height: 80,
                                      fit: BoxFit.fill,
                                    ),
                                  ),
                                  const SizedBox(width: 16),
                                  Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Row(
                                        children: [
                                          Text(
                                            'Al-Shobaki Academy',
                                            style:
                                                theme.textTheme.headlineMedium,

                                            maxLines: 1,
                                            textAlign: TextAlign.center,
                                          ),
                                        ],
                                      ),
                                      const SizedBox(height: 4),
                                      Text(
                                        'طريقك نحو التفوق و التميز',
                                        style: theme.textTheme.bodyLarge
                                            ?.copyWith(
                                              color: theme.colorScheme.onSurface
                                                  .withValues(alpha: 0.5),
                                            ),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                              const SizedBox(height: 40),

                              FadeInUp(
                                duration: const Duration(milliseconds: 800),
                                from: 75,
                                child: Container(
                                  padding: const EdgeInsets.all(24),
                                  decoration: BoxDecoration(
                                    color: Colors.white,
                                    borderRadius: BorderRadius.circular(20),
                                    boxShadow: [
                                      BoxShadow(
                                        color: Colors.black.withValues(
                                          alpha: 0.06,
                                        ),
                                        blurRadius: 24,
                                        offset: const Offset(0, 8),
                                      ),
                                    ],
                                  ),
                                  child: Column(
                                    children: [
                                      Directionality(
                                        textDirection: TextDirection.ltr,
                                        child: TextFormField(
                                          controller: phoneController,
                                          style: theme.textTheme.bodyMedium,
                                          keyboardType: TextInputType.phone,
                                          validator: (v) =>
                                              (v == null || v.isEmpty)
                                              ? 'الرجاء ادخال رقم الهاتف'
                                              : null,
                                          decoration: InputDecoration(
                                            hintTextDirection:
                                                TextDirection.rtl,
                                            hintText: 'رقم الهاتف',
                                            suffixIcon: Padding(
                                              padding: const EdgeInsets.all(
                                                8.0,
                                              ),
                                              child: Icon(Icons.phone_android),
                                            ),
                                            prefixIcon: Column(
                                              mainAxisAlignment:
                                                  MainAxisAlignment.center,
                                              children: [
                                                Text(
                                                  '+971 ',
                                                  style: theme
                                                      .textTheme
                                                      .bodyMedium,
                                                ),
                                              ],
                                            ),
                                          ),
                                        ),
                                      ),
                                      const SizedBox(height: 16),

                                      TextFormField(
                                        controller: passwordController,
                                        style: theme.textTheme.bodyMedium,
                                        obscureText: isObscure,
                                        validator: (v) =>
                                            (v == null || v.isEmpty)
                                            ? 'الرجاء ادخال كلمة المرور'
                                            : null,
                                        decoration: InputDecoration(
                                          hintText: 'كلمة السر',
                                          prefixIcon: const Icon(
                                            Icons.lock_outline,
                                          ),
                                          suffixIcon: IconButton(
                                            onPressed: () => setState(() {
                                              isObscure = !isObscure;
                                            }),
                                            icon: isObscure
                                                ? const Icon(
                                                    Icons.remove_red_eye,
                                                  )
                                                : const Icon(
                                                    Icons.visibility_off,
                                                  ),
                                          ),
                                        ),
                                      ),
                                      const SizedBox(height: 16),

                                      Row(
                                        mainAxisAlignment:
                                            MainAxisAlignment.spaceBetween,
                                        children: [
                                          InkWell(
                                            mouseCursor: SystemMouseCursors.click,
                                            onTap: () => launchUrl(
                                              Uri.parse(
                                                'https://alshobakiacademy.com/signup',
                                              ),
                                              mode: LaunchMode
                                                  .externalApplication,
                                            ),
                                            child: Text(
                                              'انشاء حساب جديد',
                                              style: TextStyle(
                                                color: theme
                                                    .colorScheme
                                                    .onSurface
                                                    .withValues(alpha: 0.6),
                                              ),
                                            ),
                                          ),
                                          InkWell(
                                            mouseCursor: SystemMouseCursors.click,
                                            onTap: () =>
                                                Get.toNamed('/forgot_password'),
                                            child: Text(
                                              'نسيت كلمة المرور؟',
                                              style: TextStyle(
                                                decoration:
                                                    TextDecoration.underline,
                                                color: theme
                                                    .colorScheme
                                                    .onSurface
                                                    .withValues(alpha: 0.6),
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                      const SizedBox(height: 28),

                                      SizedBox(
                                        width: double.infinity,
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

                                          child: Text(
                                            'تسجيل الدخول',
                                            style: theme.textTheme.bodyLarge,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),

                              const SizedBox(height: 20),
                              Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  if (!(Platform.isWindows ||
                                      Platform.isMacOS ||
                                      Platform.isLinux))
                                    IconButton(
                                      icon: const Icon(
                                        Icons.fingerprint,
                                        size: 28,
                                      ),
                                      onPressed: () async {
                                        await authController
                                            .loginWithFingerprint();
                                      },
                                    ),
                                  InkWell(
                                    mouseCursor: SystemMouseCursors.click,
                                    child: Text(
                                      'الاكمال كضيف',
                                      style: theme.textTheme.bodyMedium
                                          ?.copyWith(
                                            color: theme.colorScheme.onSurface
                                                .withValues(alpha: 0.6),
                                          ),
                                    ),
                                    onTap: () =>
                                        authController.enterGuestMode(),
                                  ),
                                ],
                              ),

                              const SizedBox(height: 24),
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
    phone = phone.replaceAll(RegExp(r'[^0-9]'), '');
    if (phone.startsWith('971')) return phone;
    phone = phone.replaceFirst(RegExp(r'^0+'), '');
    return '971$phone';
  }
}
