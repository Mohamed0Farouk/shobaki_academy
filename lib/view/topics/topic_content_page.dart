import 'dart:convert';
import 'package:animate_do/animate_do.dart';
import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:get/get.dart';
import 'package:http/http.dart' as http;
import 'package:shobaki_academy/controller/subscription_controller.dart';
import 'package:shobaki_academy/model/card_model.dart';
import 'package:shobaki_academy/model/widgets/quill_description.dart';
import 'package:shobaki_academy/services/api.dart';
import 'package:shobaki_academy/services/locale_db.dart';
import 'package:shobaki_academy/services/statics.dart';
import 'package:shobaki_academy/utils/image_utils.dart';
import 'package:shobaki_academy/view/auth/login_page.dart';
import 'package:shobaki_academy/view/enrolled_topics/topic_page.dart';
import 'package:shobaki_academy/view/sub/vdo_video_player.dart';

// ignore: must_be_immutable
class TopicContentPage extends StatelessWidget {
  TopicContentPage({
    super.key,
    required this.topicId,
    this.isGuest = false,
    this.inReview = false,
  });
  final String topicId;
  final bool isGuest;
  final bool inReview;
  bool isSubscribed = false;

  Map? topicData;

  @override
  Widget build(BuildContext context) {
    // Force RTL for Arabic pages
    return Scaffold(
      resizeToAvoidBottomInset: false,
      appBar: AppBar(
        title: const Text('تفاصيل المحتوى'),
        elevation: 0,
        centerTitle: true,
      ),
      //extendBodyBehindAppBar: true,
      body: Directionality(
        textDirection: TextDirection.rtl,
        child: SafeArea(
          child: FutureBuilder<Widget>(
            future: _topicDataFetcher(context),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.done) {
                return snapshot.data ?? _errorWidget(context);
              }
              return loading(context);
            },
          ),
        ),
      ),
    );
  }

  Future<Widget> _topicDataFetcher(BuildContext context) async {
    final api = ApiClient();
    final userData = _getUserData();

    try {
      final topicSubscription = await api.fetchWithConditions(
        'students_subscriptions',
        filters: {"student_id": userData!["id"], 'topic_id': topicId},
      );

      isSubscribed = topicSubscription.isNotEmpty;

      final topics = await api.fetchWithConditions(
        'topics',
        filters: {'hidden': false, 'id': topicId},
      );

      if (topics.isEmpty) return _errorWidget(context);

      final Map topic = Map<String, dynamic>.from(topics[0] as Map);
      topicData = topic;
      final bool isParent = (topic['is_parent'] == true);

      if (isParent) {
        return _parentTopicDetails(
          context,
          topic,
          topicSubscription,
          userData,
          api,
        );
      } else {
        return _topicDetails(context, topic, topicSubscription, userData, api);
      }
    } catch (e) {
      return Center(child: Text('خطأ: $e', textAlign: TextAlign.center));
    }
  }

  Widget _topicDetails(
    BuildContext context,
    Map topic,
    List subs,
    Map user,
    ApiClient api,
  ) {
    final String title = (topic['title'] ?? '').toString();
    final String? thumb = topic['thumbnail'];
    final String description = (topic['description'] ?? '').toString();

    return _buildContentLayout(
      context: context,
      title: title,
      thumb: thumb,
      description: description,
      topic: topic,
      subs: subs,
      user: user,
      api: api,
      sectionTitle: 'المحاضرات المتضمنة',
      emptyMessage: 'لا توجد محاضرات',
      futureBuilder: _lecturesHandler(
        topic['lectures'],
        topic['thumbnail'],
        context,
      ),
    );
  }

  Widget _parentTopicDetails(
    BuildContext context,
    Map topic,
    List subs,
    Map user,
    ApiClient api,
  ) {
    final String title = (topic['title'] ?? '').toString();
    final String? thumb = topic['thumbnail'];
    final String description = (topic['description'] ?? '').toString();

    return _buildContentLayout(
      context: context,
      title: title,
      thumb: thumb,
      description: description,
      topic: topic,
      subs: subs,
      user: user,
      api: api,
      sectionTitle: 'المحتويات الفرعية المتضمنة',
      emptyMessage: 'لا توجد مواضيع فرعية',
      futureBuilder: _subTopicsHandler(
        topic['children'],
        topic['thumbnail'],
        context,
      ),
      showChildrenHeader: true,
    );
  }

  Widget _buildContentLayout({
    required BuildContext context,
    required String title,
    required String? thumb,
    required String description,
    required Map topic,
    required List subs,
    required Map user,
    required ApiClient api,
    required String sectionTitle,
    required String emptyMessage,
    required Future<List<Widget>> futureBuilder,
    bool showChildrenHeader = false,
  }) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final isWide = constraints.maxWidth >= 800;

        if (isWide) {
          final rowWidth = constraints.maxWidth - 32;
          final leftWidth = (rowWidth - 16) * 2 / 5;
          final aspectRatioHeight = leftWidth * 3 / 4;
          final headerHeight = aspectRatioHeight.clamp(200, 360).toDouble();

          return SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  flex: 2,
                  child: Column(
                    children: [
                      _buildHeader(context, title, thumb, height: headerHeight),
                      const SizedBox(height: 16),
                      _detailsCard(
                        context,
                        topic,
                        description,
                        subs,
                        user,
                        api,
                        showChildrenHeader: showChildrenHeader,
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  flex: 3,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        sectionTitle,
                        style: Theme.of(context).textTheme.headlineMedium,
                        textAlign: TextAlign.right,
                      ),
                      const SizedBox(height: 12),
                      FutureBuilder<List<Widget>>(
                        future: futureBuilder,
                        builder: (context, snapshot) {
                          final childrenWidgets = snapshot.data ?? [];
                          if (snapshot.connectionState !=
                              ConnectionState.done) {
                            return loading(context);
                          }
                          if (childrenWidgets.isEmpty) {
                            return Padding(
                              padding: const EdgeInsets.all(20),
                              child: Center(
                                child: Text(
                                  emptyMessage,
                                  style: Theme.of(context).textTheme.bodyMedium,
                                  textAlign: TextAlign.right,
                                ),
                              ),
                            );
                          }
                          return LayoutBuilder(
                            builder: (context, constraints) {
                              final width = constraints.maxWidth;
                              final crossAxisCount = width < 500
                                  ? 2
                                  : width < 1000
                                  ? 3
                                  : 4;
                              const spacing = 12.0;
                              final itemWidth =
                                  (width - spacing * (crossAxisCount - 1)) /
                                  crossAxisCount;

                              return Wrap(
                                spacing: spacing,
                                runSpacing: spacing,
                                children: childrenWidgets
                                    .map(
                                      (child) => SizedBox(
                                        width: itemWidth,
                                        child: child,
                                      ),
                                    )
                                    .toList(),
                              );
                            },
                          );
                        },
                      ),
                    ],
                  ),
                ),
              ],
            ),
          );
        }

        return SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _buildHeader(context, title, thumb),
              const SizedBox(height: 12),
              Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  children: [
                    _detailsCard(
                      context,
                      topic,
                      description,
                      subs,
                      user,
                      api,
                      showChildrenHeader: showChildrenHeader,
                    ),
                    const SizedBox(height: 20),
                    Text(
                      sectionTitle,
                      style: Theme.of(context).textTheme.headlineMedium,
                      textAlign: TextAlign.right,
                    ),
                    const SizedBox(height: 12),
                    FutureBuilder<List<Widget>>(
                      future: futureBuilder,
                      builder: (context, snapshot) {
                        final childrenWidgets = snapshot.data ?? [];
                        if (snapshot.connectionState != ConnectionState.done) {
                          return loading(context);
                        }
                        if (childrenWidgets.isEmpty) {
                          return Padding(
                            padding: const EdgeInsets.all(20),
                            child: Center(
                              child: Text(
                                emptyMessage,
                                style: Theme.of(context).textTheme.bodyMedium,
                                textAlign: TextAlign.right,
                              ),
                            ),
                          );
                        }
                        return LayoutBuilder(
                          builder: (context, constraints) {
                            final width = constraints.maxWidth;
                            final crossAxisCount = width < 500
                                ? 2
                                : width < 1000
                                ? 3
                                : 4;
                            const spacing = 12.0;
                            final itemWidth =
                                (width - spacing * (crossAxisCount - 1)) /
                                crossAxisCount;

                            return Wrap(
                              spacing: spacing,
                              runSpacing: spacing,
                              children: childrenWidgets
                                  .map(
                                    (child) => SizedBox(
                                      width: itemWidth,
                                      child: child,
                                    ),
                                  )
                                  .toList(),
                            );
                          },
                        );
                      },
                    ),
                    const SizedBox(height: 16),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildHeader(
    BuildContext context,
    String title,
    String? thumb, {
    double height = 240,
  }) {
    final theme = Theme.of(context);

    return ClipRRect(
      borderRadius: BorderRadius.circular(16),
      child: SizedBox(
        height: height,
        width: double.infinity,
        child: Stack(
          fit: StackFit.expand,
          children: [
            ImageUtils.networkWithFallback(
              thumb,
              fit: BoxFit.fill,
              context: context,
              placeholder: _headerPlaceholder(context),
            ),
            Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    Colors.black.withValues(alpha: 0.1),
                    Colors.black.withValues(alpha: 0.6),
                  ],
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(20),
              child: Align(
                alignment: Alignment.bottomRight,
                child: Text(
                  title,
                  textAlign: TextAlign.right,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.headlineSmall?.copyWith(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _detailsCard(
    BuildContext context,
    Map topic,
    String description,
    List subs,
    Map user,
    ApiClient api, {
    bool showChildrenHeader = false,
  }) {
    final lecturesCount = (topic['lectures'] is List)
        ? (topic['lectures'] as List).length
        : 0;

    final childrenCount = (topic['children'] is List)
        ? (topic['children'] as List).length
        : 0;

    final stage = (topic['stage'] ?? '').toString();
    final hasStage = stage.isNotEmpty && stage != '-';
    final price = topic['price'];
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.06),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Directionality(
            textDirection: TextDirection.rtl,
            child: Align(
              alignment: Alignment.centerRight,
              child: QuillDescription.fromContent(
                description,
                scrollController: ScrollController(),
                enableScroll: false,
                padding: EdgeInsets.zero,
                textStyle: Theme.of(context).textTheme.bodyMedium,
                maxLines: 15,
              ),
            ),
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 12,
            runSpacing: 8,
            alignment: WrapAlignment.start,
            children: [
              childrenCount != 0
                  ? _infoChip(
                      context,
                      Icons.folder,
                      'المحتويات الفرعية: $childrenCount',
                    )
                  : _infoChip(
                      context,
                      Icons.menu_book,
                      'المحاضرات: $lecturesCount',
                    ),
              if (hasStage) _infoChip(context, Icons.tag, 'المرحلة: $stage'),
              if (!inReview && price > 0)
                _infoChip(context, Icons.price_check, 'السعر: $price AED'),
            ],
          ),
          const SizedBox(height: 16),
          Center(child: _actionButton(context, topic, subs, user, api)),
        ],
      ),
    );
  }

  Widget _headerPlaceholder(BuildContext context) {
    return Container(
      color: Theme.of(context).colorScheme.primary,
      child: Center(
        child: Icon(
          Icons.auto_stories,
          size: 120,
          color: Theme.of(context).colorScheme.onPrimary.withValues(alpha: 0.9),
        ),
      ),
    );
  }

  Widget _infoChip(BuildContext context, IconData icon, String text) {
    final primary = Theme.of(context).colorScheme.primary;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: primary.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: primary),
          const SizedBox(width: 6),
          Text(
            text,
            style: TextStyle(
              fontSize: 12,
              color: primary,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  Widget _actionButton(
    BuildContext context,
    Map topic,
    List subs,
    Map user,
    ApiClient api,
  ) {
    final isSubscribed = subs.isNotEmpty;
    final isFree = topic['free'] == true;

    // Show guest placeholder if in guest mode and topic is not free
    if (isGuest && !isFree) {
      return _guestPlaceholder(context);
    }

    // In review mode: show browse button that navigates directly
    if (inReview) {
      return ElevatedButton.icon(
        icon: const Icon(Icons.visibility, color: Colors.white),
        label: Text(
          'تصفح',
          style: Theme.of(
            context,
          ).textTheme.bodyLarge?.copyWith(color: Colors.white),
        ),
        style: ElevatedButton.styleFrom(
          backgroundColor: Theme.of(context).colorScheme.primary,
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
        onPressed: () {
          Get.to(
            () => TopicPage(topicId: topicId),
            transition: Transition.downToUp,
            duration: const Duration(milliseconds: 600),
          );
        },
      );
    }

    String label = !isSubscribed ? ' ادخل الكود للاشتراك' : 'تم الاشتراك ';
    label = topic['free'] == true ? 'المحتوى متاح' : label;

    return isSubscribed
        ? ElevatedButton.icon(
            icon: Icon(
              isSubscribed ? Icons.play_circle_fill : Icons.add_circle_outline,
              color: Colors.white,
            ),
            label: Text(
              label,
              textAlign: TextAlign.center,
              style: Theme.of(
                context,
              ).textTheme.bodyLarge?.copyWith(color: Colors.white),
            ),
            style: ElevatedButton.styleFrom(
              disabledBackgroundColor: Theme.of(context).colorScheme.primary,
              backgroundColor: Theme.of(context).colorScheme.primary,
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),

            onPressed: null,
          )
        : topic['free'] == true
        ? ElevatedButton.icon(
            icon: Icon(Icons.play_circle_fill, color: Colors.white),
            label: Text(
              label,
              textAlign: TextAlign.center,
              style: Theme.of(
                context,
              ).textTheme.bodyLarge?.copyWith(color: Colors.white),
            ),
            style: ElevatedButton.styleFrom(
              disabledBackgroundColor: Theme.of(context).colorScheme.primary,
              backgroundColor: Theme.of(context).colorScheme.primary,
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            onPressed: null,
          )
        : ElevatedButton.icon(
            icon: Icon(
              isSubscribed ? Icons.play_circle_fill : Icons.add_circle_outline,
              color: Colors.white,
            ),
            label: Text(
              label,
              textAlign: TextAlign.center,
              style: Theme.of(
                context,
              ).textTheme.bodyLarge?.copyWith(color: Colors.white),
            ),
            style: ElevatedButton.styleFrom(
              backgroundColor: Theme.of(context).colorScheme.primary,
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            onPressed: () =>
                _handleSubscription(context, topic, subs, user, api),
          );
  }

  void showGuestAnnotationDialog({required BuildContext context}) {
    Get.dialog(
      AlertDialog(
        title: const Text('ميزة مخصصة للمستخدمين', textAlign: TextAlign.center),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.lock_outline, size: 48, color: Colors.orange[700]),
            const SizedBox(height: 16),
            const Text(
              'عذراً، لا يمكنك الوصول إلى المحتوى كمستخدم ضيف. الرجاء تسجيل الدخول بحسابك الخاص.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 14, height: 1.5),
            ),
          ],
        ),
        actions: [
          ElevatedButton(
            onPressed: () => Get.back(),
            child: const Text('فهمت'),
          ),
        ],
      ),
      barrierDismissible: true,
      transitionDuration: const Duration(milliseconds: 300),
    );
  }

  void showSubscripeAnnotationDialog({required BuildContext context}) {
    Get.dialog(
      AlertDialog(
        title: const Text('محتوى مخصص للمشتركين', textAlign: TextAlign.center),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.lock_outline, size: 48, color: Colors.orange[700]),
            const SizedBox(height: 16),
            const Text(
              'عذراً، لا يمكنك الوصول إلى المحتوى كمستخدم غير مشترك. الرجاء الاشتراك للوصول للمحتوى.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 14, height: 1.5),
            ),
          ],
        ),
        actions: [
          ElevatedButton(
            onPressed: () => Get.back(),
            child: const Text('فهمت'),
          ),
        ],
      ),
      barrierDismissible: true,
      transitionDuration: const Duration(milliseconds: 300),
    );
  }

  /// Guest placeholder when trying to access paid content
  Widget _guestPlaceholder(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.orange.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.orange, width: 1.5),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.lock_outline, color: Colors.orange, size: 20),
              const SizedBox(width: 8),
              Text(
                'محتوى غير متاح للضيوف',
                style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                  color: Colors.orange,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            'سجل دخولك لعرض هذا المحتوى',
            style: Theme.of(
              context,
            ).textTheme.bodySmall?.copyWith(color: Colors.orange.shade700),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 12),
          ElevatedButton(
            onPressed: () {
              Get.offAll(
                () => LoginPage(),
                transition: Transition.upToDown,
                duration: const Duration(milliseconds: 600),
              );
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.orange,
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            child: Text(
              'تسجيل الدخول',
              style: Theme.of(
                context,
              ).textTheme.bodyLarge?.copyWith(color: Colors.white),
            ),
          ),
        ],
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

  Future<List<Widget>> _subTopicsHandler(
    List? children,
    String? thumbnail,
    context,
  ) async {
    final topics = <Map>[];
    final userData = _getUserData();
    if (children == null) return [];
    for (var id in children) {
      try {
        final res = await ApiClient().fetchWithConditions(
          'topics',
          filters: {'id': id},
        );
        if (res.isNotEmpty) {
          topics.add(Map<String, dynamic>.from(res[0] as Map));
        }
      } catch (_) {
        // ignore failed fetch for a child
      }
    }

    return topics
        .map(
          (topic) => FadeInUp(
            from: 100,
            duration: const Duration(milliseconds: 600),
            child:
                isSubscribed ||
                    topicData!['free'] == true ||
                    userData!['email'] ==
                        'appletestaccount#97111111111111@gmail.com'
                ? CardModel(
                    type: CardTypes.topic,
                    thumbnail: topic["thumbnail"],
                    title: topic['title'] ?? '',
                    description: topic['description'] ?? '',
                    note: Text(
                      'عدد المحاضرات: ${(topic['lectures'] as List?)?.length ?? 0}',
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                    id: topic['id'] ?? '',
                    navLabel: 'عرض المحتوى',
                    nav: TopicPage(topicId: topic['id'] ?? ''),
                  )
                : InkWell(
                    onTap: () {
                      if (isGuest) {
                        showGuestAnnotationDialog(context: context);
                      } else {
                        showSubscripeAnnotationDialog(context: context);
                      }
                    },
                    child: CardModel(
                      type: CardTypes.topic,
                      thumbnail: topic["thumbnail"],
                      title: topic['title'] ?? '',
                      description: topic['description'] ?? '',
                      note: Text(
                        'عدد المحاضرات: ${(topic['lectures'] as List?)?.length ?? 0}',
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                      id: topic['id'] ?? '',
                      navLabel: null,
                      nav: null,
                    ),
                  ),
          ),
        )
        .toList();
  }

  Future<List<Widget>> _lecturesHandler(
    List? lectures,
    String? thumbnail,
    context,
  ) async {
    final lecturesData = <Map>[];
    final userData = _getUserData();
    final widgets = <Widget>[];

    if (lectures == null) return [];
    for (var id in lectures) {
      try {
        final res = await ApiClient().fetchWithConditions(
          'lectures',
          filters: {'id': id},
        );
        if (res.isNotEmpty) {
          lecturesData.add(Map<String, dynamic>.from(res[0] as Map));
        }
      } catch (_) {
        // ignore failed fetch for a child
      }
    }

    for (var lecture in lecturesData) {
      final videoInfo = (lecture['videos'] as Map).values.first;
      final videoUrl = videoInfo['url'];
      final maxViewCount = videoInfo['max_view_count'] ?? 0;

      final isAccessible =
          isSubscribed ||
          topicData!['free'] == true ||
          userData!['email'] == 'appletestaccount#97111111111111@gmail.com';

      final cardWidget = CardModel(
        thumbnail: lecture["thumbnail"],
        title: lecture['title'] ?? '',
        description: lecture['description'] ?? '',
        id: lecture['id'] ?? '',
        type: CardTypes.lecture,
        navLabel: isAccessible ? 'بدء المشاهدة' : null,
        nav: null,
        onTap: isAccessible
            ? () async {
                final userViews = await _getUserVideoViewCount(
                  videoUrl,
                  userData!['id'],
                );
                final isLimited = await _isVideoViewLimitReached(
                  videoUrl,
                  maxViewCount,
                  userViews,
                  userData['id'],
                );

                if (isLimited) {
                  _showViewLimitDialog(context);
                } else {
                  Get.to(
                    () => VideoPlayerView(videoUrl: videoUrl),
                    transition: Transition.downToUp,
                    duration: const Duration(milliseconds: 600),
                  );
                }
              }
            : null,
      );

      Widget card = FadeInUp(
        from: 100,
        duration: const Duration(milliseconds: 600),
        child: isAccessible
            ? cardWidget
            : InkWell(
                onTap: () {
                  if (isGuest) {
                    showGuestAnnotationDialog(context: context);
                  } else {
                    showSubscripeAnnotationDialog(context: context);
                  }
                },
                child: cardWidget,
              ),
      );

      widgets.add(card);
    }
    return widgets;
  }

  void _addCodeToSubscribe(
    List codes,
    String name,
    ApiClient api,
    String id,
    String userId,
    int amount,
    BuildContext ctx,
  ) {
    showSubscriptionDialog(
      topicCodes: codes,
      topicName: name,
      amount: amount,
      api: api,
      topicId: id,
      userId: userId,
      context: ctx,
    );
  }

  void _directSubscribe(
    String name,
    ApiClient api,
    String id,
    String userId,
  ) async {
    Get.to(
      () => TopicPage(topicId: topicId),
      transition: Transition.downToUp,
      duration: const Duration(milliseconds: 600),
    );
  }

  void _handleSubscription(
    BuildContext context,
    Map topic,
    List subs,
    Map user,
    ApiClient api,
  ) {
    if (subs.isEmpty) {
      if (topic['free'] == false) {
        _addCodeToSubscribe(
          topic['codes'] ?? [],
          topic['title'] ?? '',
          api,
          topic['id'] ?? '',
          user['id'] ?? '',
          topic['price'] ?? 0,
          context,
        );
      } else {
        _directSubscribe(
          topic['title'] ?? '',
          api,
          topic['id'] ?? '',
          user['id'] ?? '',
        );
      }
    } else {
      Get.to(
        () => TopicPage(topicId: topicId),
        transition: Transition.downToUp,
        duration: const Duration(milliseconds: 600),
      );
    }
  }

  Widget _errorWidget(BuildContext context) => Center(
    child: Text('توجد مشكلة', style: Theme.of(context).textTheme.headlineLarge),
  );

  Future<int> _getUserVideoViewCount(String videoUrl, String userId) async {
    try {
      final apiBaseUrl = dotenv.env['ALSHOBAKI_API'];

      if (apiBaseUrl == null || apiBaseUrl.isEmpty) {
        projectLogger.e('ALSHOBAKI_API not found in .env');
        return 0;
      }

      final uri = Uri.parse(
        '${apiBaseUrl}api/videos/view-count',
      ).replace(queryParameters: {'videoUrl': videoUrl, 'userId': userId});

      final response = await http
          .get(
            uri,
            headers: {
              'Content-Type': 'application/json',
              // Add authorization header if needed
              // 'Authorization': 'Bearer $token',
            },
          )
          .timeout(
            const Duration(seconds: 10),
            onTimeout: () {
              throw Exception('Request timeout');
            },
          );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final viewCount = data['data']['viewCount'] as int;

        return viewCount;
      } else {
        projectLogger.e(
          'Error fetching video view count: ${response.statusCode} - ${response.body}',
        );
        return 0;
      }
    } catch (e) {
      projectLogger.e('Error fetching video view count: $e');
      return 0;
    }
  }

  /// Check if video view limit is reached
  Future<bool> _isVideoViewLimitReached(
    String videoUrl,
    int maxViewCount,
    int userViewCount,
    String userId,
  ) async {
    if (maxViewCount <= 0) return false; // No limit set

    return userViewCount >= maxViewCount;
  }

  Widget buildLockedOverlay(String message, context) {
    return Card(
      shadowColor: Colors.black.withValues(alpha: 0.12),
      elevation: 4,
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
      color: Colors.black.withValues(alpha: 0.5),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            message,
            textAlign: TextAlign.center,
            maxLines: 3,
            overflow: TextOverflow.ellipsis,
            style: Theme.of(
              context,
            ).textTheme.bodyLarge!.copyWith(color: Colors.white),
          ),
          const Icon(Icons.lock_rounded, color: Colors.white),
        ],
      ),
    );
  }

  void _showViewLimitDialog(BuildContext context) {
    Get.dialog(
      AlertDialog(
        title: const Text('تم الوصول للحد الأقصى', textAlign: TextAlign.center),
        content: const Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.lock_outline, size: 48, color: Colors.orange),
            SizedBox(height: 16),
            Text(
              'تم الوصول للحد الأقصى من المشاهدات لهذا الفيديو، يرجى التواصل مع الدعم الفني',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 14, height: 1.5),
            ),
          ],
        ),
        actions: [
          ElevatedButton(
            onPressed: () => Get.back(),
            child: const Text('فهمت'),
          ),
        ],
      ),
      barrierDismissible: true,
      transitionDuration: const Duration(milliseconds: 300),
    );
  }
}
