import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';

class NetworkController extends GetxController {
  RxBool connectedToInternet = true.obs;
  final Connectivity connectivity = Connectivity();

  @override
  void onInit() {
    super.onInit();
    connectivity.onConnectivityChanged.listen(_updateConnectionState);
  }

  void _updateConnectionState(List<ConnectivityResult> connectivityResult) {
    if (connectivityResult.contains(ConnectivityResult.none)) {
      connectedToInternet = false.obs;

      // Display a BottomSheet when there's no internet connection
      Get.bottomSheet(
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(20),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.signal_wifi_off,
                size: 100,
                color: Colors.red,
              ),
              const SizedBox(height: 20),
              Text(
                'لا انترنت',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Colors.black,
                ),
              ),
            ],
          ),
        ),
        isDismissible: false, // User cannot dismiss this bottom sheet
        enableDrag: false, // Disable dragging the bottom sheet
        backgroundColor:
            Colors.transparent, // Transparent background for the bottom sheet
      );
    } else {
      // Close the bottom sheet if it's open and we have an internet connection
      if (Get.isBottomSheetOpen != null && Get.isBottomSheetOpen!) {
        Get.back(); // Close the bottom sheet
      }

      connectedToInternet = true.obs;
    }
  }
}
