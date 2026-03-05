import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:shobaki_academy/controller/auth_controller.dart';
import 'package:shobaki_academy/controller/splash_controller.dart';
import 'package:shobaki_academy/services/statics.dart';

class SplashPage extends StatelessWidget {
  const SplashPage({super.key});

  @override
  Widget build(BuildContext context) {
    final controller = Get.put(SplashController());
    final authController = Get.put(AuthController());

    return Scaffold(
      body: Center(
        child: Obx(() {
          final state = controller.status.value;

          if (state == null) {
            // still loading
            return loading(context);
          }

          // navigate based on status once loaded
          WidgetsBinding.instance.addPostFrameCallback((_) async {
            switch (state) {
              case AuthStatus.notLogged:
                Get.offAllNamed('/login');
                break;
              case AuthStatus.inReview:
                Get.offAllNamed('/home', parameters: {'inReview': 'true'});
                break;
              case AuthStatus.guest:
                await authController.enterGuestMode();
                break;
              case AuthStatus.notVerified:
                //Get.offAllNamed('/otp');
                print('not verified');
                break;
              case AuthStatus.loggedIn:
                //Get.offAllNamed('/home');
                print('logged in');
                break;
            }
          });

          // return empty placeholder
          return const SizedBox.shrink();
        }),
      ),
    );
  }
}
