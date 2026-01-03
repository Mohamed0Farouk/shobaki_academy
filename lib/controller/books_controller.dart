// lib/controller/books_controller.dart
import 'package:get/get.dart';
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

  final RxList<Book> books = <Book>[].obs;
  final RxBool isLoading = false.obs;
  final RxString errorMessage = ''.obs;
  final RxBool showFAB = false.obs;
  final RxString userEmail = ''.obs;
  final RxString userId = ''.obs;
  final RxBool isGuest = false.obs;
  final RxBool isReviewer = false.obs;
  Map? userData;

  @override
  void onInit() {
    super.onInit();
    _loadUserData();
    checkBookSubscription();
    fetchBooks();
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
            userEmail.value == 'appletestaccount#11111111111@gmail.com';

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
}
