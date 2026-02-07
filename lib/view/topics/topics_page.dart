import 'package:animate_do/animate_do.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:shobaki_academy/controller/topics_controller.dart';
import 'package:shobaki_academy/services/statics.dart';

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
    final size = MediaQuery.of(context).size;
    final isDesktop = size.width > 900;
    final crossAxisCount = isDesktop
        ? (size.width > 1600
              ? 6
              : size.width > 1200
              ? 5
              : 4)
        : 2;

    return Scaffold(
      backgroundColor: const Color(0xfff7f7f7),
      body: SafeArea(
        child: Directionality(
          textDirection: TextDirection.rtl,
          child: SingleChildScrollView(
            physics: const BouncingScrollPhysics(),
            child: Center(
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 420),
                curve: Curves.easeInOutCubic,
                width: isDesktop ? 1200 : double.infinity,
                padding: EdgeInsets.symmetric(
                  horizontal: isDesktop ? 18 : 8,
                  vertical: isDesktop ? 12 : 6,
                ),
                child: Column(
                  children: [
                    /// -------------------------
                    /// MODERN SEARCH BAR
                    /// -------------------------
                    _buildModernSearchBar(context),

                    SizedBox(height: isDesktop ? 8 : 32),

                    /// -------------------------
                    /// SECTION: Recommended
                    /// -------------------------
                    FadeInLeft(
                      duration: const Duration(milliseconds: 500),
                      delay: const Duration(milliseconds: 100),
                      child: _buildSectionHeader("نرشحها لك", Icons.star),
                    ),
                    SizedBox(height: isDesktop ? 16 : 14),

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

                      return isDesktop
                          ? FadeInUp(
                              duration: const Duration(milliseconds: 600),
                              delay: const Duration(milliseconds: 120),
                              child: _buildResponsiveGrid(recs, crossAxisCount),
                            )
                          : _buildHorizontalList(recs);
                    }),

                    SizedBox(height: isDesktop ? 16 : 14),

                    /// -------------------------
                    /// SECTION: Latest topics
                    /// -------------------------
                    FadeInLeft(
                      duration: const Duration(milliseconds: 500),
                      delay: const Duration(milliseconds: 200),
                      child: _buildSectionHeader(
                        "اخر المحتويات",
                        Icons.fire_truck,
                      ),
                    ),
                    SizedBox(height: isDesktop ? 16 : 14),

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

                      return isDesktop
                          ? FadeInUp(
                              duration: const Duration(milliseconds: 640),
                              delay: const Duration(milliseconds: 160),
                              child: _buildResponsiveGrid(
                                latest,
                                crossAxisCount,
                              ),
                            )
                          : _buildHorizontalList(latest);
                    }),

                    SizedBox(height: isDesktop ? 4 : 2),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  /// ===================================
  /// MODERN SEARCH BAR
  /// ===================================
  Widget _buildModernSearchBar(BuildContext context) {
    final size = MediaQuery.of(context).size;
    final isDesktop = size.width > 900;

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        boxShadow: [
          BoxShadow(
            color: Colors.blue.withOpacity(0.08),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: TextField(
        controller: controller.searchController,
        textInputAction: TextInputAction.search,
        onSubmitted: (q) => controller.onSearchSubmitted(q, context),
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
        //style: Theme.of(context).textTheme.bodyMedium,
      ),
    );
  }

  /// ===================================
  /// SECTION HEADER WITH ICON
  /// ===================================
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

  /// ===================================
  /// RESPONSIVE GRID LAYOUT (Desktop)
  /// ===================================
  Widget _buildResponsiveGrid(List<dynamic> items, int crossAxisCount) {
    final threshold = crossAxisCount * 2; // Threshold for rows before scrolling

    return Column(
      children: [
        GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: crossAxisCount,
            mainAxisSpacing: 12,
            crossAxisSpacing: 10,

            childAspectRatio: 0.9,
          ),
          itemCount: items.length,
          itemBuilder: (context, index) {
            return BounceInUp(
              from: 50,
              delay: Duration(milliseconds: 100 + (index * 50)),
              duration: const Duration(milliseconds: 600),
              child: _buildModernTopicCard(
                context,
                items[index]['title'] ?? '',
                items[index]['thumbnail'] ?? 'https://placehold.co/300/png',
                () => controller.onSelectTopic(items[index]),
                index,
              ),
            );
          },
        ),
        // if (items.length > threshold)
        //   SizedBox(
        //     height: 160, // Adjusted height for horizontal scrolling
        //     child: ListView.separated(
        //       scrollDirection: Axis.horizontal,
        //       physics: const BouncingScrollPhysics(),
        //       itemBuilder: (context, index) {
        //         final adjustedIndex = index + threshold;
        //         if (adjustedIndex >= items.length) return const SizedBox();
        //         return FadeInRight(
        //           delay: Duration(milliseconds: 100 + (adjustedIndex * 50)),
        //           duration: const Duration(milliseconds: 500),
        //           child: _buildModernTopicCard(
        //             context,
        //             items[adjustedIndex]['title'] ?? '',
        //             items[adjustedIndex]['thumbnail'] ??
        //                 'https://placehold.co/300/png',
        //             () => controller.onSelectTopic(items[adjustedIndex]),
        //             adjustedIndex,
        //           ),
        //         );
        //       },
        //       separatorBuilder: (_, __) => const SizedBox(width: 12),
        //       itemCount:
        //           items.length - threshold, // Only items beyond threshold
        //     ),
        //   ),
      ],
    );
  }

  /// ===================================
  /// HORIZONTAL LIST (Mobile)
  /// ===================================
  Widget _buildHorizontalList(List<dynamic> items) {
    //final size = MediaQuery.of(context).size;
    final cardWidth = _computeCardWidth(context);
    final listHeight = cardWidth + 80; // increased height for larger cards

    return SizedBox(
      height: listHeight,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        physics: const BouncingScrollPhysics(),
        padding: const EdgeInsets.symmetric(
          horizontal: 16,
        ), // Fixed padding from left
        itemBuilder: (context, index) {
          return FadeInRight(
            delay: Duration(milliseconds: 100 + (index * 50)),
            duration: const Duration(milliseconds: 500),
            child: _buildModernTopicCard(
              context,
              items[index]['title'] ?? '',
              items[index]['thumbnail'] ?? 'https://placehold.co/300/png',
              () => controller.onSelectTopic(items[index]),
              index,
            ),
          );
        },
        separatorBuilder: (_, __) => const SizedBox(width: 12),
        itemCount: items.length,
      ),
    );
  }

  /// ===================================
  /// MODERN TOPIC CARD
  /// ===================================
  Widget _buildModernTopicCard(
    BuildContext context,
    String title,
    String imageUrl,
    VoidCallback onTap,
    int index,
  ) {
    final cardWidth = _computeCardWidth(context);
    return GestureDetector(
      onTap: onTap,
      child: _HoverableCard(
        title: title,
        imageUrl: imageUrl,
        cardWidth: cardWidth,
        isDesktop: MediaQuery.of(context).size.width > 900,
        index: index,
      ),
    );
  }

  /// ===================================
  /// COMPUTE CARD WIDTH HELPER
  /// ===================================
  double _computeCardWidth(BuildContext context) {
    final size = MediaQuery.of(context).size;
    final isDesktop = size.width > 900;
    if (isDesktop) {
      // keep desktop sizing logic (same as before)
      final base = (size.width - 60) / (size.width > 1400 ? 4 : 3);
      return base * 0.66;
    } else {
      // larger card on mobile (≈46% of width)
      return size.width * 0.46;
    }
  }
}

/// ===================================
/// HOVERABLE CARD WITH LOCAL STATE
/// ===================================
class _HoverableCard extends StatefulWidget {
  const _HoverableCard({
    required this.title,
    required this.imageUrl,
    required this.cardWidth,
    required this.isDesktop,
    required this.index,
  });

  final String title;
  final String imageUrl;
  final double cardWidth;
  final bool isDesktop;
  final int index;

  @override
  State<_HoverableCard> createState() => _HoverableCardState();
}

class _HoverableCardState extends State<_HoverableCard>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scaleAnimation;
  late Animation<double> _shadowAnimation;
  late Animation<double> _rotateAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 350),
      vsync: this,
    );

    _scaleAnimation = Tween<double>(
      begin: 1.0,
      end: 1.06,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeOutCubic));

    _rotateAnimation = Tween<double>(
      begin: 0.0,
      end: 0.02,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeOutCubic));

    _shadowAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeOutCubic));
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      cursor: SystemMouseCursors.click,

      onEnter: (_) => _controller.forward(),
      onExit: (_) => _controller.reverse(),
      child: AnimatedBuilder(
        animation: _controller,
        builder: (context, child) {
          return Transform.rotate(
            angle: _rotateAnimation.value,
            child: Transform.scale(scale: _scaleAnimation.value, child: child),
          );
        },
        child: Container(
          width: widget.cardWidth,
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            boxShadow: [
              BoxShadow(
                color: Colors.blue.withOpacity(0.10),
                blurRadius: 12 + (_shadowAnimation.value * 6),
                offset: Offset(0, 6 + (_shadowAnimation.value * 3)),
              ),
              BoxShadow(
                color: Colors.black.withOpacity(0.04),
                blurRadius: 6,
                offset: const Offset(0, 1),
              ),
            ],
          ),
          child: Column(
            children: [
              /// ===== IMAGE SECTION =====
              Expanded(
                flex: 3,
                child: Container(
                  decoration: BoxDecoration(
                    borderRadius: const BorderRadius.vertical(
                      top: Radius.circular(12),
                    ),
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [
                        Colors.blue.withOpacity(0.08),
                        Colors.blue.withOpacity(0.04),
                      ],
                    ),
                  ),
                  child: ClipRRect(
                    borderRadius: const BorderRadius.vertical(
                      top: Radius.circular(12),
                    ),
                    child: Stack(
                      fit: StackFit.expand,
                      children: [
                        AspectRatio(
                          aspectRatio: 1 / 1,
                          child: Image.network(
                            widget.imageUrl,
                            fit: BoxFit.fill,
                            errorBuilder: (_, __, ___) => Container(
                              color: Colors.grey.shade200,
                              child: const Icon(
                                Icons.broken_image,
                                size: 32,
                                color: Colors.grey,
                              ),
                            ),
                          ),
                        ),

                        /// ===== OVERLAY GRADIENT =====
                        Positioned.fill(
                          child: Container(
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                begin: Alignment.topCenter,
                                end: Alignment.bottomCenter,
                                colors: [
                                  Colors.transparent,
                                  Colors.black.withOpacity(0.25),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),

              /// ===== CONTENT SECTION =====
              Expanded(
                flex: 1,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 6,
                  ),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: Text(
                          widget.title,
                          maxLines: 3,
                          overflow: TextOverflow.ellipsis,
                          style: Theme.of(context).textTheme.bodySmall
                              ?.copyWith(
                                fontWeight: FontWeight.w600,
                                color: Colors.black87,
                              ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              /// ===== FOOTER BUTTON =====
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  borderRadius: const BorderRadius.vertical(
                    bottom: Radius.circular(12),
                  ),
                  gradient: LinearGradient(
                    colors: [Colors.blue.shade50, Colors.blue.shade100],
                  ),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    Text(
                      "ابدأ الآن",
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                        color: Colors.blue.shade600,
                      ),
                    ),
                    SizedBox(width: 8),
                    Icon(
                      Icons.arrow_forward,
                      color: Colors.blue.shade600,
                      size: 14,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
