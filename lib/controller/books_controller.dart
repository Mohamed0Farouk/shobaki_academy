// lib/controller/books_controller.dart
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:shobaki_academy/controller/subscription_controller.dart';
import 'package:shobaki_academy/model/pdf_model.dart';
import 'package:shobaki_academy/services/api.dart';
import 'package:shobaki_academy/services/locale_db.dart';
import 'dart:convert';

class Book {
  final int id;
  final String title;
  final String url;
  final String? thumbnail;
  final bool free;
  final DateTime createdAt;

  Book({
    required this.id,
    required this.title,
    required this.url,
    this.thumbnail,
    required this.free,
    required this.createdAt,
  });

  factory Book.fromJson(Map<String, dynamic> json) {
    return Book(
      id: json['id'] as int,
      title: json['title'] as String,
      url: json['url'] as String,
      thumbnail: json['thumbnail'] as String?,
      free: json['free'] as bool? ?? false,
      createdAt: DateTime.parse(
        json['created_at'] as String? ?? DateTime.now().toIso8601String(),
      ),
    );
  }
}

class BooksController extends GetxController {
  final ApiClient _api = ApiClient();
  final LocalDB _localDb = Get.find<LocalDB>();

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

  /// Check if user has books subscription
  Future<bool> checkBookSubscription() async {
    try {
      if (isGuest.value || isReviewer.value || userId.value.isEmpty) {
        return false;
      }

      final subscriptions = await _api.fetchWithConditions(
        'students_subscriptions',
        filters: {'student_id': userId.value, 'subscription_type': 'books'},
      );

      // Show FAB only if no books subscription exists
      Get.log('Books subscription check - showFAB: ${showFAB.value}');
      return subscriptions.isNotEmpty;
    } catch (e) {
      Get.log('Error checking book subscription: $e', isError: true);
      return false;
    }
  }

  Future<void> fetchBooks() async {
    try {
      isLoading.value = true;
      errorMessage.value = '';
      if (userData != null && userData!['stage'] != null) {
        final response = await _api.fetchWithConditions(
          'books',
          filters: {'stage': userData!['stage']},
        );
        books.value = (response)
            .map((item) => Book.fromJson(item as Map<String, dynamic>))
            .toList();
      } else {
        final response = await _api.fetchData('books');
        books.value = (response)
            .map((item) => Book.fromJson(item as Map<String, dynamic>))
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
      errorMessage.value = 'فشل تحميل الملازم: $e';
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
      Get.snackbar(
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
      final hasSubscription = await checkBookSubscription();
      if (hasSubscription) {
        Get.to(() => PdfModel(pdfUrl: book.url, filename: '${book.title}.pdf'));
      } else {
        showBookSubscriptionDialog(
          api: ApiClient(),
          userId: userId.value,
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
