import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:shobaki_academy/services/api.dart';
import 'package:shobaki_academy/services/locale_db.dart';
import 'package:shobaki_academy/services/statics.dart';

class ExamController extends GetxController {
  RxString? topicId;
  RxString? examId;
  Map answers = {};
  late final Map examData;
  String? answer;
  List<Widget>? pages;
  List? questions;
  final RxInt currentPage = 0.obs;
  RxDouble subTimer = 0.0.obs;
  RxDouble mainTimer = 0.0.obs;
  RxDouble remainingMainTimer = 0.0.obs;

  final LocalDB services = Get.find();

  void init({required String topicId, required String examId}) async {
    final ApiClient api = ApiClient();

    this.topicId = topicId.obs;
    this.examId = examId.obs;
    final db = services.sharedPref;

    final examResponse = await api.fetchWithConditions(
      'exams',
      filters: {'id': examId},
    );

    final examData = examResponse[0];

    this.examData = examData;

    answers.clear();

    final String? jsonLocalData = db!.getString(topicId);

    //if the local storage contain answers use it if not use default empty answers

    if (jsonLocalData != null) {
      final decodedData = jsonDecode(jsonLocalData);

      answers.addAll({examId: decodedData[examId]});
      if ((decodedData as Map).containsKey(examId)) {
        final timer = double.parse(decodedData['timer'].toString());

        if (timer == 0 || timer < 1) {
          subTimer.value = 1.0;
          mainTimer.value = 1.0;
          remainingMainTimer.value = mainTimer.value * 60;
        } else {
          subTimer.value = timer;
          mainTimer.value = timer;
          remainingMainTimer.value = mainTimer.value * 60;
        }
      } else {
        subTimer.value = double.parse(examData['timer'].toString());
        mainTimer.value = double.parse(examData['timer'].toString());
        remainingMainTimer.value = mainTimer.value * 60;

        answers.addAll({examId: {}, 'timer': subTimer.value});
      }
    } else {
      subTimer.value = double.parse(examData['timer'].toString());
      mainTimer.value = double.parse(examData['timer'].toString());
      remainingMainTimer.value = mainTimer.value * 60;

      answers.addAll({examId: {}, 'timer': subTimer.value});
    }
  }

  void addQuestionAnswer({required String questionId}) {
    final db = services.sharedPref;
    if (topicId != null && examId != null) {
      if (topicId!.isNotEmpty && examId!.isNotEmpty) {
        //add the current and questoin to memory
        final questoinsMap = answers[examId!.value];
        questoinsMap.addAll({questionId: answer});
        answer = null;

        //add question and answers to locale db

        answers[examId!.value] = questoinsMap;
        final data = {
          examId!.value: answers[examId!.value],
          'timer': mainTimer.value,
        };
        db!.setString(topicId!.value, jsonEncode(data));
      } else {
        throw Exception('Initialize the values with valid data');
      }
    } else {
      throw Exception('Initialize the values');
    }
  }

  Future<void> done(context) async {
    loadingDilog(context);

    final ApiClient api = ApiClient();

    final db = services.sharedPref;

    final jsonUserData = db!.getString('UserData');
    final Map userData = jsonDecode(jsonUserData!);

    final studentAnswers = jsonDecode(
      db.getString(topicId!.value)!,
    )[examId!.value];
    int grade = 0;
    for (var element in questions!) {
      final response = await api.fetchWithConditions(
        'questions_bank',
        filters: {'id': element},
      );
      final questionData = response[0];
      final studentAnswer = studentAnswers[element];
      final rightAnswer = questionData['correct_answer'];

      if (studentAnswer == rightAnswer) {
        questionData['right_answers_amount']++;
        grade++;
      } else {
        await api.insertData('students_wrong_answers', {
          'student_id': userData['id'],
          'question_id': element,
          'topic_id': topicId!.value,
          'answer': studentAnswer,
        });
        questionData['wrong_answers_amount']++;
        // if (grade != 0) {
        //   grade--;
        // }
      }
      await api.updateData('questions_bank', questionData, {'id': element});
    }

    final double time = (examData['timer'] - mainTimer.value) * 60;

    int minutes = time ~/ 60;
    int seconds = time.round() % 60;

    // Format seconds to always show two digits (e.g., 1:05 instead of 1:5)
    String formattedSeconds = seconds < 10 ? '0$seconds' : '$seconds';

    // Store the result in a string formatted as "MM:SS"
    String timeString = '$minutes:$formattedSeconds';

    await api.insertData('students_solved_exams', {
      'student_id': userData['id'],
      'exam_id': examId!.value,
      'grade': grade,
      'time': timeString,
      'answers': studentAnswers,
    });

    showSnackbar(
      'معلومات سرية للغاية !!',
      "درجتك فلامتحان : $grade",
      backgroundColor: Colors.green,
      snackPosition: SnackPosition.BOTTOM,
    );

    db.remove(topicId!.value);
    Get.close(1);
  }
}
