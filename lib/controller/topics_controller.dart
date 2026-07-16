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
      isLoading.value = true;

      final baseFilters = <String, dynamic>{'hidden': false};

      List<dynamic> merged = [];

      if (_userStage == null || _userStage!.isEmpty) {
        // Guest → fetch all topics (no stage filter)
        merged = await _api.fetchWithConditions('topics', filters: baseFilters);
      } else {
        // Logged user → fetch stage topics + global topics

        final stageTopics = await _api.fetchWithConditions(
          'topics',
          filters: {...baseFilters, 'stage': _userStage!},
        );

        final globalTopics = await _api.fetchWithConditions(
          'topics',
          filters: {...baseFilters, 'stage': ''},
        );

        merged = [...stageTopics, ...globalTopics];
      }

      // Remove duplicates
      final uniqueTopics = {
        for (var topic in merged)
          (topic as Map)['id']: Map<String, dynamic>.from(topic),
      }.values.toList();

      // Split recommended / latest
      final rec = uniqueTopics.where((t) => t['recommended'] == true).toList();

      final latest = uniqueTopics
          .where((t) => t['recommended'] == false)
          .toList();

      // Sorting
      int sortByDate(Map a, Map b) {
        if (a['created_at'] == null && b['created_at'] == null) return 0;
        if (a['created_at'] == null) return 1;
        if (b['created_at'] == null) return -1;

        return DateTime.parse(
          b['created_at'].toString(),
        ).compareTo(DateTime.parse(a['created_at'].toString()));
      }

      rec.sort(sortByDate);
      latest.sort(sortByDate);

      recommendations.assignAll(rec);
      latestTopics.assignAll(latest);
    } catch (e) {
      projectLogger.e('Error loading topics: $e');

      // showSnackbar(
      //   'خطأ',
      //   'فشل في جلب المحتويات: $e',
      //   backgroundColor: Colors.red,
      //   snackPosition: SnackPosition.BOTTOM,
      // );
      print('Error loading topics: $e');
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
      showSnackbar(
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
