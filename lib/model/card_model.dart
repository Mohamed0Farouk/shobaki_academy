import 'dart:convert';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:shobaki_academy/model/pdf_model.dart';
import 'package:shobaki_academy/services/device_guard.dart';
import 'package:shobaki_academy/services/locale_db.dart';
import 'package:shobaki_academy/theme.dart';
import 'package:shobaki_academy/utils/constants.dart';
import 'package:shobaki_academy/utils/image_utils.dart';
import 'package:shobaki_academy/utils/responsive_utils.dart';
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
  final VoidCallback? onTap;

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
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    switch (type) {
      case CardTypes.topic:
        return _SimpleCard(
          title: title,
          thumbnail: thumbnail,
          navlabel: navLabel,
          note: note,
          navPage: nav,
          onTap: onTap,
        );
      case CardTypes.enrolledTopic:
        return _SimpleCard(
          title: title,
          thumbnail: thumbnail,
          navlabel: 'تصفح المحتوى',
          navPage: TopicPage(topicId: id),
          onTap: onTap,
        );
      case CardTypes.lecture:
        return _SimpleCard(
          title: title,
          thumbnail: thumbnail,
          navlabel: navLabel,
          navPage: nav,
          onTap: onTap,
        );
      case CardTypes.video:
        return _SimpleCard(
          title: title,
          thumbnail: thumbnail,
          note: note,
          navlabel: 'بدء المشاهدة',
          navPage: VideoPlayerView(videoUrl: url!),
          onTap: onTap,
        );
      case CardTypes.book:
        return _SimpleCard(
          title: title,
          thumbnail: thumbnail,
          navlabel: 'بدء القراءة',
          navPage: PdfModel(),
          onTap: onTap,
        );
      case CardTypes.homework:
        return _SimpleCard(
          title: title,
          thumbnail: thumbnail,
          navlabel: 'بدء الواجب',
          navPage: HomeworkPage(topicId: topicId!, id: id),
          questionsNumber: questionsNumber,
          grade: grade,
          onTap: onTap,
        );
      case CardTypes.exam:
        return _SimpleCard(
          title: title,
          thumbnail: thumbnail,
          navlabel: 'بدء الامتحان',
          navPage: ExamPage(id: id, topicId: topicId!),
          questionsNumber: questionsNumber,
          examDuration: examDuration,
          grade: grade,
          onTap: onTap,
        );
      case CardTypes.wrongQuestions:
        return _SimpleCard(
          title: title,
          thumbnail: thumbnail,
          navlabel: 'عرض الاخطاء',
          navPage: nav != null ? nav! : ResultsPage(),
          onTap: onTap,
        );
    }
  }
}

/// Apple-style card with overlaid title, metadata row, subtle action link
class _SimpleCard extends StatefulWidget {
  final String title;
  final String? thumbnail;
  final String? navlabel;
  final Widget? note;
  final Widget? navPage;
  final int? questionsNumber;
  final int? examDuration;
  final int? grade;
  final VoidCallback? onTap;

  const _SimpleCard({
    required this.title,
    required this.navlabel,
    required this.navPage,
    this.thumbnail,
    this.note,
    this.questionsNumber,
    this.examDuration,
    this.grade,
    this.onTap,
  });

  @override
  State<_SimpleCard> createState() => _SimpleCardState();
}

class _SimpleCardState extends State<_SimpleCard>
    with SingleTickerProviderStateMixin {
  late AnimationController _hoverController;
  late Animation<double> _scaleAnimation;
  late Animation<double> _shadowAnimation;

  @override
  void initState() {
    super.initState();
    _hoverController = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );
    _scaleAnimation = Tween<double>(begin: 1.0, end: 1.02).animate(
      CurvedAnimation(parent: _hoverController, curve: Curves.easeOutCubic),
    );
    _shadowAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _hoverController, curve: Curves.easeOutCubic),
    );
  }

  @override
  void dispose() {
    _hoverController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final primary = theme.colorScheme.primary;
    final screenWidth = MediaQuery.of(context).size.width;
    final isTiny = screenWidth < 280;
    final isSmall = screenWidth < 360;
    final radius = ResponsiveUtils.cardRadius(context);
    final maxWidth = ResponsiveUtils.cardMaxWidth(context);
    final isLocked = widget.navlabel == null;

    return Directionality(
      textDirection: TextDirection.rtl,
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: maxWidth),
        child: MouseRegion(
          cursor: SystemMouseCursors.click,
          onEnter: (_) => _hoverController.forward(),
          onExit: (_) => _hoverController.reverse(),
          child: GestureDetector(
            onTap: () {
              if (widget.onTap != null) {
                widget.onTap!();
              } else if (widget.navPage != null) {
                _navigate(context);
              }
            },
            child: AnimatedBuilder(
              animation: _hoverController,
              builder: (context, child) {
                final shadow = _shadowAnimation.value > 0.5
                    ? AppTheme.cardShadowLifted
                    : [AppTheme.cardShadow];
                return Transform.scale(
                  scale: _scaleAnimation.value,
                  child: Container(
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(radius),
                      boxShadow: shadow,
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(radius),
                      child: child,
                    ),
                  ),
                );
              },
              child: Stack(
                fit: StackFit.loose,
                children: [
                  Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      _buildImageArea(context, primary, radius, isTiny),
                      _buildMetadataRow(context, primary, isTiny, isSmall),
                      if (widget.navlabel != null)
                        _buildActionRow(context, primary),
                    ],
                  ),
                  if (isLocked) _buildLockedOverlay(context, radius),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildImageArea(
    BuildContext context,
    Color primary,
    double radius,
    bool isTiny,
  ) {
    return Stack(
      children: [
        AspectRatio(
          aspectRatio: AppConstants.cardAspectRatio,
          child: ImageUtils.networkWithFallback(
            widget.thumbnail,
            fit: BoxFit.cover,
            context: context,
            placeholder: _imagePlaceholder(isTiny),
          ),
        ),
        Positioned.fill(
          child: Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  Colors.transparent,
                  Colors.black.withValues(alpha: 0.6),
                ],
              ),
            ),
          ),
        ),
        Positioned(
          left: 12,
          right: 12,
          bottom: 10,
          child: Text(
            widget.title,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: isTiny ? 13 : 15,
              fontWeight: FontWeight.bold,
              color: Colors.white,
              height: 1.2,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildMetadataRow(
    BuildContext context,
    Color primary,
    bool isTiny,
    bool isSmall,
  ) {
    final hasGrade = widget.grade != null;
    final hasInfo =
        widget.questionsNumber != null || widget.examDuration != null;
    final hasNote = widget.note != null && !isTiny;

    if (!hasGrade && !hasInfo && !hasNote) {
      return const SizedBox.shrink();
    }

    return Padding(
      padding: EdgeInsets.fromLTRB(12, 10, 12, hasNote ? 4 : 8),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              if (hasGrade)
                Container(
                  padding: EdgeInsets.symmetric(
                    horizontal: isTiny ? 5 : (isSmall ? 6 : 8),
                    vertical: 2,
                  ),
                  decoration: BoxDecoration(
                    color: primary.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    '${widget.grade}',
                    style: TextStyle(
                      fontSize: isTiny ? 9 : (isSmall ? 10 : 11),
                      color: primary,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              if (hasGrade && hasInfo) const SizedBox(width: 8),
              if (hasInfo)
                Flexible(
                  child: widget.questionsNumber != null
                      ? _InfoChip(
                          icon: Icons.quiz_outlined,
                          label: '${widget.questionsNumber} أسئلة',
                          isTiny: isTiny,
                          isSmall: isSmall,
                        )
                      : _InfoChip(
                          icon: Icons.access_time,
                          label: '${widget.examDuration} د',
                          isTiny: isTiny,
                          isSmall: isSmall,
                        ),
                ),
            ],
          ),
          if (hasNote)
            Padding(
              padding: const EdgeInsets.only(top: 6),
              child: widget.note!,
            ),
        ],
      ),
    );
  }

  Widget _buildActionRow(BuildContext context, Color primary) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 4, 12, 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            widget.navlabel!,
            style: TextStyle(
              fontSize: 12,
              color: primary,
              fontWeight: FontWeight.w600,
            ),
          ),
          Icon(Icons.arrow_back_ios_new_rounded, color: primary, size: 11),
        ],
      ),
    );
  }

  Widget _buildLockedOverlay(BuildContext context, double radius) {
    return Positioned.fill(
      child: ClipRRect(
        borderRadius: BorderRadius.circular(radius),
        child: BackdropFilter(
          filter: ui.ImageFilter.blur(sigmaX: 0.75, sigmaY: 0.75),
          child: Center(
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.lock_outline, color: Colors.white70, size: 18),
                const SizedBox(width: 8),
                Text(
                  'غير متاح',
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.white,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _navigate(BuildContext context) async {
    final userData = _getUserData();
    final isGuestOrReviewer =
        userData != null &&
        (userData['email'] == 'guest@example.com' ||
            userData['email'] == 'appletestaccount#97111111111111@gmail.com');
    if (isGuestOrReviewer) {
      Get.to(
        () => widget.navPage!,
        transition: Transition.fade,
        preventDuplicates: false,
        duration: const Duration(milliseconds: 350),
      );
      return;
    }
    final DeviceGuardController guard = Get.find<DeviceGuardController>();
    final isAllowed = await guard.checkNow();
    if (isAllowed == false) return;
    Get.to(
      () => widget.navPage!,
      transition: Transition.leftToRightWithFade,
      preventDuplicates: false,
      duration: const Duration(milliseconds: 450),
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
        const SizedBox(width: 4),
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
