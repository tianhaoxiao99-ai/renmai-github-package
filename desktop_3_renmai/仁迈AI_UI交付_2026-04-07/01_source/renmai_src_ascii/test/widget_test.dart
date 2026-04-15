import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:renmai/config/app_theme.dart';
import 'package:renmai/providers/analysis_provider.dart';
import 'package:renmai/providers/display_settings_provider.dart';
import 'package:renmai/providers/gift_provider.dart';
import 'package:renmai/providers/relationship_provider.dart';
import 'package:renmai/screens/home/home_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _TestAnalysisProvider extends AnalysisProvider {
  @override
  Future<void> initialize() async {}
}

void main() {
  testWidgets(
    'Home screen explains product and does not overflow on desktop width',
    (WidgetTester tester) async {
      SharedPreferences.setMockInitialValues({});
      await tester.binding.setSurfaceSize(const Size(1440, 960));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      await tester.pumpWidget(
        MultiProvider(
          providers: [
            ChangeNotifierProvider(create: (_) => DisplaySettingsProvider()),
            ChangeNotifierProvider<AnalysisProvider>(
              create: (_) => _TestAnalysisProvider(),
            ),
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
          child: MaterialApp(
            theme: AppTheme.lightTheme(
              preset: AppThemePreset.warmApricot,
            ),
            home: const HomeScreen(),
          ),
        ),
      );

      await tester.pump();
      await tester.pump(const Duration(milliseconds: 800));

      expect(find.byType(HomeScreen), findsOneWidget);
      expect(find.text('先判断今天该先处理哪段关系。'), findsOneWidget);
      expect(find.text('导入记录'), findsOneWidget);
      expect(find.text('系统分析'), findsOneWidget);
      expect(find.text('生成建议'), findsOneWidget);
      expect(find.text('立即导入'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );
}
