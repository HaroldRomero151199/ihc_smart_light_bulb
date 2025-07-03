import 'dart:async';
import 'dart:math';
import 'package:sensors_plus/sensors_plus.dart';
import '../config/accelerometer_config.dart';
import 'package:flutter_foreground_task/flutter_foreground_task.dart';
import 'package:flutter_tts/flutter_tts.dart';

// Clase para monitorear acelerómetro directamente
class SimpleAccelerometerService {
  StreamSubscription<AccelerometerEvent>? _accelerometerSubscription;
  List<double> _recentMagnitudes = [];
  DateTime? _lastShakeTime;
  bool _isRunning = false;
  Function()? _onShakeDetected;
  Timer? _healthCheckTimer;
  int _eventCount = 0;

  // Inicializar el servicio
  Future<void> initialize() async {
    _isRunning = false;
    _eventCount = 0;
    _recentMagnitudes.clear();
    _lastShakeTime = null;

    _healthCheckTimer = Timer.periodic(
        Duration(seconds: AccelerometerConfig.healthCheckInterval), (timer) {
      _healthCheck();
    });
  }

  // Verificación de salud del servicio
  void _healthCheck() {
    if (_isRunning) {
      print('💓 Servicio simple - Eventos: $_eventCount');
    } else {
      if (_onShakeDetected != null) {
        startSimpleTest(_onShakeDetected!);
      }
    }
  }

  // Iniciar el monitoreo
  Future<bool> startMonitoring(Function() onShakeDetected) async {
    try {
      _onShakeDetected = onShakeDetected;
      _isRunning = true;
      _eventCount = 0;

      _accelerometerSubscription =
          accelerometerEventStream().listen((AccelerometerEvent event) {
        _processAccelerometerData(event);
      }, onError: (error) {
        print('❌ Error en stream de acelerómetro: $error');
        _restartService();
      });

      return true;
    } catch (e) {
      print('❌ Error al iniciar monitoreo simple: $e');
      _isRunning = false;
      return false;
    }
  }

  // Método de prueba simple - detecta cualquier movimiento significativo
  Future<bool> startSimpleTest(Function() onShakeDetected) async {
    try {
      _onShakeDetected = onShakeDetected;
      _isRunning = true;
      _eventCount = 0;

      _accelerometerSubscription =
          accelerometerEventStream().listen((AccelerometerEvent event) {
        _processSimpleTest(event);
      }, onError: (error) {
        print('❌ Error en stream de acelerómetro (simple test): $error');
        _restartService();
      });

      return true;
    } catch (e) {
      print('❌ Error al iniciar prueba simple: $e');
      _isRunning = false;
      return false;
    }
  }

  // Reiniciar el servicio automáticamente
  void _restartService() {
    _accelerometerSubscription?.cancel();
    _accelerometerSubscription = null;

    Future.delayed(Duration(seconds: AccelerometerConfig.serviceRestartDelay),
        () {
      if (_isRunning && _onShakeDetected != null) {
        _accelerometerSubscription = accelerometerEventStream().listen(
            (AccelerometerEvent event) => _processSimpleTest(event),
            onError: (error) => print('❌ Error persistente: $error'));
      }
    });
  }

  // Detener el monitoreo
  Future<void> stopMonitoring() async {
    _isRunning = false;
    _accelerometerSubscription?.cancel();
    _accelerometerSubscription = null;
    _healthCheckTimer?.cancel();
  }

  // Verificar si está ejecutándose
  bool isRunning() {
    return _isRunning;
  }

  void _processAccelerometerData(AccelerometerEvent event) {
    if (!_isRunning) return;

    _eventCount++;

    double magnitude =
        sqrt(event.x * event.x + event.y * event.y + event.z * event.z);

    if (_eventCount % 100 == 0) {
      print(
          '📊 Acelerómetro - Eventos: $_eventCount, Magnitud: ${magnitude.toStringAsFixed(2)}');
    }

    _recentMagnitudes.add(magnitude);
    if (_recentMagnitudes.length > AccelerometerConfig.bufferSize) {
      _recentMagnitudes.removeAt(0);
    }

    if (_recentMagnitudes.length >= AccelerometerConfig.bufferSize) {
      _detectShake();
    }
  }

  void _detectShake() {
    double mean =
        _recentMagnitudes.reduce((a, b) => a + b) / _recentMagnitudes.length;
    double variance =
        _recentMagnitudes.map((m) => pow(m - mean, 2)).reduce((a, b) => a + b) /
            _recentMagnitudes.length;

    if (_eventCount % 50 == 0) {
      print(
          '📈 Análisis de agitación - Varianza: ${variance.toStringAsFixed(2)}');
    }

    bool isShaking = variance > AccelerometerConfig.varianceThreshold &&
        _recentMagnitudes.any((m) => m > AccelerometerConfig.shakeThreshold);

    DateTime now = DateTime.now();
    if (isShaking &&
        (_lastShakeTime == null ||
            now.difference(_lastShakeTime!).inMilliseconds >
                AccelerometerConfig.shakeTimeWindow)) {
      _lastShakeTime = now;
      print(
          '🎯 ¡AGITACIÓN DETECTADA! Varianza: ${variance.toStringAsFixed(2)}');
      _onShakeDetected?.call();
    }
  }

  void _processSimpleTest(AccelerometerEvent event) {
    if (!_isRunning) return;

    _eventCount++;

    double magnitude =
        sqrt(event.x * event.x + event.y * event.y + event.z * event.z);

    if (_eventCount % 50 == 0) {
      print(
          '📱 Acelerómetro - Eventos: $_eventCount, Magnitud: ${magnitude.toStringAsFixed(2)}');
    }

    if (magnitude > AccelerometerConfig.simpleTestThreshold) {
      DateTime now = DateTime.now();
      if (_lastShakeTime == null ||
          now.difference(_lastShakeTime!).inMilliseconds >
              AccelerometerConfig.simpleTestTimeWindow) {
        _lastShakeTime = now;
        print(
            '🎯 ¡AGITACIÓN DETECTADA! Magnitud: ${magnitude.toStringAsFixed(2)}');
        _onShakeDetected?.call();
      }
    }
  }
}

// Clase simplificada para el servicio en primer plano
class AccelerometerForegroundService {
  static bool _isInitialized = false;
  static bool _isServiceRunning = false;

  // Inicializar el servicio en primer plano
  static Future<void> initialize() async {
    if (_isInitialized) return;

    // Initialize FlutterForegroundTask
    FlutterForegroundTask.init(
      androidNotificationOptions: AndroidNotificationOptions(
        channelId: 'accelerometer_channel',
        channelName: 'Accelerometer Background Service',
        channelDescription:
            'This notification appears when the accelerometer background service is running.',
        onlyAlertOnce: true,
      ),
      iosNotificationOptions: const IOSNotificationOptions(
        showNotification: false,
        playSound: false,
      ),
      foregroundTaskOptions: ForegroundTaskOptions(
        eventAction: ForegroundTaskEventAction.repeat(5000),
        autoRunOnBoot: true,
        autoRunOnMyPackageReplaced: true,
        allowWakeLock: true,
        allowWifiLock: true,
      ),
    );

    _isInitialized = true;
  }

  // Iniciar el servicio en primer plano
  static Future<bool> startService() async {
    if (!_isInitialized) {
      await initialize();
    }

    // Check if the service is already running
    if (await FlutterForegroundTask.isRunningService) {
      return true;
    }

    // Request permissions
    final NotificationPermission notificationPermission =
        await FlutterForegroundTask.checkNotificationPermission();
    if (notificationPermission != NotificationPermission.granted) {
      await FlutterForegroundTask.requestNotificationPermission();
    }

    // Start the foreground service
    await FlutterForegroundTask.startService(
      serviceId: 256,
      notificationTitle: 'IHC Smart Light Bulb',
      notificationText: 'Monitoring accelerometer in background...',
      callback: startAccelerometerCallback,
    );

    _isServiceRunning = await FlutterForegroundTask.isRunningService;
    print('🚀 Foreground service started: $_isServiceRunning');
    return _isServiceRunning;
  }

  // Detener el servicio en primer plano
  static Future<bool> stopService() async {
    await FlutterForegroundTask.stopService();
    _isServiceRunning = false;
    print('🛑 Foreground service stopped');
    return !await FlutterForegroundTask.isRunningService;
  }

  // Verificar si el servicio está corriendo
  static Future<bool> isServiceRunning() async {
    return await FlutterForegroundTask.isRunningService;
  }

  // Update notification
  static Future<void> updateNotification({
    String? title,
    String? text,
  }) async {
    await FlutterForegroundTask.updateService(
      notificationTitle: title ?? 'IHC Smart Light Bulb',
      notificationText: text ?? 'Monitoring accelerometer in background...',
    );
  }
}

// Background callback function
@pragma('vm:entry-point')
void startAccelerometerCallback() {
  FlutterForegroundTask.setTaskHandler(AccelerometerTaskHandler());
}

// Task handler class for background service
class AccelerometerTaskHandler extends TaskHandler {
  StreamSubscription<AccelerometerEvent>? _accelerometerSubscription;
  List<double> _recentMagnitudes = [];
  DateTime? _lastShakeTime;
  int _eventCount = 0;
  bool _isActivating = false;

  @override
  Future<void> onStart(DateTime timestamp, TaskStarter starter) async {
    print('🎯 Background accelerometer service started');

    // Start accelerometer monitoring
    _startAccelerometerMonitoring();
  }

  @override
  void onRepeatEvent(DateTime timestamp) {
    // This is called periodically based on the eventAction interval
    if (_accelerometerSubscription == null) {
      _startAccelerometerMonitoring();
    }

    // Update notification with current event count
    FlutterForegroundTask.updateService(
      notificationTitle: 'IHC Smart Light Bulb',
      notificationText: 'Events: $_eventCount - Monitoring accelerometer...',
    );
  }

  @override
  Future<void> onDestroy(DateTime timestamp, bool isTimeout) async {
    print(
        '🛑 Background accelerometer service destroyed (timeout: $isTimeout)');
    _accelerometerSubscription?.cancel();
  }

  @override
  void onNotificationButtonPressed(String id) {
    print('🔘 Notification button pressed: $id');
    if (id == 'stop_service') {
      FlutterForegroundTask.stopService();
    }
  }

  @override
  void onNotificationPressed() {
    print('📱 Notification pressed');
  }

  @override
  void onNotificationDismissed() {
    print('❌ Notification dismissed');
  }

  void _startAccelerometerMonitoring() {
    try {
      _accelerometerSubscription = accelerometerEventStream().listen(
        (AccelerometerEvent event) => _processAccelerometerData(event),
        onError: (error) {
          print('❌ Background accelerometer error: $error');
          // Restart monitoring after error
          Future.delayed(Duration(seconds: 2), () {
            _startAccelerometerMonitoring();
          });
        },
      );
      print('📱 Background accelerometer monitoring started');
    } catch (e) {
      print('❌ Failed to start background accelerometer: $e');
    }
  }

  void _processAccelerometerData(AccelerometerEvent event) {
    _eventCount++;

    double magnitude =
        sqrt(event.x * event.x + event.y * event.y + event.z * event.z);

    if (_eventCount % 100 == 0) {
      print(
          '📊 Background - Events: $_eventCount, Magnitude: ${magnitude.toStringAsFixed(2)}');
    }

    _recentMagnitudes.add(magnitude);
    if (_recentMagnitudes.length > AccelerometerConfig.bufferSize) {
      _recentMagnitudes.removeAt(0);
    }

    if (_recentMagnitudes.length >= AccelerometerConfig.bufferSize) {
      _detectShake();
    }
  }

  void _detectShake() {
    if (_isActivating) return;

    double mean =
        _recentMagnitudes.reduce((a, b) => a + b) / _recentMagnitudes.length;
    double variance =
        _recentMagnitudes.map((m) => pow(m - mean, 2)).reduce((a, b) => a + b) /
            _recentMagnitudes.length;

    if (_eventCount % 50 == 0) {
      print('📈 Background - Variance: ${variance.toStringAsFixed(2)}');
    }

    bool isShaking =
        variance > AccelerometerConfig.foregroundServiceVarianceThreshold &&
            _recentMagnitudes
                .any((m) => m > AccelerometerConfig.foregroundServiceThreshold);

    DateTime now = DateTime.now();
    if (isShaking &&
        (_lastShakeTime == null ||
            now.difference(_lastShakeTime!).inMilliseconds >
                AccelerometerConfig.shakeTimeWindow)) {
      _lastShakeTime = now;
      _activateVoiceAssistant();
    }
  }

  void _activateVoiceAssistant() {
    if (_isActivating) return;

    _isActivating = true;
    print('🎯 Background shake detected! Activating voice assistant...');

    // Update notification to show activation
    FlutterForegroundTask.updateService(
      notificationTitle: 'IHC Smart Light Bulb',
      notificationText: 'Voice assistant activated! Listening...',
    );

    // Play TTS (this will work even in background)
    _playTTS();

    // Reset activation flag after cooldown
    Future.delayed(Duration(seconds: AccelerometerConfig.activationCooldown),
        () {
      _isActivating = false;
      FlutterForegroundTask.updateService(
        notificationTitle: 'IHC Smart Light Bulb',
        notificationText: 'Events: $_eventCount - Monitoring accelerometer...',
      );
    });
  }

  void _playTTS() async {
    try {
      // Note: For background TTS to work, you might need additional setup
      // This is a basic implementation
      final flutterTts = FlutterTts();
      await flutterTts.setLanguage("es-ES");
      await flutterTts.speak("Te estoy escuchando");
    } catch (e) {
      print('❌ Background TTS error: $e');
    }
  }
}
