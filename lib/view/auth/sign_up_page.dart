import 'package:animate_do/animate_do.dart';
import 'package:flutter/material.dart';
import 'package:typewritertext/typewritertext.dart';
import 'package:get/get.dart';
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
                                      if (v != null && v.length < 9) {
                                        return 'بلرجاء ادخال الاسم كاملاً';
                                      }
                                      return (v == null || v.isEmpty)
                                          ? 'الرجاء ادخال الاسم'
                                          : null;
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
                                          'ادخل الاسم ثلاثي باللغة الانجليزية',
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
                                      filled: true,
                                      fillColor: Colors.grey[200],
                                      contentPadding:
                                          const EdgeInsets.symmetric(
                                            horizontal: 16,
                                            vertical: 16,
                                          ),
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
                                      border: OutlineInputBorder(
                                        borderRadius: BorderRadius.circular(12),
                                        borderSide: BorderSide.none,
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
                                    obscureText: true,
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
                                      value: auth.selectedStage.value.isEmpty
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

                                  // uae state dropdown
                                  Obx(() {
                                    return DropdownButtonFormField<String>(
                                      style: Theme.of(
                                        context,
                                      ).textTheme.bodyMedium,
                                      value: auth.selectedUae.value.isEmpty
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

                                  const SizedBox(height: 12),

                                  // subscription dropdown (if re-enabled)
                                  // Obx(() {
                                  //   return DropdownButtonFormField<String>(
                                  //     value:
                                  //         auth.selectedSubscription.value.isEmpty
                                  //         ? null
                                  //         : auth.selectedSubscription.value,
                                  //     items: auth.subscriptionOptions
                                  //         .map(
                                  //           (s) => DropdownMenuItem(
                                  //             value: s,
                                  //             child: Text(
                                  //               s,
                                  //               textAlign: TextAlign.right,
                                  //             ),
                                  //           ),
                                  //         )
                                  //         .toList(),
                                  //     onChanged: auth.setSubscription,
                                  //     decoration: InputDecoration(
                                  //       hintText: 'نوع الاشتراك',
                                  //       hintStyle: Theme.of(context)
                                  //           .textTheme
                                  //           .bodyMedium!
                                  //           .copyWith(color: Colors.grey),
                                  //       filled: true,
                                  //       fillColor: Colors.grey[200],
                                  //       contentPadding:
                                  //           const EdgeInsets.symmetric(
                                  //             horizontal: 12,
                                  //             vertical: 14,
                                  //           ),
                                  //       prefixIcon: const Icon(Icons.star_border),
                                  //       border: OutlineInputBorder(
                                  //         borderRadius: BorderRadius.circular(12),
                                  //         borderSide: BorderSide.none,
                                  //       ),
                                  //     ),
                                  //     validator: (v) => (v == null || v.isEmpty)
                                  //         ? 'اختر نوع الاشتراك'
                                  //         : null,
                                  //   );
                                  // }),

                                  // const SizedBox(height: 12),
                                  SizedBox(
                                    height: 48,
                                    child: ElevatedButton(
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: primary,
                                        shape: RoundedRectangleBorder(
                                          borderRadius: BorderRadius.circular(
                                            12,
                                          ),
                                        ),
                                      ),
                                      child: Row(
                                        mainAxisSize: MainAxisSize.min,
                                        spacing: 15,
                                        children: [
                                          Text(
                                            'تسجيل بصمة الاصبع',
                                            style: Theme.of(context)
                                                .textTheme
                                                .bodyLarge
                                                ?.copyWith(color: Colors.white),
                                          ),
                                          const Icon(
                                            Icons.fingerprint,
                                            size: 28,
                                          ),
                                        ],
                                      ),
                                      onPressed: () async {
                                        await auth.gatherFingerprint();
                                      },
                                    ),
                                  ),
                                  const SizedBox(height: 16),

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
