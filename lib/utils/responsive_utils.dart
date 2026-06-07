import 'dart:math';
import 'package:flutter/material.dart';
import 'package:shobaki_academy/utils/constants.dart';

enum DeviceType { phone, tablet, desktop }
enum HeightCategory { short, medium, tall }

class ResponsiveUtils {
  static DeviceType getDeviceType(BuildContext context) {
    final width = MediaQuery.of(context).size.width;
    if (width < AppConstants.phoneBreakpoint) return DeviceType.phone;
    if (width < AppConstants.tabletBreakpoint) return DeviceType.tablet;
    return DeviceType.desktop;
  }

  static bool isPhone(BuildContext context) =>
      MediaQuery.of(context).size.width < AppConstants.phoneBreakpoint;

  static bool isTablet(BuildContext context) {
    final width = MediaQuery.of(context).size.width;
    return width >= AppConstants.phoneBreakpoint &&
        width < AppConstants.tabletBreakpoint;
  }

  static bool isDesktop(BuildContext context) =>
      MediaQuery.of(context).size.width >= AppConstants.tabletBreakpoint;

  static HeightCategory getHeightCategory(BuildContext context) {
    final height = MediaQuery.of(context).size.height;
    if (height < AppConstants.heightShortBreakpoint) return HeightCategory.short;
    if (height < AppConstants.heightMediumBreakpoint) return HeightCategory.medium;
    return HeightCategory.tall;
  }

  static double sectionSpacing(BuildContext context) {
    switch (getHeightCategory(context)) {
      case HeightCategory.short:
        return 8;
      case HeightCategory.medium:
        return 12;
      case HeightCategory.tall:
        return 16;
    }
  }

  static double cardGridGap(BuildContext context) {
    switch (getHeightCategory(context)) {
      case HeightCategory.short:
        return 8;
      case HeightCategory.medium:
        return 10;
      case HeightCategory.tall:
        return 12;
    }
  }

  static double cardScaleFactor(BuildContext context) {
    final size = MediaQuery.of(context).size;
    final widthScale = size.width / 1280.0;
    final heightScale = size.height / 720.0;
    return max(widthScale, heightScale).clamp(1.0, 2.0);
  }

  static double cardImageAspectRatio(BuildContext context) {
    final device = getDeviceType(context);
    if (device == DeviceType.phone) {
      return AppConstants.cardAspectRatio;
    }
    final size = MediaQuery.of(context).size;
    final viewportAspect = size.width / size.height;
    const referenceAspect = 1280.0 / 720.0;
    if (viewportAspect < referenceAspect) {
      final adjusted = AppConstants.cardAspectRatio * (viewportAspect / referenceAspect);
      return adjusted.clamp(1.0, 2.0);
    }
    return AppConstants.cardAspectRatio;
  }

  static double cardMaxWidth(BuildContext context) {
    final device = getDeviceType(context);
    switch (device) {
      case DeviceType.phone:
        return AppConstants.cardMaxWidthPhone;
      case DeviceType.tablet:
        return AppConstants.cardMaxWidthTablet;
      case DeviceType.desktop:
        final scale = cardScaleFactor(context);
        return (AppConstants.cardMaxWidthDesktop * scale).clamp(280, 600);
    }
  }

  static double sidebarWidth(BuildContext context, {bool collapsed = false}) {
    final device = getDeviceType(context);
    if (collapsed) {
      switch (device) {
        case DeviceType.phone:
          return AppConstants.sidebarCollapsedPhone;
        case DeviceType.tablet:
          return AppConstants.sidebarCollapsedTablet;
        case DeviceType.desktop:
          return AppConstants.sidebarCollapsedDesktop;
      }
    }
    switch (device) {
      case DeviceType.phone:
        return AppConstants.sidebarExpandedPhone;
      case DeviceType.tablet:
        return AppConstants.sidebarExpandedTablet;
      case DeviceType.desktop:
        return AppConstants.sidebarExpandedDesktop;
    }
  }

  static int gridCrossAxisCount(BuildContext context) {
    final width = MediaQuery.of(context).size.width;
    return gridColumnsFromTargetWidth(width, targetCardWidth: 380, maxColumns: 4);
  }

  static int gridColumnsFromTargetWidth(double availableWidth, {double targetCardWidth = 380, int maxColumns = 4}) {
    if (availableWidth < 500) return 1;
    final cols = (availableWidth / targetCardWidth).floor();
    return cols.clamp(1, maxColumns);
  }

  static double cardRadius(BuildContext context) {
    final device = getDeviceType(context);
    switch (device) {
      case DeviceType.phone:
        return AppConstants.cardRadiusPhone;
      case DeviceType.tablet:
        return AppConstants.cardRadiusTablet;
      case DeviceType.desktop:
        return AppConstants.cardRadiusDesktop;
    }
  }

  static double titleSize(BuildContext context, {bool isSmall = false}) {
    final device = getDeviceType(context);
    final base = isSmall ? 12.0 : 15.0;
    switch (device) {
      case DeviceType.phone:
        return base;
      case DeviceType.tablet:
        return base + 1;
      case DeviceType.desktop:
        return base + 2;
    }
  }

  static EdgeInsets cardPadding(BuildContext context) {
    final device = getDeviceType(context);
    switch (device) {
      case DeviceType.phone:
        return const EdgeInsets.all(12);
      case DeviceType.tablet:
        return const EdgeInsets.all(14);
      case DeviceType.desktop:
        return const EdgeInsets.all(16);
    }
  }
}