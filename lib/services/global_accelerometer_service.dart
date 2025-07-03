import 'dart:async';
import 'dart:math';
import 'package:sensors_plus/sensors_plus.dart';
import 'accelerometer_service.dart';
import '../config/accelerometer_config.dart';

// Servicio global que mantiene el acelerómetro activo independientemente de la UI
class GlobalAccelerometerService {
  static GlobalAccelerometerService? _instance;
  static bool _isInitialized = false;

  // Variables del servicio
  StreamSubscription<AccelerometerEvent>? _accelerometerSubscription;
  List<double> _recentMagnitudes = [];
  DateTime? _lastShakeTime;
  bool _isRunning = false;
  Function()? _onShakeDetected;
  Timer? _healthCheckTimer;
  int _eventCount = 0;
  bool _isActivating = false; // Evitar múltiples activaciones simultáneas

  // Singleton pattern
  static GlobalAccelerometerService get instance {
    _instance ??= GlobalAccelerometerService._internal();
    return _instance!;
  }

  GlobalAccelerometerService._internal();

  // Inicializar el servicio global
  static Future<void> initialize() async {
    if (_isInitialized) return;

    try {
      await AccelerometerForegroundService.initialize();
      bool foregroundStarted =
          await AccelerometerForegroundService.startService();

      if (foregroundStarted) {
        _isInitialized = true;
        return;
      }
    } catch (e) {
      print('⚠️ Error al iniciar servicio en primer plano: $e');
    }

    await instance._initializeSimpleService();
    _isInitialized = true;
  }

  // Inicializar el servicio simple global
  Future<void> _initializeSimpleService() async {
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
      print('💓 Servicio global - Eventos: $_eventCount');
    } else {
      startMonitoring(_onShakeDetected);
    }
  }

  // Iniciar el monitoreo global
  Future<bool> startMonitoring([Function()? onShakeDetected]) async {
    if (_isRunning) return true;

    try {
      _onShakeDetected = onShakeDetected;
      _isRunning = true;
      _eventCount = 0;

      _accelerometerSubscription = accelerometerEventStream().listen(
          (AccelerometerEvent event) => _processAccelerometerData(event),
          onError: (error) {
        print('❌ Error en stream: $error');
        _restartService();
      });

      return true;
    } catch (e) {
      print('❌ Error al iniciar monitoreo: $e');
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
            (AccelerometerEvent event) => _processAccelerometerData(event),
            onError: (error) => print('❌ Error persistente: $error'));
      }
    });
  }

  // Detener el monitoreo (solo usar cuando sea absolutamente necesario)
  Future<void> stopMonitoring() async {
    _isRunning = false;
    _accelerometerSubscription?.cancel();
    _accelerometerSubscription = null;
    _healthCheckTimer?.cancel();
  }

  // Verificar si está ejecutándose
  bool isRunning() => _isRunning;

  // Procesar datos del acelerómetro
  void _processAccelerometerData(AccelerometerEvent event) {
    if (!_isRunning) return;

    _eventCount++;

    double magnitude =
        sqrt(event.x * event.x + event.y * event.y + event.z * event.z);

    if (_eventCount % 100 == 0) {
      print(
          '📊 Global - Eventos: $_eventCount, Magnitud: ${magnitude.toStringAsFixed(2)}');
    }

    _recentMagnitudes.add(magnitude);
    if (_recentMagnitudes.length > AccelerometerConfig.bufferSize) {
      _recentMagnitudes.removeAt(0);
    }

    if (_recentMagnitudes.length >= AccelerometerConfig.bufferSize) {
      _detectShake();
    }
  }

  // Detectar agitación
  void _detectShake() {
    if (_isActivating) return;

    double mean =
        _recentMagnitudes.reduce((a, b) => a + b) / _recentMagnitudes.length;
    double variance =
        _recentMagnitudes.map((m) => pow(m - mean, 2)).reduce((a, b) => a + b) /
            _recentMagnitudes.length;

    if (_eventCount % 50 == 0) {
      print('📈 Global - Varianza: ${variance.toStringAsFixed(2)}');
    }

    bool isShaking = variance > AccelerometerConfig.varianceThreshold &&
        _recentMagnitudes.any((m) => m > AccelerometerConfig.shakeThreshold);

    DateTime now = DateTime.now();
    if (isShaking &&
        (_lastShakeTime == null ||
            now.difference(_lastShakeTime!).inMilliseconds >
                AccelerometerConfig.shakeTimeWindow)) {
      _lastShakeTime = now;
      _activateAssistant();
    }
  }

  // Activar el asistente de voz
  void _activateAssistant() {
    if (_isActivating) return;

    _isActivating = true;
    _onShakeDetected?.call();

    Future.delayed(Duration(seconds: AccelerometerConfig.activationCooldown),
        () {
      _isActivating = false;
    });
  }

  // Método para mantener el servicio activo
  static void startKeepAliveTimer() {
    Timer.periodic(Duration(seconds: AccelerometerConfig.keepAliveInterval),
        (timer) {
      if (!instance._isRunning) {
        instance.startMonitoring(instance._onShakeDetected);
      }
    });
  }
}
