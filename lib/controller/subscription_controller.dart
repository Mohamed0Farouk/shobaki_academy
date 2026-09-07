import 'package:shobaki_academy/controller/books_controller.dart';
import 'package:shobaki_academy/services/api.dart';
import 'package:shobaki_academy/services/statics.dart';
import 'package:shobaki_academy/view/home.dart';
import 'package:get/get.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:pinput/pinput.dart';
import 'package:url_launcher/url_launcher.dart';

/// Outcome of validating a book subscription code.
enum BookCodeValidationStatus { invalidCode, bookNotAllowed, ok }

class SubscriptionController extends GetxController {
  final RxString inputText = ''.obs;
  final ApiClient api;

  SubscriptionController({required this.api});

  /// Whether a code's `allowed_books` permits subscribing to [bookId].
  /// A missing, null or empty list means the code is unrestricted.
  static bool isBookAllowed(Object? allowedBooks, int bookId) {
    if (allowedBooks == null ||
        allowedBooks is! List ||
        allowedBooks.isEmpty) {
      return true;
    }
    return allowedBooks.any((id) => id.toString() == bookId.toString());
  }

  /// Builds the `students_subscriptions` row for a per-book subscription.
  static Map<String, dynamic> buildBookSubscriptionRow(
    String userId,
    int bookId,
  ) {
    return {
      'student_id': userId,
      'topic_id': null,
      'book_id': bookId,
      'subscription_type': 'books',
    };
  }

  /// Validates a book subscription code without any UI side effects.
  Future<BookCodeValidationStatus> validateBookCode(
    String code,
    String userId,
    int bookId,
  ) async {
    final codeResult = await api.fetchWithConditions(
      'student_codes',
      filters: {'student_id': userId, 'code': code},
    );
    if (codeResult.isEmpty) {
      return BookCodeValidationStatus.invalidCode;
    }
    if (!isBookAllowed(codeResult[0]['allowed_books'], bookId)) {
      return BookCodeValidationStatus.bookNotAllowed;
    }
    return BookCodeValidationStatus.ok;
  }

  void updateInputText(String value) {
    inputText.value = value;
  }

  Future<void> handleSubscription(
    List<dynamic> topicCodes,
    String topicName,
    String topicId,
    String userId,
  ) async {
    if (!topicCodes.contains(inputText.value)) {
      await api
          .fetchWithConditions(
            'student_codes',
            filters: {'student_id': userId, 'code': inputText.value},
          )
          .then((value) async {
            if (value.isNotEmpty) {
              final allowedContent = value[0]['allowed_content'];
              if (allowedContent != null &&
                  allowedContent is List &&
                  allowedContent.isNotEmpty) {
                if (!allowedContent.contains(topicId)) {
                  _showErrorSnackbar(
                    'توجد مشكلة',
                    'هذا الكود لا يدعم الاشتراك في هذا المحتوى',
                    Colors.red,
                  );
                  return;
                }
              }

              if (value[0]['limited'] && value[0]['remain_uses'] > 0) {
                await api.updateData(
                  'student_codes',
                  {'remain_uses': value[0]['remain_uses'] - 1},
                  {'id': value[0]['id']},
                );

                await api.insertData('students_subscriptions', {
                  "student_id": userId,
                  "topic_id": topicId,
                });

                _showSuccessSnackbar('اشعار', 'تم الاشتراك في $topicName');

                Get.offAll(() => HomePage());

                return;
              } else if (value[0]['limited'] && value[0]['remain_uses'] <= 0) {
                _showErrorSnackbar(
                  'توجد مشكلة',
                  "الكود الذي تستخدمه قد استُخدم بالكامل",
                  Colors.red,
                );
                return;
              } else if (!value[0]['limited']) {
                await api.insertData('students_subscriptions', {
                  "student_id": userId,
                  "topic_id": topicId,
                });

                _showSuccessSnackbar('اشعار', 'تم الاشتراك في $topicName');

                Get.offAll(() => HomePage());

                return;
              }
            } else {
              _showErrorSnackbar(
                'توجد مشكلة',
                "انت تستخدم كود خاطئ",
                Colors.red,
              );
              return;
            }
          });
    }

    if (topicCodes.contains(inputText.value)) {
      try {
        topicCodes.remove(inputText.value);

        await api.insertData('students_subscriptions', {
          "student_id": userId,
          "topic_id": topicId,
        });

        await api.updateData('topics', {'codes': topicCodes}, {'id': topicId});

        _showSuccessSnackbar('اشعار', 'تم الاشتراك في $topicName');

        Get.offAllNamed('/home');
      } catch (e) {
        _showErrorSnackbar(
          'خطأ',
          'حدث خطأ أثناء الاشتراك. حاول مرة أخرى',
          Colors.red,
        );
      }
    }
  }

  /// Handle book subscription with code validation
  Future<void> handleBookSubscription(
    String code,
    String userId,
    int bookId,
  ) async {
    try {
      final status = await validateBookCode(code, userId, bookId);

      if (status == BookCodeValidationStatus.invalidCode) {
        Get.back(); // Close loading dialog
        showSnackbar(
          'توجد مشكلة',
          'الكود غير صحيح',
          backgroundColor: Colors.red,
          snackPosition: SnackPosition.BOTTOM,
          duration: const Duration(seconds: 3),
        );
        return;
      }

      if (status == BookCodeValidationStatus.bookNotAllowed) {
        Get.back(); // Close loading dialog
        showSnackbar(
          'توجد مشكلة',
          'هذا الكود لا يدعم الاشتراك في هذه الملزمة',
          backgroundColor: Colors.red,
          snackPosition: SnackPosition.BOTTOM,
          duration: const Duration(seconds: 3),
        );
        return;
      }

      // Insert book subscription (per-book access via book_id)
      await api.insertData(
        'students_subscriptions',
        buildBookSubscriptionRow(userId, bookId),
      );

      // Close loading dialog first
      Get.back();

      // Close subscription dialog
      Get.back();

      // Show success snackbar
      showSnackbar(
        'اشعار',
        'تم الاشتراك في الملزمة بنجاح قم باعادة تحميل الصفحة عن طريق السحب من اعلى لاسفل',
        backgroundColor: Colors.greenAccent,
        snackPosition: SnackPosition.BOTTOM,
        duration: const Duration(seconds: 2),
      );

      // Refresh books controller after small delay to ensure snackbar shows
      await Future.delayed(const Duration(milliseconds: 500));
      if (Get.isRegistered<BooksController>()) {
        final booksController = Get.find<BooksController>();
        await booksController.checkBookSubscription();
      }
    } catch (e) {
      Get.back(); // Close loading dialog
      showSnackbar(
        'خطأ',
        'حدث خطأ أثناء الاشتراك: $e',
        backgroundColor: Colors.red,
        snackPosition: SnackPosition.BOTTOM,
        duration: const Duration(seconds: 3),
      );
    }
  }

  void _showSuccessSnackbar(String title, String message) {
    showSnackbar(
      title,
      message,
      backgroundColor: Colors.greenAccent,
      snackPosition: SnackPosition.BOTTOM,
      duration: const Duration(seconds: 2),
    );
  }

  void _showErrorSnackbar(String title, String message, Color backgroundColor) {
    showSnackbar(
      title,
      message,
      backgroundColor: backgroundColor,
      snackPosition: SnackPosition.BOTTOM,
      duration: const Duration(seconds: 3),
    );
  }
}

/// Builds a themed, LTR pinput restricted to English letters and numbers.
Widget buildCodePinput(BuildContext context, SubscriptionController controller) {
  final primary = Theme.of(context).colorScheme.primary;

  final defaultPinTheme = PinTheme(
    width: 44,
    height: 54,
    textStyle: TextStyle(
      fontSize: 22,
      fontWeight: FontWeight.w600,
      color: primary,
    ),
    decoration: BoxDecoration(
      borderRadius: BorderRadius.circular(12),
      border: Border.all(color: Colors.black38, width: 1.5),
    ),
  );

  final focusedPinTheme = defaultPinTheme.copyWith(
    decoration: BoxDecoration(
      borderRadius: BorderRadius.circular(12),
      border: Border.all(color: primary, width: 2),
      boxShadow: [
        BoxShadow(
          color: primary.withValues(alpha: 0.15),
          blurRadius: 6,
          offset: const Offset(0, 3),
        ),
      ],
    ),
  );

  final submittedPinTheme = defaultPinTheme.copyWith(
    decoration: BoxDecoration(
      color: primary.withValues(alpha: 0.1),
      borderRadius: BorderRadius.circular(12),
      border: Border.all(color: primary, width: 1.5),
    ),
  );

  return Directionality(
    textDirection: TextDirection.ltr,
    child: Pinput(
      length: 6,
      keyboardType: TextInputType.text,
      defaultPinTheme: defaultPinTheme,
      focusedPinTheme: focusedPinTheme,
      submittedPinTheme: submittedPinTheme,
      showCursor: true,
      inputFormatters: [
        FilteringTextInputFormatter.allow(RegExp(r'[a-zA-Z0-9]')),
      ],
      onChanged: controller.updateInputText,
    ),
  );
}

// Function to show the subscription dialog
void showSubscriptionDialog({
  required List<dynamic> topicCodes,
  required String topicName,
  required ApiClient api,
  required String topicId,
  required String userId,
  required int amount,
  required context,
}) {
  final controller = Get.put(SubscriptionController(api: api));

  Get.dialog(
    AlertDialog(
      title: const Text('ادخل كود الاشتراك', textAlign: TextAlign.center),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          buildCodePinput(context, controller),
          const SizedBox(height: 10),
          Wrap(
            alignment: WrapAlignment.center,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              InkWell(
                onTap: () => launchUrl(
                  Uri.parse(
                    'https://wa.me/+971502762100?text=${Uri.encodeFull('مرحباً، أود الحصول على كود الاشتراك')}',
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  spacing: 5,
                  children: [
                    Image.asset(
                      'assets/logos/whatsapp.png',
                      width: 20,
                      height: 20,
                    ),
                    Text(
                      'Whatapp',
                      style: Theme.of(
                        context,
                      ).textTheme.bodySmall?.copyWith(color: Colors.green),
                    ),
                  ],
                ),
              ),
              Text(
                ' للحصول على الكود ',
                style: Theme.of(context).textTheme.bodySmall,
                softWrap: true,
              ),
            ],
          ),
        ],
      ),
      actions: [
        Obx(
          () => ElevatedButton(
            onPressed: controller.inputText.value.isNotEmpty
                ? () {
                    loadingDilog(context);
                    controller.handleSubscription(
                      topicCodes,
                      topicName,
                      topicId,
                      userId,
                    );
                    Get.close(1);
                  }
                : null,
            child: Text('اشترك', style: Theme.of(context).textTheme.bodyMedium),
          ),
        ),
      ],
    ),
    barrierDismissible: true,
  );
}

/// Show subscription dialog for books
void showBookSubscriptionDialog({
  required ApiClient api,
  required String userId,
  required int bookId,
  required context,
}) {
  final controller = Get.put(SubscriptionController(api: api), tag: 'books');

  Get.dialog(
    AlertDialog(
      title: const Text('لتحميل الملزمة', textAlign: TextAlign.center),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            'ادخل كود الاشتراك للوصول إلى هذه الملزمة',
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodySmall,
          ),
          const SizedBox(height: 16),
          buildCodePinput(context, controller),
          const SizedBox(height: 10),
          Wrap(
            alignment: WrapAlignment.center,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              InkWell(
                onTap: () => launchUrl(
                  Uri.parse(
                    'https://wa.me/+971502762100?text=${Uri.encodeFull('مرحباً، أود الحصول على كود الاشتراك')}',
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  spacing: 5,
                  children: [
                    Image.asset(
                      'assets/logos/whatsapp.png',
                      width: 20,
                      height: 20,
                    ),
                    Text(
                      'Whatapp',
                      style: Theme.of(
                        context,
                      ).textTheme.bodySmall?.copyWith(color: Colors.green),
                    ),
                  ],
                ),
              ),
              Text(
                ' للحصول على الكود ',
                style: Theme.of(context).textTheme.bodySmall,
                softWrap: true,
              ),
            ],
          ),
        ],
      ),
      actions: [
        TextButton(onPressed: () => Get.back(), child: const Text('إلغاء')),
        Obx(
          () => ElevatedButton(
            onPressed: controller.inputText.value.isNotEmpty
                ? () {
                    loadingDilog(context);
                    controller.handleBookSubscription(
                      controller.inputText.value,
                      userId,
                      bookId,
                    );
                  }
                : null,
            child: const Text('اشترك'),
          ),
        ),
      ],
    ),
    barrierDismissible: true,
  );
}

/// Show guest annotation dialog
void showGuestAnnotationDialog({required BuildContext context}) {
  Get.dialog(
    AlertDialog(
      title: const Text('ميزة مخصصة للمستخدمين', textAlign: TextAlign.center),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.lock_outline, size: 48, color: Colors.orange[700]),
          const SizedBox(height: 16),
          const Text(
            'عذراً، لا يمكنك الوصول إلى الملزمة كمستخدم ضيف. الرجاء تسجيل الدخول بحسابك الخاص.',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 14, height: 1.5),
          ),
        ],
      ),
      actions: [
        ElevatedButton(onPressed: () => Get.back(), child: const Text('فهمت')),
      ],
    ),
    barrierDismissible: true,
    transitionDuration: const Duration(milliseconds: 300),
  );
}
