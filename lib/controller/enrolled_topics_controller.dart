import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:shobaki_academy/services/api.dart';
import 'package:shobaki_academy/services/locale_db.dart';
import 'package:shobaki_academy/services/statics.dart';
import 'package:shobaki_academy/view/enrolled_topics/topic_page.dart';

class EnrolledTopicsController extends GetxController {
  final ApiClient _api = ApiClient();

  // public
  final TextEditingController searchController = TextEditingController();
  final RxList<Map<String, dynamic>> recommendations =
      <Map<String, dynamic>>[].obs;
  final RxList<Map<String, dynamic>> latestenrolledtopics =
      <Map<String, dynamic>>[].obs;
  final RxList<Map<String, dynamic>> results = <Map<String, dynamic>>[].obs;
  final RxBool isLoading = true.obs;

  // internal
  final RxBool sheetOpen = false.obs;
  final RxBool isSearching = false.obs;
  final RxBool isGuest = false.obs;
  final String? userStageArg;
  String? _userStage;
  String? _studentId;

  EnrolledTopicsController({this.userStageArg});

  @override
  void onInit() {
    super.onInit();
    final LocalDB prefs = Get.find();
    final jsonUserData = prefs.sharedPref!.getString('UserData');
    final Map<String, dynamic>? userData = jsonUserData != null
        ? jsonDecode(jsonUserData)
        : null;
    _userStage = userData?['stage'] as String?;
    _studentId = userData?['id'] as String?;

    if (_studentId == null) {
      isGuest.value = true;
    }
  }

  @override
  void onClose() {
    searchController.dispose();
    super.onClose();
  }

  /// Load recommended and latest enrolled topics using students_subscriptions
  /// Uses select parameter with foreign key relations for optimization
  Future<void> loadenrolledtopics() async {
    try {
      isLoading.value = true;
      if (_studentId == null || _studentId!.isEmpty) {
        isGuest.value = true;
        isLoading.value = false;
        return;
      }

      print('Loading enrolled topics for student ID: $_studentId');

      // Fetch subscriptions with related topic data in one query
      final allSubscriptions = await _api.fetchWithConditions(
        'students_subscriptions',
        filters: {'student_id': _studentId},
        select:
            'id,topic_id,created_at,topic:topics(id,title,description,thumbnail,recommended,stage,hidden,created_at)',
      );

      if (allSubscriptions.isEmpty) {
        isLoading.value = false;
        return;
      }

      // Enrich and filter by stage
      final enrichedSubs = <Map<String, dynamic>>[];
      for (final sub in allSubscriptions) {
        final topicData = sub['topic'];
        if (topicData == null) continue;

        // Filter by stage if available
        if (_userStage != null && _userStage!.isNotEmpty) {
          if (topicData['stage'] != _userStage) continue;
        }

        final enrichedSub = Map<String, dynamic>.from(sub as Map);
        enrichedSub['title'] = topicData['title'];
        enrichedSub['description'] = topicData['description'];
        enrichedSub['thumbnail'] = topicData['thumbnail'];
        enrichedSubs.add(enrichedSub);
      }

      // Separate into recommended and latest
      final recommended = <Map<String, dynamic>>[];
      final latest = <Map<String, dynamic>>[];

      for (final sub in enrichedSubs) {
        if (sub['topic']?['recommended'] == true &&
            sub['topic']?['hidden'] != true) {
          recommended.add(sub);
        } else if (sub['topic']?['hidden'] != true &&
            sub['topic']?['recommended'] != true) {
          latest.add(sub);
        }
      }

      // Sort latest by created_at descending
      latest.sort((a, b) {
        final dateA = DateTime.tryParse(
          a['topic']?['created_at']?.toString() ?? '',
        );
        final dateB = DateTime.tryParse(
          b['topic']?['created_at']?.toString() ?? '',
        );
        if (dateA == null || dateB == null) return 0;
        return dateB.compareTo(dateA);
      });

      recommendations.assignAll(recommended);
      latestenrolledtopics.assignAll(latest);
    } catch (e) {
      projectLogger.e('Error loading enrolled topics: $e');
      showSnackbar(
        'خطأ',
        'فشل في جلب المحتويات: $e',
        backgroundColor: Colors.red,
        snackPosition: SnackPosition.BOTTOM,
      );
    } finally {
      isLoading.value = false;
    }
  }

  /// Called when user submits search
  void onSearchSubmitted(String value, context) {
    _doSearch(value, context);
  }

  /// Perform search on enrolled topics with optimized query
  Future<void> _doSearch(String q, context) async {
    final query = q.trim();
    if (query.isEmpty) {
      results.clear();
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
      if (_studentId == null || _studentId!.isEmpty) {
        results.clear();
        isSearching.value = false;
        return;
      }

      // Fetch subscriptions with related topics using select
      final subscriptions = await _api.fetchWithConditions(
        'students_subscriptions',
        filters: {'student_id': _studentId},
        select: 'id,topic_id,topic:topics(id,title,description,stage,hidden)',
      );

      if (subscriptions.isEmpty) {
        results.clear();
        isSearching.value = false;
        return;
      }

      // Search in memory for better performance
      final pattern = query.toLowerCase();
      final merged = <Map<String, dynamic>>[];

      for (final sub in subscriptions) {
        final topicData = sub['topic'];
        if (topicData == null) continue;

        final title = topicData['title']?.toString().toLowerCase() ?? '';
        final description =
            topicData['description']?.toString().toLowerCase() ?? '';

        // Apply stage filter if available
        if (_userStage != null && _userStage!.isNotEmpty) {
          if (topicData['stage'] != _userStage) continue;
        }

        // Match title or description
        if (title.contains(pattern) ||
            description.contains(pattern) && topicData['hidden'] != true) {
          final item = Map<String, dynamic>.from(topicData as Map);
          item['subscription_id'] = sub['id'];
          merged.add(item);
        }
      }

      results.assignAll(merged);
    } catch (e) {
      projectLogger.e('Search error: $e');
      results.clear();
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

  /// Show results bottom sheet
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
                        results.clear();
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
                          onSelectenrolledtopic(item);
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

  /// Handle topic selection and navigate
  void onSelectenrolledtopic(Map<String, dynamic> topic) {
    projectLogger.i('Selected topic: $topic');
    Get.to(
      () => TopicPage(topicId: topic['topic_id'].toString()),
      transition: Transition.downToUp,
    );
  }
}
