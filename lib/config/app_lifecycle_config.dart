import 'package:flutter/material.dart';
import 'dart:async';
import '../services/global_accelerometer_service.dart';
import 'accelerometer_config.dart';

class AppLifecycleConfig {
  static Timer? _keepAliveTimer;
  static bool _isConfigured = false;

  static void configureAppLifecycle() {
    if (_isConfigured) return;

    WidgetsBinding.instance.addObserver(AppLifecycleObserver());
    _isConfigured = true;
  }

  static void startKeepAliveTimer() {
    _keepAliveTimer?.cancel();

    _keepAliveTimer = Timer.periodic(
        Duration(seconds: AccelerometerConfig.appKeepAliveInterval), (timer) {
      if (!GlobalAccelerometerService.instance.isRunning()) {
        GlobalAccelerometerService.instance.startMonitoring();
      }
    });
  }

  static void stopKeepAliveTimer() {
    _keepAliveTimer?.cancel();
    _keepAliveTimer = null;
  }
}

class AppLifecycleObserver extends WidgetsBindingObserver {
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    switch (state) {
      case AppLifecycleState.paused:
        _handleAppPaused();
        break;
      case AppLifecycleState.resumed:
        _handleAppResumed();
        break;
      case AppLifecycleState.detached:
        _handleAppDetached();
        break;
      default:
        break;
    }
  }

  void _handleAppPaused() {
    if (!GlobalAccelerometerService.instance.isRunning()) {
      GlobalAccelerometerService.instance.startMonitoring();
    }
  }

  void _handleAppResumed() {
    if (!GlobalAccelerometerService.instance.isRunning()) {
      GlobalAccelerometerService.instance.startMonitoring();
    }
  }

  void _handleAppDetached() {
    if (!GlobalAccelerometerService.instance.isRunning()) {
      GlobalAccelerometerService.instance.startMonitoring();
    }
  }
}
