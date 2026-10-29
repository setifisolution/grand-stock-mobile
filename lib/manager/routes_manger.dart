import 'package:flutter/material.dart';

import '../screens/auth/change_password_screen.dart';
import '../screens/auth/login_screen.dart';
import '../screens/home_screen.dart';
import '../screens/splash_screen.dart';

class Routes {
  static const String splashRoute = "/";
  static const String login = "/Login";
  static const String forgetPassword = "/ForgetPassword";
  static const String mainRoute = "/Main";
  static const String account = "/Account";
  static const String changePassword = "/ChangePassword";
  static const String settings = "/Settings";
  static const String profile = "/Profile";
  static const String dashBoard = "/DashBoard";
  static const String productDetails = "/productDetails";
  static const String search = "/SearchScreen";
}

class RouteGenerator {
  static Route<dynamic> getRoute(RouteSettings settings) {
    switch (settings.name) {
      case Routes.splashRoute:
        return MaterialPageRoute(builder: (_) => const SplashScreen());
      case Routes.login:
        return MaterialPageRoute(builder: (_) => const LoginScreen());
      case Routes.changePassword:
        return MaterialPageRoute(builder: (_) => const ChangePasswordScreen());
      case Routes.mainRoute:
        return MaterialPageRoute(builder: (_) => const HomeScreen());
      default:
        return undefinedRoute(settings);
    }
  }

  static Route<dynamic> undefinedRoute(RouteSettings settings) {
    return MaterialPageRoute(
      builder: (_) =>
          const Scaffold(body: Center(child: Text('404 - Page not found'))),
    );
  }
}
