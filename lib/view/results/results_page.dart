import 'package:animate_do/animate_do.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:shobaki_academy/controller/results_controller.dart';
import 'package:shobaki_academy/model/card_model.dart';
import 'package:shobaki_academy/services/statics.dart';
import 'package:shobaki_academy/utils/responsive_utils.dart';

class ResultsPage extends StatelessWidget {
  const ResultsPage({super.key});

  @override
  Widget build(BuildContext context) {
    final controller = Get.put(ResultsController());

    WidgetsBinding.instance.addPostFrameCallback((_) {
      controller.loadResults();
    });

    final size = MediaQuery.of(context).size;
    final isPhone = ResponsiveUtils.isPhone(context);

    final content = Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
          child: _buildSearchBar(context, controller),
        ),
        const SizedBox(height: 20),
        _buildExamSection(context, controller, size),
        const SizedBox(height: 26),
        _buildHomeworkSection(context, controller, size),
        const SizedBox(height: 16),
      ],
    );

    Widget body;
    if (isPhone) {
      body = SafeArea(
        child: SingleChildScrollView(
          child: content,
        ),
      );
    } else {
      body = Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 1000),
          child: Column(
            children: [
              Expanded(
                child: SingleChildScrollView(
                  child: content,
                ),
              ),
            ],
          ),
        ),
      );
    }

    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: Theme.of(context).scaffoldBackgroundColor,
        body: body,
      ),
    );
  }

  Widget _buildSearchBar(BuildContext context, ResultsController controller) {
    return TextField(
      controller: controller.searchController,
      onSubmitted: (q) => controller.onSearchSubmitted(q, context),
      textAlign: TextAlign.right,
      decoration: InputDecoration(
        filled: true,
        fillColor: Colors.white,
        hintText: "ابحث عن اختبار أو واجب...",
        hintStyle: const TextStyle(color: Colors.black45),
        prefixIcon: const Icon(Icons.search, color: Colors.black54),
        contentPadding: const EdgeInsets.symmetric(vertical: 14),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide.none,
        ),
      ),
    );
  }

  Widget _buildExamSection(BuildContext context, ResultsController controller, Size size) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        children: [
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
              return _buildHorizontalList(exams, (item) {
                return CardModel(
                  type: CardTypes.exam,
                  title: item['exam']["title"] ?? "",
                  description: '',
                  thumbnail: item["thumbnail"],
                  id: item['id']?.toString() ?? '',
                  onTap: () => controller.onSelectTopic(item),
                );
              }, size);
            }),
          ),
        ],
      ),
    );
  }

  Widget _buildHomeworkSection(BuildContext context, ResultsController controller, Size size) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        children: [
          _sectionHeader("الواجبات"),
          const SizedBox(height: 10),
          SizedBox(
            height: size.height / 3.2,
            child: Obx(() {
              if (controller.isLoading.value) {
                return Center(child: loading(context));
              }
              final homeworks = controller.homeworks;
              if (homeworks.isEmpty) {
                return const Center(
                  child: Text("لا توجد واجبات"),
                );
              }
              return _buildHorizontalList(homeworks, (item) {
                return CardModel(
                  type: CardTypes.homework,
                  title: item["homework"]['title'] ?? "",
                  description: '',
                  thumbnail: item["thumbnail"],
                  id: item['id']?.toString() ?? '',
                  onTap: () => controller.onSelectTopic(item),
                );
              }, size);
            }),
          ),
        ],
      ),
    );
  }

  Widget _buildHorizontalList(List items, Widget Function(dynamic) itemBuilder, Size size) {
    return ListView.separated(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.all(8),
      itemCount: items.length,
      separatorBuilder: (_, __) => const SizedBox(width: 12),
      itemBuilder: (_, i) {
        final item = items[i];
        return FadeInUp(
          from: 50,
          delay: Duration(milliseconds: 50 * i),
          duration: const Duration(milliseconds: 500),
          child: SizedBox(
            width: size.width * 0.5,
            child: itemBuilder(item),
          ),
        );
      },
    );
  }

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
}
