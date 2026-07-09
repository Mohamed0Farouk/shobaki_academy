import 'dart:io';
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:shobaki_academy/controller/security_controller.dart';

class AppColors {
  static const Color primaryColor = Color(0xFF00A8E8);
  static const Color backgroundColor = Color(0xFFFFFBF5);
  static const Color cardColor = Colors.white;

  static const Color warningColor = Color(0xFFF57C00);
  static const Color dangerColor = Color(0xFFE53935);
}

// ── Full-screen recording detected overlay ─────────────────────────────────
class RecordingDetectedOverlay extends StatelessWidget {
  const RecordingDetectedOverlay({super.key, required this.controller});

  final SecurityController controller;

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      final seconds = controller.countdown.value;
      final isCritical = seconds <= 15;
      final isUrgent = seconds <= 30;
      final isMobile = controller.isMobileRecording.value;
      final flicker = controller.isFlickering.value;
      final apps = controller.detectedApps;

      final accentColor = isCritical
          ? AppColors.dangerColor
          : isUrgent
          ? AppColors.warningColor
          : AppColors.primaryColor;

      return Stack(
        children: [
          // Layer 1: Backdrop (absorbs taps, blocks player)
          Positioned.fill(
            child: AbsorbPointer(
              child: ClipRect(
                child: BackdropFilter(
                  filter: ImageFilter.blur(sigmaX: 24, sigmaY: 24),
                  child: Container(
                    color: flicker
                        ? Colors.red.withOpacity(0.40)
                        : Colors.black.withOpacity(0.40),
                  ),
                ),
              ),
            ),
          ),

          // Layer 2: Centered card (fully tappable)
          Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(
                vertical: 40,
                horizontal: 24,
              ),
              child: Container(
                constraints: const BoxConstraints(maxWidth: 420),
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: AppColors.backgroundColor,
                  borderRadius: BorderRadius.circular(22),
                  border: Border.all(
                    color: accentColor.withOpacity(0.25),
                    width: 0.5,
                  ),
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Icon badge
                    Container(
                      width: 56,
                      height: 56,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: accentColor.withOpacity(0.10),
                        border: Border.all(
                          color: accentColor.withOpacity(0.30),
                          width: 0.5,
                        ),
                      ),
                      child: Icon(
                        Icons.block_rounded,
                        color: accentColor,
                        size: 28,
                      ),
                    ),
                    const SizedBox(height: 12),

                    // Title
                    const Text(
                      "Screen Recording Detected",
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: Color(0xFF1A1A1A),
                        fontSize: 17,
                        fontWeight: FontWeight.w600,
                        letterSpacing: -0.3,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      isMobile
                          ? "تم اكتشاف تسجيل للشاشة"
                          : "تم اكتشاف برنامج تسجيل أو مشاركة شاشة",
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: Colors.black.withOpacity(0.40),
                        fontSize: 13,
                        height: 1.5,
                      ),
                    ),
                    const SizedBox(height: 16),

                    // Countdown ring
                    SizedBox(
                      width: 72,
                      height: 72,
                      child: Stack(
                        fit: StackFit.expand,
                        children: [
                          CircularProgressIndicator(
                            value: seconds / 60,
                            strokeWidth: 3.5,
                            backgroundColor: accentColor.withOpacity(
                              0.12,
                            ),
                            valueColor: AlwaysStoppedAnimation(
                              accentColor,
                            ),
                          ),
                          Center(
                            child: Text(
                              "$seconds",
                              style: TextStyle(
                                color: accentColor,
                                fontSize: 24,
                                fontWeight: FontWeight.w700,
                                letterSpacing: -1,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 12),

                    // Warning message
                    AnimatedSwitcher(
                      duration: const Duration(milliseconds: 300),
                      child: Text(
                        _warningMessage(seconds, isMobile),
                        key: ValueKey(_warningStage(seconds)),
                        textAlign: TextAlign.center,
                        textDirection: TextDirection.rtl,
                        style: TextStyle(
                          color: accentColor,
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          height: 1.55,
                        ),
                      ),
                    ),
                    const SizedBox(height: 14),

                    // Taskbar warning (desktop only)
                    if (!isMobile)
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 14,
                          vertical: 12,
                        ),
                        decoration: BoxDecoration(
                          color: AppColors.dangerColor.withOpacity(0.06),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: AppColors.dangerColor.withOpacity(
                              0.20,
                            ),
                            width: 0.5,
                          ),
                        ),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Icon(
                              Icons.info_outline_rounded,
                              color: AppColors.dangerColor.withOpacity(
                                0.80,
                              ),
                              size: 16,
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Text(
                                "تنبيه: قد يبدو البرنامج مغلقاً لكنه لا يزال يعمل في الخلفية. "
                                "تأكد من إغلاقه بالكامل من شريط المهام (Taskbar) أو إدارة المهام.",
                                textDirection: TextDirection.rtl,
                                style: TextStyle(
                                  color: AppColors.dangerColor
                                      .withOpacity(0.85),
                                  fontSize: 12,
                                  height: 1.6,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    if (!isMobile) const SizedBox(height: 8),

                    // ── Close section (desktop only, unsupported on macOS) ──
                    if (!isMobile && !Platform.isMacOS && apps.isNotEmpty) ...[
                      // Section header
                      Row(
                        children: [
                          const Icon(Icons.close, size: 14, color: Color(0xFF999999)),
                          const SizedBox(width: 6),
                          Text(
                            apps.length == 1
                                ? "البرنامج المكتشف"
                                : "البرامج المكتشفة (${apps.length})",
                            style: const TextStyle(
                              color: Color(0xFF999999),
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),

                      // Per-app close rows
                      ...apps.map((app) => Padding(
                        padding: const EdgeInsets.only(bottom: 8),
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 14,
                            vertical: 10,
                          ),
                          decoration: BoxDecoration(
                            color: AppColors.cardColor,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: accentColor.withOpacity(0.15),
                              width: 0.5,
                            ),
                          ),
                          child: Row(
                            children: [
                              Icon(
                                Icons.stop_circle_outlined,
                                color: accentColor,
                                size: 18,
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Directionality(
                                  textDirection: TextDirection.ltr,
                                  child: Text(
                                    app,
                                    overflow: TextOverflow.ellipsis,
                                    style: TextStyle(
                                      color: Colors.black.withOpacity(0.75),
                                      fontSize: 14,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                ),
                              ),
                              GestureDetector(
                                onTap: () =>
                                    controller.closeDetectedApp(app),
                                child: Container(
                                  padding: const EdgeInsets.all(6),
                                  decoration: BoxDecoration(
                                    color: AppColors.dangerColor
                                        .withOpacity(0.10),
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: Icon(
                                    Icons.close,
                                    color: AppColors.dangerColor,
                                    size: 17,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      )),

                      // Close All button
                      if (apps.length > 1)
                        SizedBox(
                          width: double.infinity,
                          child: Material(
                            color: Colors.transparent,
                            child: InkWell(
                              borderRadius: BorderRadius.circular(12),
                              onTap: () =>
                                  controller.closeAllDetectedApps(),
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                  vertical: 12,
                                ),
                                decoration: BoxDecoration(
                                  color: AppColors.dangerColor,
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Center(
                                  child: Text(
                                    "✕  إغلاق الكل (${apps.length})",
                                    textDirection: TextDirection.rtl,
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 13,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
                      const SizedBox(height: 4),
                    ],

                    // Admin notification
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 10,
                      ),
                      decoration: BoxDecoration(
                        color: AppColors.dangerColor.withOpacity(0.06),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(
                          color: AppColors.dangerColor.withOpacity(0.15),
                          width: 0.5,
                        ),
                      ),
                      child: Row(
                        children: [
                          Icon(
                            Icons.admin_panel_settings_outlined,
                            size: 16,
                            color: AppColors.dangerColor.withOpacity(
                              0.80,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              "تم إرسال تنبيه للمشرف — هذه المحاولة موثقة",
                              textDirection: TextDirection.rtl,
                              style: TextStyle(
                                color: AppColors.dangerColor
                                    .withOpacity(0.85),
                                fontSize: 12,
                                height: 1.5,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 12),

                    // Security badge
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 9,
                      ),
                      decoration: BoxDecoration(
                        color: AppColors.primaryColor.withOpacity(0.08),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                          color: AppColors.primaryColor.withOpacity(
                            0.25,
                          ),
                          width: 0.5,
                        ),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.shield_rounded,
                            color: AppColors.primaryColor,
                            size: 14,
                          ),
                          const SizedBox(width: 7),
                          Text(
                            "الحماية الأمنية مفعّلة — الجلسة مراقبة",
                            style: TextStyle(
                              color: AppColors.primaryColor,
                              fontSize: 12,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      );
    });
  }

  int _warningStage(int seconds) {
    if (seconds > 30) return 0;
    if (seconds > 15) return 1;
    if (seconds > 5) return 2;
    return 3;
  }

  String _warningMessage(int seconds, bool isMobile) {
    if (seconds > 30) {
      return isMobile
          ? "أغلق تطبيق تسجيل الشاشة فوراً\nللحفاظ على جلستك"
          : "أغلق برنامج التسجيل فوراً\nللحفاظ على جلستك";
    } else if (seconds > 15) {
      return isMobile
          ? "تحذير — لن تتمكن من المتابعة\nحتى يتم إغلاق تسجيل الشاشة بالكامل"
          : "تحذير — لن تتمكن من المتابعة\nحتى يتم إغلاق البرنامج بالكامل";
    } else if (seconds > 5) {
      return isMobile
          ? "⚠ آخر تحذير — $seconds ثانية\nأغلق تطبيق التسجيل الآن"
          : "⚠ آخر تحذير — $seconds ثانية\nأغلق البرنامج من شريط المهام الآن";
    } else {
      return isMobile
          ? "🔴 الجلسة محجوبة — $seconds ثانية\nلا يمكنك المتابعة حتى يتم إغلاق التسجيل"
          : "🔴 الجلسة محجوبة — $seconds ثانية\nلا يمكنك المتابعة حتى يتم الإغلاق الكامل";
    }
  }
}

// ── Screenshot alert banner ─────────────────────────────────────────────────
class ScreenshotAlertBanner extends StatelessWidget {
  const ScreenshotAlertBanner({super.key});

  @override
  Widget build(BuildContext context) {
    return Positioned(
      top: MediaQuery.of(context).padding.top + 8,
      left: 12,
      right: 12,
      child: Material(
        elevation: 8,
        borderRadius: BorderRadius.circular(12),
        color: const Color(0xFFE53935),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          child: Row(
            children: [
              Icon(Icons.warning_amber_rounded, color: Colors.white, size: 22),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  "تم اكتشاف محاولة تصوير للشاشة\nتم توثيق هذه المحاولة وإرسال تنبيه للمشرف",
                  textDirection: TextDirection.rtl,
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 13,
                    height: 1.5,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}