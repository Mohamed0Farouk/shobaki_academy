import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:shobaki_academy/services/api.dart';
import 'package:shobaki_academy/services/locale_db.dart';
import 'package:shobaki_academy/services/statics.dart';
import 'package:shobaki_academy/view/results/answers.dart';

class ResultsController extends GetxController {
  final ApiClient _api = ApiClient();

  // public
  final TextEditingController searchController = TextEditingController();
  final RxList<Map<String, dynamic>> exams = <Map<String, dynamic>>[].obs;
  final RxList<Map<String, dynamic>> homeworks = <Map<String, dynamic>>[].obs;
  final RxList<Map<String, dynamic>> results = <Map<String, dynamic>>[].obs;

  // internal
  final RxBool sheetOpen = false.obs;
  // loading indicator for search
  final RxBool isSearching = false.obs;
  final RxBool isLoading = true.obs;

  final String? userStageArg;

  ResultsController({this.userStageArg});

  @override
  void onClose() {
    searchController.dispose();
    super.onClose();
  }

  /// Load recommended and latest topics using ApiClient.fetchWithConditions
  /// Applies stage filter if available.
  Future<void> loadResults() async {
    final LocalDB db = Get.find();
    final localDb = db.sharedPref;
    final jsonUserData = localDb?.getString('UserData');
    final Map<String, dynamic>? userData = jsonUserData != null
        ? jsonDecode(jsonUserData)
        : null;
    try {
      // fetch exams (no paging)
      final examsResp = await _api.fetchWithConditions(
        'students_solved_exams',
        filters: {'student_id': userData!['id']},
        orderBy: 'created_at',
        ascending: true,
        select: '*, exam:exams(*)',
      );

      final homeworksResp = await _api.fetchWithConditions(
        'students_solved_homeworks',
        filters: {'student_id': userData['id']},
        orderBy: 'created_at',
        ascending: false,
        select: '*, homework:homeworks(*)',
      );

      exams.assignAll(
        examsResp.map((e) => Map<String, dynamic>.from(e as Map)).toList(),
      );

      homeworks.assignAll(
        homeworksResp.map((e) => Map<String, dynamic>.from(e as Map)).toList(),
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
  void onSearchSubmitted(String value, context) {
    _doSearch(value, context);
  }

  Future<void> _doSearch(String q, context) async {
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

    // ensure we have the user id (filter by user_id only)
    final LocalDB db = Get.find();
    final localDb = db.sharedPref;
    final jsonUserData = localDb?.getString('UserData');
    final Map<String, dynamic>? userData = jsonUserData != null
        ? jsonDecode(jsonUserData)
        : null;
    final userId = userData != null ? userData['id'] : null;
    if (userId == null) {
      Get.snackbar(
        'خطأ',
        'لم يتم العثور على معرف المستخدم',
        backgroundColor: Colors.red,
        snackPosition: SnackPosition.BOTTOM,
      );
      isSearching.value = false;
      return;
    }

    if (!sheetOpen.value) {
      _showResultsSheet(context);
    }

    isSearching.value = true;
    try {
      final pattern = '%$query%';

      // title and description filters including user_id
      final titleFilter = <String, dynamic>{
        'title': {'operator': 'ilike', 'value': pattern},
        'student_id': userId,
      };
      final descFilter = <String, dynamic>{
        'description': {'operator': 'ilike', 'value': pattern},
        'student_id': userId,
      };

      final List<Map<String, dynamic>> fetched = [];
      final seen = <String>{};

      Future<void> fetchAndAppend(
        String table,
        Map<String, dynamic> filters,
        String source,
      ) async {
        final resp = await _api.fetchWithConditions(table, filters: filters);
        for (final r in resp) {
          final map = Map<String, dynamic>.from(r as Map);
          final id = map['id']?.toString() ?? UniqueKey().toString();
          final key = '${table}_$id';
          if (!seen.contains(key)) {
            seen.add(key);
            map['__source'] = source;
            map['__table'] = table;
            fetched.add(map);
          }
        }
      }

      // search exams (title + description)
      await fetchAndAppend(
        'students_solved_exams',
        Map.from(titleFilter),
        'exam',
      );
      await fetchAndAppend(
        'students_solved_exams',
        Map.from(descFilter),
        'exam',
      );

      // search homeworks (title + description)
      await fetchAndAppend(
        'students_solved_homeworks',
        Map.from(titleFilter),
        'homework',
      );
      await fetchAndAppend(
        'students_solved_homeworks',
        Map.from(descFilter),
        'homework',
      );

      results.assignAll(fetched);
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
                          onSelectTopic(item);
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
  void onSelectTopic(Map<String, dynamic> item) {
    // Example: navigate to a detail route; change to your real route/widget
    // Get.toNamed('/topicDetail', arguments: topic);
    // For now, just print and close sheet if open
    debugPrint('Selected topic: ${item['id'] ?? item['title']}');
    Get.to(() => AnswersPage(answers: item['answers'] ?? {}));
  }
}
