// ignore_for_file: invalid_use_of_protected_member

import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:animate_do/animate_do.dart';
import 'package:shobaki_academy/controller/enrolled_topics_controller.dart';
import 'package:shobaki_academy/model/card_model.dart';
import 'package:shobaki_academy/services/statics.dart';
import 'package:shobaki_academy/theme.dart';
import 'package:shobaki_academy/utils/responsive_utils.dart';

class EnrolledTopicsPage extends StatefulWidget {
  const EnrolledTopicsPage({super.key, this.guest = false});

  final bool guest;

  @override
  State<EnrolledTopicsPage> createState() => _EnrolledTopicsPageState();
}

class _EnrolledTopicsPageState extends State<EnrolledTopicsPage> {
  final controller = Get.put(EnrolledTopicsController(), permanent: true);

  @override
  void initState() {
    controller.loadenrolledtopics();
    super.initState();
  }

  @override
  Widget build(BuildContext context) {
    final device = ResponsiveUtils.getDeviceType(context);
    final isPhone = device == DeviceType.phone;
    final isTablet = device == DeviceType.tablet;
    final hPad = isPhone ? 14.0 : (isTablet ? 24.0 : 20.0);

    final content = Directionality(
      textDirection: TextDirection.rtl,
      child: Padding(
        padding: EdgeInsets.symmetric(horizontal: hPad, vertical: isPhone ? 12 : 0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: EdgeInsets.only(top: isPhone ? 0 : 12),
              child: _buildSearchBar(),
            ),
            const SizedBox(height: 20),
            Expanded(
              child: Obx(() {
                if (controller.isLoading.value) {
                  return Center(child: loading(context));
                }
                final allTopics = [
                  ...controller.recommendations.value,
                  ...controller.latestenrolledtopics.value,
                ];
                if (allTopics.isEmpty) {
                  return _buildEmptyState(context);
                }
                return _buildTopicsGrid(context, allTopics);
              }),
            ),
          ],
        ),
      ),
    );

    return Scaffold(
      backgroundColor: const Color(0xfff7f7f7),
      body: isPhone ? SafeArea(child: content) : content,
    );
  }

  Widget _buildSearchBar() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.08),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: TextField(
        controller: controller.searchController,
        textInputAction: TextInputAction.search,
        onSubmitted: (q) => controller.onSearchSubmitted(q, context),
        decoration: InputDecoration(
          hintText: 'ابحث في اشتراكاتك',
          hintStyle: const TextStyle(color: Colors.black45),
          prefixIcon: const Icon(Icons.search, color: Colors.black54),
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(horizontal: 20),
        ),
      ),
    );
  }

  Widget _buildEmptyState(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.inbox_outlined, size: 64, color: Colors.grey[400]),
          const SizedBox(height: 16),
          Text(
            'لم تشترك في أي مواضيع بعد',
            style: Theme.of(context)
                .textTheme
                .bodyLarge
                ?.copyWith(color: Colors.grey[600]),
          ),
        ],
      ),
    );
  }

  Widget _buildTopicsGrid(BuildContext context, List allTopics) {
    return Directionality(
      textDirection: TextDirection.ltr,
      child: LayoutBuilder(
        builder: (ctx, constraints) {
          final aw = constraints.maxWidth;
          final ah = constraints.maxHeight;
          final cols = aw < 470
              ? 1
              : aw < 700
                  ? 2
                  : ah < 700
                      ? 2
                      : aw < 1000
                          ? 3
                          : 4;
          final gap = ResponsiveUtils.cardGridGap(context);
          return GridView.builder(
            physics: const BouncingScrollPhysics(),
            gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: cols,
              childAspectRatio: 0.95,
              mainAxisSpacing: gap,
              crossAxisSpacing: gap,
            ),
            itemCount: allTopics.length,
            itemBuilder: (_, i) {
              final item = allTopics[i];
              final isRecommended = item['topic']?['recommended'] == true;
              return _buildTopicCard(item, isRecommended, i);
            },
          );
        },
      ),
    );
  }

  Widget _buildTopicCard(dynamic item, bool isRecommended, int index) {
    return FadeInUp(
      from: 50,
      delay: Duration(milliseconds: 50 + (index * 80)),
      duration: const Duration(milliseconds: 600),
      child: Stack(
        children: [
          CardModel(
            type: CardTypes.enrolledTopic,
            title: item['title'] ?? '',
            description: '',
            thumbnail: item['thumbnail'],
            id: item['id']?.toString() ?? '',
            onTap: () => controller.onSelectenrolledtopic(item),
          ),
          if (isRecommended)
            Positioned(
              top: 6,
              right: 6,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: AppTheme.primaryColor,
                  borderRadius: BorderRadius.circular(8),
                  boxShadow: [
                    BoxShadow(
                      color: AppTheme.primaryColor.withValues(alpha: 0.4),
                      blurRadius: 4,
                      offset: const Offset(0, 1),
                    ),
                  ],
                ),
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.star, color: Colors.white, size: 10),
                    SizedBox(width: 2),
                    Text(
                      'مُرشّح',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 8,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }
}
