import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:shobaki_academy/controller/exam_controller.dart';
import 'package:shobaki_academy/controller/exam_model_controller.dart';
import 'package:shobaki_academy/extentions.dart';
import 'package:shobaki_academy/model/exam_model.dart';
import 'package:shobaki_academy/services/api.dart';
import 'package:shobaki_academy/services/locale_db.dart';
import 'package:shobaki_academy/services/statics.dart';
import 'package:shobaki_academy/view/home.dart';
import 'package:slide_countdown/slide_countdown.dart';
import 'package:smooth_page_indicator/smooth_page_indicator.dart';

class ExamPage extends StatefulWidget {
  const ExamPage({super.key, required this.id, required this.topicId});
  final String id;
  final String topicId;

  @override
  State<ExamPage> createState() => _ExamPageState();
}

class _ExamPageState extends State<ExamPage> {
  final pageController = PageController();

  final controller = Get.put(ExamController());

  late Timer _mainTimer; // Timer for mainTimer

  bool notEditable = false;

  @override
  void initState() {
    controller.init(topicId: widget.topicId, examId: widget.id);
    controller.remainingMainTimer.value =
        controller.mainTimer.value * 60; // Convert minutes to seconds
    _startMainTimer(); // Start the main timer countdown

    super.initState();
  }

  @override
  void dispose() {
    _mainTimer.cancel();
    controller.dispose();
    super.dispose();
  }

  // Start the countdown for mainTimer
  void _startMainTimer() {
    if (notEditable == true) {
      _mainTimer = Timer.periodic(Duration(seconds: 1), (timer) {
        if (controller.remainingMainTimer > 0) {
          controller.remainingMainTimer.value--; // Decrease the remaining time
          controller.mainTimer.value =
              controller.remainingMainTimer.value / 60; // Update the main timer
        } else {
          _mainTimer.cancel();
          _onMainTimerEnd(); // Perform action when timer reaches zero
        }
      });
    }
  }

  void _onMainTimerEnd() async {
    if (notEditable == false) {
      controller.addQuestionAnswer(
        questionId: controller.questions![controller.currentPage.value],
      );
      await controller.done(context).then((value) {
        for (var element in controller.questions!) {
          Get.delete<ExamModelController>(tag: element);
        }
        Get.offAll(HomePage());
      });
    } else {
      for (var element in controller.questions!) {
        Get.delete<ExamModelController>(tag: element);
      }
      Get.back();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          'امتحان ',
          style: Theme.of(
            context,
          ).textTheme.headlineMedium?.copyWith(color: Colors.white),
        ),
        centerTitle: true,
        actions: [
          notEditable == false
              ? Obx(() {
                  return Directionality(
                    textDirection: TextDirection.ltr,
                    child: Container(
                      margin: EdgeInsets.symmetric(horizontal: 15),
                      child: SlideCountdownSeparated(
                        duration: Duration(
                          minutes: controller.subTimer.value.round(),
                        ),
                      ),
                    ),
                  );
                })
              : SizedBox(),
        ],
      ),
      body: SafeArea(
        child: FutureBuilder(
          future: fetchexam(),
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
                      right: 1,
                      left: 1,
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

  Future fetchexam() async {
    final ApiClient api = ApiClient();
    final LocalDB services = Get.find();
    final localDb = services.sharedPref;

    final jsonUserData = localDb!.getString('UserData');
    final Map userData = jsonDecode(jsonUserData!);

    final List<Widget> widgets = [];

    final studetSolvedResponse = await api.fetchWithConditions(
      'students_solved_exams',
      filters: {'student_id': userData['id'], 'exam_id': widget.id},
    );

    Map? studentSolvedData;

    if (studetSolvedResponse.isNotEmpty) {
      studentSolvedData = studetSolvedResponse[0];
    }

    final examResponse = await api.fetchWithConditions(
      'exams',
      filters: {'id': widget.id},
    );

    final examData = examResponse[0];

    final topicLocalJsonData = localDb.getString(widget.topicId);
    final topicLocalData = topicLocalJsonData != null
        ? jsonDecode(topicLocalJsonData)
        : null;
    final answers = topicLocalData != null ? topicLocalData[widget.id] : null;

    if (studentSolvedData == null) {
      for (var element in examData['questions'] as List) {
        controller.questions = examData['questions'];

        widgets.add(
          ExamModel(
            questionId: element,
            answer: answers != null ? answers[element] : null,
          ),
        );
      }
    } else {
      final Map answers = studentSolvedData['answers'];
      controller.questions = examData['questions'];
      if (notEditable != true) {
        setState(() {
          notEditable = true;
        });
      }
      for (var element in examData['questions'] as List) {
        widgets.add(
          ExamModel(
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
                middleText: 'هل أنت متأكد أنك تريد إنهاء الامتحان؟',
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
                        Get.delete<ExamModelController>(tag: element);
                      }
                      Get.offAll(HomePage());
                    });
                  } else {
                    for (var element in controller.questions!) {
                      Get.delete<ExamModelController>(tag: element);
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
