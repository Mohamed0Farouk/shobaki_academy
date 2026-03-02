import 'dart:convert';
import 'package:animate_do/animate_do.dart';
import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:get/get.dart';
import 'package:http/http.dart' as http;
import 'package:shobaki_academy/model/card_model.dart';
import 'package:shobaki_academy/services/api.dart';
import 'package:shobaki_academy/services/locale_db.dart';
import 'package:shobaki_academy/services/statics.dart';

class TopicPage extends StatefulWidget {
  const TopicPage({super.key, required this.topicId});
  final String topicId;

  @override
  State<TopicPage> createState() => _TopicPageState();
}

class _TopicPageState extends State<TopicPage> {
  final ApiClient _apiClient = ApiClient();

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    final isDesktop = size.width > 900;
    final crossAxisCount = isDesktop
        ? (size.width > 1600
              ? 5
              : size.width > 1200
              ? 4
              : 4)
        : 1;

    return Scaffold(
      backgroundColor: const Color(0xfff7f7f7),
      appBar: AppBar(
        title: Text(
          ' المحتوى',
          style: Theme.of(
            context,
          ).textTheme.headlineMedium?.copyWith(color: Colors.white),
        ),
        centerTitle: true,
      ),
      body: SafeArea(
        child: FutureBuilder(
          future: fetcher(),
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.done) {
              return Directionality(
                textDirection: TextDirection.ltr,
                child: Padding(
                  padding: EdgeInsets.symmetric(
                    horizontal: isDesktop ? 20 : 10,
                    vertical: isDesktop ? 12 : 10,
                  ),
                  child: snapshot.data == null
                      ? Center(child: Text('لا توجد بيانات'))
                      : FadeInUp(
                          duration: const Duration(milliseconds: 500),
                          child: _buildResponsiveLayout(
                            snapshot.data as List<Widget>,
                            isDesktop,
                            crossAxisCount,
                          ),
                        ),
                ),
              );
            } else {
              return loading(context);
            }
          },
        ),
      ),
    );
  }

  Widget _buildResponsiveLayout(
    List<Widget> items,
    bool isDesktop,
    int crossAxisCount,
  ) {
    if (!isDesktop) {
      final itemWidth = (MediaQuery.of(context).size.width - 50) / 2;
      // 28 = horizontal padding (8+8) + spacing between columns (12)

      return SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8),
          child: Wrap(
            spacing: 12, // horizontal gap between columns
            runSpacing: 12, // vertical gap between rows
            children: items.map((item) {
              return SizedBox(
                width: itemWidth,
                child: item, // card sizes itself in height naturally
              );
            }).toList(),
          ),
        ),
      );
    }

    return GridView.builder(
      shrinkWrap: true,
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: crossAxisCount,
        mainAxisSpacing: 12,
        crossAxisSpacing: 10,
        childAspectRatio: 0.75,
      ),
      itemCount: items.length,
      itemBuilder: (context, index) {
        return items[index];
      },
    );
  }

  fetcher() async {
    List response = await _apiClient.fetchWithConditions(
      'topics',
      filters: {'id': widget.topicId},
    );

    Map topic = response[0];

    List widgets;

    if (topic['is_parent']) {
      widgets = await subTopicsHandler(topic['children']);
    } else {
      widgets = await lecturesHandler(context, topic['lectures']);
    }

    return widgets;
  }

  Future<List<Widget>> subTopicsHandler(List topicsList) async {
    final topics = [];

    try {
      for (var element in topicsList) {
        List response = await _apiClient.fetchWithConditions(
          'topics',
          filters: {'id': element},
        );
        Map topic = response[0];
        topics.add(topic);
      }
    } on Exception catch (e) {
      print('Error fetching subtopics: $e');
    }

    final List<Widget> widgets = [];

    for (int idx = 0; idx < topics.length; idx++) {
      final element = topics[idx];
      widgets.add(
        FadeInUp(
          from: 100,
          duration: const Duration(milliseconds: 600),
          delay: Duration(milliseconds: 50 + (idx * 80)),
          child: CardModel(
            type: CardTypes.enrolledTopic,
            title: element['title'],
            thumbnail: element['thumbnail'],
            description: element['description'],
            id: element['id'],
          ),
        ),
      );
    }

    return widgets;
  }

  Future<List<Widget>> lecturesHandler(context, lecturesList) async {
    final ApiClient api = ApiClient();

    final LocalDB services = Get.find();
    final localDb = services.sharedPref;

    final jsonUserData = localDb!.getString('UserData');
    final Map userData = jsonDecode(jsonUserData!);

    final data = [];

    final List<Widget> widgets = [];

    for (var element in lecturesList) {
      final fetchedLectureData = await api.fetchWithConditions(
        'lectures',
        filters: {'id': element},
      );
      data.add(fetchedLectureData[0]);
    }

    if (data.isNotEmpty) {
      final List<Map<String, dynamic>> sortedData = data
          .map((item) => item as Map<String, dynamic>)
          .toList();

      sortedData.sort((a, b) {
        final aDate = DateTime.parse(a['created_at']);
        final bDate = DateTime.parse(b['created_at']);
        return aDate.compareTo(bDate);
      });

      for (var i = 0; i < sortedData.length; i++) {
        if (sortedData[i]['videos'] != null) {
          for (final MapEntry entry in sortedData[i]['videos'].entries) {
            final value = entry.value;
            final videoUrl = value['url'];
            final maxViewCount =
                value['max_view_count'] ?? 0; // Get max views from video data

            final userViews = await _getUserVideoViewCount(
              videoUrl,
              userData['id'],
            );
            final isLimited = await _isVideoViewLimitReached(
              videoUrl,
              maxViewCount,
              userViews,
              userData['id'],
            );

            Widget card = CardModel(
              type: CardTypes.video,
              title: value['title'],
              description: value['description'],
              thumbnail: sortedData[i]['thumbnail'],
              // note: Text(
              //   ' المشاهدات  ($userViews/$maxViewCount)',
              //   style: Theme.of(context).textTheme.bodySmall,
              // ),
              id: '',
              url: value['url'],
            );

            print(
              'user views for ${value['title']}: $userViews / $maxViewCount',
            );

            if (isLimited) {
              final lockMsg =
                  'وصلت للحد الأقصى من\n المشاهدات ($userViews/$maxViewCount)';
              card = Stack(
                children: [
                  Padding(padding: const EdgeInsets.all(15), child: card),
                  buildLockedOverlay(lockMsg),
                ],
              );
            }
            widgets.add(card);
          }
        }
      }
    }
    return widgets;
  }

  Future<int> _getUserVideoViewCount(String videoUrl, String userId) async {
    try {
      final apiBaseUrl = dotenv.env['ALSHOBAKI_API'];

      if (apiBaseUrl == null || apiBaseUrl.isEmpty) {
        projectLogger.e('ALSHOBAKI_API not found in .env');
        return 0;
      }

      final uri = Uri.parse(
        '${apiBaseUrl}api/videos/view-count',
      ).replace(queryParameters: {'videoUrl': videoUrl, 'userId': userId});

      final response = await http
          .get(
            uri,
            headers: {
              'Content-Type': 'application/json',
              // Add authorization header if needed
              // 'Authorization': 'Bearer $token',
            },
          )
          .timeout(
            const Duration(seconds: 10),
            onTimeout: () {
              throw Exception('Request timeout');
            },
          );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final viewCount = data['data']['viewCount'] as int;

        return viewCount;
      } else {
        projectLogger.e(
          'Error fetching video view count: ${response.statusCode} - ${response.body}',
        );
        return 0;
      }
    } catch (e) {
      projectLogger.e('Error fetching video view count: $e');
      return 0;
    }
  }

  /// Check if video view limit is reached
  Future<bool> _isVideoViewLimitReached(
    String videoUrl,
    int maxViewCount,
    int userViewCount,
    String userId,
  ) async {
    if (maxViewCount <= 0) return false; // No limit set

    return userViewCount >= maxViewCount;
  }

  Widget buildLockedOverlay(String message) {
    return Positioned.fill(
      child: Card(
        shadowColor: Colors.black.withOpacity(0.12),
        elevation: 4,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(25)),
        color: Colors.black.withOpacity(0.5),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              message,
              textAlign: TextAlign.center,
              maxLines: 3,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(
                context,
              ).textTheme.bodyLarge!.copyWith(color: Colors.white),
            ),
            const Icon(Icons.lock_rounded, color: Colors.white),
          ],
        ),
      ),
    );
  }
}
