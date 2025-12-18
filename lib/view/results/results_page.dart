import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:shobaki_academy/controller/results_controller.dart';
import 'package:shobaki_academy/services/statics.dart';

class ResultsPage extends StatelessWidget {
  const ResultsPage({super.key});

  @override
  Widget build(BuildContext context) {
    final controller = Get.put(ResultsController());

    WidgetsBinding.instance.addPostFrameCallback((_) {
      controller.loadResults();
    });

    final size = MediaQuery.of(context).size;

    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: Colors.grey.shade100,
        body: SafeArea(
          child: Column(
            children: [
              const SizedBox(height: 10),

              // NICE SEARCH BAR (RTL + MODERN)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: TextField(
                  controller: controller.searchController,
                  onSubmitted: (q) => controller.onSearchSubmitted(q, context),
                  textAlign: TextAlign.right,
                  decoration: InputDecoration(
                    filled: true,
                    fillColor: Colors.white,
                    hintText: "ابحث عن اختبار أو واجب...",
                    hintStyle: const TextStyle(color: Colors.black45),

                    prefixIcon: const Icon(Icons.search, color: Colors.black54),

                    // Rounded beautiful border
                    contentPadding: const EdgeInsets.symmetric(vertical: 14),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(16),
                      borderSide: BorderSide.none,
                    ),

                    // Shadow
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(16),
                      borderSide: BorderSide.none,
                    ),
                  ),
                ),
              ),

              const SizedBox(height: 20),

              Expanded(
                child: SingleChildScrollView(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: Column(
                      children: [
                        // ==========================
                        // EXAMS SECTION
                        // ==========================
                        _sectionHeader("الاختبارات"),
                        const SizedBox(height: 10),

                        SizedBox(
                          height: size.height / 3.2,
                          child: Obx(() {
                            if (controller.isLoading.value) {
                              return Center(child: loading(context));
                            }

                            final exams = controller.exams;
                            if (exams.isEmpty) {
                              return const Center(
                                child: Text("لا توجد اختبارات"),
                              );
                            }

                            return ListView.separated(
                              scrollDirection: Axis.horizontal,
                              padding: const EdgeInsets.all(8),
                              itemCount: exams.length,
                              separatorBuilder: (_, __) =>
                                  const SizedBox(width: 12),
                              itemBuilder: (_, i) {
                                final item = exams[i];
                                return _topicCardWithData(
                                  context,
                                  item['exam']["title"] ?? "",
                                  item["thumbnail"] ??
                                      "https://placehold.co/200/png",
                                  () => controller.onSelectTopic(item),
                                );
                              },
                            );
                          }),
                        ),

                        const SizedBox(height: 26),

                        // ==========================
                        // HOMEWORKS SECTION
                        // ==========================
                        _sectionHeader("الواجبات"),
                        const SizedBox(height: 10),

                        SizedBox(
                          height: size.height / 3.2,
                          child: Obx(() {
                            if (controller.isLoading.value) {
                              return Center(child: loading(context));
                            }

                            final latest = controller.homeworks;
                            if (latest.isEmpty) {
                              return const Center(
                                child: Text("لا توجد واجبات"),
                              );
                            }

                            return ListView.separated(
                              scrollDirection: Axis.horizontal,
                              padding: const EdgeInsets.all(8),
                              itemCount: latest.length,
                              separatorBuilder: (_, __) =>
                                  const SizedBox(width: 12),
                              itemBuilder: (_, i) {
                                final item = latest[i];
                                print(item);

                                return _topicCardWithData(
                                  context,
                                  item["homework"]['title'] ?? "",
                                  item["thumbnail"] ??
                                      "https://placehold.co/200/png",
                                  () => controller.onSelectTopic(item),
                                );
                              },
                            );
                          }),
                        ),

                        const SizedBox(height: 16),
                      ],
                    ),
                  ),
                ),
              ),
            ],
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

  Widget _topicCardWithData(
    BuildContext context,
    String title,
    String imageUrl,
    VoidCallback onTap,
  ) {
    print(title);

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
              AspectRatio(
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
              const SizedBox(height: 12),
              Center(
                child: Text(
                  title,
                  style: Theme.of(
                    context,
                  ).textTheme.bodyMedium?.copyWith(color: Colors.black87),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
