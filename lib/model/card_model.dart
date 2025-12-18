import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:shobaki_academy/model/webview_model.dart';
import 'package:shobaki_academy/model/widgets/quill_description.dart';
import 'package:shobaki_academy/view/enrolled_topics/lecture_content_page.dart';
import 'package:shobaki_academy/view/enrolled_topics/topic_page.dart';
import 'package:shobaki_academy/view/results/results_page.dart';
import 'package:shobaki_academy/view/sub/exam_page.dart';
import 'package:shobaki_academy/view/sub/homework_page.dart';
import 'package:shobaki_academy/view/sub/vdo_video_player.dart';
import 'package:shobaki_academy/view/topics/topic_content_page.dart';

enum CardTypes {
  topic,
  enrolledTopic,
  wrongQuestions,
  lecture,
  video,
  book,
  homework,
  exam,
}

enum SignupModelTypes { formFields, selectList }

class CardModel extends StatelessWidget {
  final CardTypes type;
  final String title;
  final String description;
  final String? note;
  final String id;
  final String? topicId;
  final String? url;
  final String? subTopicKey;
  final Widget? nav;
  final String? thumbnail;
  final int? questionsNumber;
  final int? examDuration;
  final int? grade;

  const CardModel({
    super.key,
    required this.type,
    required this.title,
    required this.description,
    required this.id,
    this.note,
    this.nav,
    this.url,
    this.subTopicKey,
    this.thumbnail,
    this.topicId,
    this.examDuration,
    this.questionsNumber,
    this.grade,
  });

  @override
  Widget build(BuildContext context) {
    switch (type) {
      case CardTypes.topic:
        return _SimpleCard(
          title: title,
          description: description,
          thumbnail: thumbnail,
          //fallbackAsset: 'assets/gifs/MobileMarketing.gif',
          navlabel: 'تعلم المزيد',
          navPage: nav == null ? TopicContentPage(topicId: id) : nav!,
        );
      case CardTypes.enrolledTopic:
        return _SimpleCard(
          title: title,
          description: description,
          thumbnail: thumbnail,
          //fallbackAsset: 'assets/gifs/Science.gif',
          navlabel: 'تصفح الموضوع',
          navPage: TopicPage(topicId: id),
        );
      case CardTypes.lecture:
        return _SimpleCard(
          title: title,
          description: description,
          thumbnail: thumbnail,
          //fallbackAsset: 'assets/gifs/Science2.gif',
          navlabel: 'تصفح المحاضرة',
          navPage: LectureContentPage(lectureId: id, topicId: topicId),
        );
      case CardTypes.video:
        return _SimpleCard(
          title: title,
          description: description,
          thumbnail: thumbnail,
          note: note,
          //fallbackAsset: 'assets/gifs/KidsStudyingfromHome.gif',
          navlabel: 'بدء المشاهدة',
          //navPage: WatchingPage(videoUrl: url!),
          navPage: VideoPlayerView(videoId: url!),
        );
      case CardTypes.book:
        return _SimpleCard(
          title: title,
          description: description,
          thumbnail: thumbnail,
          //fallbackAsset: 'assets/gifs/Readinglist.gif',
          navlabel: 'بدء القراءة',
          navPage: WebviewModel(url: url!),
        );
      case CardTypes.homework:
        return _SimpleCard(
          title: title,
          description: description,
          thumbnail: thumbnail,
          //fallbackAsset: 'assets/gifs/Todolist.gif',
          navlabel: 'بدء الواجب',
          navPage: HomeworkPage(topicId: topicId!, id: id),
          questionsNumber: questionsNumber,
          grade: grade,
        );
      case CardTypes.exam:
        return _SimpleCard(
          title: title,
          description: description,
          thumbnail: thumbnail,
          //fallbackAsset: 'assets/gifs/Exams.gif',
          navlabel: 'بدء الامتحان',
          navPage: ExamPage(id: id, topicId: topicId!),
          questionsNumber: questionsNumber,
          examDuration: examDuration,
          grade: grade,
        );
      case CardTypes.wrongQuestions:
        return _SimpleCard(
          title: title,
          description: description,
          thumbnail: thumbnail,
          //fallbackAsset: 'assets/gifs/Questions.gif',
          navlabel: 'عرض الاخطاء',
          navPage: nav != null ? nav! : ResultsPage(),
        );
    }
  }
}

/// Unified simple card used for all card types (replaces fullImage / cornerImage)
class _SimpleCard extends StatelessWidget {
  final String title;
  final String description;
  final String? thumbnail;
  //final String? fallbackAsset;
  final String navlabel;
  final String? note;
  final Widget navPage;
  final int? questionsNumber;
  final int? examDuration;
  final int? grade;

  const _SimpleCard({
    required this.title,
    required this.description,
    //this.fallbackAsset,
    required this.navlabel,
    required this.navPage,
    this.thumbnail,
    this.note,
    this.questionsNumber,
    this.examDuration,
    this.grade,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final primary = theme.colorScheme.primary;

    return Directionality(
      textDirection: TextDirection.rtl,
      child: Container(
        padding: const EdgeInsets.all(10.0),
        margin: const EdgeInsets.symmetric(vertical: 10, horizontal: 10),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(24),
          gradient: LinearGradient(
            colors: [primary.withOpacity(0.12), primary.withOpacity(0.18)],
            begin: Alignment.topRight,
            end: Alignment.bottomLeft,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.08),
              blurRadius: 12,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(24),
          child: Material(
            color: Colors.white.withOpacity(0.92),
            child: InkWell(
              onTap: () => Get.to(
                () => navPage,
                transition: Transition.fade,
                duration: const Duration(milliseconds: 350),
              ),
              child: Padding(
                padding: const EdgeInsets.all(14.0),
                child: Column(
                  children: [
                    /// ---------------- IMAGE ----------------
                    AspectRatio(
                      aspectRatio: 16 / 9,
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(16),
                        child: thumbnail != null
                            ? Image.network(
                                thumbnail!,
                                fit: BoxFit.fill,
                                width: double.infinity,

                                errorBuilder: (_, __, ___) => Image.network(
                                  'https://placehold.co/320x180/png',
                                ),
                              )
                            : Image.network(
                                'https://placehold.co/320x180/png',
                                fit: BoxFit.fill,
                              ),
                      ),
                    ),

                    const SizedBox(height: 12),

                    /// ---------------- TITLE + GRADE ----------------
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            title,
                            style: theme.textTheme.headlineSmall?.copyWith(
                              fontWeight: FontWeight.bold,
                              color: Colors.black87,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),

                        if (grade != null)
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 4,
                            ),
                            decoration: BoxDecoration(
                              color: primary.withOpacity(0.2),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Text(
                              "درجتك: $grade",
                              style: theme.textTheme.bodySmall?.copyWith(
                                color: primary,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                      ],
                    ),

                    const SizedBox(height: 8),

                    /// ---------------- DESCRIPTION ----------------
                    QuillDescription.fromContent(
                      description,
                      maxLines: 2,
                      textStyle: theme.textTheme.bodyMedium?.copyWith(
                        color: Colors.black87,
                        height: 1.4,
                      ),
                    ),

                    note != null
                        ? Text(
                            note!,
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: Colors.black54,
                              fontStyle: FontStyle.italic,
                            ),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          )
                        : SizedBox(height: 0),

                    const SizedBox(height: 10),

                    /// ---------------- FOOTER ----------------
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        if (questionsNumber != null)
                          Text(
                            "عدد الأسئلة: $questionsNumber",
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: Colors.black54,
                              fontWeight: FontWeight.w500,
                            ),
                          ),

                        InkWell(
                          onTap: () {
                            Get.to(
                              () => navPage,
                              transition: Transition.leftToRightWithFade,
                              duration: const Duration(milliseconds: 450),
                              preventDuplicates: false,
                            );
                          },
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 14,
                              vertical: 6,
                            ),
                            decoration: BoxDecoration(
                              color: primary,
                              borderRadius: BorderRadius.circular(14),
                              boxShadow: [
                                BoxShadow(
                                  color: primary.withOpacity(0.35),
                                  blurRadius: 6,
                                  offset: const Offset(0, 3),
                                ),
                              ],
                            ),
                            child: Text(
                              navlabel,
                              style: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
