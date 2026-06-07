import 'dart:math';
import 'package:animate_do/animate_do.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:shobaki_academy/controller/topics_controller.dart';
import 'package:shobaki_academy/model/card_model.dart';
import 'package:shobaki_academy/services/statics.dart';
import 'package:shobaki_academy/utils/constants.dart';
import 'package:shobaki_academy/utils/responsive_utils.dart';

class TopicsPage extends StatefulWidget {
  const TopicsPage({super.key, this.guest = false, this.inReview = false});

  final bool guest;
  final bool inReview;

  @override
  State<TopicsPage> createState() => _TopicsPageState();
}

class _TopicsPageState extends State<TopicsPage> {
  late final controller = Get.put(TopicsController(), permanent: true);

  @override
  void initState() {
    super.initState();
    controller.isGuest.value = widget.guest;
    controller.loadTopics();
  }

  @override
  Widget build(BuildContext context) {
    final device = ResponsiveUtils.getDeviceType(context);
    final isPhone = device == DeviceType.phone;
    final isTablet = device == DeviceType.tablet;
    final hPad = isPhone ? 8.0 : (isTablet ? 24.0 : 18.0);

    final bodyContent = Directionality(
      textDirection: TextDirection.rtl,
      child: isPhone
          ? _buildPhoneLayout(hPad)
          : _buildDesktopLayout(hPad, isTablet),
    );

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      body: bodyContent,
    );
  }

  Widget _buildPhoneLayout(double hPad) {
    return SafeArea(
      child: SingleChildScrollView(
        physics: const BouncingScrollPhysics(),
        padding: EdgeInsets.symmetric(horizontal: hPad, vertical: 6),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.start,
          children: _buildContentSections(),
        ),
      ),
    );
  }

  Widget _buildDesktopLayout(double hPad, bool isTablet) {
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: AppConstants.contentMaxWidth),
        child: Column(
          children: [
            Padding(
              padding: EdgeInsets.fromLTRB(hPad, 12, hPad, 0),
              child: _buildModernSearchBar(context),
            ),
            Expanded(
              child: SingleChildScrollView(
                physics: const BouncingScrollPhysics(),
                padding: EdgeInsets.symmetric(horizontal: hPad, vertical: 12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.start,
                  children: _buildContentSections(),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  List<Widget> _buildContentSections() {
    return [
      SizedBox(height: 8),
      FadeInLeft(
        duration: const Duration(milliseconds: 500),
        delay: const Duration(milliseconds: 100),
        child: _buildSectionHeader("نرشحها لك", Icons.star),
      ),
      const SizedBox(height: 14),
      Obx(() {
        final recs = controller.recommendations;
        if (controller.isLoading.value) {
          return Center(child: loading(context));
        }
        if (recs.isEmpty) {
          return FadeIn(
            child: const Center(child: Text("لا توجد ترشيحات")),
          );
        }
        return FadeInUp(
          duration: const Duration(milliseconds: 600),
          delay: const Duration(milliseconds: 120),
          child: _buildResponsiveGrid(recs, 0),
        );
      }),
      const SizedBox(height: 14),
      FadeInLeft(
        duration: const Duration(milliseconds: 500),
        delay: const Duration(milliseconds: 200),
        child: _buildSectionHeader(
          "اخر المحتويات",
          Icons.fire_truck,
        ),
      ),
      const SizedBox(height: 14),
      Obx(() {
        final latest = controller.latestTopics;
        if (controller.isLoading.value) {
          return Center(child: loading(context));
        }
        if (latest.isEmpty) {
          return FadeIn(
            child: const Center(child: Text("لا توجد مواضيع")),
          );
        }
        return FadeInUp(
          duration: const Duration(milliseconds: 640),
          delay: const Duration(milliseconds: 160),
          child: _buildResponsiveGrid(latest, 0),
        );
      }),
      const SizedBox(height: 4),
    ];
  }

  Widget _buildModernSearchBar(BuildContext context) {
    final size = MediaQuery.of(context).size;
    final isDesktop = size.width > 900;

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        boxShadow: [
          BoxShadow(
            color: Colors.blue.withValues(alpha: 0.08),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: TextField(
        controller: controller.searchController,
        textInputAction: TextInputAction.search,
        onSubmitted: (q) =>
            controller.onSearchSubmitted(q, context, widget.inReview),
        decoration: InputDecoration(
          hintText: 'ابحث عن محتوى',
          hintStyle: const TextStyle(color: Colors.black45),
          prefixIcon: const Icon(Icons.search, color: Colors.black54),
          border: InputBorder.none,
          contentPadding: EdgeInsets.symmetric(
            horizontal: isDesktop ? 14 : 10,
            vertical: isDesktop ? 8 : 6,
          ),
        ),
      ),
    );
  }

  Widget _buildSectionHeader(String title, IconData icon) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [Colors.blue.shade400, Colors.blue.shade600],
            ),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(icon, color: Colors.white, size: 20),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: Colors.black87,
                ),
              ),
              Container(
                height: 3,
                width: 40,
                margin: const EdgeInsets.only(top: 4),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [Colors.blue.shade300, Colors.blue.shade600],
                  ),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  int _gridColumns(double availableWidth) {
    return ResponsiveUtils.gridColumnsFromTargetWidth(availableWidth, targetCardWidth: 300, maxColumns: 4);
  }

  Widget _buildResponsiveGrid(List<dynamic> items, int crossAxisCount) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth;
        final cols = _gridColumns(width);
        final gap = 10.0;
        final childWidth = (width - (cols - 1) * gap) / cols;
        final cardWidth = min(childWidth, ResponsiveUtils.cardMaxWidth(context));
        return Wrap(
          spacing: gap,
          runSpacing: 12,
          children: items.asMap().entries.map((entry) {
            final index = entry.key;
            final item = entry.value;
            return BounceInUp(
              from: 50,
              delay: Duration(milliseconds: 100 + (index * 50)),
              duration: const Duration(milliseconds: 600),
              child: SizedBox(
                width: cardWidth,
                child: CardModel(
                  type: CardTypes.topic,
                  title: item['title'] ?? '',
                  description: '',
                  thumbnail: item['thumbnail'],
                  id: '',
                  navLabel: 'ابدأ الآن',
                  onTap: () => controller.onSelectTopic(item, widget.inReview),
                ),
              ),
            );
          }).toList(),
        );
      },
    );
  }
}
