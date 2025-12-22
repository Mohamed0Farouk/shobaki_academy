// import 'package:flutter/material.dart';
// import 'package:get/get.dart';
// import 'package:shobaki_academy/controller/lecture_content_controller.dart';
// import 'package:shobaki_academy/model/card_model.dart';

// class LectureContentPage extends StatelessWidget {
//   final String lectureId;

//   const LectureContentPage({
//     super.key,
//     required this.lectureId,
//   });

//   @override
//   Widget build(BuildContext context) {
//     final controller = Get.put(LectureContentController());
//     controller.loadLectureContent(lectureId);

//     return Scaffold(
//       backgroundColor: const Color(0xfff7f7f7),
//       appBar: AppBar(
//         title: Obx(() => Text(controller.lectureTitle.value)),
//         centerTitle: true,
//       ),
//       body: Obx(() {
//         if (controller.isLoading.value) {
//           return const Center(child: CircularProgressIndicator());
//         }

//         if (controller.errorMessage.isNotEmpty) {
//           return Center(child: Text(controller.errorMessage.value));
//         }

//         return ListView.builder(
//           padding: const EdgeInsets.all(12),
//           itemCount: controller.lectureContent.length,
//           itemBuilder: (context, index) {
//             final item = controller.lectureContent[index];

//             return FutureBuilder<VideoViewResult>(
//               future: controller.getVideoViewResult(item),
//               builder: (context, snapshot) {
//                 final result = snapshot.data;

//                 final viewText = result == null
//                     ? '...'
//                     : 'عدد المشاهدات: ${result.viewCount}'
//                         '${item.maxViews > 0 ? ' / ${item.maxViews}' : ''}';

//                 final isLocked = result?.isLocked ?? false;

//                 return Padding(
//                   padding: const EdgeInsets.only(bottom: 12),
//                   child: Stack(
//                     children: [
//                       AbsorbPointer(
//                         absorbing: isLocked,
//                         child: CardModel(
//                           type: CardTypes.video,
//                           title: item.title,
//                           description: item.description ?? '',
//                           note: viewText, // ✅ NEW
//                           url: item.videoUrl,
//                         ),
//                       ),

//                       if (isLocked)
//                         Positioned.fill(
//                           child: Container(
//                             decoration: BoxDecoration(
//                               color: Colors.black.withOpacity(0.6),
//                               borderRadius: BorderRadius.circular(12),
//                             ),
//                             child: Column(
//                               mainAxisAlignment: MainAxisAlignment.center,
//                               children: const [
//                                 Icon(Icons.lock,
//                                     color: Colors.white, size: 48),
//                                 SizedBox(height: 8),
//                                 Text(
//                                   'تم الوصول للحد الأقصى للمشاهدات',
//                                   style: TextStyle(
//                                       color: Colors.white,
//                                       fontWeight: FontWeight.bold),
//                                 ),
//                               ],
//                             ),
//                           ),
//                         ),
//                     ],
//                   ),
//                 );
//               },
//             );
//           },
//         );
//       }),
//     );
//   }
// }
