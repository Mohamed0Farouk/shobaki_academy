// ignore_for_file: invalid_use_of_protected_member

import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:animate_do/animate_do.dart';
import 'package:shobaki_academy/controller/enrolled_topics_controller.dart';
import 'package:shobaki_academy/services/statics.dart';
import 'package:shobaki_academy/theme.dart';

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
    final size = MediaQuery.of(context).size;
    final isDesktop = size.width > 900;
    final crossAxisCount = isDesktop
        ? (size.width > 1600
              ? 5
              : size.width > 1200
              ? 4
              : 4)
        : 2;

    return Scaffold(
      backgroundColor: const Color(0xfff7f7f7),
      body: SafeArea(
        child: Directionality(
          textDirection: TextDirection.rtl,
          child: Padding(
            padding: EdgeInsets.symmetric(
              horizontal: isDesktop ? 20 : 14,
              vertical: isDesktop ? 12 : 12,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                /// -------------------------
                /// SEARCH BAR
                /// -------------------------
                Container(
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(14),
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
                      ...controller.recommendations.value,
                      ...controller.latestenrolledtopics.value,
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

                    return Directionality(
                      textDirection: TextDirection.ltr,
                      child: GridView.builder(
                        physics: const BouncingScrollPhysics(),
                        gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: crossAxisCount,
                          // taller cards on mobile, compact on desktop
                          childAspectRatio: 0.9,
                          mainAxisSpacing: 12,
                          crossAxisSpacing: 10,
                        ),
                        itemBuilder: (_, i) {
                          final item = allTopics[i];
                          final title = item['title'] ?? '';
                          final imageUrl =
                              item['thumbnail'] ??
                              'https://placehold.co/200/png';
                          final isRecommended =
                              item['topic']?['recommended'] == true;

                          return FadeInUp(
                            from: 50,
                            delay: Duration(milliseconds: 50 + (i * 80)),
                            duration: const Duration(milliseconds: 600),
                            child: _topicGridCard(
                              context,
                              title,
                              imageUrl,
                              () => controller.onSelectenrolledtopic(item),
                              isRecommended: isRecommended,
                            ),
                          );
                        },
                        itemCount: allTopics.length,
                      ),
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

  Widget _topicGridCard(
    BuildContext context,
    String title,
    String imageUrl,
    VoidCallback onTap, {
    bool isRecommended = false,
  }) {
    return _HoverableTopicCard(
      title: title,
      imageUrl: imageUrl,
      onTap: onTap,
      isRecommended: isRecommended,
    );
  }
}

/// Hoverable topic card with scale and shadow animations
class _HoverableTopicCard extends StatefulWidget {
  final String title;
  final String imageUrl;
  final VoidCallback onTap;
  final bool isRecommended;

  const _HoverableTopicCard({
    required this.title,
    required this.imageUrl,
    required this.onTap,
    this.isRecommended = false,
  });

  @override
  State<_HoverableTopicCard> createState() => _HoverableTopicCardState();
}

class _HoverableTopicCardState extends State<_HoverableTopicCard>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scaleAnimation;
  late Animation<double> _shadowAnimation;
  late Animation<double> _rotationAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );

    _scaleAnimation = Tween<double>(
      begin: 1.0,
      end: 1.05,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeOutCubic));

    _shadowAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeOutCubic));

    _rotationAnimation = Tween<double>(
      begin: 0.0,
      end: 0.025,
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
          return Transform(
            alignment: Alignment.center,
            transform: Matrix4.identity()
              ..setEntry(3, 2, 0.001)
              ..rotateZ(_rotationAnimation.value)
              ..scale(_scaleAnimation.value),
            child: child,
          );
        },
        child: GestureDetector(
          onTap: widget.onTap,
          child: Container(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              boxShadow: [
                BoxShadow(
                  color: widget.isRecommended
                      ? AppTheme.primaryColor.withOpacity(0.15)
                      : Colors.black.withOpacity(0.06),
                  blurRadius: widget.isRecommended
                      ? 8
                      : 4 + (_shadowAnimation.value * 4),
                  offset: Offset(0, 2 + (_shadowAnimation.value * 2)),
                  spreadRadius: widget.isRecommended ? 0.5 : 0,
                ),
              ],
              border: widget.isRecommended
                  ? Border.all(
                      color: AppTheme.primaryColor.withOpacity(0.2),
                      width: 1,
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
                      flex: 2,
                      child: ClipRRect(
                        borderRadius: const BorderRadius.vertical(
                          top: Radius.circular(12),
                        ),
                        child: AspectRatio(
                          aspectRatio: 1 / 1,
                          child: Image.network(
                            widget.imageUrl,
                            fit: BoxFit.fill,
                            errorBuilder: (_, __, ___) => Container(
                              color: Colors.grey[300],
                              child: const Icon(Icons.image_not_supported),
                            ),
                          ),
                        ),
                      ),
                    ),
                    Expanded(
                      flex: 1,
                      child: Padding(
                        padding: const EdgeInsets.all(6),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.center,
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text(
                              widget.title,
                              maxLines: 3,
                              overflow: TextOverflow.ellipsis,
                              textAlign: TextAlign.center,
                              style: Theme.of(context).textTheme.bodySmall
                                  ?.copyWith(
                                    fontWeight: FontWeight.w600,
                                    color: Colors.black87,
                                  ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
                if (widget.isRecommended)
                  Positioned(
                    top: 6,
                    right: 6,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 6,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: AppTheme.primaryColor,
                        borderRadius: BorderRadius.circular(8),
                        boxShadow: [
                          BoxShadow(
                            color: AppTheme.primaryColor.withOpacity(0.4),
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
          ),
        ),
      ),
    );
  }
}
