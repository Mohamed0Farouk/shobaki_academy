import 'dart:convert';
import 'package:shobaki_academy/model/widgets/quill_description.dart';
import 'package:shobaki_academy/model/widgets/zoomable_image.dart';
import 'package:shobaki_academy/services/api.dart';
import 'package:shobaki_academy/controller/exam_controller.dart';
import 'package:shobaki_academy/controller/exam_model_controller.dart';
import 'package:shobaki_academy/extentions.dart';
import 'package:shobaki_academy/services/statics.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';

class ExamModel extends StatelessWidget {
  const ExamModel({
    super.key,
    this.answer,
    required this.questionId,
    this.flag = false, // Flag parameter to control selection behavior
  });
  final String questionId;
  final String? answer;
  final bool flag; // Flag controls whether answer selection is allowed or not

  @override
  Widget build(BuildContext context) {
    // Initialize the controller using GetX
    final ExamModelController controller = Get.put(
      ExamModelController(questionId),
      tag: questionId, // Add this tag
    );
    final ExamController examController = Get.find();

    // Set the initial state of the controller
    if (answer != null) {
      controller.selectedAnswer.value = answer!;
      examController.answer = answer;
    }

    controller.flag.value = flag; // Set the flag to control answer selection

    return FutureBuilder<Map>(
      future: questionInfoFetcher(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.done) {
          final answers = (snapshot.data!['answers'] as List);
          return ListView(
            // mainAxisSize: MainAxisSize.min,
            // mainAxisAlignment: MainAxisAlignment.center,
            children: [
              SizedBox(
                height: context.screenH / 3,
                child: getImageOrText(snapshot.data!['content'], context),
              ),
              const SizedBox(height: 15),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 15.0),
                child: Divider(),
              ),
              const SizedBox(height: 15),
              Row(
                mainAxisAlignment: MainAxisAlignment.start,
                children: [
                  Text(
                    'مستوى الصعوبة : ${snapshot.data!['difficulty_level']}',
                    style: Theme.of(context).textTheme.bodyLarge!.copyWith(
                      color: getColorForDifficulty(
                        snapshot.data!['difficulty_level'],
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 15),
              SizedBox(
                height: context.screenH / 2.5,
                child: ListView(
                  children: List.generate(answers.length, (index) {
                    return Column(
                      children: [
                        Obx(
                          () => ChoiceChip(
                            label: Text(answers[index]),
                            selected:
                                controller.selectedAnswer.value ==
                                answers[index], // Remove the ?
                            onSelected: controller.flag.value
                                ? null
                                : (value) {
                                    if (value) {
                                      controller.selectAnswer(answers[index]);
                                      examController.answer = answers[index];
                                    } else {
                                      controller.resetAnswer();
                                      examController.answer = null;
                                    }
                                  },
                          ),
                        ),
                        const SizedBox(height: 15),
                      ],
                    );
                  }),
                ),
              ),
            ],
          );
        } else {
          return Center(child: loading(context));
        }
      },
    );
  }

  Color getColorForDifficulty(String difficultyLevel) {
    switch (difficultyLevel.toLowerCase()) {
      case 'سهل جداً':
        return Colors.green; // Green for very easy
      case 'سهل':
        return Colors.lightGreen; // Light Green for easy
      case 'متوسط':
        return Colors.yellow; // Yellow for medium
      case 'صعب':
        return Colors.orange; // Orange for hard
      case 'صعب جداً':
        return Colors.red; // Red for very hard
      default:
        return Colors.grey; // Default gray if the level is unknown
    }
  }

  Widget getImageOrText(String input, context) {
    // Check if the string is a valid URL
    final content = input;
    String plainContent = content;
    try {
      if (content.startsWith('[') && content.endsWith(']')) {
        // Extract text from Quill Delta format
        // Parse JSON properly instead of regex replacement
        final dynamic jsonData = jsonDecode(content);
        if (jsonData is List && jsonData.isNotEmpty) {
          final extractedTexts = <String>[];
          for (final op in jsonData) {
            if (op is Map &&
                op.containsKey('insert') &&
                op['insert'] is String) {
              extractedTexts.add(op['insert'] as String);
            }
          }
          plainContent = extractedTexts.join('').trim();
        }
      }
    } catch (e) {
      // If parsing fails, use original content
      plainContent = content;
    }

    // Better URL validation
    bool isImageUrl = false;
    if (plainContent.isNotEmpty) {
      try {
        print(plainContent);
        final uri = Uri.parse(plainContent);
        // Check if it has a valid scheme (http or https)
        if (uri.scheme == 'http' || uri.scheme == 'https') {
          // Check if it's an image URL
          isImageUrl = true;
        }
      } catch (e) {
        // Not a valid URI
        isImageUrl = false;
      }
    }

    if (isImageUrl) {
      // If it's a valid URL, return a zoomable image widget
      return ZoomableImage(imageUrl: plainContent, fit: BoxFit.contain);
    } else {
      // If it's not a valid URL, return a Text widget
      return QuillDescription.fromContent(
        input,
        enableScroll: true,
        padding: EdgeInsets.all(10),
        scrollController: ScrollController(),
        textStyle: Theme.of(context).textTheme.headlineMedium,
      );
    }
  }

  Future<Map> questionInfoFetcher() async {
    final ApiClient api = ApiClient();

    final response = await api.fetchWithConditions(
      'questions_bank',
      filters: {'id': questionId},
    );
    final questionData = response[0];
    return questionData;
  }
}
