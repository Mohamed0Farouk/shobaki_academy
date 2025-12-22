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
                              'للتواصل مع دعم المنصة  ',
                              style: Theme.of(context).textTheme.bodySmall,
                              softWrap: true,
                            ),
                            //TODO: update whatsapp number
                            InkWell(
                              onTap: () => _launchUrl(
                                'https://wa.me/+?text=${Uri.encodeFull('')}',
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
                        const SizedBox(height: 4),
                        Wrap(
                          alignment: WrapAlignment.center,
                          crossAxisAlignment: WrapCrossAlignment.center,
                          children: [
                            //TODO: update whatsapp number
                            InkWell(
                              onTap: () => _launchUrl(
                                'https://wa.me/+?text=${Uri.encodeFull('')}',
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
                            SizedBox(width: 12),
                            InkWell(
                              onTap: () => showFirstLaunchDialog(), 
                              child: Text(
                                'عرض ارشادات الاستخدام',
                                style: Theme.of(context).textTheme.bodySmall!
                                    .copyWith(
                                      decoration: TextDecoration.underline,
                                    ),
                                softWrap: true,
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
                          'Made with ❤️ By Mohamed Farouk',
                          style: Theme.of(context).textTheme.bodySmall!
                              .copyWith(fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(height: 2),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          spacing: 15,
                          children: [
                            InkWell(
                              onTap: () => _launchUrl(
                                'https://wa.me/+201200164345?text=${Uri.encodeFull('')}',
                              ),
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.center,
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
                            InkWell(
                              onTap: () => _launchUrl(
                                'https://www.instagram.com/mohamed.farouk.dev?igsh=azc5M2R3NjUwNXpw',
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
        title: const Text('Welcome 👋'),
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

  Future<void> _launchUrl(url) async {
    if (await canLaunchUrl(Uri.parse(url))) {
      await launchUrl(Uri.parse(url));
    } else {
      Get.snackbar(
        'Error',
        'Couldn\'t Launch Whatsapp',
        snackPosition: SnackPosition.BOTTOM,
        backgroundColor: Colors.yellow.withOpacity(0.5),
      );
    }
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
