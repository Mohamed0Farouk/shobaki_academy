import 'package:awesome_video_player/awesome_video_player.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:shobaki_academy/controller/watching_page_controller.dart';
import 'package:shobaki_academy/services/statics.dart';

class WatchingPage extends StatelessWidget {
  final String videoUrl;
  const WatchingPage({super.key, required this.videoUrl});

  @override
  Widget build(BuildContext context) {
    final controller = Get.put(WatchingController(videoUrl));

    return Scaffold(
      appBar: AppBar(
        title: Text(
          "صفحة المشاهدة",
          style: Theme.of(
            context,
          ).textTheme.headlineMedium?.copyWith(color: Colors.white),
        ),
        centerTitle: true,
      ),
      body: SafeArea(
        child: Obx(() {
          if (controller.isLoading.value) {
            return Center(child: loading(context));
          }
          if (controller.errorMessage.isNotEmpty) {
            return Center(child: Text(controller.errorMessage.value));
          }
          return Column(
            children: [
              // Video player
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 15),
                  child: BetterPlayer(
                    controller: controller.betterPlayerController!,
                  ),
                ),
              ),
              // Duration display at bottom
              // Container(
              //   width: double.infinity,
              //   padding: const EdgeInsets.all(12),
              //   color: Theme.of(context).colorScheme.surface,
              //   child: Obx(() {
              //     final secs = controller.viewDurationSeconds.value;
              //     final mins = secs ~/ 60;
              //     final displaySecs = secs % 60;
              //     return Text(
              //       'مدة المشاهدة: ${mins}:${displaySecs.toString().padLeft(2, '0')} دقيقة',
              //       textAlign: TextAlign.center,
              //       style: Theme.of(context).textTheme.bodyMedium,
              //     );
              //   }),
              // ),
            ],
          );
        }),
      ),
    );
  }
}
