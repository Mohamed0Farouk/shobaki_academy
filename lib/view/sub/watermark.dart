import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:shobaki_academy/controller/watermark_controller.dart';

class PermanentWatermark extends StatelessWidget {
  const PermanentWatermark({super.key});

  @override
  Widget build(BuildContext context) {
    final watermarkController = Get.find<WatermarkController>();

    return Obx(() {
      if (!watermarkController.showWatermark.value) {
        watermarkController.stop(); // stop timer when hidden
        return const SizedBox.shrink();
      }

      watermarkController.start(); // start timer when visible

      return Positioned(
        left:
            watermarkController.left.value * MediaQuery.of(context).size.width,
        top: watermarkController.top.value * MediaQuery.of(context).size.height,
        child: IgnorePointer(
          child: Material(
            type: MaterialType.transparency,
            child: Text(
              watermarkController.waterMark.value,
              style: TextStyle(
                color: Colors.red[300],
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ),
      );
    });
  }
}
