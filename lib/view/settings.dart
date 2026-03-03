import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:shobaki_academy/controller/auth_controller.dart';
//import 'package:shobaki_academy/extentions.dart';
import 'package:shobaki_academy/services/statics.dart';
import 'package:url_launcher/url_launcher.dart';

class SettingsPage extends StatefulWidget {
  const SettingsPage({super.key, this.isGuest = false});
  final bool isGuest;

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  Map<String, dynamic>? _user;
  bool _loading = true;
  late final AuthController? _auth;

  @override
  void initState() {
    super.initState();
    _auth = Get.put(AuthController(), permanent: false);
    _loadUser();
  }

  Future<void> _loadUser() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString('UserData');
    if (raw != null) {
      try {
        _user = jsonDecode(raw) as Map<String, dynamic>;
      } catch (_) {
        _user = null;
      }
    }
    setState(() => _loading = false);
  }

  Future<void> _logout() async {
    loadingDilog(context);
    // prefer controller signout if available
    try {
      if (_auth!.isGuestMode.value) {
        await _auth.exitGuestMode();
      }
      await _auth.signout();
    } catch (_) {
      Get.close(1);
      Get.offAllNamed('/login');
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: Colors.grey.shade100,
        body: _loading
            ? Center(child: loading(context))
            : SafeArea(
                child: Center(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.all(16.0),
                    child: Column(
                      children: [
                        // ===========================
                        // USER HEADER CARD
                        // ===========================
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(20),
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              colors: [
                                theme.colorScheme.primary.withOpacity(0.9),
                                theme.colorScheme.primary.withOpacity(0.6),
                              ],
                              begin: Alignment.topRight,
                              end: Alignment.bottomLeft,
                            ),
                            borderRadius: BorderRadius.circular(20),
                            boxShadow: const [
                              BoxShadow(
                                blurRadius: 12,
                                color: Colors.black12,
                                offset: Offset(0, 4),
                              ),
                            ],
                          ),
                          child: Column(
                            children: [
                              CircleAvatar(
                                radius: 40,
                                backgroundColor: Colors.white,
                                child: const Icon(
                                  Icons.person,
                                  size: 50,
                                  color: Colors.grey,
                                ),
                              ),
                              const SizedBox(height: 12),
                              Text(
                                _user?['name'] ?? '—',
                                style: theme.textTheme.headlineSmall!.copyWith(
                                  color: Colors.white,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                _user?['phone_number'] ?? '—',
                                style: theme.textTheme.bodyLarge!.copyWith(
                                  color: Colors.white70,
                                ),
                              ),
                            ],
                          ),
                        ),

                        const SizedBox(height: 20),

                        // ===========================
                        // USER INFO CARD
                        // ===========================
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(16),
                            boxShadow: const [
                              BoxShadow(
                                blurRadius: 10,
                                offset: Offset(0, 3),
                                color: Colors.black12,
                              ),
                            ],
                          ),
                          child: Column(
                            children: [
                              _tile(
                                Icons.school,
                                'اسم المدرسة',
                                _user?['school_name'] ?? '—',
                              ),
                              _divider(),
                              _tile(
                                Icons.menu_book,
                                'المرحلة',
                                _user?['stage'] ?? '—',
                              ),
                              _divider(),
                              _tile(
                                Icons.location_city,
                                'الامارة / المدينة',
                                _user?['goverment'] ?? '—',
                              ),
                            ],
                          ),
                        ),

                        const SizedBox(height: 35),

                        // ===========================
                        // LOGOUT BUTTON
                        // ===========================
                        _user!['email'] == 'guest@example.com'
                            ? SizedBox.shrink()
                            : Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  ElevatedButton(
                                    onPressed: _logout,
                                    style: ElevatedButton.styleFrom(
                                      padding: const EdgeInsets.symmetric(
                                        vertical: 16,
                                      ),
                                      backgroundColor: Colors.redAccent,
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(12),
                                      ),
                                      elevation: 6,
                                      shadowColor: Colors.redAccent.withOpacity(
                                        0.4,
                                      ),
                                    ),
                                    child: Padding(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 25,
                                        vertical: 10,
                                      ),
                                      child: Text(
                                        'تسجيل الخروج',
                                        style: theme.textTheme.bodyLarge!
                                            .copyWith(color: Colors.white),
                                      ),
                                    ),
                                  ),
                                  const SizedBox(height: 15, width: 15),
                                  ElevatedButton(
                                    onPressed: () {
                                      showDialog(
                                        context: context,
                                        builder: (context) => AlertDialog(
                                          title: Text(
                                            'حذف الحساب',
                                            style: Theme.of(
                                              context,
                                            ).textTheme.headlineMedium,
                                            textAlign: TextAlign.center,
                                          ),
                                          content: Column(
                                            mainAxisSize: MainAxisSize.min,
                                            children: [
                                              Text(
                                                'هل أنت متأكد من حذف حسابك؟',
                                                style: Theme.of(context)
                                                    .textTheme
                                                    .bodyLarge!
                                                    .copyWith(
                                                      fontWeight:
                                                          FontWeight.normal,
                                                    ),
                                                textAlign: TextAlign.start,
                                              ),
                                              const SizedBox(height: 8),
                                              Text(
                                                'سيتم حذف جميع بياناتك بشكل نهائي',
                                                style: Theme.of(context)
                                                    .textTheme
                                                    .bodyMedium
                                                    ?.copyWith(
                                                      color: Colors.red,
                                                    ),
                                                textAlign: TextAlign.start,
                                              ),
                                            ],
                                          ),
                                          actions: [
                                            TextButton(
                                              onPressed: () =>
                                                  Navigator.pop(context),
                                              child: Text(
                                                'إلغاء',
                                                style: Theme.of(
                                                  context,
                                                ).textTheme.bodyMedium,
                                              ),
                                            ),
                                            ElevatedButton(
                                              onPressed: () {
                                                Navigator.pop(context);
                                                AuthController()
                                                    .deleteAccount();
                                              },
                                              style: ElevatedButton.styleFrom(
                                                backgroundColor: Colors.red,
                                              ),
                                              child: Text(
                                                'حذف الحساب',
                                                style: Theme.of(
                                                  context,
                                                ).textTheme.bodyMedium,
                                              ),
                                            ),
                                          ],
                                        ),
                                      );
                                    },
                                    style: ElevatedButton.styleFrom(
                                      padding: const EdgeInsets.symmetric(
                                        vertical: 16,
                                      ),
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(12),
                                      ),
                                      elevation: 6,
                                    ),
                                    child: Padding(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 25,
                                        vertical: 10,
                                      ),
                                      child: Text(
                                        'حذف الحساب',
                                        style: Theme.of(context)
                                            .textTheme
                                            .bodyLarge!
                                            .copyWith(color: Colors.white),
                                      ),
                                    ),
                                  ),
                                  SizedBox(height: 30),
                                ],
                              ),
                        SizedBox(height: 30),
                        Wrap(
                          alignment: WrapAlignment.center,
                          crossAxisAlignment: WrapCrossAlignment.center,
                          children: [
                            Text(
                              'للاستعلام ',
                              style: Theme.of(context).textTheme.bodySmall,
                              softWrap: true,
                            ),
                            //TODO: update whatsapp number
                            InkWell(
                              onTap: () => launchUrl(
                                Uri.parse(
                                  'https://wa.me/+971508124370?text=${Uri.encodeFull('')}',
                                ),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                spacing: 5,
                                children: [
                                  Text(
                                    'Whatapp',
                                    style: Theme.of(context)
                                        .textTheme
                                        .bodySmall!
                                        .copyWith(color: Colors.green),
                                  ),
                                  Image.asset(
                                    'assets/logos/whatsapp.png',
                                    width: 20,
                                    height: 20,
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Wrap(
                          alignment: WrapAlignment.center,
                          crossAxisAlignment: WrapCrossAlignment.center,
                          children: [
                            Text(
                              'للتواصل مع دعم المنصة  ',
                              style: Theme.of(context).textTheme.bodySmall,
                              softWrap: true,
                            ),
                            //TODO: update whatsapp number
                            InkWell(
                              onTap: () => launchUrl(
                                Uri.parse(
                                  'https://wa.me/+971502762100?text=${Uri.encodeFull('')}',
                                ),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                spacing: 5,
                                children: [
                                  Text(
                                    'Whatapp',
                                    style: Theme.of(context)
                                        .textTheme
                                        .bodySmall!
                                        .copyWith(color: Colors.green),
                                  ),
                                  Image.asset(
                                    'assets/logos/whatsapp.png',
                                    width: 20,
                                    height: 20,
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Wrap(
                          alignment: WrapAlignment.center,
                          crossAxisAlignment: WrapCrossAlignment.center,
                          spacing: 16,

                          children: [
                            Container(
                              margin: const EdgeInsets.only(bottom: 6),
                              child: InkWell(
                                onTap: () => launchUrl(
                                  Uri.parse(
                                    'https://alshobakiacademy.com/privacy',
                                  ),
                                ),
                                child: Text(
                                  'سياسة الخصوصية و شروط الاستخدام  ',
                                  style: Theme.of(context).textTheme.bodySmall!
                                      .copyWith(
                                        decoration: TextDecoration.underline,
                                      ),
                                  softWrap: true,
                                ),
                              ),
                            ),
                            Container(
                              margin: const EdgeInsets.only(bottom: 6),

                              child: InkWell(
                                onTap: () => launchUrl(
                                  Uri.parse(
                                    'https://alshobakiacademy.com/guidelines',
                                  ),
                                ),
                                child: Text(
                                  'عرض ارشادات الاستخدام',
                                  style: Theme.of(context).textTheme.bodySmall!
                                      .copyWith(
                                        decoration: TextDecoration.underline,
                                      ),
                                  softWrap: true,
                                ),
                              ),
                            ),
                            _user!['email'] ==
                                        'appletestaccount#97111111111111@gmail.com' ||
                                    _user!['email'] == 'guest@example.com'
                                ? SizedBox.shrink()
                                : Container(
                                    margin: const EdgeInsets.only(bottom: 6),
                                    child: InkWell(
                                      onTap: () => launchUrl(
                                        Uri.parse(
                                          'https://alshobakiacademy.com/payment',
                                        ),
                                      ),
                                      child: Text(
                                        'عرض طرق الدفع ',
                                        style: Theme.of(context)
                                            .textTheme
                                            .bodySmall!
                                            .copyWith(
                                              decoration:
                                                  TextDecoration.underline,
                                            ),
                                        softWrap: true,
                                      ),
                                    ),
                                  ),
                          ],
                        ),
                        const SizedBox(height: 15),
                        const Padding(
                          padding: EdgeInsets.symmetric(horizontal: 30),
                          child: Divider(),
                        ),
                        const SizedBox(height: 15),
                        Text(
                          'Made with ❤️ By Eng / Mohamed Farouk',
                          style: Theme.of(context).textTheme.bodySmall!
                              .copyWith(fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(height: 2),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          spacing: 15,
                          children: [
                            // InkWell(
                            //   onTap: () => _launchUrl(
                            //     'https://wa.me/+201200164345?text=${Uri.encodeFull('')}',
                            //   ),
                            //   child: Row(
                            //     mainAxisAlignment: MainAxisAlignment.center,
                            //     spacing: 5,
                            //     children: [
                            //       Text(
                            //         'Whatapp',
                            //         style: Theme.of(context)
                            //             .textTheme
                            //             .bodySmall!
                            //             .copyWith(color: Colors.green),
                            //       ),
                            //       Image.asset(
                            //         'assets/logos/whatsapp.png',
                            //         width: 20,
                            //         height: 20,
                            //       ),
                            //     ],
                            //   ),
                            // ),
                            InkWell(
                              onTap: () => launchUrl(
                                Uri.parse(
                                  'https://www.instagram.com/mohamed.farouk.dev?igsh=azc5M2R3NjUwNXpw',
                                ),
                              ),
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                spacing: 5,
                                children: [
                                  Text(
                                    'Instagram',
                                    style: Theme.of(context)
                                        .textTheme
                                        .bodySmall!
                                        .copyWith(color: Colors.pinkAccent),
                                  ),
                                  Image.asset(
                                    'assets/logos/instgram.png',
                                    width: 25,
                                    height: 25,
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ),
      ),
    );
  }

  Future<void> showFirstLaunchDialog({bool dismissible = true}) {
    return Get.dialog(
      AlertDialog(
        title: const Text('ارشادات الاستخدام'),
        content: const Text(
          'Welcome to the app!\n\nHere you can explain features, rules, or anything important.',
        ),
        actions: [
          TextButton(onPressed: () => Get.back(), child: const Text('Got it')),
        ],
      ),
      barrierDismissible: dismissible,
    );
  }

  Future<void> showPaymentMethodsDialog({bool dismissible = true}) {
    return Get.dialog(
      Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        child: Container(
          constraints: BoxConstraints(maxWidth: 500),
          child: SingleChildScrollView(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Directionality(
                textDirection: TextDirection.rtl,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // Header
                    Row(
                      children: [
                        Icon(Icons.payment, color: Colors.blue, size: 28),
                        SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            'طرق الدفع',
                            style: TextStyle(
                              fontSize: 22,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                        IconButton(
                          icon: Icon(Icons.close),
                          onPressed: () => Get.back(),
                          padding: EdgeInsets.zero,
                          constraints: BoxConstraints(),
                        ),
                      ],
                    ),
                    SizedBox(height: 24),

                    // Payment Method 1: Bank Transfer
                    _buildPaymentMethod(
                      icon: Icons.account_balance,
                      title: '1. التحويل البنكي',
                      children: [
                        _buildBankAccount(
                          accountName: 'juma Al shobaki',
                          bankName: 'WIO',
                          iban: 'AE960860000009227058837',
                          swiftBic: 'WIOBAEADXXX',
                        ),
                        SizedBox(height: 16),
                        _buildBankAccount(
                          accountName: 'QUMAT ALTOMOH C B LLC',
                          bankName: 'بنك ابو ظبي التجاري ADCB',
                          accountNumber: '12853891920001',
                          iban: 'AE110030012853891920001',
                        ),
                      ],
                    ),

                    SizedBox(height: 20),
                    Divider(),
                    SizedBox(height: 20),

                    // Payment Method 2: Stripe
                    _buildPaymentMethod(
                      icon: Icons.credit_card,
                      title: '2. الدفع عبر Stripe',
                      children: [
                        SizedBox(height: 8),
                        Center(
                          child: ElevatedButton.icon(
                            onPressed: () {
                              launchUrl(
                                Uri.parse(
                                  'https://buy.stripe.com/bIYcQ2eSM1Su1S8dQW',
                                ),
                                mode: LaunchMode.externalApplication,
                              );
                            },
                            icon: Icon(Icons.open_in_new),
                            label: Padding(
                              padding: const EdgeInsets.all(8.0),
                              child: Text(
                                'الدفع بالبطاقة الآن',
                                style: Theme.of(context).textTheme.bodyMedium!
                                    .copyWith(
                                      color: Colors.white,
                                      fontWeight: FontWeight.bold,
                                    ),
                              ),
                            ),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.blue,
                              foregroundColor: Colors.white,
                              padding: EdgeInsets.symmetric(vertical: 14),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(8),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),

                    SizedBox(height: 20),
                    Divider(),
                    SizedBox(height: 20),

                    // Instructions
                    Container(
                      padding: EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.blue.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.blue.withOpacity(0.3)),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Icon(
                                Icons.info_outline,
                                color: Colors.blue,
                                size: 20,
                              ),
                              SizedBox(width: 8),
                              Text(
                                'تعليمات مهمة',
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 16,
                                  color: Colors.blue.shade700,
                                ),
                              ),
                            ],
                          ),
                          SizedBox(height: 12),
                          _buildInfoRow(
                            Icons.receipt_long,
                            'بعد إتمام الدفع، يرجى إرسال صورة الإيصال على الواتساب',
                          ),
                          SizedBox(height: 8),
                          _buildInfoRow(
                            Icons.warning_amber,
                            'الرسوم غير قابلة للاسترداد بعد الدفع لأي سبب كان',
                          ),
                          SizedBox(height: 8),
                          _buildInfoRow(
                            Icons.check_circle_outline,
                            'لا تسدد الرسوم إلا بعد التأكد من الالتزام مع الأستاذ',
                          ),
                        ],
                      ),
                    ),

                    SizedBox(height: 24),

                    // Action Button
                    TextButton(
                      onPressed: () => Get.back(),
                      style: TextButton.styleFrom(
                        padding: EdgeInsets.symmetric(vertical: 12),
                      ),
                      child: Text(
                        'فهمت',
                        style: Theme.of(context).textTheme.bodyLarge!.copyWith(
                          color: Colors.blue,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
      barrierDismissible: dismissible,
    );
  }

  // Helper Widgets
  Widget _buildPaymentMethod({
    required IconData icon,
    required String title,
    required List<Widget> children,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(icon, color: Colors.blue.shade700, size: 20),
            SizedBox(width: 8),
            Padding(
              padding: const EdgeInsets.all(8.0),
              child: Text(
                title,
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Colors.blue.shade700,
                ),
              ),
            ),
          ],
        ),
        SizedBox(height: 12),
        ...children,
      ],
    );
  }

  Widget _buildBankAccount({
    required String accountName,
    required String bankName,
    String? accountNumber,
    required String iban,
    String? swiftBic,
  }) {
    return Container(
      padding: EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.grey.shade50,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade300),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildDetailRow('اسم الحساب', accountName),
          _buildDetailRow('اسم البنك', bankName),
          if (accountNumber != null)
            _buildDetailRow('رقم الحساب', accountNumber),
          _buildDetailRow('IBAN (للتحويل)', iban, monospace: true),
          if (swiftBic != null)
            _buildDetailRow('BIC/SWIFT', swiftBic, monospace: true),
        ],
      ),
    );
  }

  Widget _buildDetailRow(String label, String value, {bool monospace = false}) {
    return Padding(
      padding: EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 120,
            child: Text(
              '$label:',
              style: TextStyle(
                fontWeight: FontWeight.w600,
                color: Colors.grey.shade700,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: TextStyle(
                fontFamily: monospace ? 'monospace' : null,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoRow(IconData icon, String text) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 18, color: Colors.blue.shade700),
        SizedBox(width: 8),
        Expanded(
          child: Text(text, style: TextStyle(fontSize: 14, height: 1.4)),
        ),
      ],
    );
  }

  Widget _tile(IconData icon, String label, String value) {
    return ListTile(
      leading: Icon(icon, color: Colors.blueGrey, size: 30),
      title: Text(
        label,
        style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 16),
      ),
      subtitle: Text(value, style: const TextStyle(fontSize: 14)),
      contentPadding: EdgeInsets.zero,
    );
  }

  Widget _divider() => const Divider(thickness: 1, height: 1);
}
