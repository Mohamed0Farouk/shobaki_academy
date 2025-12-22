import 'dart:convert';
import 'package:get/get.dart';
import 'package:shobaki_academy/services/api.dart';
import 'package:shobaki_academy/services/locale_db.dart';
import 'package:shobaki_academy/services/statics.dart';

class LectureContentController extends GetxController {
  final ApiClient api = ApiClient();

  final isLoading = true.obs;
  final errorMessage = ''.obs;
  final lectureTitle = ''.obs;
  final lectureContent = <LectureContentItem>[].obs;

  String? lectureId;
  String? userId;

  /// 🔑 Cache FUTURES (NOT VALUES)
  final Map<String, Future<VideoViewResult>> _viewFutureCache = {};

  @override
  void onInit() {
    super.onInit();
    _initUser();
  }

  void _initUser() {
    try {
      final db = Get.find<LocalDB>().sharedPref!;
      final raw = db.getString('UserData');
      if (raw != null) {
        userId = jsonDecode(raw)['id'];
      }
    } catch (e) {
      projectLogger.e('User init error: $e');
    }
  }

  Future<void> loadLectureContent(String lecId) async {
    lectureId = lecId;

    isLoading.value = true;
    errorMessage.value = '';
    lectureContent.clear();
    _viewFutureCache.clear();

    try {
      final result = await api.fetchWithConditions(
        'lectures',
        filters: {'id': lectureId},
      );

      if (result.isEmpty) throw Exception('Lecture not found');

      final lecture = result.first;
      lectureTitle.value = lecture['title'] ?? 'محتوى المحاضرة';

      final videos = lecture['videos'] as Map?;
      final temp = <LectureContentItem>[];

      if (videos != null) {
        for (final entry in videos.entries) {
          final v = entry.value;
          temp.add(
            LectureContentItem(
              title: v['title'] ?? 'فيديو',
              description: v['description'],
              videoUrl: v['url'],
              maxViews: v['max_views'] ?? 0,
            ),
          );
        }
      }

      lectureContent.value = temp;
      isLoading.value = false;
    } catch (e, s) {
      projectLogger.e('$e\n$s');
      errorMessage.value = 'حدث خطأ في تحميل المحتوى';
      isLoading.value = false;
    }
  }

  /// 🎯 PUBLIC: used by UI
  Future<VideoViewResult> getVideoViewResult(
    LectureContentItem item,
  ) {
    return _viewFutureCache.putIfAbsent(
      item.videoUrl,
      () => _calculateViewResult(item),
    );
  }

  /// 🔥 YOUR LOGIC – unchanged, just wrapped
  Future<VideoViewResult> _calculateViewResult(
    LectureContentItem item,
  ) async {
    try {
      final logs = await api.fetchWithConditions(
        'logs',
        select: 'created_at',
        filters: {
          'type': 'video_view',
          'user_id': userId,
          'video_url': item.videoUrl,
        },
      );

      if (logs.isEmpty) {
        return VideoViewResult(
          viewCount: 0,
          isLocked: false,
        );
      }

      final times = logs
          .map<DateTime>((e) => DateTime.parse(e['created_at']))
          .toList()
        ..sort();

      final Map<DateTime, List<DateTime>> byDay = {};

      for (final t in times) {
        final key = DateTime(t.year, t.month, t.day);
        byDay.putIfAbsent(key, () => []).add(t);
      }

      int count = 0;

      for (final dayLogs in byDay.values) {
        int i = 0;
        while (i < dayLogs.length) {
          final start = dayLogs[i];
          var end = start.add(const Duration(hours: 3));

          final endOfDay = DateTime(
            start.year,
            start.month,
            start.day,
            23,
            59,
            59,
          );

          if (end.isAfter(endOfDay)) end = endOfDay;

          count++;
          while (i < dayLogs.length && !dayLogs[i].isAfter(end)) {
            i++;
          }
        }
      }

      final locked = item.maxViews > 0 && count >= item.maxViews;

      return VideoViewResult(
        viewCount: count,
        isLocked: locked,
      );
    } catch (e) {
      projectLogger.e('View calc error: $e');
      return VideoViewResult(viewCount: 0, isLocked: false);
    }
  }
}

/// ---------------- MODELS ----------------

class LectureContentItem {
  final String title;
  final String? description;
  final String videoUrl;
  final int maxViews;

  LectureContentItem({
    required this.title,
    this.description,
    required this.videoUrl,
    required this.maxViews,
  });
}

class VideoViewResult {
  final int viewCount;
  final bool isLocked;

  VideoViewResult({
    required this.viewCount,
    required this.isLocked,
  });
}
