import 'package:shobaki_academy/controller/books_controller.dart';
import 'package:shobaki_academy/services/api.dart';
import 'package:shobaki_academy/services/statics.dart';
import 'package:shobaki_academy/view/home.dart';
import 'package:get/get.dart';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

class SubscriptionController extends GetxController {
  final RxString inputText = ''.obs;
  final ApiClient api;

  SubscriptionController({required this.api});

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
                Colors.yellow,
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
  Future<void> handleBookSubscription(String code, String userId) async {
    try {
      // Validate code exists and belongs to user or is global
      final codeResult = await api.fetchWithConditions(
        'student_codes',
        filters: {'student_id': userId, 'code': code},
      );

      if (codeResult.isEmpty) {
        Get.back(); // Close loading dialog
        Get.snackbar(
          'توجد مشكلة',
          'الكود غير صحيح',
          backgroundColor: Colors.yellow,
          snackPosition: SnackPosition.BOTTOM,
          duration: const Duration(seconds: 3),
        );
        return;
      }

      // Insert book subscription (no topic_id, just subscription_type: "books")
      await api.insertData('students_subscriptions', {
        'student_id': userId,
        'topic_id': null,
        'subscription_type': 'books',
      });

      // Close loading dialog first
      Get.back();

      // Close subscription dialog
      Get.back();

      // Show success snackbar
      Get.snackbar(
        'اشعار',
        'تم الاشتراك في الملازم بنجاح قم باعادة تحميل الصفحة عن طريق السحب من اعلى لاسفل',
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
      Get.snackbar(
        'خطأ',
        'حدث خطأ أثناء الاشتراك: $e',
        backgroundColor: Colors.red,
        snackPosition: SnackPosition.BOTTOM,
        duration: const Duration(seconds: 3),
      );
    }
  }

  void _showSuccessSnackbar(String title, String message) {
    Get.snackbar(
      title,
      message,
      backgroundColor: Colors.greenAccent,
      snackPosition: SnackPosition.BOTTOM,
      duration: const Duration(seconds: 2),
    );
  }

  void _showErrorSnackbar(String title, String message, Color backgroundColor) {
    Get.snackbar(
      title,
      message,
      backgroundColor: backgroundColor,
      snackPosition: SnackPosition.BOTTOM,
      duration: const Duration(seconds: 3),
    );
  }
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
          Directionality(
            textDirection: TextDirection.rtl,
            child: TextField(
              onChanged: controller.updateInputText,
              decoration: InputDecoration(
                hintText: 'ادخل الكود',
                hintStyle: Theme.of(context).textTheme.bodyMedium,
              ),
            ),
          ),
          const SizedBox(height: 10),
          Wrap(
            alignment: WrapAlignment.center,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              InkWell(
                onTap: () => launchUrl(
                  Uri.parse(
                    'https://wa.me/+971508124370?text=${Uri.encodeFull('مرحباً، أود الحصول على كود الاشتراك')}',
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
  required context,
}) {
  final controller = Get.put(SubscriptionController(api: api), tag: 'books');

  Get.dialog(
    AlertDialog(
      title: const Text('لتحميل الملازم', textAlign: TextAlign.center),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            'ادخل كود الاشتراك للوصول إلى جميع الملازم',
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodySmall,
          ),
          const SizedBox(height: 16),
          Directionality(
            textDirection: TextDirection.rtl,
            child: TextField(
              onChanged: controller.updateInputText,
              decoration: InputDecoration(
                hintText: 'ادخل الكود',
                hintStyle: Theme.of(context).textTheme.bodyMedium,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
            ),
          ),
          const SizedBox(height: 10),
          Wrap(
            alignment: WrapAlignment.center,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              InkWell(
                onTap: () => launchUrl(
                  Uri.parse(
                    'https://wa.me/+971508124370?text=${Uri.encodeFull('مرحباً، أود الحصول على كود الاشتراك')}',
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
            'عذراً، لا يمكنك الوصول إلى الملازم كمستخدم ضيف. الرجاء تسجيل الدخول بحسابك الخاص.',
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
