// lib/controller/books_controller.dart
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:shobaki_academy/controller/subscription_controller.dart';
import 'package:shobaki_academy/model/pdf_model.dart';
import 'package:shobaki_academy/services/api.dart';
import 'package:shobaki_academy/services/locale_db.dart';
import 'package:shobaki_academy/services/statics.dart';
import 'package:shobaki_academy/view/books.dart';
import 'dart:convert';

class Book {
  final int id;
  final String title;
  final String url;
  final String? thumbnail;
  final bool free;
  final bool hidden;
  final DateTime createdAt;
  final bool isParent;
  final List<int> children;

  Book({
    required this.id,
    required this.title,
    required this.url,
    this.thumbnail,
    required this.free,
    this.hidden = false,
    required this.createdAt,
    this.isParent = false,
    this.children = const [],
  });

  factory Book.fromJson(Map<String, dynamic> json) {
    final rawChildren = json['children'];
    List<int> childrenIds = const [];
    if (rawChildren is List) {
      childrenIds = rawChildren
          .map((e) => int.tryParse(e.toString()) ?? 0)
          .where((id) => id != 0)
          .toList();
    }
    return Book(
      id: json['id'] as int,
      title: json['title'] as String,
      url: json['url'] as String? ?? '',
      thumbnail: json['thumbnail'] as String?,
      free: json['free'] as bool? ?? false,
      hidden: json['hidden'] as bool? ?? false,
      createdAt: DateTime.parse(
        json['created_at'] as String? ?? DateTime.now().toIso8601String(),
      ),
      isParent: json['is_parent'] as bool? ?? false,
      children: childrenIds,
    );
  }
}

class BooksController extends GetxController {
  final ApiClient _api;
  final LocalDB _localDb = Get.find<LocalDB>();

  BooksController({ApiClient? api}) : _api = api ?? ApiClient();

  final RxList books = <Book>[].obs;
  final RxBool isLoading = false.obs;
  final RxString errorMessage = ''.obs;
  final RxBool showFAB = false.obs;
  final RxString userEmail = ''.obs;
  final RxString userId = ''.obs;
  final RxBool isGuest = false.obs;
  final RxBool isReviewer = false.obs;
  final TextEditingController searchController = TextEditingController();
  final RxString searchQuery = ''.obs;
  final RxBool isSearching = false.obs;
  final RxBool sheetOpen = false.obs;
  final RxList<Book> searchResults = <Book>[].obs;
  Map? userData;

  /// Bumped after every refresh/subscription so UI widgets re-initialize.
  final RxInt subsRevision = 0.obs;

  /// Cache: parent book id -> children book ids (from `books.children`).
  final Map<int, List<int>> _groupsById = {};

  @override
  void onInit() {
    super.onInit();
    _loadUserData();
    checkBookSubscription();
    fetchBooks();
  }

  @override
  void onClose() {
    searchController.dispose();
    super.onClose();
  }

  /// Load user data from local storage
  void _loadUserData() {
    try {
      final user = _localDb.sharedPref?.getString('UserData');
      if (user != null && user.isNotEmpty) {
        userData = jsonDecode(user) as Map<String, dynamic>;
        userEmail.value = userData?['email'] as String? ?? '';
        userId.value = userData?['id'] ?? '';

        // Check if guest
        isGuest.value = userEmail.value == 'guest@example.com';

        // Check if reviewer (special test account)
        isReviewer.value =
            userEmail.value == 'appletestaccount#97111111111111@gmail.com';

        Get.log('User loaded - Email: ${userEmail.value}, ID: ${userId.value}');
      }
    } catch (e) {
      Get.log('Error loading user data: $e', isError: true);
    }
  }

  /// Check if user has books subscription.
  ///
  /// When [bookId] is a member of a subscribed group, this returns true too,
  /// so opening a group's child requires only the group subscription.
  Future<bool> checkBookSubscription({int? bookId}) async {
    try {
      if (isGuest.value || isReviewer.value || userId.value.isEmpty) {
        return false;
      }

      if (_groupsById.isEmpty) {
        await _refreshGroupCache();
      }

      final subscriptions = await _api.fetchWithConditions(
        'students_subscriptions',
        filters: {'student_id': userId.value, 'subscription_type': 'books'},
      );

      if (subscriptions.isEmpty) {
        return false;
      }

      if (bookId == null) {
        return true;
      }

      final subscribedBookIds = subscriptions.map((s) {
        final map = Map<String, dynamic>.from(s as Map);
        return int.tryParse(map['book_id']?.toString() ?? '-1') ?? -1;
      }).toSet();

      if (subscribedBookIds.contains(bookId)) return true;

      for (final groupId in subscribedBookIds) {
        final children = _groupsById[groupId];
        if (children != null && children.contains(bookId)) {
          return true;
        }
      }
      return false;
    } catch (e) {
      Get.log('Error checking book subscription: $e', isError: true);
      return false;
    }
  }

  /// Loads the id -> children map for all parent (group) books.
  Future<void> _refreshGroupCache() async {
    try {
      final groups = await _api.fetchWithConditions(
        'books',
        filters: {'is_parent': true, 'hidden': false},
      );
      _groupsById
        ..clear()
        ..addEntries(groups.map((g) {
          final map = Map<String, dynamic>.from(g as Map);
          final id = int.tryParse(map['id']?.toString() ?? '0') ?? 0;
          final rawChildren = map['children'];
          List<int> children = const [];
          if (rawChildren is List) {
            children = rawChildren
                .map((e) => int.tryParse(e.toString()) ?? 0)
                .where((x) => x != 0)
                .toList();
          }
          return MapEntry(id, children);
        }));
    } catch (e) {
      Get.log('Error refreshing group cache: $e', isError: true);
    }
  }

  /// Fetches the child books of a group (by id, only non-hidden).
  Future<List<Book>> fetchGroupChildren(int groupId) async {
    final ids = _groupsById[groupId] ?? const [];
    final result = <Book>[];
    for (final id in ids) {
      try {
        final res = await _api.fetchWithConditions(
          'books',
          filters: {'id': id, 'hidden': false},
        );
        if (res.isNotEmpty) {
          result.add(Book.fromJson(Map<String, dynamic>.from(res[0] as Map)));
        }
      } catch (_) {
        // ignore a failed child fetch
      }
    }
    return result;
  }

  Future<void> fetchBooks() async {
    try {
      isLoading.value = true;
      errorMessage.value = '';
      await _refreshGroupCache();
      if (userData != null && userData!['stage'] != null) {
        final response = await _api.fetchWithConditions(
          'books',
          filters: {
            'stage': userData!['stage'],
            'is_parent': true,
            'hidden': false,
          },
        );
        books.value = (response)
            .map((item) => Book.fromJson(item as Map<String, dynamic>))
            .where((book) => book.isParent)
            .toList();
      } else {
        final response = await _api.fetchWithConditions(
          'books',
          filters: {'is_parent': true, 'hidden': false},
        );
        books.value = (response)
            .map((item) => Book.fromJson(item as Map<String, dynamic>))
            .where((book) => book.isParent)
            .toList();
      }

      // Sort by created_at from oldest to newest
      // ignore: invalid_use_of_protected_member
      books.value.sort((a, b) {
        if (a.createdAt == null && b.createdAt == null) return 0;
        if (a.createdAt == null) return 1;
        if (b.createdAt == null) return -1;
        return a.createdAt!.compareTo(b.createdAt!);
      });
    } catch (e) {
      errorMessage.value = 'فشل تحميل الملزمة: $e';
      Get.log('Error fetching books: $e', isError: true);
    } finally {
      isLoading.value = false;
    }
  }

  /// Refresh both books list and subscription state
  Future<void> refreshBooksAndSubscription() async {
    try {
      // Fetch latest books
      await fetchBooks();

      // Check subscription status
      await checkBookSubscription();

      // Notify UI to rebuild widgets (re-initialize subscription futures)
      subsRevision.value++;

      Get.log('Books and subscription refreshed successfully');
    } catch (e) {
      Get.log('Error refreshing books and subscription: $e', isError: true);
    }
  }

  /// Search books by title
  void onSearchSubmitted(String value, context) {
    _doSearch(value, context);
  }

  Future<void> _doSearch(String q, context) async {
    final query = q.trim();
    if (query.isEmpty) {
      searchResults.clear();
      if (sheetOpen.value) {
        if (Get.isBottomSheetOpen == true) Get.back();
        sheetOpen.value = false;
      }
      isSearching.value = false;
      return;
    }

    if (!sheetOpen.value) {
      _showResultsSheet(context);
    }

    isSearching.value = true;
    try {
      final pattern = '%$query%';
      final filters = <String, dynamic>{
        'title': {'operator': 'ilike', 'value': pattern},
        'hidden': false,
      };

      if (userData != null && userData!['stage'] != null) {
        filters['stage'] = userData!['stage'];
      }

      final response = await _api.fetchWithConditions(
        'books',
        filters: filters,
      );
      searchResults.assignAll(
        response.map((item) => Book.fromJson(item as Map<String, dynamic>)),
      );
    } catch (e) {
      Get.log('Error searching books: $e', isError: true);
      searchResults.clear();
      showSnackbar(
        'خطأ في البحث',
        'حدث خطأ أثناء البحث: $e',
        backgroundColor: Colors.red,
        snackPosition: SnackPosition.BOTTOM,
      );
    } finally {
      isSearching.value = false;
    }
  }

  void _showResultsSheet(context) {
    sheetOpen.value = true;

    Get.bottomSheet(
      SafeArea(
        child: Container(
          height: Get.height * 0.6,
          padding: const EdgeInsets.only(top: 8),
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
          ),
          child: Column(
            children: [
              // header with close icon
              Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 8,
                ),
                child: Row(
                  children: [
                    const Spacer(),
                    IconButton(
                      icon: const Icon(Icons.close),
                      onPressed: () {
                        searchController.clear();
                        searchQuery.value = '';
                        searchResults.clear();
                        if (sheetOpen.value) {
                          if (Get.isBottomSheetOpen == true) Get.back();
                          sheetOpen.value = false;
                          isSearching.value = false;
                        }
                      },
                    ),
                  ],
                ),
              ),
              Expanded(
                child: Obx(() {
                  if (isSearching.value) {
                    return Center(
                      child: CircularProgressIndicator(color: Colors.blue[400]),
                    );
                  }
                  final items = searchResults;
                  if (items.isEmpty) {
                    return const Center(child: Text('لا توجد نتائج'));
                  }
                  return ListView.separated(
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    itemBuilder: (_, i) {
                      final book = items[i];
                      if (book.isParent) {
                        return BookGroupTile(
                          group: book,
                          isGuest: isGuest.value,
                          isReviewer: isReviewer.value,
                          controller: this,
                        );
                      }
                      return ListTile(
                        title: Text(book.title),
                        subtitle: isReviewer.value
                            ? SizedBox.shrink()
                            : book.free
                            ? const Text('مجاني')
                            : Text(
                                'غير مجاني',
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),

                        onTap: () => _onTileTap(
                          book,
                          context,
                          isGuest.value,
                          isReviewer.value,
                        ),
                      );
                    },
                    separatorBuilder: (_, __) => const Divider(),
                    itemCount: items.length,
                  );
                }),
              ),
            ],
          ),
        ),
      ),
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
    ).whenComplete(() {
      sheetOpen.value = false;
      isSearching.value = false;
    });
  }

  void _onTileTap(book, context, isGuest, isReviewer) async {
    if (book.url.toString().isEmpty) {
      Get.snackbar(
        'معلومات',
        'لا يوجد ملف لهذه الملزمة بعد',
        snackPosition: SnackPosition.BOTTOM,
        duration: const Duration(seconds: 3),
      );
      return;
    }

    if (isReviewer) {
      Get.to(() => PdfModel(pdfUrl: book.url, filename: '${book.title}.pdf'));
      return;
    }

    if (book.free) {
      Get.to(() => PdfModel(pdfUrl: book.url, filename: '${book.title}.pdf'));
      return;
    }

    if (isGuest) {
      showGuestAnnotationDialog(context: context);
    } else {
      final hasSubscription = await checkBookSubscription(bookId: book.id);
      if (hasSubscription) {
        Get.to(() => PdfModel(pdfUrl: book.url, filename: '${book.title}.pdf'));
      } else {
        showBookSubscriptionDialog(
          api: ApiClient(),
          userId: userId.value,
          bookId: book.id,
          context: context,
        );
      }
    }
  }

  /// Clear search results
  void clearSearch() {
    searchQuery.value = '';
    searchController.clear();
    searchResults.clear();
    isSearching.value = false;
  }
}
