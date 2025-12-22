import 'dart:io';

import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:shobaki_academy/controller/books_controller.dart';
import 'package:shobaki_academy/controller/subscription_controller.dart';
import 'package:shobaki_academy/model/pdf_model.dart';
import 'package:shobaki_academy/services/api.dart';
import 'package:shobaki_academy/services/statics.dart';

class BooksPage extends StatelessWidget {
  const BooksPage({super.key});

  @override
  Widget build(BuildContext context) {
    final controller = Get.put(BooksController());
    final isDesktop =
        Platform.isWindows || Platform.isMacOS || Platform.isLinux;
    final crossAxisCount = isDesktop ? 4 : 2;
    final childAspectRatio = isDesktop ? 1.0 : 1.2;

    // Add this observable for view mode (list view is default)
    final isGridView = false.obs;

    return Scaffold(
      appBar: AppBar(
        backgroundColor: isDesktop ? Colors.transparent : null,
        elevation: isDesktop ? 0 : null,
        actions: [
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
      body: Obx(() {
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
                  return _BookCard(
                    book: book,
                    isGuest: controller.isGuest.value,
                    isReviewer: controller.isReviewer.value,
                    controller: controller,
                  );
                },
              )
            : ListView.separated(
                padding: const EdgeInsets.all(12),
                itemCount: controller.books.length,
                separatorBuilder: (context, index) => const Divider(height: 1),
                itemBuilder: (context, index) {
                  final book = controller.books[index];
                  return _BookListTile(
                    book: book,
                    isGuest: controller.isGuest.value,
                    isReviewer: controller.isReviewer.value,
                    controller: controller,
                  );
                },
              );

        if (isDesktop) {
          return content;
        }

        return RefreshIndicator(
          onRefresh: controller.refreshBooksAndSubscription,
          child: content,
        );
      }),
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
    final isDesktop =
        Platform.isWindows || Platform.isMacOS || Platform.isLinux;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: _onTileTap,
        child: Padding(
          padding: EdgeInsets.symmetric(
            vertical: isDesktop ? 16 : 12,
            horizontal: isDesktop ? 16 : 8,
          ),
          child: Row(
            children: [
              // Title and badges
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      widget.book.title,
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        if (!widget.isReviewer && widget.book.free)
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 4,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.green[400],
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: const [
                                Icon(
                                  Icons.lock_open_rounded,
                                  color: Colors.white,
                                  size: 16,
                                ),
                                SizedBox(width: 4),
                                Text(
                                  'مجاني',
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontSize: 12,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        if (!widget.isReviewer && !widget.book.free)
                          FutureBuilder<bool>(
                            future: _hasSubscriptionFuture,
                            builder: (context, snapshot) {
                              final hasSubscription = snapshot.data ?? false;
                              return Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 8,
                                  vertical: 4,
                                ),
                                decoration: BoxDecoration(
                                  color: hasSubscription
                                      ? Colors.green[400]
                                      : Colors.red[400],
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(
                                      hasSubscription
                                          ? Icons.lock_open_rounded
                                          : Icons.lock,
                                      color: Colors.white,
                                      size: 16,
                                    ),
                                    const SizedBox(width: 4),
                                    Text(
                                      hasSubscription ? 'مفتوح' : 'مقفل',
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontSize: 12,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ],
                                ),
                              );
                            },
                          ),
                      ],
                    ),
                  ],
                ),
              ),
              // Arrow icon
              Icon(
                Icons.arrow_forward_ios,
                size: isDesktop ? 20 : 16,
                color: Colors.grey[400],
              ),
            ],
          ),
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
      duration: const Duration(milliseconds: 200),
      vsync: this,
    );

    _scaleAnimation = Tween<double>(
      begin: 1.0,
      end: 1.05,
    ).animate(CurvedAnimation(parent: _hoverController, curve: Curves.easeOut));

    _elevationAnimation = Tween<double>(
      begin: 4,
      end: 8,
    ).animate(CurvedAnimation(parent: _hoverController, curve: Curves.easeOut));

    _rotationAnimation = Tween<double>(
      begin: 0.0,
      end: 0.05,
    ).animate(CurvedAnimation(parent: _hoverController, curve: Curves.easeOut));

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
              transform: Matrix4.identity()
                ..setEntry(3, 2, 0.001)
                ..rotateZ(_rotationAnimation.value)
                ..scale(_scaleAnimation.value),
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
                      child: widget.book.thumbnail != null
                          ? ClipRRect(
                              borderRadius: BorderRadius.circular(12),
                              child: Image.network(
                                widget.book.thumbnail!,
                                fit: BoxFit.cover,
                                errorBuilder: (context, error, stackTrace) {
                                  return _buildPlaceholder();
                                },
                              ),
                            )
                          : _buildPlaceholder(),
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
                              Colors.black.withOpacity(0.8),
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
