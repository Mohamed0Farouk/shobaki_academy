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
    // if (topicCodes.isEmpty) {
    //   _showErrorSnackbar(
    //     'توجد مشكلة',
    //     'الاكواد الخاصة ب $topicName تم استخدامها جميعاً',
    //     Colors.red,
    //   );
    //   return;
    // }

    if (!topicCodes.contains(inputText.value)) {
      //_showErrorSnackbar('توجد مشكلة', "انت تستخدم كود خاطئ", Colors.yellow);

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

    // Valid code, proceed with subscription
    if (topicCodes.contains(inputText.value)) {
      try {
        // Remove used code
        topicCodes.remove(inputText.value);

        // Update subscription
        await api.insertData('students_subscriptions', {
          "student_id": userId,
          "topic_id": topicId,
        });

        // Update remaining codes
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

  void _showSuccessSnackbar(String title, String message) {
    Get.back(); // Close dialog first
    Get.snackbar(
      title,
      message,
      backgroundColor: Colors.greenAccent,
      snackPosition: SnackPosition.BOTTOM,
    );
  }

  void _showErrorSnackbar(String title, String message, Color backgroundColor) {
    Get.back(); // Close dialog first
    Get.snackbar(
      title,
      message,
      backgroundColor: backgroundColor,
      snackPosition: SnackPosition.BOTTOM,
    );
  }
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
  // Initialize controller
  final controller = Get.put(SubscriptionController(api: api));
  // final paymentController = Get.put(
  //   PaymentController(
  //     apiKey: dotenv.get("PAYMENT_API_KEY"),
  //     integrationId: 73082,
  //   ),
  // );

  Get.dialog(
    AlertDialog(
      title: const Text('ادخل كود الاشتراك', textAlign: TextAlign.center),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // ElevatedButton(
          //   style: ElevatedButton.styleFrom(
          //     padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
          //     shape: RoundedRectangleBorder(
          //       borderRadius: BorderRadius.circular(12),
          //     ),
          //   ),
          //   onPressed: () async {
          //     await paymentController.pay(
          //       amountCents: amount,
          //       topicId: topicId,
          //       topicName: topicName,
          //       userId: userId,
          //     );
          //   },
          //   child: SizedBox(
          //     width: double.infinity,
          //     child: Center(
          //       child: Text(
          //         'الدفع المباشر',
          //         style: Theme.of(
          //           context,
          //         ).textTheme.bodyMedium!.copyWith(color: Colors.white),
          //       ),
          //     ),
          //   ),
          // ),
          // const SizedBox(height: 15),
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
                onTap: () => _launchUrl(
                  //TODO: Add pre-filled message if needed
                  'https://wa.me/+?text=${Uri.encodeFull('')}',
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
                      ).textTheme.bodySmall!.copyWith(color: Colors.green),
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
