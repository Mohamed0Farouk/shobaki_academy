import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:shobaki_academy/model/pdf_model.dart';
//import 'package:shobaki_academy/model/webview_model.dart';
//import 'package:shobaki_academy/model/widgets/quill_description.dart';
//import 'package:shobaki_academy/view/enrolled_topics/lecture_content.dart';
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
  final Widget? note;
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
          navlabel: 'تعلم المزيد',
          navPage: nav == null ? TopicContentPage(topicId: id) : nav!,
        );
      case CardTypes.enrolledTopic:
        return _SimpleCard(
          title: title,
          description: description,
          thumbnail: thumbnail,
          navlabel: 'تصفح الموضوع',
          navPage: TopicPage(topicId: id),
        );
      case CardTypes.lecture:
        return _SimpleCard(
          title: title,
          description: description,
          thumbnail: thumbnail,
          navlabel: 'تصفح المحاضرة',
          navPage: LectureContentPage(lectureId: id, topicId: topicId),
        );
      case CardTypes.video:
        return _SimpleCard(
          title: title,
          description: description,
          thumbnail: thumbnail,
          note: note,
          navlabel: 'بدء المشاهدة',
          navPage: VideoPlayerView(videoId: url!),
        );
      case CardTypes.book:
        return _SimpleCard(
          title: title,
          description: description,
          thumbnail: thumbnail,
          navlabel: 'بدء القراءة',
          //navPage: WebviewModel(url: url!),
          navPage: PdfModel(),
        );
      case CardTypes.homework:
        return _SimpleCard(
          title: title,
          description: description,
          thumbnail: thumbnail,
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
          navlabel: 'عرض الاخطاء',
          navPage: nav != null ? nav! : ResultsPage(),
        );
    }
  }
}

/// Unified simple card used for all card types
class _SimpleCard extends StatelessWidget {
  final String title;
  final String description;
  final String? thumbnail;
  final String navlabel;
  final Widget? note;
  final Widget navPage;
  final int? questionsNumber;
  final int? examDuration;
  final int? grade;

  const _SimpleCard({
    required this.title,
    required this.description,
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
    final screenSize = MediaQuery.of(context).size;
    final screenWidth = screenSize.width;
    final screenHeight = screenSize.height;

    // Responsive sizing
    final isSmallScreen = screenWidth < 360;
    final isTinyScreen = screenWidth < 280;
    final titleSize = isTinyScreen ? 12.0 : (isSmallScreen ? 13.0 : 15.0);
    //final descSize = isTinyScreen ? 9.0 : (isSmallScreen ? 10.0 : 12.0);
    final buttonPadH = isTinyScreen ? 8.0 : (isSmallScreen ? 10.0 : 14.0);
    final buttonPadV = isTinyScreen ? 4.0 : (isSmallScreen ? 5.0 : 7.0);
    final buttonFontSize = isTinyScreen ? 14.0 : (isSmallScreen ? 14.0 : 14.0);
    final contentPad = isTinyScreen ? 6.0 : (isSmallScreen ? 8.0 : 12.0);

    // Calculate max dimensions
    final maxCardHeight = screenHeight * 0.65;
    final maxCardWidth = screenWidth > 600 ? 600.0 : double.infinity;

    return Directionality(
      textDirection: TextDirection.rtl,
      child: Center(
        child: ConstrainedBox(
          constraints: BoxConstraints(
            maxHeight: maxCardHeight,
            maxWidth: maxCardWidth,
            minHeight: 180,
          ),
          child: Container(
            margin: EdgeInsets.symmetric(
              vertical: isSmallScreen ? 6 : 8,
              horizontal: isSmallScreen ? 2 : 4,
            ),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(isSmallScreen ? 12 : 16),
              gradient: LinearGradient(
                colors: [primary.withOpacity(0.12), primary.withOpacity(0.18)],
                begin: Alignment.topRight,
                end: Alignment.bottomLeft,
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.08),
                  blurRadius: 12,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(isSmallScreen ? 12 : 16),
              child: Material(
                color: Colors.white,
                child: InkWell(
                  onTap: () {
                    if (navPage is LectureContentPage) {
                      Get.offAll(
                        () => navPage,
                        transition: Transition.fade,
                        duration: const Duration(milliseconds: 350),
                      );
                    }
                    Get.to(
                      () => navPage,
                      transition: Transition.fade,
                      duration: const Duration(milliseconds: 350),
                    );
                  },
                  child: LayoutBuilder(
                    builder: (context, constraints) {
                      return Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          /// ---------------- IMAGE ----------------
                          Flexible(
                            flex: 5,
                            child: ConstrainedBox(
                              constraints: BoxConstraints(
                                maxHeight: constraints.maxHeight * 0.5,
                              ),
                              child: AspectRatio(
                                aspectRatio: 16 / 9,
                                child: thumbnail != null
                                    ? Image.network(
                                        thumbnail!,
                                        fit: BoxFit.fill,
                                        width: double.infinity,
                                        errorBuilder: (_, __, ___) => Container(
                                          color: Colors.grey[200],
                                          child: Icon(
                                            Icons.image_not_supported,
                                            color: Colors.grey[400],
                                            size: isTinyScreen ? 30 : 40,
                                          ),
                                        ),
                                      )
                                    : Container(
                                        color: Colors.grey[200],
                                        child: Icon(
                                          Icons.image,
                                          color: Colors.grey[400],
                                          size: isTinyScreen ? 30 : 40,
                                        ),
                                      ),
                              ),
                            ),
                          ),

                          /// ---------------- CONTENT SECTION ----------------
                          Flexible(
                            flex: 5,
                            child: Padding(
                              padding: EdgeInsets.all(contentPad),
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                crossAxisAlignment: CrossAxisAlignment.start,
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceBetween,
                                children: [
                                  /// Top content (title, description, note)
                                  Flexible(
                                    child: Column(
                                      mainAxisSize: MainAxisSize.min,
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        /// Title + Grade Row
                                        Row(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            Expanded(
                                              child: Text(
                                                title,
                                                style: TextStyle(
                                                  fontSize: titleSize,
                                                  fontWeight: FontWeight.bold,
                                                  color: Colors.black87,
                                                  height: 1.2,
                                                ),
                                                maxLines: isTinyScreen ? 1 : 2,
                                                overflow: TextOverflow.ellipsis,
                                              ),
                                            ),
                                            if (grade != null) ...[
                                              const SizedBox(width: 4),
                                              Container(
                                                padding: EdgeInsets.symmetric(
                                                  horizontal: isTinyScreen
                                                      ? 5
                                                      : (isSmallScreen ? 6 : 8),
                                                  vertical: 2,
                                                ),
                                                decoration: BoxDecoration(
                                                  color: primary.withOpacity(
                                                    0.15,
                                                  ),
                                                  borderRadius:
                                                      BorderRadius.circular(6),
                                                ),
                                                child: Text(
                                                  "$grade",
                                                  style: TextStyle(
                                                    fontSize: isTinyScreen
                                                        ? 9
                                                        : (isSmallScreen
                                                              ? 10
                                                              : 11),
                                                    color: primary,
                                                    fontWeight: FontWeight.bold,
                                                  ),
                                                ),
                                              ),
                                            ],
                                          ],
                                        ),

                                        SizedBox(
                                          height: isTinyScreen
                                              ? 3
                                              : (isSmallScreen ? 4 : 6),
                                        ),

                                        /// Description
                                        // QuillDescription.fromContent(
                                        //   description,
                                        //   maxLines: 1,
                                        //   textStyle: TextStyle(
                                        //     fontSize: descSize,
                                        //     color: Colors.black54,
                                        //     height: 1.3,
                                        //   ),
                                        // ),

                                        /// Note (if exists)
                                        if (note != null && !isTinyScreen) ...[
                                          SizedBox(
                                            height: isSmallScreen ? 6 : 8,
                                          ),
                                          note!,
                                        ],
                                      ],
                                    ),
                                  ),

                                  SizedBox(
                                    height: isTinyScreen
                                        ? 4
                                        : (isSmallScreen ? 6 : 8),
                                  ),

                                  /// Footer Row - Always visible
                                  Column(
                                    mainAxisSize: MainAxisSize.min,
                                    crossAxisAlignment:
                                        CrossAxisAlignment.stretch,
                                    children: [
                                      /// Info and Button Row
                                      Row(
                                        mainAxisAlignment:
                                            MainAxisAlignment.spaceBetween,
                                        crossAxisAlignment:
                                            CrossAxisAlignment.center,
                                        children: [
                                          /// Questions/Duration Info
                                          if (questionsNumber != null)
                                            Flexible(
                                              child: Row(
                                                mainAxisSize: MainAxisSize.min,
                                                children: [
                                                  Icon(
                                                    Icons.quiz_outlined,
                                                    size: isTinyScreen
                                                        ? 10
                                                        : 12,
                                                    color: Colors.black54,
                                                  ),
                                                  const SizedBox(width: 2),
                                                  Flexible(
                                                    child: Text(
                                                      "$questionsNumber أسئلة",
                                                      style: TextStyle(
                                                        fontSize: isTinyScreen
                                                            ? 8
                                                            : (isSmallScreen
                                                                  ? 9
                                                                  : 10),
                                                        color: Colors.black54,
                                                        fontWeight:
                                                            FontWeight.w500,
                                                      ),
                                                      overflow:
                                                          TextOverflow.ellipsis,
                                                    ),
                                                  ),
                                                ],
                                              ),
                                            )
                                          else if (examDuration != null)
                                            Flexible(
                                              child: Row(
                                                mainAxisSize: MainAxisSize.min,
                                                children: [
                                                  Icon(
                                                    Icons.access_time,
                                                    size: isTinyScreen
                                                        ? 10
                                                        : 12,
                                                    color: Colors.black54,
                                                  ),
                                                  const SizedBox(width: 2),
                                                  Flexible(
                                                    child: Text(
                                                      "$examDuration د",
                                                      style: TextStyle(
                                                        fontSize: isTinyScreen
                                                            ? 8
                                                            : (isSmallScreen
                                                                  ? 9
                                                                  : 10),
                                                        color: Colors.black54,
                                                        fontWeight:
                                                            FontWeight.w500,
                                                      ),
                                                      overflow:
                                                          TextOverflow.ellipsis,
                                                    ),
                                                  ),
                                                ],
                                              ),
                                            )
                                          else
                                            const SizedBox(width: 4),

                                          const SizedBox(width: 6),

                                          /// Action Button
                                          Flexible(
                                            child: Row(
                                              mainAxisAlignment:
                                                  MainAxisAlignment.end,
                                              children: [
                                                Material(
                                                  color: Colors.transparent,
                                                  child: InkWell(
                                                    onTap: () {
                                                      Get.to(
                                                        () => navPage,
                                                        transition: Transition
                                                            .leftToRightWithFade,
                                                        duration:
                                                            const Duration(
                                                              milliseconds: 450,
                                                            ),
                                                        preventDuplicates:
                                                            false,
                                                      );
                                                    },
                                                    borderRadius:
                                                        BorderRadius.circular(
                                                          8,
                                                        ),
                                                    child: Container(
                                                      padding:
                                                          EdgeInsets.symmetric(
                                                            horizontal:
                                                                buttonPadH,
                                                            vertical:
                                                                buttonPadV,
                                                          ),
                                                      decoration: BoxDecoration(
                                                        color: primary,
                                                        borderRadius:
                                                            BorderRadius.circular(
                                                              8,
                                                            ),
                                                        boxShadow: [
                                                          BoxShadow(
                                                            color: primary
                                                                .withOpacity(
                                                                  0.3,
                                                                ),
                                                            blurRadius: 4,
                                                            offset:
                                                                const Offset(
                                                                  0,
                                                                  2,
                                                                ),
                                                          ),
                                                        ],
                                                      ),
                                                      child: Text(
                                                        navlabel,
                                                        style: TextStyle(
                                                          fontSize:
                                                              buttonFontSize,
                                                          color: Colors.white,
                                                          fontWeight:
                                                              FontWeight.w600,
                                                        ),
                                                        textAlign:
                                                            TextAlign.center,
                                                        overflow: TextOverflow
                                                            .ellipsis,
                                                      ),
                                                    ),
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ),
                                        ],
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ],
                      );
                    },
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
