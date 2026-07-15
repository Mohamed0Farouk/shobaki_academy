import 'package:dio/dio.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:shobaki_academy/services/api.dart';

class WhatsAppNotification {
  static final ApiClient _api = ApiClient();
  static final Dio _dio = Dio();

  /// Send a message to the admin WhatsApp number.
  /// Returns silently if the message is empty, config is missing, or the student is a guest.
  static Future<void> sendAdminMessage(String message) async {
    if (message.trim().isEmpty) return;

    try {
      final apiUrl = dotenv.get('ALSHOBAKI_API', fallback: '');
      final adminPhone = dotenv.get('ADMIN_WHATSAPP', fallback: '');
      if (apiUrl.isEmpty || adminPhone.isEmpty) return;

      await _dio.post(
        '${apiUrl}api/send-message',
        data: {'phone_number': adminPhone, 'message': message},
      );
    } catch (_) {}
  }

  /// Check if the user data represents a guest account.
  static bool _isGuest(Map<String, dynamic> user) {
    return user['email']?.toString() == 'guest@example.com';
  }

  /// Format a timestamp for display in notifications.
  static String _formatTimestamp(DateTime dt) {
    return '${dt.hour.toString().padLeft(2, '0')}:'
        '${dt.minute.toString().padLeft(2, '0')} '
        '${dt.day}/${dt.month}/${dt.year}';
  }

  // ─────────────────────────────────────────────
  //  SCREEN RECORDING BLOCK (60s countdown ended)
  // ─────────────────────────────────────────────

  static String buildBlockMessage({
    required Map<String, dynamic> student,
    required List<String> detectedApps,
    required DateTime detectionTime,
  }) {
    if (_isGuest(student)) return '';

    final name = student['name']?.toString() ?? 'غير معروف';
    final phone = student['phone_number']?.toString() ?? 'غير معروف';
    final school = student['school_name']?.toString() ?? 'غير معروف';
    final stage = student['stage']?.toString() ?? 'غير معروف';
    final government = student['goverment']?.toString() ?? 'غير معروف';
    final fingerprint = student['device_fingerprint']?.toString() ?? 'غير معروف';
    final apps = detectedApps.isEmpty ? 'غير محددة' : detectedApps.join('، ');
    final timestamp = _formatTimestamp(detectionTime);

    return '🚫 تم حجب الطالب — محاولة تسجيل شاشة\n'
        '\n'
        '👤 بيانات الطالب:\n'
        '   الاسم: $name\n'
        '   رقم الهاتف: $phone\n'
        '   المدرسة: $school\n'
        '   المرحلة: $stage\n'
        '   الإمارة: $government\n'
        '   بصمة الجهاز: $fingerprint\n'
        '\n'
        '📱 البرامج المكتشفة: $apps\n'
        '🕐 الوقت: $timestamp\n'
        '📝 السبب: محاولة تسجيل شاشة (تم تجاوز المهلة 60 ثانية)\n'
        '\n'
        '⚠️ تم تعطيل الحساب تلقائياً';
  }

  // ─────────────────────────────────────────────
  //  SCREENSHOT DETECTION (initial alert)
  // ─────────────────────────────────────────────

  static String buildScreenshotAlertMessage({
    required Map<String, dynamic> student,
    required String detectedApp,
    required DateTime detectionTime,
  }) {
    if (_isGuest(student)) return '';

    final name = student['name']?.toString() ?? 'غير معروف';
    final phone = student['phone_number']?.toString() ?? 'غير معروف';
    final timestamp = _formatTimestamp(detectionTime);

    return '📸 تنبيه — محاولة أخذ لقطة شاشة\n'
        '\n'
        '👤 الطالب: $name\n'
        '📞 رقم الهاتف: $phone\n'
        '📱 التطبيق المكتشف: $detectedApp\n'
        '🕐 الوقت: $timestamp';
  }

  // ─────────────────────────────────────────────
  //  SIGN-OUT NOTIFICATIONS (3 reasons)
  // ─────────────────────────────────────────────

  static String buildSignOutBlockedMessage({
    required Map<String, dynamic> student,
    required DateTime signOutTime,
  }) {
    if (_isGuest(student)) return '';

    final name = student['name']?.toString() ?? 'غير معروف';
    final phone = student['phone_number']?.toString() ?? 'غير معروف';
    final school = student['school_name']?.toString() ?? 'غير معروف';
    final stage = student['stage']?.toString() ?? 'غير معروف';
    final government = student['goverment']?.toString() ?? 'غير معروف';
    final fingerprint = student['device_fingerprint']?.toString() ?? 'غير معروف';
    final timestamp = _formatTimestamp(signOutTime);

    return '🔒 تم تسجيل خروج — حجب الحساب\n'
        '\n'
        '👤 بيانات الطالب:\n'
        '   الاسم: $name\n'
        '   رقم الهاتف: $phone\n'
        '   المدرسة: $school\n'
        '   المرحلة: $stage\n'
        '   الإمارة: $government\n'
        '   بصمة الجهاز: $fingerprint\n'
        '\n'
        '🕐 الوقت: $timestamp\n'
        '📝 السبب: تم حجب الحساب من قبل الإدارة';
  }

  static String buildSignOutDeviceChangeMessage({
    required Map<String, dynamic> student,
    required DateTime signOutTime,
  }) {
    if (_isGuest(student)) return '';

    final name = student['name']?.toString() ?? 'غير معروف';
    final phone = student['phone_number']?.toString() ?? 'غير معروف';
    final school = student['school_name']?.toString() ?? 'غير معروف';
    final stage = student['stage']?.toString() ?? 'غير معروف';
    final government = student['goverment']?.toString() ?? 'غير معروف';
    final fingerprint = student['device_fingerprint']?.toString() ?? 'غير معروف';
    final timestamp = _formatTimestamp(signOutTime);

    return '🔄 تم تسجيل خروج — تغيير الجهاز\n'
        '\n'
        '👤 بيانات الطالب:\n'
        '   الاسم: $name\n'
        '   رقم الهاتف: $phone\n'
        '   المدرسة: $school\n'
        '   المرحلة: $stage\n'
        '   الإمارة: $government\n'
        '   بصمة الجهاز الحالية: $fingerprint\n'
        '\n'
        '🕐 الوقت: $timestamp\n'
        '📝 السبب: تم اكتشاف تغيير في الجهاز، تم تسجيل الخروج تلقائياً';
  }

  static String buildSignOutVoluntaryMessage({
    required Map<String, dynamic> student,
    required DateTime signOutTime,
  }) {
    if (_isGuest(student)) return '';

    final name = student['name']?.toString() ?? 'غير معروف';
    final phone = student['phone_number']?.toString() ?? 'غير معروف';
    final school = student['school_name']?.toString() ?? 'غير معروف';
    final stage = student['stage']?.toString() ?? 'غير معروف';
    final government = student['goverment']?.toString() ?? 'غير معروف';
    final timestamp = _formatTimestamp(signOutTime);

    return '🚪 تم تسجيل خروج — طوعي\n'
        '\n'
        '👤 بيانات الطالب:\n'
        '   الاسم: $name\n'
        '   رقم الهاتف: $phone\n'
        '   المدرسة: $school\n'
        '   المرحلة: $stage\n'
        '   الإمارة: $government\n'
        '\n'
        '🕐 الوقت: $timestamp\n'
        '📝 السبب: تسجيل خروج طوعي من الطالب';
  }

  // ─────────────────────────────────────────────
  //  DELETE ACCOUNT (comprehensive data)
  // ─────────────────────────────────────────────

  static Future<String> buildDeleteAccountMessage({
    required Map<String, dynamic> student,
  }) async {
    if (_isGuest(student)) return '';

    final name = student['name']?.toString() ?? 'غير معروف';
    final phone = student['phone_number']?.toString() ?? 'غير معروف';
    final email = student['email']?.toString() ?? 'غير معروف';
    final school = student['school_name']?.toString() ?? 'غير معروف';
    final stage = student['stage']?.toString() ?? 'غير معروف';
    final government = student['goverment']?.toString() ?? 'غير معروف';
    final fingerprint = student['device_fingerprint']?.toString() ?? 'غير معروف';
    final createdAt = student['created_at']?.toString() ?? 'غير معروف';
    final studentId = student['id']?.toString();
    final timestamp = _formatTimestamp(DateTime.now());

    // Fetch subscriptions with topic names
    String subscriptionsSection = '   لا توجد اشتراكات';
    try {
      final subscriptions = await _api.fetchWithConditions(
        'students_subscriptions',
        filters: {'student_id': studentId},
        select: 'id,topic_id,subscription_type,created_at,topic:topics(id,title)',
      );

      if (subscriptions.isNotEmpty) {
        final lines = <String>[];
        for (final sub in subscriptions) {
          final type = sub['subscription_type']?.toString();
          if (type == 'books') {
            lines.add('   • اشتراك الملازم (كتب)');
          } else {
            final topicTitle = sub['topic']?['title']?.toString();
            if (topicTitle != null && topicTitle.isNotEmpty) {
              lines.add('   • اشتراك في: $topicTitle');
            } else {
              lines.add('   • اشتراك في موضوع (ID: ${sub['topic_id']})');
            }
          }
        }
        subscriptionsSection = lines.join('\n');
      }
    } catch (_) {}

    // Fetch student codes
    String codesSection = '   لا توجد أكواد';
    try {
      final codes = await _api.fetchWithConditions(
        'student_codes',
        filters: {'student_id': studentId},
      );

      if (codes.isNotEmpty) {
        final lines = <String>[];
        for (final code in codes) {
          final codeValue = code['code']?.toString() ?? 'غير معروف';
          final limited = code['limited'] as bool? ?? false;
          final remainUses = code['remain_uses'];
          if (limited && remainUses != null) {
            lines.add('   • الكود: $codeValue | متبقي: $remainUses استخدامات');
          } else {
            lines.add('   • الكود: $codeValue | غير محدود');
          }
        }
        codesSection = lines.join('\n');
      }
    } catch (_) {}

    // Fetch wrong answers count
    int wrongAnswersCount = 0;
    try {
      final wrongAnswers = await _api.fetchWithConditions(
        'students_wrong_answers',
        filters: {'student_id': studentId},
      );
      wrongAnswersCount = wrongAnswers.length;
    } catch (_) {}

    // Build the final message
    return '⚠️ تم حذف حساب طالب — بيانات كاملة\n'
        '\n'
        '━━━━━━━ بيانات الطالب ━━━━━━━\n'
        '👤 الاسم: $name\n'
        '📞 رقم الهاتف: $phone\n'
        '📧 البريد: $email\n'
        '🏫 المدرسة: $school\n'
        '📚 المرحلة: $stage\n'
        '📍 الإمارة: $government\n'
        '🔑 بصمة الجهاز: $fingerprint\n'
        '📅 تاريخ الإنشاء: $createdAt\n'
        '\n'
        '━━━━━━━ الاشتراكات (ستُحذف) ━━━━━━━\n'
        '$subscriptionsSection\n'
        '\n'
        '━━━━━━━ الأكواد المستخدمة (ستُحذف) ━━━━━━━\n'
        '$codesSection\n'
        '\n'
        '━━━━━━━ إحصائيات ━━━━━━━\n'
        '❌ عدد الإجابات الخاطئة: $wrongAnswersCount\n'
        '\n'
        '🕐 وقت الحذف: $timestamp\n'
        '⚠️ سيتم حذف جميع البيانات المذكورة أعلاه نهائياً';
  }
}
