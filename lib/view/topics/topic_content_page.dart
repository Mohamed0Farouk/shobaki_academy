import 'dart:convert';
import 'package:animate_do/animate_do.dart';
import 'package:intl/intl.dart' as intl;
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:shobaki_academy/controller/subscription_controller.dart';
import 'package:shobaki_academy/extentions.dart';
import 'package:shobaki_academy/model/card_model.dart';
import 'package:shobaki_academy/model/widgets/quill_description.dart';
import 'package:shobaki_academy/services/api.dart';
import 'package:shobaki_academy/services/locale_db.dart';
import 'package:shobaki_academy/services/statics.dart';
import 'package:shobaki_academy/view/auth/login_page.dart';
import 'package:shobaki_academy/view/enrolled_topics/topic_page.dart';
//import 'package:shobaki_academy/view/home.dart';

class TopicContentPage extends StatelessWidget {
  const TopicContentPage({
    super.key,
    required this.topicId,
    this.isGuest = false,
    this.inReview = false,
  });
  final String topicId;
  final bool isGuest;
  final bool inReview;

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

      final topics = await api.fetchWithConditions(
        'topics',
        filters: {'hidden': false, 'id': topicId},
      );

      if (topics.isEmpty) return _errorWidget(context);

      final Map topic = Map<String, dynamic>.from(topics[0] as Map);
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

    // Use a simple scrolling column with a header instead of SliverAppBar
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
                _detailsCard(context, topic, description, subs, user, api),
                const SizedBox(height: 20),
              ],
            ),
          ),
        ],
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

    // Replace sliver layout with a simple scrollable column + header
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
                  showChildrenHeader: true,
                ),
                const SizedBox(height: 12),
                Text(
                  'المحتويات الفرعية المتضمنة',
                  style: Theme.of(context).textTheme.headlineMedium,
                  textAlign: TextAlign.right,
                ),
                const SizedBox(height: 12),
                FutureBuilder<List<Widget>>(
                  future: _subTopicsHandler(
                    topic['children'],
                    topic['thumbnail'],
                  ),
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
                            'لا توجد مواضيع فرعية',
                            style: Theme.of(context).textTheme.bodyMedium,
                            textAlign: TextAlign.right,
                          ),
                        ),
                      );
                    }
                    return SizedBox(
                      height: context.screenH / 3,
                      width: double.infinity,
                      child: ListView.builder(
                        itemCount: childrenWidgets.length,
                        scrollDirection: Axis.horizontal,
                        itemBuilder: (ctx, i) {
                          return Directionality(
                            textDirection: TextDirection.rtl,
                            child: SizedBox(
                              height: context.screenH / 3.2,
                              width: context.screenW / 2,
                              child: childrenWidgets[i],
                            ),
                          );
                        },
                      ),
                    );
                  },
                ),
                const SizedBox(height: 24),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // Replace SliverAppBar with a simple header widget
  Widget _buildHeader(BuildContext context, String title, String? thumb) {
    final theme = Theme.of(context);
    final hasThumb = thumb != null && thumb.trim().isNotEmpty;

    return Material(
      elevation: 4,
      color: theme.colorScheme.primary,
      child: SizedBox(
        height: 240,
        width: double.infinity,
        child: LayoutBuilder(
          builder: (context, constraints) {
            final isWide = constraints.maxWidth >= 700;

            /// ===============================
            /// WIDE SCREENS (Tablet / Desktop)
            /// ===============================
            if (isWide) {
              return Padding(
                padding: const EdgeInsets.all(15),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    // LEFT: Square image
                    Expanded(
                      child: Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: [
                              theme.colorScheme.primary,
                              theme.colorScheme.primary.withOpacity(0.85),
                            ],
                            begin: Alignment.centerLeft,
                            end: Alignment.centerRight,
                          ),
                        ),
                        child: Align(
                          alignment: Alignment.bottomRight,
                          child: Text(
                            title,
                            textAlign: TextAlign.right,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: theme.textTheme.headlineSmall?.copyWith(
                              color: theme.colorScheme.onPrimary,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ),
                    ),

                    // RIGHT: Title area
                    AspectRatio(
                      aspectRatio: 1 / 1,
                      child: hasThumb
                          ? Image.network(
                              thumb,
                              fit: BoxFit.fill,
                              errorBuilder: (_, __, ___) =>
                                  _headerPlaceholder(context),
                            )
                          : _headerPlaceholder(context),
                    ),
                  ],
                ),
              );
            }

            /// ===============================
            /// SMALL SCREENS (Mobile)
            /// ===============================
            return Stack(
              fit: StackFit.expand,
              children: [
                if (hasThumb)
                  Image.network(
                    thumb,
                    fit: BoxFit.fill,
                    errorBuilder: (_, __, ___) => _headerPlaceholder(context),
                  )
                else
                  _headerPlaceholder(context),

                // Gradient overlay
                Container(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        theme.colorScheme.primary.withOpacity(0.75),
                        theme.colorScheme.primary.withOpacity(0.45),
                        Colors.transparent,
                      ],
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                    ),
                  ),
                ),

                // Title
                Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 16,
                  ),
                  child: Align(
                    alignment: Alignment.bottomRight,
                    child: Text(
                      title,
                      textAlign: TextAlign.right,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.headlineSmall?.copyWith(
                        color: theme.colorScheme.onPrimary,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
              ],
            );
          },
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
    final createdAt = topic['created_at'];
    final stage = (topic['stage'] ?? '-').toString();
    final price = topic['price'];
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(14),
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
                  maxLines: 4,
                ),
              ),
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 12,
              runSpacing: 8,
              alignment: WrapAlignment.end,
              children: [
                _infoChip(
                  context,
                  Icons.menu_book,
                  'المحاضرات: $lecturesCount',
                ),
                _infoChip(
                  context,
                  Icons.calendar_today,
                  'تاريخ: ${_formatDate(createdAt)}',
                ),
                _infoChip(context, Icons.tag, 'المرحلة: $stage'),
                // Hide price in review mode
                // if (!inReview)
                //   _infoChip(
                //     context,
                //     Icons.price_check,
                //     'السعر: ${_formatPrice(price)}',
                //   ),
              ],
            ),
            const SizedBox(height: 16),
            Center(child: _actionButton(context, topic, subs, user, api)),
            if (showChildrenHeader) const SizedBox(height: 20),
            if (showChildrenHeader)
              Text(
                'المحتويات الفرعية',
                style: Theme.of(context).textTheme.titleLarge,
                textAlign: TextAlign.right,
              ),
          ],
        ),
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
          color: Theme.of(context).colorScheme.onPrimary.withOpacity(0.9),
        ),
      ),
    );
  }

  Widget _infoChip(BuildContext context, IconData icon, String text) {
    return Chip(
      backgroundColor: Theme.of(context).colorScheme.surface,
      avatar: Icon(
        icon,
        size: 18,
        color: Theme.of(context).colorScheme.primary,
      ),
      label: Text(
        text,
        style: Theme.of(context).textTheme.bodySmall,
        textAlign: TextAlign.right,
      ),
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
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

    String label = !isSubscribed
        ? 'انضم الى المحتوى'
        : 'تم الانضمام — افتح المحتوى';
    label = topic['free'] == true ? 'افتح المحتوى' : label;

    return ElevatedButton.icon(
      icon: Icon(
        isSubscribed ? Icons.play_circle_fill : Icons.add_circle_outline,
        color: Colors.white,
      ),
      label: Text(
        label,
        style: Theme.of(
          context,
        ).textTheme.bodyLarge?.copyWith(color: Colors.white),
      ),
      style: ElevatedButton.styleFrom(
        backgroundColor: Theme.of(context).colorScheme.primary,
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
      onPressed: () => _handleSubscription(context, topic, subs, user, api),
    );
  }

  /// Guest placeholder when trying to access paid content
  Widget _guestPlaceholder(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.orange.withOpacity(0.1),
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
                'هذا المحتوى مدفوع',
                style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                  color: Colors.orange,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            'سجل دخولك للاشتراك في هذا المحتوى',
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

  String _formatDate(dynamic date) {
    try {
      return intl.DateFormat(
        'yyyy/MM/dd',
      ).format(DateTime.parse(date.toString()));
    } catch (_) {
      return '-';
    }
  }

  String _formatPrice(dynamic price) {
    try {
      final p = (price ?? 0) as num;
      // original code stored price in cents, but safe fallback to raw if small
      return p > 100 ? '${(p / 100).toString()} AED' : '${p.toString()} AED';
    } catch (_) {
      return '0 AED';
    }
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
  ) async {
    final topics = <Map>[];
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
            child: CardModel(
              type: CardTypes.topic,
              thumbnail: thumbnail,
              title: topic['title'] ?? '',
              description: topic['description'] ?? '',
              id: topic['id'] ?? '',
              nav: TopicContentPage(
                topicId: topicId,
                isGuest: isGuest,
                inReview: inReview,
              ),
            ),
          ),
        )
        .toList();
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
    // await api
    // .insertData('students_subscriptions', {
    //   "student_id": userId,
    //   "topic_id": id,
    // })
    // .then((_) {
    //   // Get.snackbar(
    //   //   'اشعار',
    //   //   'تم الانضمام في $name',
    //   //   backgroundColor: Colors.greenAccent,
    //   //   snackPosition: SnackPosition.BOTTOM,
    //   // );
    //   //Get.offAllNamed('/home');

    // })
    // .onError((err, _) {
    //   Get.snackbar(
    //     'توجد مشكلة',
    //     err.toString(),
    //     backgroundColor: Colors.red,
    //     snackPosition: SnackPosition.BOTTOM,
    //   );
    //   Get.offAll(
    //     () => HomePage(),
    //     transition: Transition.upToDown,
    //     duration: const Duration(milliseconds: 600),
    //   );
    // });
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
}
