import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:shobaki_academy/controller/topics_controller.dart';
import 'package:shobaki_academy/services/statics.dart';

class TopicsPage extends StatelessWidget {
  TopicsPage({super.key, this.guest = false, this.inReview = false});

  final controller = Get.put(TopicsController(), permanent: true);
  final bool guest;
  final bool inReview;

  @override
  Widget build(BuildContext context) {
    controller.isGuest.value = guest;
    controller.loadTopics();

    final size = MediaQuery.of(context).size;

    return Scaffold(
      backgroundColor: const Color(0xfff7f7f7),
      body: SafeArea(
        child: Directionality(
          textDirection: TextDirection.rtl,
          child: SingleChildScrollView(
            physics: const BouncingScrollPhysics(),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  /// -------------------------
                  /// SEARCH BAR (Improved UI)
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
                        hintText: 'ابحث عن موضوع',
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

                  const SizedBox(height: 24),

                  /// -------------------------
                  /// SECTION: Recommended
                  /// -------------------------
                  _sectionHeader("نرشحها لك"),
                  const SizedBox(height: 12),

                  SizedBox(
                    height: size.height / 3.2,
                    child: Obx(() {
                      final recs = controller.recommendations;

                      if (controller.isLoading.value) {
                        return Center(child: loading(context));
                      }
                      if (recs.isEmpty) {
                        return const Center(child: Text("لا توجد ترشيحات"));
                      }

                      return ListView.separated(
                        scrollDirection: Axis.horizontal,
                        physics: const BouncingScrollPhysics(),
                        itemBuilder: (_, i) {
                          final item = recs[i];
                          final title = item['title'] ?? '';
                          final imageUrl =
                              item['thumbnail'] ??
                              'https://placehold.co/200/png';

                          return _topicCardWithData(
                            context,
                            title,
                            imageUrl,
                            () => controller.onSelectTopic(item),
                          );
                        },
                        separatorBuilder: (_, __) => const SizedBox(width: 14),
                        itemCount: recs.length,
                      );
                    }),
                  ),

                  const SizedBox(height: 28),

                  /// -------------------------
                  /// SECTION: Latest topics
                  /// -------------------------
                  _sectionHeader("اخر المواضيع"),
                  const SizedBox(height: 12),

                  SizedBox(
                    height: size.height / 3.2,
                    child: Obx(() {
                      final latest = controller.latestTopics;

                      if (controller.isLoading.value) {
                        return Center(child: loading(context));
                      }
                      if (latest.isEmpty) {
                        return const Center(child: Text("لا توجد مواضيع"));
                      }

                      return ListView.separated(
                        scrollDirection: Axis.horizontal,
                        physics: const BouncingScrollPhysics(),
                        itemBuilder: (_, i) {
                          final item = latest[i];
                          final title = item['title'] ?? '';
                          final imageUrl =
                              item['thumbnail'] ??
                              'https://placehold.co/200/png';

                          return _topicCardWithData(
                            context,
                            title,
                            imageUrl,
                            () => controller.onSelectTopic(item),
                          );
                        },
                        separatorBuilder: (_, __) => const SizedBox(width: 14),
                        itemCount: latest.length,
                      );
                    }),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  // ===================================
  // BEAUTIFUL SECTION HEADER
  // ===================================
  Widget _sectionHeader(String title) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.only(right: 8),
          decoration: const BoxDecoration(
            border: Border(right: BorderSide(color: Colors.blue, width: 4)),
          ),
          child: Text(
            title,
            style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
          ),
        ),
      ],
    );
  }

  /// --------------------------------------
  /// Improved Topic Card UI (keep your old)
  /// --------------------------------------
  Widget _topicCardWithData(
    BuildContext context,
    String title,
    String imageUrl,
    VoidCallback onTap,
  ) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(8),
        width: MediaQuery.of(context).size.width / 2,
        height: MediaQuery.of(context).size.height / 3.2,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: const BorderRadius.only(
            topRight: Radius.circular(24),
            bottomLeft: Radius.circular(24),
          ),
          boxShadow: const [
            BoxShadow(
              color: Colors.black12,
              blurRadius: 8,
              offset: Offset(0, 4),
            ),
          ],
        ),
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Hero(
                tag: '$title-image',
                child: AspectRatio(
                  aspectRatio: 1 / 1,
                  child: Image.network(
                    imageUrl,
                    fit: BoxFit.fill,
                    width: double.infinity,
                    errorBuilder: (_, __, ___) => Image.network(
                      'https://placehold.co/200/png',
                      fit: BoxFit.fill,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              Center(
                child: Text(
                  title,
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
