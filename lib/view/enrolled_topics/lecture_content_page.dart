import 'dart:convert';
import 'package:animate_do/animate_do.dart';
import 'package:shobaki_academy/controller/watermark_controller.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:shobaki_academy/model/card_model.dart';
import 'package:shobaki_academy/services/api.dart';
import 'package:shobaki_academy/services/locale_db.dart';
import 'package:shobaki_academy/services/statics.dart';

class LectureContentPage extends StatefulWidget {
  const LectureContentPage({
    super.key,
    required this.lectureId,
    required this.topicId,
  });
  final String lectureId;
  final String? topicId;

  @override
  State<LectureContentPage> createState() => _LectureContentPageState();
}

class _LectureContentPageState extends State<LectureContentPage> {
  final WatermarkController watermarkController = Get.find();
  final ApiClient api = ApiClient();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      setState(() {
        watermarkController.showWatermark.value = true;
      });
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      watermarkController.showWatermark.value = false;
    });
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    final isDesktop = size.width > 900;
    final crossAxisCount = isDesktop
        ? (size.width > 1600
              ? 5
              : size.width > 1200
              ? 4
              : 4)
        : 1;

    return Scaffold(
      backgroundColor: const Color(0xfff7f7f7),
      appBar: AppBar(
        title: Text(
          'محتوى المحاضرة',
          style: Theme.of(
            context,
          ).textTheme.headlineMedium?.copyWith(color: Colors.white),
        ),
        centerTitle: true,
      ),
      body: SafeArea(
        child: FutureBuilder(
          future: lecDataFetcher(context),
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.done) {
              if (snapshot.data!.isNotEmpty) {
                return Directionality(
                  textDirection: TextDirection.rtl,
                  child: Padding(
                    padding: EdgeInsets.symmetric(
                      horizontal: isDesktop ? 20 : 10,
                      vertical: isDesktop ? 12 : 10,
                    ),
                    child: FadeInUp(
                      duration: const Duration(milliseconds: 500),
                      child: _buildResponsiveLayout(
                        snapshot.data as List<Widget>,
                        isDesktop,
                        crossAxisCount,
                      ),
                    ),
                  ),
                );
              } else {
                return Center(
                  child: Text(
                    'المحاضرة فارغة',
                    style: Theme.of(context).textTheme.headlineLarge,
                  ),
                );
              }
            } else {
              return Center(child: loading(context));
            }
          },
        ),
      ),
    );
  }

  Widget _buildResponsiveLayout(
    List<Widget> items,
    bool isDesktop,
    int crossAxisCount,
  ) {
    if (!isDesktop) {
      return ListView(children: items);
    }

    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: crossAxisCount,
        mainAxisSpacing: 12,
        crossAxisSpacing: 10,
        //childAspectRatio: 1.2,
      ),
      itemCount: items.length,
      itemBuilder: (context, index) {
        return items[index];
      },
    );
  }

  /// Get user's view count for a specific video from logs
  Future<int> _getUserVideoViewCount(String videoUrl, String userId) async {
    try {
      final logs = await api.fetchWithConditions(
        'logs',
        select: 'video_url, viewed, created_at',
        filters: {
          'type': 'video_view',
          'user_id': userId,
          'video_url': videoUrl,
        },
      );

      if (logs.isEmpty) return 0;

      // 1️⃣ Parse & sort logs by created_at
      final sortedLogs =
          logs.map((e) => DateTime.parse(e['created_at'])).toList()..sort();

      int viewCount = 0;

      // 2️⃣ Group logs by day
      final Map<DateTime, List<DateTime>> logsByDay = {};
      for (final time in sortedLogs) {
        final dayKey = DateTime(time.year, time.month, time.day);
        logsByDay.putIfAbsent(dayKey, () => []).add(time);
      }

      // 3️⃣ Process each day
      for (final dayKey in logsByDay.keys.toList()..sort()) {
        final dayLogs = logsByDay[dayKey]!;
        int i = 0;

        while (i < dayLogs.length) {
          final sessionStart = dayLogs[i];

          // Calculate session end
          var sessionEnd = sessionStart.add(const Duration(hours: 3));

          // If session crosses midnight, limit to the end of day
          final endOfDay = DateTime(
            sessionStart.year,
            sessionStart.month,
            sessionStart.day,
            23,
            59,
            59,
          );
          if (sessionEnd.isAfter(endOfDay)) {
            sessionEnd = endOfDay;
          }

          // Count 1 view
          viewCount++;

          // Skip logs inside the session window
          while (i < dayLogs.length && !dayLogs[i].isAfter(sessionEnd)) {
            i++;
          }
        }
      }

      return viewCount;
    } catch (e) {
      projectLogger.e('Error fetching video view logs: $e');
      return 0;
    }
  }

  // Count logs where viewed=true (user watched > 25% of video)
  // int viewCount = 0;
  // for (final log in logs) {
  //   if (log['video_url'] == videoUrl) {
  //     if (log['viewed'] == true) {
  //       viewCount++;
  //     }
  //   }
  // }
  // return viewCount;

  /// Check if video view limit is reached
  Future<bool> _isVideoViewLimitReached(
    String videoUrl,
    int maxViewCount,
    String userId,
  ) async {
    if (maxViewCount <= 0) return false; // No limit set

    final userViewCount = await _getUserVideoViewCount(videoUrl, userId);
    return userViewCount >= maxViewCount;
  }

  Future<List<Widget>> lecDataFetcher(BuildContext context) async {
    final localDb = Get.find<LocalDB>().sharedPref!;
    final userData = jsonDecode(localDb.getString('UserData')!) as Map;
    final userId = userData['id'] as String;

    final lectureData = (await api.fetchWithConditions(
      'lectures',
      filters: {'id': widget.lectureId},
    ))[0];

    final List<Widget> content = [];

    void addCard(List<Widget> targetList, Widget card) {
      targetList.add(
        FadeInUp(
          from: 100,
          duration: const Duration(milliseconds: 600),
          child: card,
        ),
      );
      targetList.add(const SizedBox(height: 15));
    }

    Widget buildLockedOverlay(String message) {
      return Positioned.fill(
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
              Text(
                message,
                textAlign: TextAlign.center,
                style: Theme.of(
                  context,
                ).textTheme.bodyLarge!.copyWith(color: Colors.white),
              ),
              const SizedBox(width: 15),
              const Icon(Icons.lock_rounded, color: Colors.white),
            ],
          ),
        ),
      );
    }

    // void addVideoCards(
    //   Map videos,
    //   List<Widget> list, {
    //   bool isLocked = false,
    //   String? lockMessage,
    // }) {
    //   videos.forEach((key, value) {
    //     Widget card = CardModel(
    //       type: CardTypes.video,
    //       title: value['title'],
    //       description: value['description'],
    //       id: '',
    //       url: value['url'],
    //     );

    //     if (isLocked && lockMessage != null) {
    //       card = Stack(children: [card, buildLockedOverlay(lockMessage)]);
    //     }

    //     addCard(list, card);
    //   });
    // }

    // Videos with view limit checking
    if (lectureData['videos'] != null) {
      for (final MapEntry entry in lectureData['videos'].entries) {
        final value = entry.value;
        final videoUrl = value['url'];
        final maxViewCount =
            value['max_view_count'] ?? 0; // Get max views from video data

        final isLimited = await _isVideoViewLimitReached(
          videoUrl,
          maxViewCount,
          userId,
        );
        final userViews = await _getUserVideoViewCount(videoUrl, userId);

        Widget card = CardModel(
          type: CardTypes.video,
          title: value['title'],
          description: value['description'],
          note: ' المشاهدات  ($userViews/$maxViewCount)',
          id: '',
          url: value['url'],
        );

        if (isLimited) {
          final lockMsg =
              'وصلت للحد الأقصى من المشاهدات\n($userViews/$maxViewCount)';
          card = Stack(children: [card, buildLockedOverlay(lockMsg)]);
        }

        addCard(content, card);
      }
    }

    // PDFs
    if (lectureData['pdf'] != null) {
      lectureData['pdf'].forEach((key, value) {
        addCard(
          content,
          CardModel(
            type: CardTypes.book,
            title: value['title'],
            description: value['description'],
            id: '',
            url: value['url'],
          ),
        );
      });
    }

    // Homework
    if (lectureData['homework_id'] != null) {
      final homeworkData = (await api.fetchWithConditions(
        'homeworks',
        filters: {'id': lectureData['homework_id']},
      ))[0];

      final solvedHomework = await api.fetchWithConditions(
        'students_solved_homeworks',
        filters: {'student_id': userId, 'homework_id': homeworkData['id']},
      );

      addCard(
        content,
        CardModel(
          type: CardTypes.homework,
          title: homeworkData['title'],
          description: homeworkData['description'],
          grade: solvedHomework.isNotEmpty ? solvedHomework[0]['grade'] : null,
          questionsNumber: homeworkData['questions_number'],
          id: homeworkData['id'],
          topicId: widget.topicId,
        ),
      );

      if (homeworkData['videos'] != null) {
        for (final MapEntry entry in homeworkData['videos'].entries) {
          final value = entry.value;
          final videoUrl = value['url'];
          final maxViewCount = value['max_view_count'] ?? 0;

          final isLimited = await _isVideoViewLimitReached(
            videoUrl,
            maxViewCount,
            userId,
          );
          final userViews = await _getUserVideoViewCount(videoUrl, userId);

          Widget card = CardModel(
            type: CardTypes.video,
            title: value['title'],
            description: value['description'],
            note: ' المشاهدات  ($userViews/$maxViewCount)',

            id: '',
            url: value['url'],
          );

          final shouldLock = solvedHomework.isEmpty || isLimited;
          String lockMsg = '';

          if (solvedHomework.isEmpty) {
            lockMsg = 'روح حل الواجب وتعالى';
          } else if (isLimited) {
            lockMsg =
                'وصلت للحد الأقصى من المشاهدات\n($userViews/$maxViewCount)';
          }

          if (shouldLock) {
            card = Stack(children: [card, buildLockedOverlay(lockMsg)]);
          }

          addCard(content, card);
        }
      }
    }

    // Exam
    if (lectureData['exam_id'] != null) {
      final examData = (await api.fetchWithConditions(
        'exams',
        filters: {'id': lectureData['exam_id']},
      ))[0];

      final solvedExam = await api.fetchWithConditions(
        'students_solved_exams',
        filters: {'student_id': userId, 'exam_id': examData['id']},
      );

      addCard(
        content,
        CardModel(
          type: CardTypes.exam,
          title: examData['title'],
          examDuration: examData['timer'],
          grade: solvedExam.isNotEmpty ? solvedExam[0]['grade'] : null,
          description: examData['description'],
          questionsNumber: examData['questions_number'],
          id: examData['id'],
          topicId: widget.topicId,
        ),
      );

      if (examData['videos'] != null) {
        for (final MapEntry entry in examData['videos'].entries) {
          final value = entry.value;
          final videoUrl = value['url'];
          final maxViewCount = value['max_view_count'] ?? 0;

          final isLimited = await _isVideoViewLimitReached(
            videoUrl,
            maxViewCount,
            userId,
          );
          final userViews = await _getUserVideoViewCount(videoUrl, userId);

          Widget card = CardModel(
            type: CardTypes.video,
            title: value['title'],
            description: value['description'],
            note: ' المشاهدات  ($userViews/$maxViewCount)',

            id: '',
            url: value['url'],
          );

          final shouldLock = solvedExam.isEmpty || isLimited;
          String lockMsg = '';

          if (solvedExam.isEmpty) {
            lockMsg = 'روح حل الامتحان وتعالى';
          } else if (isLimited) {
            lockMsg =
                'وصلت للحد الأقصى من المشاهدات\n($userViews/$maxViewCount)';
          }

          if (shouldLock) {
            card = Stack(children: [card, buildLockedOverlay(lockMsg)]);
          }

          addCard(content, card);
        }
      }
    }

    return content;
  }
}
