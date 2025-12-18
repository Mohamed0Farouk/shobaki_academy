import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:shobaki_academy/controller/enrolled_topics_controller.dart';
import 'package:shobaki_academy/services/statics.dart';
import 'package:shobaki_academy/theme.dart';

class EnrolledTopicsPage extends StatelessWidget {
  EnrolledTopicsPage({super.key, this.guest = false});

  final controller = Get.put(EnrolledTopicsController(), permanent: true);
  final bool guest;

  @override
  Widget build(BuildContext context) {
    controller.isGuest.value = guest;
    if (!guest) {
      controller.loadenrolledtopics();
    }

    return Scaffold(
      backgroundColor: const Color(0xfff7f7f7),
      body: SafeArea(
        child: Directionality(
          textDirection: TextDirection.rtl,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                /// -------------------------
                /// SEARCH BAR
                /// -------------------------
                Container(
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(28),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.08),
                        blurRadius: 10,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: TextField(
                    controller: controller.searchController,
                    textInputAction: TextInputAction.search,
                    onSubmitted: (q) =>
                        controller.onSearchSubmitted(q, context),
                    decoration: InputDecoration(
                      hintText: 'ابحث في اشتراكاتك',
                      hintStyle: const TextStyle(color: Colors.black45),
                      prefixIcon: const Icon(
                        Icons.search,
                        color: Colors.black54,
                      ),
                      border: InputBorder.none,
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 20,
                      ),
                    ),
                  ),
                ),

                const SizedBox(height: 20),

                /// -------------------------
                /// GRID: All Topics (Mixed)
                /// -------------------------
                Expanded(
                  child: Obx(() {
                    if (controller.isLoading.value) {
                      return Center(child: loading(context));
                    }

                    // Combine recommended and latest topics
                    final allTopics = [
                      ...controller.recommendations,
                      ...controller.latestenrolledtopics,
                    ];

                    if (allTopics.isEmpty) {
                      return Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.inbox_outlined,
                              size: 64,
                              color: Colors.grey[400],
                            ),
                            const SizedBox(height: 16),
                            Text(
                              'لم تشترك في أي مواضيع بعد',
                              style: Theme.of(context).textTheme.bodyLarge
                                  ?.copyWith(color: Colors.grey[600]),
                            ),
                          ],
                        ),
                      );
                    }

                    return GridView.builder(
                      physics: const BouncingScrollPhysics(),
                      gridDelegate:
                          const SliverGridDelegateWithFixedCrossAxisCount(
                            crossAxisCount: 2,
                            childAspectRatio: 0.85,
                            mainAxisSpacing: 14,
                            crossAxisSpacing: 12,
                          ),
                      itemBuilder: (_, i) {
                        final item = allTopics[i];
                        final title = item['title'] ?? '';
                        final imageUrl =
                            item['thumbnail'] ?? 'https://placehold.co/200/png';
                        final isRecommended =
                            item['topic']?['recommended'] == true;

                        return _topicGridCard(
                          context,
                          title,
                          imageUrl,
                          () => controller.onSelectenrolledtopic(item),
                          isRecommended: isRecommended,
                        );
                      },
                      itemCount: allTopics.length,
                    );
                  }),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  /// ===================================
  /// Grid Card for All Topics
  /// ===================================
  Widget _topicGridCard(
    BuildContext context,
    String title,
    String imageUrl,
    VoidCallback onTap, {
    bool isRecommended = false,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.only(
            topLeft: Radius.circular(16),
            bottomRight: Radius.circular(16),
          ),
          boxShadow: [
            BoxShadow(
              color: isRecommended
                  ? AppTheme.primaryColor.withOpacity(0.25)
                  : Colors.black.withOpacity(0.08),
              blurRadius: isRecommended ? 10 : 6,
              offset: const Offset(0, 3),
              spreadRadius: isRecommended ? 1 : 0,
            ),
          ],
          border: isRecommended
              ? Border.all(
                  color: AppTheme.primaryColor.withOpacity(0.3),
                  width: 1.5,
                )
              : null,
        ),
        child: Stack(
          fit: StackFit.expand,
          children: [
            Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Expanded(
                  child: Hero(
                    tag: '$title-image-grid-$isRecommended',
                    child: ClipRRect(
                      borderRadius: const BorderRadius.only(
                        topLeft: Radius.circular(16),
                      ),
                      child: AspectRatio(
                        aspectRatio: 1 / 1,
                        child: Image.network(
                          imageUrl,
                          fit: BoxFit.fill,
                          errorBuilder: (_, __, ___) => Container(
                            color: Colors.grey[300],
                            child: const Icon(Icons.image_not_supported),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.all(10),
                  child: Text(
                    title,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    textAlign: TextAlign.right,
                    style: Theme.of(context).textTheme.labelMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                      height: 1.3,
                    ),
                  ),
                ),
              ],
            ),
            if (isRecommended)
              Positioned(
                top: 8,
                right: 8,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: AppTheme.primaryColor,
                    borderRadius: BorderRadius.circular(12),
                    boxShadow: [
                      BoxShadow(
                        color: AppTheme.primaryColor.withOpacity(0.5),
                        blurRadius: 6,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.star, color: Colors.white, size: 12),
                      SizedBox(width: 2),
                      Text(
                        'مُرشّح',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
