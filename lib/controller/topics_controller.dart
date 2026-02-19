import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:shobaki_academy/services/api.dart';
import 'package:shobaki_academy/services/locale_db.dart';
import 'package:shobaki_academy/services/statics.dart';
import 'package:shobaki_academy/view/topics/topic_content_page.dart';

class TopicsController extends GetxController {
  final ApiClient _api = ApiClient();

  // public
  final TextEditingController searchController = TextEditingController();
  final RxList<Map<String, dynamic>> recommendations =
      <Map<String, dynamic>>[].obs;
  final RxList<Map<String, dynamic>> latestTopics =
      <Map<String, dynamic>>[].obs;
  final RxList<Map<String, dynamic>> results = <Map<String, dynamic>>[].obs;
  final RxBool isLoading = true.obs;

  // internal
  final RxBool sheetOpen = false.obs;
  // loading indicator for search
  final RxBool isSearching = false.obs;
  final RxBool isGuest = false.obs;
  final String? userStageArg;
  String? _userStage;

  TopicsController({this.userStageArg});

  @override
  void onInit() {
    super.onInit();
    final LocalDB prefs = Get.find();
    final jsonUserData = prefs.sharedPref!.getString('UserData');
    final Map<String, dynamic>? userData = jsonUserData != null
        ? jsonDecode(jsonUserData)
        : null;
    _userStage = userData!['stage'] as String?;
    print(userData);
  }

  @override
  void onClose() {
    searchController.dispose();
    super.onClose();
  }

  /// Load recommended and latest topics using ApiClient.fetchWithConditions
  /// Applies stage filter if available.
  Future<void> loadTopics() async {
    try {
      // recommended == true filter
      final recFilters = <String, dynamic>{
        'recommended': true,
        'hidden': false,
      };
      //in guest state it will be defaulted to null because we don't have user data
      if (_userStage != null && _userStage!.isNotEmpty) {
        recFilters['stage'] = _userStage!;
      }

      final latestFilters = <String, dynamic>{
        'recommended': false,
        'hidden': false,
      };
      if (_userStage != null && _userStage!.isNotEmpty) {
        latestFilters['stage'] = _userStage!;
      }

      // fetch recommendations (no paging)
      final recResp = await _api.fetchWithConditions(
        'topics',
        filters: recFilters,
        orderBy: 'created_at',
        ascending: true,
      );

      // fetch latest topics (order by created_at desc)
      final latestResp = await _api.fetchWithConditions(
        'topics',
        filters: latestFilters.isEmpty ? null : latestFilters,
        orderBy: 'created_at',
        ascending: true,
      );

      // Sort recommendations by created_at (newest to oldest)
      recommendations.assignAll(
        (recResp.map((e) => Map<String, dynamic>.from(e as Map)).toList()
          ..sort((a, b) {
            if (a['created_at'] == null && b['created_at'] == null) return 0;
            if (a['created_at'] == null) return 1;
            if (b['created_at'] == null) return -1;
            return DateTime.parse(
              b['created_at'].toString(),
            ).compareTo(DateTime.parse(a['created_at'].toString()));
          })),
      );

      // Sort latestTopics by created_at (newest to oldest)
      latestTopics.assignAll(
        (latestResp.map((e) => Map<String, dynamic>.from(e as Map)).toList()
          ..sort((a, b) {
            if (a['created_at'] == null && b['created_at'] == null) return 0;
            if (a['created_at'] == null) return 1;
            if (b['created_at'] == null) return -1;
            return DateTime.parse(
              b['created_at'].toString(),
            ).compareTo(DateTime.parse(a['created_at'].toString()));
          })),
      );
    } catch (e) {
      // keep lists unchanged on error but show notification
      Get.snackbar(
        'خطأ',
        'فشل في جلب المحتويات: $e',
        backgroundColor: Colors.red,
        snackPosition: SnackPosition.BOTTOM,
      );
    } finally {
      isLoading.value = false;
    }
  }

  /// Called when user presses the keyboard "done" button
  void onSearchSubmitted(String value, context, bool inReview) {
    _doSearch(value, context, inReview);
  }

  Future<void> _doSearch(String q, context, inReview) async {
    final query = q.trim();
    if (query.isEmpty) {
      results.clear();
      if (sheetOpen.value) {
        if (Get.isBottomSheetOpen == true) Get.back();
        sheetOpen.value = false;
      }
      // ensure loading flag reset
      isSearching.value = false;
      return;
    }

    if (!sheetOpen.value) {
      _showResultsSheet(context, inReview);
    }

    isSearching.value = true;
    try {
      final pattern = '%$query%';

      final titleFilters = <String, dynamic>{
        'title': {'operator': 'ilike', 'value': pattern},
        'hidden': false,
      };
      final descFilters = <String, dynamic>{
        'description': {'operator': 'ilike', 'value': pattern},
        'hidden': false,
      };

      if (_userStage != null && _userStage!.isNotEmpty) {
        titleFilters['stage'] = _userStage!;
        descFilters['stage'] = _userStage!;
      }

      final r1 = await _api.fetchWithConditions(
        'topics',
        filters: titleFilters,
      );
      final r2 = await _api.fetchWithConditions('topics', filters: descFilters);

      // merge unique by id
      final merged = <Map<String, dynamic>>[];
      final seen = <dynamic>{};
      for (final item in [...r1, ...r2]) {
        final map = Map<String, dynamic>.from(item as Map);
        final id = map['id'];
        if (!seen.contains(id)) {
          seen.add(id);
          merged.add(map);
        }
      }

      results.assignAll(merged);
    } catch (e) {
      results.clear();
      Get.snackbar(
        'خطأ في البحث',
        'حدث خطأ أثناء البحث: $e',
        backgroundColor: Colors.red,
        snackPosition: SnackPosition.BOTTOM,
      );
    } finally {
      // stop loading regardless of result
      isSearching.value = false;
    }
  }

  void _showResultsSheet(context, bool inReview) {
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
                        results.clear();
                        if (sheetOpen.value) {
                          if (Get.isBottomSheetOpen == true) Get.back();
                          sheetOpen.value = false;
                          // reset loading when closing
                          isSearching.value = false;
                        }
                      },
                    ),
                  ],
                ),
              ),
              Expanded(
                child: Obx(() {
                  // show loader while searching, otherwise show results or empty state
                  if (isSearching.value) {
                    return Center(child: loading(context));
                  }
                  final items = results;
                  if (items.isEmpty) {
                    return const Center(child: Text('لا توجد نتائج'));
                  }
                  return ListView.separated(
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    itemBuilder: (_, i) {
                      final item = items[i];
                      return ListTile(
                        title: Text(item['title']?.toString() ?? ''),
                        subtitle: item['description'] != null
                            ? Text(
                                item['description'].toString(),
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                              )
                            : null,
                        onTap: () {
                          onSelectTopic(item, inReview);
                          if (sheetOpen.value) {
                            if (Get.isBottomSheetOpen == true) Get.back();
                            sheetOpen.value = false;
                          }
                        },
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

  /// Handle topic selection (navigate). Adjust route/name to your app.
  void onSelectTopic(Map<String, dynamic> topic, bool inReview) {
    // Example: navigate to a detail route; change to your real route/widget
    // Get.toNamed('/topicDetail', arguments: topic);
    // For now, just print and close sheet if open
    debugPrint('Selected topic: ${topic['id'] ?? topic['title']}');
    Get.to(
      () => TopicContentPage(
        topicId: topic['id'],
        isGuest: isGuest.value,
        inReview: inReview,
      ),
      transition: Transition.downToUp,
    );
  }
}
