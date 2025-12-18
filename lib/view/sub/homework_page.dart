import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:shobaki_academy/controller/homework_controller.dart';
import 'package:shobaki_academy/controller/homework_model_controller.dart';
import 'package:shobaki_academy/extentions.dart';
import 'package:shobaki_academy/model/home_work_model.dart';
import 'package:shobaki_academy/services/api.dart';
import 'package:shobaki_academy/services/locale_db.dart';
import 'package:shobaki_academy/services/statics.dart';
import 'package:shobaki_academy/view/home.dart';
import 'package:smooth_page_indicator/smooth_page_indicator.dart';

class HomeworkPage extends StatefulWidget {
  const HomeworkPage({super.key, required this.id, required this.topicId});
  final String id;
  final String topicId;

  @override
  State<HomeworkPage> createState() => _HomeworkPageState();
}

class _HomeworkPageState extends State<HomeworkPage> {
  final pageController = PageController();

  final controller = Get.put(HomeworkController());

  bool notEditable = false;

  @override
  void initState() {
    controller.init(topicId: widget.topicId, homeworkId: widget.id);
    super.initState();
  }

  @override
  void dispose() {
    controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          'واجب ',
          style: Theme.of(
            context,
          ).textTheme.headlineMedium?.copyWith(color: Colors.white),
        ),
        centerTitle: true,
      ),
      body: SafeArea(
        child: FutureBuilder(
          future: fetchHomework(),
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.done) {
              return Padding(
                padding: const EdgeInsets.only(top: 45, right: 15, left: 15),
                child: Stack(
                  children: [
                    SizedBox(
                      width: context.screenW,
                      child: PageView(
                        physics: const NeverScrollableScrollPhysics(),
                        controller: pageController,
                        children: controller.pages!,
                      ),
                    ),
                    Positioned(
                      bottom: 1,
                      left: 1,
                      right: 1,
                      child: Container(
                        margin: EdgeInsets.symmetric(vertical: 15),
                        child: Column(
                          children: [
                            SmoothPageIndicator(
                              controller: pageController,
                              effect: WormEffect(
                                activeDotColor: Theme.of(context).primaryColor,
                              ),
                              count: controller.pages!.length,
                            ),
                            const SizedBox(height: 15),
                            Obx(() {
                              return navButtons(context);
                            }),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              );
            } else {
              return Center(child: loading(context));
            }
          },
        ),
      ),
    );
  }

  Future fetchHomework() async {
    final ApiClient api = ApiClient();
    final LocalDB services = Get.find();
    final localDb = services.sharedPref;

    final jsonUserData = localDb!.getString('UserData');
    final Map userData = jsonDecode(jsonUserData!);

    final List<Widget> widgets = [];

    final studetSolvedResponse = await api.fetchWithConditions(
      'students_solved_homeworks',
      filters: {'student_id': userData['id'], 'homework_id': widget.id},
    );

    Map? studentSolvedData;

    if (studetSolvedResponse.isNotEmpty) {
      studentSolvedData = studetSolvedResponse[0];
    }

    final homeworkResponse = await api.fetchWithConditions(
      'homeworks',
      filters: {'id': widget.id},
    );

    final homeworkData = homeworkResponse[0];

    final topicLocalJsonData = localDb.getString(widget.topicId);
    final topicLocalData = topicLocalJsonData != null
        ? jsonDecode(topicLocalJsonData)
        : null;
    final answers = topicLocalData != null ? topicLocalData[widget.id] : null;

    if (studentSolvedData == null) {
      for (var element in homeworkData['questions'] as List) {
        controller.questions = homeworkData['questions'];

        widgets.add(
          HomeWorkModel(
            questionId: element,
            answer: answers != null ? answers[element] : null,
          ),
        );
      }
    } else {
      final Map answers = studentSolvedData['answers'];
      controller.questions = homeworkData['questions'];
      notEditable = true;
      for (var element in homeworkData['questions'] as List) {
        widgets.add(
          HomeWorkModel(
            questionId: element,
            answer: answers[element],
            flag: notEditable,
          ),
        );
      }
    }
    controller.pages = widgets;
  }

  // updateAnswer() {
  Widget navButtons(BuildContext context) {
    final lastPageIndex = controller.pages!.length - 1;
    if (controller.currentPage.value == lastPageIndex) {
      return Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Theme.of(context).colorScheme.secondary,
            ),
            onPressed: () {
              pageController.previousPage(
                duration: Duration(milliseconds: 10),
                curve: Curves.easeInOut,
              );
              controller.currentPage.value -= 1;
            },
            child: SizedBox(
              width: context.screenW / 4,
              child: Text(
                'السابق',
                textAlign: TextAlign.center,
                style: Theme.of(
                  context,
                ).textTheme.bodyLarge?.copyWith(color: Colors.white),
              ),
            ),
          ),
          ElevatedButton(
            onPressed: () async {
              Get.defaultDialog(
                title: 'تأكيد',
                middleText: 'هل أنت متأكد أنك تريد إنهاء الواجب ؟',
                textCancel: 'إلغاء',
                textConfirm: 'نعم، إنهاء',
                confirmTextColor: Colors.white,
                onConfirm: () async {
                  Get.back(); // Close the dialog
                  if (!notEditable) {
                    controller.addQuestionAnswer(
                      questionId:
                          controller.questions![controller.currentPage.value],
                    );
                    await controller.done(context).then((value) {
                      for (var element in controller.questions!) {
                        Get.delete<HomeworkModelController>(tag: element);
                      }
                      Get.offAll(HomePage());
                    });
                  } else {
                    for (var element in controller.questions!) {
                      Get.delete<HomeworkController>(tag: element);
                    }
                    Get.offAll(HomePage());
                  }
                },
              );
            },
            child: SizedBox(
              width: context.screenW / 3,
              child: Text(
                'انهاء',
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodyLarge,
              ),
            ),
          ),
        ],
      );
    } else {
      if (controller.currentPage.value == 0 &&
          controller.currentPage.value != lastPageIndex) {
        return Center(
          child: ElevatedButton(
            onPressed: () {
              if (!notEditable) {
                controller.addQuestionAnswer(
                  questionId:
                      controller.questions![controller.currentPage.value],
                );
              }

              pageController.nextPage(
                duration: Duration(milliseconds: 10),
                curve: Curves.easeIn,
              );
              controller.currentPage.value += 1;
            },
            child: SizedBox(
              width: context.screenW / 4,
              child: Text(
                'التالي',
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodyLarge,
              ),
            ),
          ),
        );
      } else {
        return Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: Theme.of(context).colorScheme.secondary,
              ),
              onPressed: () {
                pageController.previousPage(
                  duration: Duration(milliseconds: 10),
                  curve: Curves.easeInOut,
                );
                controller.currentPage.value -= 1;
              },
              child: SizedBox(
                width: context.screenW / 4,
                child: Text(
                  'السابق',
                  textAlign: TextAlign.center,
                  style: Theme.of(
                    context,
                  ).textTheme.bodyLarge?.copyWith(color: Colors.white),
                ),
              ),
            ),
            ElevatedButton(
              onPressed: () {
                if (!notEditable) {
                  controller.addQuestionAnswer(
                    questionId:
                        controller.questions![controller.currentPage.value],
                  );
                }
                pageController.nextPage(
                  duration: Duration(milliseconds: 10),
                  curve: Curves.easeIn,
                );
                controller.currentPage.value += 1;
              },
              child: SizedBox(
                width: context.screenW / 4,
                child: Text(
                  'التالي',
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.bodyLarge,
                ),
              ),
            ),
          ],
        );
      }
    }
  }
}
