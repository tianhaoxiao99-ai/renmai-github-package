import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:renmai/config/app_constants.dart';
import 'package:renmai/config/app_routes.dart';
import 'package:renmai/config/app_theme.dart';
import 'package:renmai/providers/analysis_provider.dart';
import 'package:renmai/providers/display_settings_provider.dart';
import 'package:renmai/providers/gift_provider.dart';
import 'package:renmai/providers/relationship_provider.dart';
import 'package:renmai/services/storage_service.dart';
import 'package:renmai/utils/responsive_utils.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await StorageService.instance.initialize();
  _setupSystemUi();
  runApp(const RenMaiApp());
}

void _setupSystemUi() {
  if (ResponsiveUtils.isMobile || ResponsiveUtils.isTablet) {
    SystemChrome.setPreferredOrientations([
      DeviceOrientation.portraitUp,
      DeviceOrientation.portraitDown,
    ]);
  }

  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.dark,
      statusBarBrightness: Brightness.light,
    ),
  );
}

class RenMaiApp extends StatelessWidget {
  const RenMaiApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => DisplaySettingsProvider()),
        ChangeNotifierProvider(create: (_) => AnalysisProvider()),
        ChangeNotifierProxyProvider<AnalysisProvider, RelationshipProvider>(
          create: (_) => RelationshipProvider(),
          update: (_, analysis, relationship) {
            final provider = relationship ?? RelationshipProvider();
            provider.syncFromAnalysis(analysis);
            return provider;
          },
        ),
        ChangeNotifierProxyProvider<AnalysisProvider, GiftProvider>(
          create: (_) => GiftProvider(),
          update: (_, analysis, gift) {
            final provider = gift ?? GiftProvider();
            provider.syncFromAnalysis(analysis);
            return provider;
          },
        ),
      ],
      child: Consumer<DisplaySettingsProvider>(
        builder: (context, displaySettings, _) {
          AppTheme.setActivePreset(displaySettings.themePreset);
          return MaterialApp(
            title: AppConstants.appName,
            debugShowCheckedModeBanner: false,
            theme: AppTheme.lightTheme(
              preset: displaySettings.themePreset,
              highContrast: displaySettings.highContrast,
            ),
            darkTheme: AppTheme.darkTheme(
              preset: displaySettings.themePreset,
              highContrast: displaySettings.highContrast,
            ),
            themeMode: displaySettings.themeMode,
            initialRoute: AppRoutes.splash,
            onGenerateRoute: AppRoutes.generateRoute,
            navigatorKey: AppRoutes.navigatorKey,
            builder: (context, child) {
              return MediaQuery(
                data: MediaQuery.of(context).copyWith(
                  textScaler: TextScaler.noScaling,
                  highContrast: displaySettings.highContrast,
                ),
                child: child ?? const SizedBox.shrink(),
              );
            },
          );
        },
      ),
    );
  }
}
