import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:shobaki_academy/services/api.dart';
import 'package:shobaki_academy/services/locale_db.dart';
import 'package:shobaki_academy/services/statics.dart';

class HomeworkController extends GetxController {
  RxString? topicId;
  RxString? homeworkId;
  Map answers = {};
  String? answer;
  List<Widget>? pages;
  List? questions;
  final RxInt currentPage = 0.obs;

  final LocalDB services = Get.find();

  void init({required String topicId, required String homeworkId}) {
    this.topicId = topicId.obs;
    this.homeworkId = homeworkId.obs;
    final db = services.sharedPref;

    answers.clear();

    final String? jsonAnswers = db!.getString(topicId);

    //if the local storage contain answers use it if not use default empty answers

    if (jsonAnswers != null) {
      final decodedAnswers = jsonDecode(jsonAnswers);

      if ((decodedAnswers as Map).containsKey(homeworkId)) {
        answers.addAll(decodedAnswers);
      } else {
        answers.addAll({homeworkId: {}});
      }
    } else {
      answers.addAll({homeworkId: {}});
    }
  }

  void addQuestionAnswer({required String questionId}) {
    final db = services.sharedPref;
    if (topicId != null && homeworkId != null) {
      if (topicId!.isNotEmpty && homeworkId!.isNotEmpty) {
        //add the current and questoin to memory
        final questoinsMap = answers[homeworkId!.value];
        questoinsMap.addAll({questionId: answer});
        answer = null;

        //add question and answers to locale db
        answers[homeworkId!.value] = questoinsMap;
        db!.setString(topicId!.value, jsonEncode(answers));
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
    )[homeworkId!.value];
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
    await api.insertData('students_solved_homeworks', {
      'student_id': userData['id'],
      'homework_id': homeworkId!.value,
      'grade': grade,
      'answers': studentAnswers,
    });

    Get.snackbar(
      'معلومات سرية للغاية !!',
      "درجتك فلواجب : $grade",
      backgroundColor: Colors.green,
      snackPosition: SnackPosition.BOTTOM,
    );

    db.remove(topicId!.value);
    Get.close(1);
  }
}
