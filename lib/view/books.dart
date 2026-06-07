import 'package:animate_do/animate_do.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:shobaki_academy/controller/books_controller.dart';
import 'package:shobaki_academy/controller/subscription_controller.dart';
import 'package:shobaki_academy/model/pdf_model.dart';
import 'package:shobaki_academy/services/api.dart';
import 'package:shobaki_academy/services/statics.dart';
import 'package:shobaki_academy/utils/image_utils.dart';
import 'package:shobaki_academy/utils/constants.dart';
import 'package:shobaki_academy/utils/responsive_utils.dart';

class BooksPage extends StatelessWidget {
  const BooksPage({super.key});

  @override
  Widget build(BuildContext context) {
    final controller = Get.put(BooksController());
    final isDesktop = ResponsiveUtils.isDesktop(context);
    final isTablet = ResponsiveUtils.isTablet(context);
    final crossAxisCount = isDesktop ? 4 : (isTablet ? 3 : 2);
    final childAspectRatio = isDesktop ? 1.0 : 1.2;

    // Add this observable for view mode (list view is default)
    final isGridView = false.obs;

    return Scaffold(
      body: SafeArea(
        child: Obx(() {
          if (controller.isLoading.value) {
            return loading(context);
          }

          if (controller.errorMessage.isNotEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.error_outline, size: 64, color: Colors.red[300]),
                  const SizedBox(height: 16),
                  Text(
                    controller.errorMessage.value,
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                  const SizedBox(height: 16),
                  ElevatedButton.icon(
                    onPressed: controller.refreshBooksAndSubscription,
                    icon: Icon(
                      Icons.refresh,
                      color: Theme.of(context).colorScheme.primary,
                    ),
                    label: const Text('إعادة محاولة'),
                  ),
                ],
              ),
            );
          }

          if (controller.books.isEmpty) {
            if (isDesktop) {
              return SingleChildScrollView(
                child: Center(
                  child: Padding(
                    padding: const EdgeInsets.only(top: 100.0),
                    child: const Text('لا توجد ملازم متاحة'),
                  ),
                ),
              );
            }
            return RefreshIndicator(
              onRefresh: controller.refreshBooksAndSubscription,
              child: ListView(
                children: const [
                  Padding(
                    padding: EdgeInsets.only(top: 100.0),
                    child: Center(child: Text('لا توجد ملازم متاحة')),
                  ),
                ],
              ),
            );
          }

          Widget content = isGridView.value
              ? GridView.builder(
                  padding: const EdgeInsets.all(12),
                  gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: crossAxisCount,
                    childAspectRatio: childAspectRatio,
                    crossAxisSpacing: 12,
                    mainAxisSpacing: 12,
                  ),
                  itemCount: controller.books.length,
                  itemBuilder: (context, index) {
                    final book = controller.books[index];
                    return BounceInUp(
                      from: 100,
                      duration: const Duration(milliseconds: 500),
                      delay: Duration(milliseconds: index * 80),
                      child: _BookCard(
                        book: book,
                        isGuest: controller.isGuest.value,
                        isReviewer: controller.isReviewer.value,
                        controller: controller,
                      ),
                    );
                  },
                )
              : ListView.separated(
                  padding: const EdgeInsets.all(12),
                  itemCount: controller.books.length,
                  separatorBuilder: (context, index) =>
                      const Divider(height: 1),
                  itemBuilder: (context, index) {
                    final book = controller.books[index];
                    if (index == controller.books.length - 1) {
                      // Add extra space at the end for better UX on mobile
                      return Column(
                        children: [
                          BounceInUp(
                            from: 100,
                            duration: const Duration(milliseconds: 600),
                            delay: Duration(milliseconds: index * 80),
                            child: _BookListTile(
                              book: book,
                              isGuest: controller.isGuest.value,
                              isReviewer: controller.isReviewer.value,
                              controller: controller,
                            ),
                          ),
                          const SizedBox(height: 80),
                        ],
                      );
                    }
                    return BounceInUp(
                      from: 100,
                      duration: const Duration(milliseconds: 600),
                      delay: Duration(milliseconds: index * 80),
                      child: _BookListTile(
                        book: book,
                        isGuest: controller.isGuest.value,
                        isReviewer: controller.isReviewer.value,
                        controller: controller,
                      ),
                    );
                  },
                );

          if (isDesktop) {
            return Column(
              children: [
                Padding(
                  padding: const EdgeInsets.all(12.0),
                  child: _buildSearchBar(context, controller, isGridView),
                ),
                Expanded(child: content),
              ],
            );
          }

          return Column(
            children: [
              Padding(
                padding: const EdgeInsets.all(12.0),
                child: _buildSearchBar(context, controller, isGridView),
              ),
              Expanded(
                child: RefreshIndicator(
                  onRefresh: controller.refreshBooksAndSubscription,
                  child: content,
                ),
              ),
            ],
          );
        }),
      ),
    );
  }

  Widget _buildSearchBar(
    BuildContext context,
    BooksController controller,
    RxBool isGridView,
  ) {
    final size = MediaQuery.of(context).size;
    final isDesktop = size.width > 900;

    return Directionality(
      textDirection: TextDirection.rtl,
      child: Row(
        children: [
          Row(
            children: [
              Obx(
                () => IconButton(
                  icon: Icon(
                    isGridView.value ? Icons.view_list : Icons.grid_view,
                    color: Theme.of(context).colorScheme.primary,
                  ),
                  onPressed: () => isGridView.value = !isGridView.value,
                  tooltip: isGridView.value ? 'عرض كقائمة' : 'عرض كشبكة',
                ),
              ),
              if (isDesktop) _RefreshButton(controller: controller),
            ],
          ),
          Expanded(
            child: Container(
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
                onSubmitted: (q) => controller.onSearchSubmitted(q, context),
                decoration: InputDecoration(
                  hintText: 'ابحث عن ملزمة',
                  hintStyle: const TextStyle(color: Colors.black45),
                  prefixIcon: const Icon(Icons.search, color: Colors.black54),
                  border: InputBorder.none,
                  contentPadding: EdgeInsets.symmetric(
                    horizontal: isDesktop ? 14 : 10,
                    vertical: isDesktop ? 8 : 6,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _RefreshButton extends StatefulWidget {
  final BooksController controller;
  const _RefreshButton({required this.controller});

  @override
  State<_RefreshButton> createState() => _RefreshButtonState();
}

class _RefreshButtonState extends State<_RefreshButton>
    with SingleTickerProviderStateMixin {
  late AnimationController _rotationController;

  @override
  void initState() {
    super.initState();
    _rotationController = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );
  }

  @override
  void dispose() {
    _rotationController.dispose();
    super.dispose();
  }

  void _refresh() async {
    _rotationController.forward(from: 0.0);
    await widget.controller.refreshBooksAndSubscription();
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(8.0),
      child: MouseRegion(
        cursor: SystemMouseCursors.click,
        child: RotationTransition(
          turns: Tween(begin: 0.0, end: 1.0).animate(_rotationController),
          child: IconButton(
            icon: Icon(
              Icons.refresh,
              color: Theme.of(context).colorScheme.primary,
            ),
            onPressed: _refresh,
            tooltip: 'تحديث',
          ),
        ),
      ),
    );
  }
}

class _BookListTile extends StatefulWidget {
  final Book book;
  final bool isGuest;
  final bool isReviewer;
  final BooksController controller;
  const _BookListTile({
    required this.book,
    required this.isGuest,
    required this.isReviewer,
    required this.controller,
  });

  @override
  State<_BookListTile> createState() => _BookListTileState();
}

class _BookListTileState extends State<_BookListTile> {
  late Future<bool> _hasSubscriptionFuture;
  bool _isHovered = false;

  @override
  void initState() {
    super.initState();
    _hasSubscriptionFuture = widget.controller.checkBookSubscription();
  }

  void _onTileTap() async {
    if (widget.isReviewer) {
      Get.to(
        () => PdfModel(
          pdfUrl: widget.book.url,
          filename: '${widget.book.title}.pdf',
        ),
      );
      return;
    }

    if (widget.book.free) {
      Get.to(
        () => PdfModel(
          pdfUrl: widget.book.url,
          filename: '${widget.book.title}.pdf',
        ),
      );
      return;
    }

    if (widget.isGuest) {
      showGuestAnnotationDialog(context: context);
    } else {
      final hasSubscription = await widget.controller.checkBookSubscription();
      if (hasSubscription) {
        Get.to(
          () => PdfModel(
            pdfUrl: widget.book.url,
            filename: '${widget.book.title}.pdf',
          ),
        );
      } else {
        showBookSubscriptionDialog(
          api: ApiClient(),
          userId: widget.controller.userId.value,
          context: context,
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDesktop = ResponsiveUtils.isDesktop(context);

    return MouseRegion(
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      child: TweenAnimationBuilder<double>(
        tween: Tween(begin: 1.0, end: _isHovered ? 1.02 : 1.0),
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOutCubic,
        builder: (context, scale, child) {
          return Transform.scale(
            scale: scale,
            child: child,
          );
        },
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 250),
          margin: EdgeInsets.symmetric(
            horizontal: isDesktop ? 16 : 12,
            vertical: 8,
          ),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: _isHovered
                  ? Theme.of(context).primaryColor.withValues(alpha: 0.5)
                  : Colors.grey.shade200,
              width: 1.5,
            ),
            boxShadow: [
              BoxShadow(
                color: Theme.of(
                  context,
                ).primaryColor.withValues(alpha: _isHovered ? 0.18 : 0.06),
                blurRadius: _isHovered ? 20 : 8,
                offset: Offset(0, _isHovered ? 8 : 3),
                spreadRadius: 0,
              ),
            ],
          ),
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: _onTileTap,
              borderRadius: BorderRadius.circular(16),
              child: Directionality(
                textDirection: TextDirection.rtl,
                child: Padding(
                  padding: EdgeInsets.all(isDesktop ? 20 : 16),
                  child: Row(
                    children: [
                      // Book icon with border (now on the right)
                      Container(
                        width: isDesktop ? 56 : 48,
                        height: isDesktop ? 56 : 48,
                        decoration: BoxDecoration(
                          color: Theme.of(
                            context,
                          ).primaryColor.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: Theme.of(
                              context,
                            ).primaryColor.withValues(alpha: 0.2),
                            width: 1.5,
                          ),
                        ),
                        child: Icon(
                          Icons.menu_book_rounded,
                          color: Theme.of(context).primaryColor,
                          size: isDesktop ? 28 : 24,
                        ),
                      ),
                      const SizedBox(width: 16),

                      // Title and badges
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              widget.book.title,
                              style: Theme.of(context).textTheme.bodyMedium,
                              maxLines: 3,
                              overflow: TextOverflow.ellipsis,
                              textDirection: TextDirection.rtl,
                            ),
                            const SizedBox(height: 10),
                            _buildStatusBadge(),
                          ],
                        ),
                      ),

                      const SizedBox(width: 12),

                      // Arrow icon (now pointing left)
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: Theme.of(
                            context,
                          ).primaryColor.withValues(alpha: 0.08),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(
                            color: Theme.of(
                              context,
                            ).primaryColor.withValues(alpha: 0.15),
                            width: 1,
                          ),
                        ),
                        child: Icon(
                          Icons.arrow_forward_ios_rounded,
                          size: 16,
                          color: Theme.of(context).primaryColor,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildStatusBadge() {
    if (widget.isReviewer) {
      return const SizedBox.shrink();
    }

    if (widget.book.free) {
      return _StatusBadge(
        icon: Icons.lock_open_rounded,
        label: 'مجاني',
        color: const Color(0xFF10B981), // Modern green
      );
    }

    return FutureBuilder<bool>(
      future: _hasSubscriptionFuture,
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return _StatusBadge(
            icon: Icons.hourglass_empty_rounded,
            label: 'جاري التحميل...',
            color: Colors.grey.shade600,
          );
        }

        final hasSubscription = snapshot.data!;
        return _StatusBadge(
          icon: hasSubscription ? Icons.lock_open_rounded : Icons.lock_rounded,
          label: hasSubscription ? 'مفتوح' : 'مقفل',
          color: hasSubscription
              ? const Color(0xFF10B981) // Green
              : const Color(0xFFF59E0B), // Amber/Orange
        );
      },
    );
  }
}

class _StatusBadge extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;

  const _StatusBadge({
    required this.icon,
    required this.label,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: color.withValues(alpha: 0.25), width: 1.2),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: color, size: 16),
            const SizedBox(width: 6),
            Text(
              label,
              style: TextStyle(
                color: color,
                fontSize: 13,
                fontWeight: FontWeight.w700,
                letterSpacing: 0.2,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _BookCard extends StatefulWidget {
  final Book book;
  final bool isGuest;
  final bool isReviewer;
  final BooksController controller;
  const _BookCard({
    required this.book,
    required this.isGuest,
    required this.isReviewer,
    required this.controller,
  });

  @override
  State<_BookCard> createState() => _BookCardState();
}

class _BookCardState extends State<_BookCard>
    with SingleTickerProviderStateMixin {
  late AnimationController _hoverController;
  late Animation<double> _scaleAnimation;
  late Animation<double> _elevationAnimation;
  late Animation<double> _rotationAnimation;
  late Future<bool> _hasSubscriptionFuture;

  @override
  void initState() {
    super.initState();
    _hoverController = AnimationController(
      duration: const Duration(milliseconds: 350),
      vsync: this,
    );

    _scaleAnimation = Tween<double>(
      begin: 1.0,
      end: 1.07,
    ).animate(CurvedAnimation(
      parent: _hoverController,
      curve: Curves.easeOutBack,
    ));

    _elevationAnimation = Tween<double>(
      begin: 4,
      end: 14,
    ).animate(CurvedAnimation(
      parent: _hoverController,
      curve: Curves.easeOutCubic,
    ));

    _rotationAnimation = Tween<double>(
      begin: 0.0,
      end: 0.03,
    ).animate(CurvedAnimation(
      parent: _hoverController,
      curve: Curves.easeOutCubic,
    ));

    _hasSubscriptionFuture = widget.controller.checkBookSubscription();
  }

  @override
  void dispose() {
    _hoverController.dispose();
    super.dispose();
  }

  void _onHover(bool isHovering) {
    if (isHovering) {
      _hoverController.forward();
    } else {
      _hoverController.reverse();
    }
  }

  void _onCardTap() async {
    if (widget.isReviewer) {
      Get.to(
        () => PdfModel(
          pdfUrl: widget.book.url,
          filename: '${widget.book.title}.pdf',
        ),
      );
      return;
    }

    if (widget.book.free) {
      Get.to(
        () => PdfModel(
          pdfUrl: widget.book.url,
          filename: '${widget.book.title}.pdf',
        ),
      );
      return;
    }

    if (widget.isGuest) {
      showGuestAnnotationDialog(context: context);
    } else {
      final hasSubscription = await widget.controller.checkBookSubscription();
      if (hasSubscription) {
        Get.to(
          () => PdfModel(
            pdfUrl: widget.book.url,
            filename: '${widget.book.title}.pdf',
          ),
        );
      } else {
        showBookSubscriptionDialog(
          api: ApiClient(),
          userId: widget.controller.userId.value,
          context: context,
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => _onHover(true),
      onExit: (_) => _onHover(false),
      child: GestureDetector(
        onTap: _onCardTap,
        child: AnimatedBuilder(
          animation: _hoverController,
          builder: (context, child) {
            return Transform(
              alignment: Alignment.center,
              transform: Matrix4.diagonal3Values(
                _scaleAnimation.value,
                _scaleAnimation.value,
                1.0,
              )..rotateZ(_rotationAnimation.value)
                ..setEntry(3, 2, 0.001),
              child: Card(
                elevation: _elevationAnimation.value,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Stack(
                  children: [
                    Container(
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(12),
                        color: Colors.grey[200],
                      ),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(12),
                        child: AspectRatio(
                          aspectRatio: AppConstants.bookAspectRatio,
                          child: ImageUtils.networkWithFallback(
                            widget.book.thumbnail,
                            fit: BoxFit.fill,
                            context: context,
                            placeholder: _buildPlaceholder(),
                          ),
                        ),
                      ),
                    ),
                    Positioned(
                      bottom: 0,
                      left: 0,
                      right: 0,
                      child: Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          borderRadius: const BorderRadius.only(
                            bottomLeft: Radius.circular(12),
                            bottomRight: Radius.circular(12),
                          ),
                          gradient: LinearGradient(
                            begin: Alignment.bottomCenter,
                            end: Alignment.topCenter,
                            colors: [
                              Colors.black.withValues(alpha: 0.8),
                              Colors.transparent,
                            ],
                          ),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              widget.book.title,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: Theme.of(context).textTheme.bodySmall
                                  ?.copyWith(
                                    color: Colors.white,
                                    fontWeight: FontWeight.w600,
                                  ),
                            ),
                            if (!widget.isReviewer && widget.book.free)
                              const SizedBox(height: 4),
                            if (!widget.isReviewer && widget.book.free)
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 6,
                                  vertical: 2,
                                ),
                                decoration: BoxDecoration(
                                  color: Colors.green[400],
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                child: const Icon(
                                  Icons.lock_open_rounded,
                                  color: Colors.white,
                                  size: 20,
                                ),
                              ),
                          ],
                        ),
                      ),
                    ),
                    if (!widget.isReviewer && !widget.book.free)
                      Positioned(
                        bottom: 8,
                        right: 8,
                        child: FutureBuilder<bool>(
                          future: _hasSubscriptionFuture,
                          builder: (context, snapshot) {
                            final hasSubscription = snapshot.data ?? false;
                            return Container(
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                color: hasSubscription
                                    ? Colors.green[400]
                                    : Colors.red[400],
                                shape: BoxShape.circle,
                              ),
                              child: Icon(
                                hasSubscription
                                    ? Icons.lock_open_rounded
                                    : Icons.lock,
                                color: Colors.white,
                                size: 20,
                              ),
                            );
                          },
                        ),
                      ),
                  ],
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _buildPlaceholder() {
    return Container(
      color: Colors.grey[300],
      child: Center(
        child: Icon(Icons.description, size: 48, color: Colors.grey[600]),
      ),
    );
  }
}
