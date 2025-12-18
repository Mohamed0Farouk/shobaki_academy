import 'package:get/get.dart';
import 'package:shobaki_academy/view/auth/forgot_password_page.dart';
import 'package:shobaki_academy/view/auth/login_page.dart';
import 'package:shobaki_academy/view/auth/otp_page.dart';
import 'package:shobaki_academy/view/auth/sign_up_page.dart';
import 'package:shobaki_academy/view/auth/splash_page.dart';
import 'package:shobaki_academy/view/home.dart';

class AppRouter {
  static final routes = [
    GetPage(name: '/', page: () => const SplashPage()),
    GetPage(name: '/home', page: () => const HomePage()),
    GetPage(name: '/login', page: () => const LoginPage()),
    GetPage(name: '/signup', page: () => const SignUpPage()),
    GetPage(name: '/otp', page: () => OtpPage()),
    GetPage(
      name: '/otp_forgot_password',
      page: () => OtpPage(isForgotPassword: true),
    ),
    GetPage(name: '/forgot_password', page: () => ForgotPasswordPage()),
  ];
}
