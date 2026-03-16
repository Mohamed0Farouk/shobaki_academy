import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:shobaki_academy/model/pdf_model.dart';
import 'package:shobaki_academy/services/device_guard.dart';
import 'package:shobaki_academy/services/locale_db.dart';
import 'package:shobaki_academy/view/enrolled_topics/topic_page.dart';
import 'package:shobaki_academy/view/results/results_page.dart';
import 'package:shobaki_academy/view/sub/exam_page.dart';
import 'package:shobaki_academy/view/sub/homework_page.dart';
import 'package:shobaki_academy/view/sub/vdo_video_player.dart';

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
  final String? navLabel;
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
    this.navLabel,
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
          navlabel: navLabel,
          note: note,
          navPage: nav,
        );
      case CardTypes.enrolledTopic:
        return _SimpleCard(
          title: title,
          description: description,
          thumbnail: thumbnail,
          navlabel: 'تصفح المحتوى',
          navPage: TopicPage(topicId: id),
        );
      case CardTypes.lecture:
        return _SimpleCard(
          title: title,
          description: description,
          thumbnail: thumbnail,
          navlabel: navLabel,
          navPage: nav,
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
  final String? navlabel;
  final Widget? note;
  final Widget? navPage;
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
    final screenWidth = MediaQuery.of(context).size.width;

    final isTiny = screenWidth < 280;
    final isSmall = screenWidth < 360;

    final titleSize = isTiny ? 12.0 : (isSmall ? 13.0 : 15.0);
    final buttonFontSize = 12.0;
    final buttonPadH = isTiny ? 8.0 : (isSmall ? 10.0 : 14.0);
    final buttonPadV = isTiny ? 4.0 : (isSmall ? 5.0 : 7.0);
    final contentPad = isTiny ? 6.0 : (isSmall ? 8.0 : 12.0);
    final imageHeight = isTiny ? 100.0 : (isSmall ? 120.0 : 150.0);
    final radius = isSmall ? 12.0 : 16.0;

    return Directionality(
      textDirection: TextDirection.rtl,
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxWidth: screenWidth > 600 ? 600.0 : double.infinity,
        ),
        child: Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(radius),
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
            borderRadius: BorderRadius.circular(radius),
            child: Material(
              color: Colors.white,
              child: InkWell(
                onTap: navPage != null
                    ? () async {
                        final userData = _getUserData();
                        if (userData!['email'] == 'guest@example.com' ||
                            userData['email'] ==
                                'appletestaccount#97111111111111@gmail.com') {
                          Get.to(
                            () => navPage!,
                            transition: Transition.fade,
                            preventDuplicates: false,
                            duration: const Duration(milliseconds: 350),
                          );
                        }
                        final DeviceGuardController guard =
                            Get.find<DeviceGuardController>();
                        final isAllowed = await guard.checkNow();
                        print('Is Allowed: $isAllowed');
                        if (isAllowed == false) return;
                        Get.to(
                          () => navPage!,
                          transition: Transition.fade,
                          preventDuplicates: false,
                          duration: const Duration(milliseconds: 350),
                        );
                      }
                    : null,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    /// ── IMAGE ──
                    SizedBox(
                      height: imageHeight,
                      width: double.infinity,
                      child: thumbnail != null
                          ? Image.network(
                              thumbnail!,
                              fit: BoxFit.fill,
                              errorBuilder: (_, __, ___) =>
                                  _imagePlaceholder(isTiny),
                            )
                          : _imagePlaceholder(isTiny),
                    ),

                    /// ── CONTENT ──
                    Padding(
                      padding: EdgeInsets.all(contentPad),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          /// Title + Grade
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Expanded(
                                child: Text(
                                  title,
                                  textAlign: TextAlign.center,
                                  style: TextStyle(
                                    fontSize: titleSize,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.black87,
                                    height: 1.2,
                                  ),
                                  maxLines: isTiny ? 1 : 2,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              if (grade != null) ...[
                                const SizedBox(width: 4),
                                Container(
                                  padding: EdgeInsets.symmetric(
                                    horizontal: isTiny ? 5 : (isSmall ? 6 : 8),
                                    vertical: 2,
                                  ),
                                  decoration: BoxDecoration(
                                    color: primary.withOpacity(0.15),
                                    borderRadius: BorderRadius.circular(6),
                                  ),
                                  child: Text(
                                    '$grade',
                                    style: TextStyle(
                                      fontSize: isTiny
                                          ? 9
                                          : (isSmall ? 10 : 11),
                                      color: primary,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                              ],
                            ],
                          ),

                          /// Note
                          if (note != null && !isTiny) ...[
                            SizedBox(height: isSmall ? 6 : 8),
                            note!,
                          ],

                          SizedBox(height: isTiny ? 4 : (isSmall ? 6 : 8)),

                          /// Footer: info + button
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            crossAxisAlignment: CrossAxisAlignment.center,
                            children: [
                              /// Info chip
                              if (questionsNumber != null)
                                _InfoChip(
                                  icon: Icons.quiz_outlined,
                                  label: '$questionsNumber أسئلة',
                                  isTiny: isTiny,
                                  isSmall: isSmall,
                                )
                              else if (examDuration != null)
                                _InfoChip(
                                  icon: Icons.access_time,
                                  label: '$examDuration د',
                                  isTiny: isTiny,
                                  isSmall: isSmall,
                                )
                              else
                                const SizedBox(width: 4),

                              /// Action button
                              if (navlabel != null)
                                InkWell(
                                  onTap: () async {
                                    final DeviceGuardController guard =
                                        Get.find<DeviceGuardController>();
                                    final isAllowed = await guard.checkNow();
                                    if (isAllowed == false) return;
                                    Get.to(
                                      () => navPage!,
                                      transition:
                                          Transition.leftToRightWithFade,
                                      duration: const Duration(
                                        milliseconds: 450,
                                      ),
                                      preventDuplicates: false,
                                    );
                                  },
                                  borderRadius: BorderRadius.circular(8),
                                  child: Container(
                                    padding: EdgeInsets.symmetric(
                                      horizontal: buttonPadH,
                                      vertical: buttonPadV,
                                    ),
                                    decoration: BoxDecoration(
                                      color: primary,
                                      borderRadius: BorderRadius.circular(8),
                                      boxShadow: [
                                        BoxShadow(
                                          color: primary.withOpacity(0.3),
                                          blurRadius: 4,
                                          offset: const Offset(0, 2),
                                        ),
                                      ],
                                    ),
                                    child: Text(
                                      navlabel!,
                                      style: TextStyle(
                                        fontSize: buttonFontSize,
                                        color: Colors.white,
                                        fontWeight: FontWeight.w600,
                                      ),
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                ),
                            ],
                          ),
                        ],
                      ),
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

  Map? _getUserData() {
    try {
      final services = Get.find<LocalDB>();
      final localDb = services.sharedPref;
      final jsonUserData = localDb?.getString('UserData');
      if (jsonUserData == null || jsonUserData.isEmpty) return null;
      final decoded = jsonDecode(jsonUserData);
      if (decoded is Map) return decoded;
      return null;
    } catch (_) {
      return null;
    }
  }

  Widget _imagePlaceholder(bool isTiny) => Container(
    color: Colors.grey[200],
    child: Icon(
      Icons.image_not_supported,
      color: Colors.grey[400],
      size: isTiny ? 30 : 40,
    ),
  );
}

/// Small reusable info chip (questions count / duration)
class _InfoChip extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool isTiny;
  final bool isSmall;

  const _InfoChip({
    required this.icon,
    required this.label,
    required this.isTiny,
    required this.isSmall,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: isTiny ? 10 : 12, color: Colors.black54),
        const SizedBox(width: 2),
        Text(
          label,
          style: TextStyle(
            fontSize: isTiny ? 8 : (isSmall ? 9 : 10),
            color: Colors.black54,
            fontWeight: FontWeight.w500,
          ),
          overflow: TextOverflow.ellipsis,
        ),
      ],
    );
  }
}
