import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:start_app/connectivity_popup.dart';

class ConnectivityService {
  static ConnectivityService? _instance;
  static ConnectivityService get instance => _instance ??= ConnectivityService._();
  ConnectivityService._();

  Timer? _timer;
  bool _isConnected = true;
  bool _isPopupShown = false;
  BuildContext? _context;

  void initialize(BuildContext context) {
    _context = context;
    startMonitoring();
  }

  void startMonitoring() {
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 3), (_) => _checkConnection());
  }

  void stopMonitoring() {
    _timer?.cancel();
  }

  Future<void> _checkConnection() async {
    if (_context == null || !_context!.mounted) return;

    try {
      final result = await InternetAddress.lookup('google.com').timeout(
        const Duration(seconds: 5),
      );
      
      final hasConnection = result.isNotEmpty && result[0].rawAddress.isNotEmpty;
      
      if (!hasConnection && _isConnected) {
        _isConnected = false;
        _showNoConnectionPopup();
      } else if (hasConnection && !_isConnected) {
        _isConnected = true;
        _hideNoConnectionPopup();
      }
    } catch (_) {
      if (_isConnected) {
        _isConnected = false;
        _showNoConnectionPopup();
      }
    }
  }

  void _showNoConnectionPopup() {
    if (!_isPopupShown && _context != null && _context!.mounted) {
      _isPopupShown = true;
      ConnectivityPopup.show(_context!);
    }
  }

  void _hideNoConnectionPopup() {
    if (_isPopupShown) {
      _isPopupShown = false;
      ConnectivityPopup.hide();
    }
  }

  bool get isConnected => _isConnected;

  void dispose() {
    stopMonitoring();
    _hideNoConnectionPopup();
    _context = null;
  }
}