import 'dart:convert';
import 'package:animate_do/animate_do.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:shobaki_academy/model/card_model.dart';
import 'package:shobaki_academy/services/api.dart';
import 'package:shobaki_academy/services/locale_db.dart';
import 'package:shobaki_academy/services/statics.dart';

class TopicPage extends StatefulWidget {
  const TopicPage({super.key, required this.topicId});
  final String topicId;

  @override
  State<TopicPage> createState() => _TopicPageState();
}

class _TopicPageState extends State<TopicPage> {
  final ApiClient _apiClient = ApiClient();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          'محتوى الموضوع',
          style: Theme.of(
            context,
          ).textTheme.headlineMedium?.copyWith(color: Colors.white),
        ),
        centerTitle: true,
      ),
      body: SafeArea(
        child: FutureBuilder(
          future: fetcher(),
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.done) {
              return Padding(
                padding: const EdgeInsets.all(10.0),
                child: snapshot.data == null
                    ? Center(child: Text('لا توجد بيانات'))
                    : ListView(children: snapshot.data as List<Widget>),
              );
            } else {
              return loading(context);
            }
          },
        ),
      ),
    );
  }

  fetcher() async {
    List response = await _apiClient.fetchWithConditions(
      'topics',
      filters: {'id': widget.topicId},
    );

    Map topic = response[0];

    List widgets;

    if (topic['is_parent']) {
      widgets = await subTopicsHandler(topic['children']);
    } else {
      widgets = await lecturesHandler(context, topic['lectures']);
    }

    return widgets;
  }

  Future<List<Widget>> subTopicsHandler(List topicsList) async {
    final topics = [];

    try {
      for (var element in topicsList) {
        List response = await _apiClient.fetchWithConditions(
          'topics',
          filters: {'id': element},
        );
        Map topic = response[0];
        topics.add(topic);
        print('element: $element');
      }
    } on Exception catch (e) {
      print('Error fetching subtopics: $e');
    }

    print(topics);

    final List<Widget> widgets = [];

    for (var element in topics) {
      widgets.add(
        FadeInUp(
          from: 100,
          duration: const Duration(milliseconds: 600),
          child: CardModel(
            type: CardTypes.enrolledTopic,
            title: element['title'],
            description: element['description'],
            id: element['id'],
          ),
        ),
      );
    }

    return widgets;
  }

  Future<List<Widget>> lecturesHandler(context, lecturesList) async {
    final ApiClient api = ApiClient();

    final LocalDB services = Get.find();
    final localDb = services.sharedPref;

    final jsonUserData = localDb!.getString('UserData');
    final Map userData = jsonDecode(jsonUserData!);

    final data = [];

    final List<Widget> widgets = [];

    for (var element in lecturesList) {
      final fetchedLectureData = await api.fetchWithConditions(
        'lectures',
        filters: {'id': element},
      );
      data.add(fetchedLectureData[0]);
    }

    if (data.isNotEmpty) {
      final List<Map<String, dynamic>> sortedData = data
          .map((item) => item as Map<String, dynamic>)
          .toList();

      sortedData.sort((a, b) {
        final aDate = DateTime.parse(a['created_at']);
        final bDate = DateTime.parse(b['created_at']);
        return aDate.compareTo(bDate);
      });

      for (Map element in sortedData) {
        if (element['exam_to_open'] != null) {
          final studentSolvedExam = await api.fetchWithConditions(
            'students_solved_exams',
            filters: {
              'student_id': userData['id'],
              'exam_id': element['exam_to_open'],
            },
          );
          if (studentSolvedExam.isNotEmpty) {
            widgets.add(
              FadeInUp(
                from: 100,
                duration: const Duration(milliseconds: 600),
                child: CardModel(
                  type: CardTypes.lecture,
                  id: element['id'],
                  topicId: widget.topicId,
                  title: element['title'],
                  description: element['description'],
                ),
              ),
            );
            widgets.add(SizedBox(height: 15));
          } else {
            widgets.add(
              FadeInUp(
                from: 100,
                duration: const Duration(milliseconds: 600),
                child: SizedBox(
                  child: Stack(
                    children: [
                      CardModel(
                        type: CardTypes.lecture,
                        id: element['id'],
                        topicId: widget.topicId,
                        title: element['title'],
                        description: element['description'],
                      ),
                      Positioned.fill(
                        child: Card(
                          shadowColor: Colors.black.withOpacity(0.12),
                          elevation: 4,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(25),
                          ),
                          color: Colors.black.withOpacity(0.5),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              SizedBox(
                                width: 300,
                                child: Text(
                                  'قم بحل الاختبار السابق لفتح هذه المحاضرة',
                                  maxLines: 3,
                                  textAlign: TextAlign.center,
                                  style: Theme.of(context).textTheme.bodyLarge!
                                      .copyWith(color: Colors.white),
                                ),
                              ),
                              const SizedBox(width: 15),
                              const Icon(
                                Icons.lock_rounded,
                                color: Colors.white,
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            );
            widgets.add(SizedBox(height: 15));
          }
        } else {
          widgets.add(
            FadeInUp(
              from: 100,
              duration: const Duration(milliseconds: 600),
              child: CardModel(
                type: CardTypes.lecture,
                id: element['id'],
                thumbnail: element['thumbnail'],
                topicId: widget.topicId,
                title: element['title'],
                description: element['description'],
              ),
            ),
          );

          widgets.add(SizedBox(height: 15));
        }
      }
    }
    return widgets;
  }
}
