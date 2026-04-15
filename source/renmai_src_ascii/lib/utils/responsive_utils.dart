import 'dart:io' show Platform;
import 'dart:ui' show FlutterView, PlatformDispatcher;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

class ResponsiveUtils {
  ResponsiveUtils._();

  static FlutterView get _view => PlatformDispatcher.instance.views.first;

  static DeviceType get deviceType {
    if (kIsWeb) {
      return DeviceType.web;
    }
    if (Platform.isWindows || Platform.isMacOS || Platform.isLinux) {
      return DeviceType.desktop;
    }
    if (Platform.isAndroid || Platform.isIOS) {
      return DeviceType.mobile;
    }
    return DeviceType.mobile;
  }

  static bool get isMobile =>
      deviceType != DeviceType.desktop && screenWidth < mobileBreakpoint;

  static bool get isTablet =>
      deviceType != DeviceType.desktop &&
      screenWidth >= mobileBreakpoint &&
      screenWidth < tabletBreakpoint;

  static bool get isDesktop =>
      deviceType == DeviceType.desktop ||
      (deviceType == DeviceType.web && screenWidth >= tabletBreakpoint);

  static bool get isWeb => deviceType == DeviceType.web;

  static double get screenWidth =>
      _view.physicalSize.width / _view.devicePixelRatio;

  static double get screenHeight =>
      _view.physicalSize.height / _view.devicePixelRatio;

  static const double mobileBreakpoint = 768;
  static const double tabletBreakpoint = 1200;

  static LayoutType get layoutType {
    final width = screenWidth;
    if (width < mobileBreakpoint) {
      return LayoutType.mobile;
    }
    if (width < tabletBreakpoint) {
      return LayoutType.tablet;
    }
    return LayoutType.desktop;
  }

  static double responsiveValue(double mobile,
      {double? tablet, double? desktop}) {
    final type = layoutType;
    if (type == LayoutType.desktop && desktop != null) {
      return desktop;
    }
    if (type == LayoutType.tablet && tablet != null) {
      return tablet;
    }
    return mobile;
  }

  static EdgeInsets responsivePadding({
    double? mobile,
    double? tablet,
    double? desktop,
  }) {
    final value = responsiveValue(
      mobile ?? 16,
      tablet: tablet ?? 24,
      desktop: desktop ?? 32,
    );
    return EdgeInsets.all(value);
  }

  static EdgeInsets horizontalPadding({
    double? mobile,
    double? tablet,
    double? desktop,
  }) {
    final value = responsiveValue(
      mobile ?? 16,
      tablet: tablet ?? 24,
      desktop: desktop ?? 48,
    );
    return EdgeInsets.symmetric(horizontal: value);
  }
}

enum DeviceType {
  mobile,
  tablet,
  desktop,
  web,
}

enum LayoutType {
  mobile,
  tablet,
  desktop,
}

class ResponsiveBuilder extends StatelessWidget {
  final Widget Function(BuildContext context, LayoutType layoutType) builder;

  const ResponsiveBuilder({
    super.key,
    required this.builder,
  });

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final layoutType =
            constraints.maxWidth < ResponsiveUtils.mobileBreakpoint
                ? LayoutType.mobile
                : constraints.maxWidth < ResponsiveUtils.tabletBreakpoint
                    ? LayoutType.tablet
                    : LayoutType.desktop;
        return builder(context, layoutType);
      },
    );
  }
}

class ResponsiveColumn extends StatelessWidget {
  final List<Widget> children;
  final MainAxisAlignment mainAxisAlignment;
  final CrossAxisAlignment crossAxisAlignment;
  final double? mobileCrossAxisCount;
  final double? tabletCrossAxisCount;
  final double? desktopCrossAxisCount;
  final double spacing;
  final double runSpacing;

  const ResponsiveColumn({
    super.key,
    required this.children,
    this.mainAxisAlignment = MainAxisAlignment.start,
    this.crossAxisAlignment = CrossAxisAlignment.start,
    this.mobileCrossAxisCount,
    this.tabletCrossAxisCount,
    this.desktopCrossAxisCount,
    this.spacing = 16,
    this.runSpacing = 16,
  });

  @override
  Widget build(BuildContext context) {
    return ResponsiveBuilder(
      builder: (context, layoutType) {
        final crossAxisCount = _getCrossAxisCount(layoutType);

        return Wrap(
          spacing: runSpacing,
          runSpacing: spacing,
          children: [
            for (int i = 0; i < children.length; i += crossAxisCount.toInt())
              Row(
                mainAxisAlignment: mainAxisAlignment,
                crossAxisAlignment: crossAxisAlignment,
                children: [
                  for (int j = i;
                      j < i + crossAxisCount.toInt() && j < children.length;
                      j++)
                    Expanded(child: children[j]),
                ],
              ),
          ],
        );
      },
    );
  }

  double _getCrossAxisCount(LayoutType layoutType) {
    switch (layoutType) {
      case LayoutType.mobile:
        return mobileCrossAxisCount ?? 1;
      case LayoutType.tablet:
        return tabletCrossAxisCount ?? 2;
      case LayoutType.desktop:
        return desktopCrossAxisCount ?? 3;
    }
  }
}

class ResponsiveGrid extends StatelessWidget {
  final List<Widget> children;
  final int mobileColumns;
  final int tabletColumns;
  final int desktopColumns;
  final double spacing;
  final double runSpacing;

  const ResponsiveGrid({
    super.key,
    required this.children,
    this.mobileColumns = 1,
    this.tabletColumns = 2,
    this.desktopColumns = 3,
    this.spacing = 16,
    this.runSpacing = 16,
  });

  @override
  Widget build(BuildContext context) {
    return ResponsiveBuilder(
      builder: (context, layoutType) {
        final columns = _getColumns(layoutType);

        return GridView.count(
          crossAxisCount: columns,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          mainAxisSpacing: spacing,
          crossAxisSpacing: runSpacing,
          childAspectRatio: columns == 1 ? 1.5 : 1.2,
          children: children,
        );
      },
    );
  }

  int _getColumns(LayoutType layoutType) {
    switch (layoutType) {
      case LayoutType.mobile:
        return mobileColumns;
      case LayoutType.tablet:
        return tabletColumns;
      case LayoutType.desktop:
        return desktopColumns;
    }
  }
}

class ResponsiveVisibility extends StatelessWidget {
  final Widget child;
  final bool visibleOnMobile;
  final bool visibleOnTablet;
  final bool visibleOnDesktop;

  const ResponsiveVisibility({
    super.key,
    required this.child,
    this.visibleOnMobile = true,
    this.visibleOnTablet = true,
    this.visibleOnDesktop = true,
  });

  @override
  Widget build(BuildContext context) {
    final layoutType = ResponsiveUtils.layoutType;
    bool isVisible = false;

    switch (layoutType) {
      case LayoutType.mobile:
        isVisible = visibleOnMobile;
        break;
      case LayoutType.tablet:
        isVisible = visibleOnTablet;
        break;
      case LayoutType.desktop:
        isVisible = visibleOnDesktop;
        break;
    }

    return isVisible ? child : const SizedBox.shrink();
  }
}
