import 'package:flutter/material.dart';
import 'package:renmai/screens/contacts/contact_detail_screen.dart';
import 'package:renmai/screens/home/home_screen.dart';
import 'package:renmai/screens/splash/splash_screen.dart';
import 'package:renmai/utils/animation_utils.dart';

class AppRoutes {
  AppRoutes._();

  static final GlobalKey<NavigatorState> navigatorKey =
      GlobalKey<NavigatorState>();

  static const String splash = '/';
  static const String home = '/home';
  static const String contactDetail = '/contact-detail';

  static Route<dynamic> generateRoute(RouteSettings settings) {
    switch (settings.name) {
      case splash:
        return AnimationUtils.fadePageRoute(
          page: const SplashScreen(),
          settings: settings,
        );
      case home:
        return AnimationUtils.fadePageRoute(
          page: const HomeScreen(),
          settings: settings,
        );
      case contactDetail:
        final contactId = settings.arguments as String? ?? '';
        return AnimationUtils.slideHorizontalPageRoute(
          page: ContactDetailScreen(contactId: contactId),
          settings: settings,
        );
      default:
        return AnimationUtils.fadePageRoute(
          page: Scaffold(
            appBar: AppBar(title: const Text('页面未找到')),
            body: const Center(child: Text('这个页面不存在。')),
          ),
          settings: settings,
        );
    }
  }
}
