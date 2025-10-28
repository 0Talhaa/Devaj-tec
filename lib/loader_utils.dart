import 'package:flutter/material.dart';
import 'package:start_app/custom_app_loader.dart';
import 'package:start_app/connectivity_service.dart';

/// Utility class for managing app-wide loading states
class LoaderUtils {
  static OverlayEntry? _overlayEntry;

  /// Show loader with optional message
  static void show(BuildContext context, {String? message}) {
    AppLoaderOverlay.show(context, message: message);
  }

  /// Hide the loader
  static void hide() {
    AppLoaderOverlay.hide();
  }

  /// Show loader for async operations with automatic hide
  static Future<T> showForOperation<T>(
    BuildContext context,
    Future<T> operation, {
    String? message,
  }) async {
    show(context, message: message);
    try {
      final result = await operation;
      return result;
    } finally {
      hide();
    }
  }

  /// Show loader widget for stateful widgets
  static Widget buildLoader({String? message, double? size}) {
    return AppLoader(
      message: message,
      size: size ?? 50.0,
    );
  }

  /// Check internet connectivity before operations
  static bool hasConnection() {
    return ConnectivityService.instance.isConnected;
  }
}