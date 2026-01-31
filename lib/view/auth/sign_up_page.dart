import 'package:animate_do/animate_do.dart';
import 'package:flutter/material.dart';
import 'package:typewritertext/typewritertext.dart';
import 'package:get/get.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:shobaki_academy/controller/auth_controller.dart';

class SignUpPage extends StatefulWidget {
  const SignUpPage({super.key});

  @override
  State<SignUpPage> createState() => _SignUpPageState();
}

class _SignUpPageState extends State<SignUpPage> {
  final TextEditingController nameController = TextEditingController();
  final TextEditingController phoneController = TextEditingController();
  final TextEditingController passwordController = TextEditingController();
  final TextEditingController schoolController = TextEditingController();
  final _formKey = GlobalKey<FormState>();
  bool isObscure = true;
  bool agreeToPrivacy = false;
  late final AuthController auth;

  @override
  void initState() {
    super.initState();
    auth = Get.put(AuthController());
  }

  @override
  void dispose() {
    nameController.dispose();
    phoneController.dispose();
    passwordController.dispose();
    schoolController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final primary = Theme.of(context).primaryColor;
    final size = MediaQuery.of(context).size;

    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        appBar: AppBar(
          backgroundColor: Colors.transparent,
          elevation: 0,
          iconTheme: const IconThemeData(color: Colors.black),
        ),
        resizeToAvoidBottomInset: false,
        extendBodyBehindAppBar: true,
        backgroundColor: Theme.of(context).scaffoldBackgroundColor,
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

            // content
            Positioned.fill(
              child: SafeArea(
                child: SingleChildScrollView(
                  // bottom padding respects keyboard inset so content scrolls above the keyboard
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
                            TypeWriter.text(
                              'اهلا بك في  Al-Shobaki Academy',
                              style: Theme.of(context).textTheme.headlineLarge
                                  ?.copyWith(
                                    fontSize: 26,
                                    fontWeight: FontWeight.w800,
                                  ),
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
                            const SizedBox(height: 24),

                            FadeInUp(
                              duration: const Duration(milliseconds: 800),
                              from: 75,
                              child: Column(
                                children: [
                                  // name
                                  TextFormField(
                                    controller: nameController,
                                    style: Theme.of(
                                      context,
                                    ).textTheme.bodyMedium,
                                    validator: (v) {
                                      if (v == null || v.trim().isEmpty) {
                                        return 'الرجاء إدخال الاسم';
                                      }

                                      if (v.trim().length < 9) {
                                        return 'برجاء إدخال الاسم كاملاً';
                                      }

                                      final englishNameRegex = RegExp(
                                        r'^[A-Za-z ]+$',
                                      );

                                      if (!englishNameRegex.hasMatch(
                                        v.trim(),
                                      )) {
                                        return 'الاسم يجب أن يكون باللغة الإنجليزية فقط';
                                      }

                                      return null;
                                    },
                                    decoration: InputDecoration(
                                      label: Text(
                                        'الاسم',
                                        style: Theme.of(context)
                                            .textTheme
                                            .bodyMedium!
                                            .copyWith(color: Colors.grey),
                                      ),
                                      hintText:
                                          'ادخل الاسم الكامل باللغة الانجليزية',
                                      filled: true,
                                      fillColor: Colors.grey[200],
                                      contentPadding:
                                          const EdgeInsets.symmetric(
                                            horizontal: 16,
                                            vertical: 16,
                                          ),
                                      prefixIcon: const Icon(Icons.person),
                                      border: OutlineInputBorder(
                                        borderRadius: BorderRadius.circular(12),
                                        borderSide: BorderSide.none,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(height: 16),

                                  // school
                                  TextFormField(
                                    controller: schoolController,
                                    style: Theme.of(
                                      context,
                                    ).textTheme.bodyMedium,
                                    validator: (v) => (v == null || v.isEmpty)
                                        ? 'الرجاء ادخال اسم المدرسة'
                                        : null,
                                    decoration: InputDecoration(
                                      hintText: 'اسم المدرسة',
                                      filled: true,
                                      fillColor: Colors.grey[200],
                                      contentPadding:
                                          const EdgeInsets.symmetric(
                                            horizontal: 16,
                                            vertical: 16,
                                          ),
                                      prefixIcon: const Icon(Icons.school),
                                      border: OutlineInputBorder(
                                        borderRadius: BorderRadius.circular(12),
                                        borderSide: BorderSide.none,
                                      ),
                                    ),
                                  ),

                                  const SizedBox(height: 16),

                                  // phone
                                  Directionality(
                                    textDirection: TextDirection.ltr,
                                    child: TextFormField(
                                      controller: phoneController,
                                      style: Theme.of(
                                        context,
                                      ).textTheme.bodyMedium,
                                      keyboardType: TextInputType.phone,
                                      validator: (v) => (v == null || v.isEmpty)
                                          ? 'الرجاء ادخال رقم الهاتف'
                                          : null,
                                      decoration: InputDecoration(
                                        hintTextDirection: TextDirection.rtl,
                                        hintText: 'رقم الهاتف',
                                        filled: true,

                                        fillColor: Colors.grey[200],
                                        contentPadding:
                                            const EdgeInsets.symmetric(
                                              horizontal: 16,
                                              vertical: 16,
                                            ),
                                        suffixIcon: Padding(
                                          padding: const EdgeInsets.all(8.0),
                                          child: const Icon(
                                            Icons.phone_android,
                                          ),
                                        ),
                                        prefixIcon: Column(
                                          mainAxisAlignment:
                                              MainAxisAlignment.center,
                                          children: [
                                            Text(
                                              '+971 ',
                                              style: Theme.of(
                                                context,
                                              ).textTheme.bodyMedium,
                                            ),
                                          ],
                                        ),
                                        border: OutlineInputBorder(
                                          borderRadius: BorderRadius.circular(
                                            12,
                                          ),
                                          borderSide: BorderSide.none,
                                        ),
                                      ),
                                    ),
                                  ),

                                  const SizedBox(height: 16),

                                  // password
                                  TextFormField(
                                    controller: passwordController,
                                    style: Theme.of(
                                      context,
                                    ).textTheme.bodyMedium,
                                    obscureText: isObscure,
                                    validator: (v) => (v == null || v.isEmpty)
                                        ? 'الرجاء ادخال كلمة المرور'
                                        : null,
                                    decoration: InputDecoration(
                                      hintText: 'كلمة السر',
                                      filled: true,
                                      fillColor: Colors.grey[200],
                                      contentPadding:
                                          const EdgeInsets.symmetric(
                                            horizontal: 16,
                                            vertical: 16,
                                          ),
                                      suffixIcon: IconButton(
                                        onPressed: () => setState(() {
                                          isObscure = !isObscure;
                                        }),
                                        icon: isObscure
                                            ? Icon(Icons.remove_red_eye)
                                            : Icon(Icons.visibility_off),
                                      ),
                                      prefixIcon: const Icon(
                                        Icons.lock_outline,
                                      ),
                                      border: OutlineInputBorder(
                                        borderRadius: BorderRadius.circular(12),
                                        borderSide: BorderSide.none,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(height: 16),

                                  // education stage dropdown
                                  Obx(() {
                                    return DropdownButtonFormField<String>(
                                      style: Theme.of(
                                        context,
                                      ).textTheme.bodyMedium,
                                      initialValue:
                                          auth.selectedStage.value.isEmpty
                                          ? null
                                          : auth.selectedStage.value,
                                      items: auth.educationStages
                                          .map(
                                            (s) => DropdownMenuItem(
                                              value: s,
                                              child: Text(
                                                s,
                                                textAlign: TextAlign.right,
                                              ),
                                            ),
                                          )
                                          .toList(),
                                      onChanged: auth.setStage,
                                      decoration: InputDecoration(
                                        hintText: 'المرحلة الدراسية',
                                        hintStyle: Theme.of(
                                          context,
                                        ).textTheme.bodyMedium,
                                        filled: true,
                                        fillColor: Colors.grey[200],
                                        contentPadding:
                                            const EdgeInsets.symmetric(
                                              horizontal: 12,
                                              vertical: 14,
                                            ),
                                        prefixIcon: const Icon(
                                          Icons.menu_book_outlined,
                                        ),
                                        border: OutlineInputBorder(
                                          borderRadius: BorderRadius.circular(
                                            12,
                                          ),
                                          borderSide: BorderSide.none,
                                        ),
                                      ),
                                      validator: (v) => (v == null || v.isEmpty)
                                          ? 'اختر المرحلة الدراسية'
                                          : null,
                                    );
                                  }),

                                  const SizedBox(height: 16),

                                  Obx(() {
                                    return DropdownButtonFormField<String>(
                                      style: Theme.of(
                                        context,
                                      ).textTheme.bodyMedium,
                                      initialValue:
                                          auth.selectedUae.value.isEmpty
                                          ? null
                                          : auth.selectedUae.value,
                                      items: auth.uaeStates
                                          .map(
                                            (s) => DropdownMenuItem(
                                              value: s,
                                              child: Text(
                                                s,
                                                textAlign: TextAlign.right,
                                              ),
                                            ),
                                          )
                                          .toList(),
                                      onChanged: auth.setUae,
                                      decoration: InputDecoration(
                                        hintText: 'الامارة',
                                        hintStyle: Theme.of(context)
                                            .textTheme
                                            .bodyMedium!
                                            .copyWith(color: Colors.grey),
                                        filled: true,
                                        fillColor: Colors.grey[200],
                                        contentPadding:
                                            const EdgeInsets.symmetric(
                                              horizontal: 12,
                                              vertical: 14,
                                            ),
                                        prefixIcon: const Icon(
                                          Icons.location_on,
                                        ),
                                        border: OutlineInputBorder(
                                          borderRadius: BorderRadius.circular(
                                            12,
                                          ),
                                          borderSide: BorderSide.none,
                                        ),
                                      ),
                                      validator: (v) => (v == null || v.isEmpty)
                                          ? 'اختر الامارة'
                                          : null,
                                    );
                                  }),

                                  const SizedBox(height: 16),

                                  FormField<bool>(
                                    validator: (v) => !agreeToPrivacy
                                        ? 'يجب الموافقة على سياسة الخصوصية'
                                        : null,
                                    builder: (formFieldState) {
                                      return Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Row(
                                            children: [
                                              Checkbox(
                                                value: agreeToPrivacy,
                                                onChanged: (value) {
                                                  setState(() {
                                                    agreeToPrivacy =
                                                        value ?? false;
                                                  });
                                                  formFieldState.didChange(
                                                    value,
                                                  );
                                                },
                                              ),
                                              Expanded(
                                                child: InkWell(
                                                  onTap: () async {
                                                    final Uri url = Uri.parse(
                                                      'https://www.alshobaki.com/privacy-policy',
                                                    );
                                                    if (await canLaunchUrl(
                                                      url,
                                                    )) {
                                                      await launchUrl(
                                                        url,
                                                        mode: LaunchMode
                                                            .externalApplication,
                                                      );
                                                    }
                                                  },
                                                  child: RichText(
                                                    text: TextSpan(
                                                      children: [
                                                        TextSpan(
                                                          text: 'اوافق على ',
                                                          style: Theme.of(
                                                            context,
                                                          ).textTheme.bodySmall,
                                                        ),
                                                        TextSpan(
                                                          text:
                                                              'سياسة الخصوصية',
                                                          style: Theme.of(context)
                                                              .textTheme
                                                              .bodySmall
                                                              ?.copyWith(
                                                                color: Theme.of(
                                                                  context,
                                                                ).primaryColor,
                                                                decoration:
                                                                    TextDecoration
                                                                        .underline,
                                                              ),
                                                        ),
                                                      ],
                                                    ),
                                                  ),
                                                ),
                                              ),
                                            ],
                                          ),
                                          if (formFieldState.hasError)
                                            Padding(
                                              padding: const EdgeInsets.only(
                                                top: 8.0,
                                                right: 12.0,
                                              ),
                                              child: Text(
                                                formFieldState.errorText ?? '',
                                                style: Theme.of(context)
                                                    .textTheme
                                                    .bodySmall
                                                    ?.copyWith(
                                                      color: Colors.red,
                                                    ),
                                              ),
                                            ),
                                        ],
                                      );
                                    },
                                  ),

                                  const SizedBox(height: 12),

                                  SizedBox(
                                    width: double.infinity,
                                    height: 48,
                                    child: ElevatedButton(
                                      onPressed: () async {
                                        if (_formKey.currentState?.validate() ??
                                            false) {
                                          await auth.signup(
                                            context,
                                            name: nameController.text.trim(),
                                            schoolName: schoolController.text
                                                .trim(),
                                            password: passwordController.text,
                                            studentPhoneNumber: add971Prefix(
                                              phoneController.text.trim(),
                                            ),
                                          );
                                        }
                                      },
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: primary,
                                        shape: RoundedRectangleBorder(
                                          borderRadius: BorderRadius.circular(
                                            12,
                                          ),
                                        ),
                                      ),
                                      child: Text(
                                        'انشاء حساب',
                                        style: Theme.of(context)
                                            .textTheme
                                            .bodyLarge
                                            ?.copyWith(color: Colors.white),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
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
