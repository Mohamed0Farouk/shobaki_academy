import 'package:flutter/material.dart';
import 'package:shobaki_academy/utils/constants.dart';

enum DeviceType { phone, tablet, desktop }

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

  static double cardMaxWidth(BuildContext context) {
    final device = getDeviceType(context);
    switch (device) {
      case DeviceType.phone:
        return AppConstants.cardMaxWidthPhone;
      case DeviceType.tablet:
        return AppConstants.cardMaxWidthTablet;
      case DeviceType.desktop:
        return AppConstants.cardMaxWidthDesktop;
    }
  }

  static double imageHeight(BuildContext context) {
    final device = getDeviceType(context);
    switch (device) {
      case DeviceType.phone:
        return AppConstants.imageHeightPhone;
      case DeviceType.tablet:
        return AppConstants.imageHeightTablet;
      case DeviceType.desktop:
        return AppConstants.imageHeightDesktop;
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
    if (width < 400) return 1;
    if (width < 600) return 2;
    if (width < 900) return 3;
    if (width < 1200) return 4;
    if (width < 1600) return 5;
    return 6;
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