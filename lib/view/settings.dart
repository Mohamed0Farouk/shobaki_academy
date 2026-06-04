import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:shobaki_academy/controller/auth_controller.dart';
import 'package:shobaki_academy/services/statics.dart';
import 'package:shobaki_academy/theme.dart';
import 'package:shobaki_academy/utils/responsive_utils.dart';
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
    final primary = theme.colorScheme.primary;
    final isPhone = ResponsiveUtils.isPhone(context);

    final content = _loading
        ? Center(child: loading(context))
        : _buildSettingsContent(theme, primary, isPhone);

    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: Theme.of(context).scaffoldBackgroundColor,
        body: isPhone
            ? SafeArea(child: content)
            : content,
      ),
    );
  }

  Widget _buildSettingsContent(ThemeData theme, Color primary, bool isPhone) {
    final sections = [
      _buildProfileHeader(theme, primary),
      const SizedBox(height: 20),
      _buildInfoCard(theme),
      const SizedBox(height: 24),
      if (_user?['email'] != 'guest@example.com')
        _buildAccountSection(context, theme, primary),
      const SizedBox(height: 24),
      _buildContactSection(theme),
      const SizedBox(height: 24),
      _buildLinksSection(theme),
      const SizedBox(height: 24),
      _buildAboutSection(theme),
      const SizedBox(height: 30),
    ];

    if (isPhone) {
      return SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.start,
          children: sections,
        ),
      );
    }

    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 800),
        child: Column(
          children: [
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(16),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.start,
                  children: sections,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildProfileHeader(ThemeData theme, Color primary) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            primary.withValues(alpha: 0.9),
            primary.withValues(alpha: 0.6),
          ],
          begin: Alignment.topRight,
          end: Alignment.bottomLeft,
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.1),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: [
          CircleAvatar(
            radius: 40,
            backgroundColor: Colors.white,
            child: Icon(Icons.person, size: 50, color: Colors.grey[400]),
          ),
          const SizedBox(height: 12),
          Text(
            _user?['name'] ?? '—',
            style: theme.textTheme.headlineSmall?.copyWith(
              color: Colors.white,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            _user?['phone_number'] ?? '—',
            style: theme.textTheme.bodyMedium?.copyWith(color: Colors.white70),
            textDirection: TextDirection.ltr,
          ),
        ],
      ),
    );
  }

  Widget _buildInfoCard(ThemeData theme) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [AppTheme.cardShadow],
      ),
      child: Column(
        children: [
          _tile(Icons.school, 'اسم المدرسة', _user?['school_name'] ?? '—'),
          const Divider(thickness: 1, height: 1),
          _tile(Icons.menu_book, 'المرحلة', _user?['stage'] ?? '—'),
          const Divider(thickness: 1, height: 1),
          _tile(Icons.location_city, 'الامارة', _user?['goverment'] ?? '—'),
        ],
      ),
    );
  }

  Widget _buildAccountSection(
    BuildContext context,
    ThemeData theme,
    Color primary,
  ) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [AppTheme.cardShadow],
      ),
      child: Column(
        children: [
          _sectionHeader(theme, 'الحساب'),
          ListTile(
            leading: Icon(Icons.logout, color: Colors.redAccent, size: 22),
            title: Text('تسجيل الخروج', style: theme.textTheme.bodyMedium),
            trailing: const Icon(Icons.chevron_left, color: Colors.black38),
            onTap: _logout,
          ),
          const Divider(height: 1, indent: 16, endIndent: 16),
          ListTile(
            leading: Icon(
              Icons.delete_forever,
              color: Colors.red.shade300,
              size: 22,
            ),
            title: Text(
              'حذف الحساب',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: Colors.red.shade300,
              ),
            ),
            trailing: const Icon(Icons.chevron_left, color: Colors.black38),
            onTap: () => _showDeleteDialog(context),
          ),
        ],
      ),
    );
  }

  void _showDeleteDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('حذف الحساب', textAlign: TextAlign.center),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('هل أنت متأكد من حذف حسابك؟'),
            const SizedBox(height: 8),
            Text(
              'سيتم حذف جميع بياناتك بشكل نهائي',
              style: TextStyle(color: Colors.red.shade400),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('إلغاء'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(ctx);
              AuthController().deleteAccount();
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('حذف الحساب'),
          ),
        ],
      ),
    );
  }

  Widget _buildContactSection(ThemeData theme) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [AppTheme.cardShadow],
      ),
      child: Column(
        children: [
          _sectionHeader(theme, 'التواصل'),
          ListTile(
            leading: Image.asset(
              'assets/logos/whatsapp.png',
              width: 22,
              height: 22,
            ),
            title: Text('للاستعلام', style: theme.textTheme.bodyMedium),
            subtitle: Text(
              '+971 50 812 4370',
              style: theme.textTheme.labelMedium,
              textDirection: TextDirection.ltr,
            ),
            trailing: const Icon(Icons.chevron_left, color: Colors.black38),
            onTap: () => launchUrl(Uri.parse('https://wa.me/+971508124370')),
          ),
          const Divider(height: 1, indent: 16, endIndent: 16),
          ListTile(
            leading: Image.asset(
              'assets/logos/whatsapp.png',
              width: 22,
              height: 22,
            ),
            title: Text('دعم المنصة', style: theme.textTheme.bodyMedium),
            subtitle: Text(
              '+971 50 276 2100',
              style: theme.textTheme.labelMedium,
              textDirection: TextDirection.ltr,
            ),
            trailing: const Icon(Icons.chevron_left, color: Colors.black38),
            onTap: () => launchUrl(Uri.parse('https://wa.me/+971502762100')),
          ),
        ],
      ),
    );
  }

  Widget _buildLinksSection(ThemeData theme) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [AppTheme.cardShadow],
      ),
      child: Column(
        children: [
          _sectionHeader(theme, 'روابط مهمة'),
          _linkTile(
            theme,
            'سياسة الخصوصية',
            'https://alshobakiacademy.com/privacy',
          ),
          const Divider(height: 1, indent: 16, endIndent: 16),
          _linkTile(
            theme,
            'ارشادات الاستخدام',
            'https://alshobakiacademy.com/guidelines',
          ),
          // if (_user?['email'] != 'guest@example.com' &&
          //     _user?['email'] != 'appletestaccount#97111111111111@gmail.com') ...[
          //   const Divider(height: 1, indent: 16, endIndent: 16),
          //   _linkTile(theme, 'طرق الدفع', 'https://alshobakiacademy.com/payment'),
          // ],
        ],
      ),
    );
  }

  Widget _linkTile(ThemeData theme, String label, String url) {
    return ListTile(
      title: Text(label, style: theme.textTheme.bodyMedium),
      trailing: const Icon(Icons.open_in_new, size: 18, color: Colors.black38),
      onTap: () => launchUrl(Uri.parse(url)),
    );
  }

  Widget _buildAboutSection(ThemeData theme) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [AppTheme.cardShadow],
      ),
      child: Column(
        children: [
          _sectionHeader(theme, 'عن التطبيق'),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: Text(
              'Made with ❤️ By Eng / Mohamed Farouk',
              style: theme.textTheme.bodySmall?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: InkWell(
              onTap: () => launchUrl(
                Uri.parse('https://www.instagram.com/mohamed.farouk.dev'),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Image.asset(
                    'assets/logos/instgram.png',
                    width: 22,
                    height: 22,
                  ),
                  const SizedBox(width: 6),
                  Text(
                    'Instagram',
                    style: TextStyle(
                      color: Colors.pinkAccent.shade200,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _sectionHeader(ThemeData theme, String title) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 6),
      child: Row(
        children: [
          Text(
            title,
            style: theme.textTheme.labelLarge?.copyWith(
              color: Theme.of(context).colorScheme.primary,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }

  Widget _tile(IconData icon, String label, String value) {
    return ListTile(
      leading: Icon(icon, color: Colors.blueGrey, size: 26),
      title: Text(
        label,
        style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 15),
      ),
      subtitle: Text(value, style: const TextStyle(fontSize: 13)),
      contentPadding: EdgeInsets.zero,
    );
  }
}
