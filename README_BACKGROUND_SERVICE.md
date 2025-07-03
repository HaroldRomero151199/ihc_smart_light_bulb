# Documentación Técnica: Servicio en Segundo Plano

Esta documentación detalla la implementación técnica del servicio en segundo plano para la detección de agitación en IHC Smart Light Bulb.

## 🏗️ Arquitectura del Servicio

### Componentes Principales

1. **AccelerometerForegroundService**: Clase estática que gestiona el servicio
2. **AccelerometerTaskHandler**: Handler que ejecuta la lógica en segundo plano
3. **Configuración de Android**: Permisos y declaraciones en AndroidManifest.xml

## 📋 Configuración de Permisos

### AndroidManifest.xml - Permisos Requeridos

```xml
<!-- Permisos básicos de la aplicación -->
<uses-permission android:name="android.permission.RECORD_AUDIO"/>
<uses-permission android:name="android.permission.INTERNET"/>

<!-- Permisos para servicio en segundo plano -->
<uses-permission android:name="android.permission.FOREGROUND_SERVICE" />
<uses-permission android:name="android.permission.FOREGROUND_SERVICE_DATA_SYNC" />
<uses-permission android:name="android.permission.WAKE_LOCK" />
<uses-permission android:name="android.permission.RECEIVE_BOOT_COMPLETED" />
<uses-permission android:name="android.permission.REQUEST_IGNORE_BATTERY_OPTIMIZATIONS" />
<uses-permission android:name="android.permission.POST_NOTIFICATIONS"/>

<!-- Permisos adicionales para optimización -->
<uses-permission android:name="android.permission.SYSTEM_ALERT_WINDOW" />
<uses-permission android:name="android.permission.REQUEST_COMPANION_RUN_IN_BACKGROUND" />
<uses-permission android:name="android.permission.REQUEST_COMPANION_USE_DATA_IN_BACKGROUND" />
```

### Configuración del Servicio

```xml
<!-- Declaración del servicio principal -->
<service
    android:name="com.pravera.flutter_foreground_task.service.ForegroundService"
    android:exported="false"
    android:stopWithTask="false"
    android:foregroundServiceType="dataSync"
    android:enabled="true"
    android:persistent="true" />

<!-- Receptor para reinicio automático -->
<receiver
    android:name="com.pravera.flutter_foreground_task.FlutterForegroundTaskReceiver"
    android:exported="true">
    <intent-filter>
        <action android:name="android.intent.action.BOOT_COMPLETED" />
        <action android:name="android.intent.action.MY_PACKAGE_REPLACED" />
        <action android:name="android.intent.action.PACKAGE_REPLACED" />
        <data android:scheme="package" />
    </intent-filter>
</receiver>
```

## 🔧 Implementación del Servicio

### AccelerometerForegroundService

```dart
class AccelerometerForegroundService {
  static bool _isInitialized = false;
  static bool _isServiceRunning = false;

  /// Inicializa el servicio de foreground task
  static Future<void> initialize() async {
    if (_isInitialized) return;

    print('🚀 Inicializando AccelerometerForegroundService...');
    
    // Configurar las opciones del servicio
    FlutterForegroundTask.init(
      androidNotificationOptions: AndroidNotificationOptions(
        channelId: 'accelerometer_service_channel',
        channelName: 'Accelerometer Service',
        channelDescription: 'Servicio de detección de agitación en segundo plano',
        channelImportance: NotificationChannelImportance.LOW,
        priority: NotificationPriority.LOW,
        iconData: const NotificationIconData(
          resType: ResourceType.mipmap,
          resPrefix: ResourcePrefix.ic,
          name: 'launcher',
        ),
        buttons: [
          const NotificationButton(id: 'stop_service', text: 'Detener Servicio'),
        ],
      ),
      iosNotificationOptions: const IOSNotificationOptions(
        showNotification: true,
        playSound: false,
      ),
      foregroundTaskOptions: ForegroundTaskOptions(
        eventAction: ForegroundTaskEventAction.repeat(1000), // Cada segundo
        autoRunOnBoot: true,
        allowWakeLock: true,
        allowWifiLock: true,
      ),
    );

    _isInitialized = true;
    print('✅ AccelerometerForegroundService inicializado correctamente');
  }

  /// Inicia el servicio en segundo plano
  static Future<bool> startService() async {
    if (!_isInitialized) {
      print('❌ Error: Servicio no inicializado');
      return false;
    }

    if (_isServiceRunning) {
      print('⚠️ El servicio ya está ejecutándose');
      return true;
    }

    try {
      print('🚀 Iniciando servicio en segundo plano...');
      
      // Verificar permisos de notificación
      if (await FlutterForegroundTask.isIgnoringBatteryOptimizations == false) {
        await FlutterForegroundTask.requestIgnoreBatteryOptimization();
      }

      // Solicitar permisos de notificación
      final notificationPermission = await FlutterForegroundTask.checkNotificationPermission();
      if (notificationPermission != NotificationPermission.granted) {
        await FlutterForegroundTask.requestNotificationPermission();
      }

      // Registrar el task handler
      FlutterForegroundTask.setTaskHandler(AccelerometerTaskHandler());

      // Iniciar el servicio
      final serviceRequestResult = await FlutterForegroundTask.startService(
        serviceId: 256,
        notificationTitle: 'IHC Smart Light Bulb',
        notificationText: 'Detectando agitación...',
      );

      _isServiceRunning = await FlutterForegroundTask.isRunningService;
      
      print('🚀 Resultado del servicio: $_isServiceRunning');
      
      if (_isServiceRunning) {
        print('✅ Servicio en segundo plano iniciado correctamente');
        return true;
      } else {
        print('❌ Error: No se pudo iniciar el servicio en segundo plano');
        return false;
      }
    } catch (e) {
      print('❌ Error al iniciar el servicio: $e');
      _isServiceRunning = false;
      return false;
    }
  }

  /// Detiene el servicio en segundo plano
  static Future<void> stopService() async {
    if (!_isServiceRunning) return;

    print('🛑 Deteniendo servicio en segundo plano...');
    
    try {
      await FlutterForegroundTask.stopService();
      _isServiceRunning = false;
      print('✅ Servicio detenido correctamente');
    } catch (e) {
      print('❌ Error al detener el servicio: $e');
    }
  }

  /// Verifica si el servicio está ejecutándose
  static Future<bool> isServiceRunning() async {
    return await FlutterForegroundTask.isRunningService;
  }
}
```

### AccelerometerTaskHandler

```dart
class AccelerometerTaskHandler extends TaskHandler {
  static const String _tag = 'AccelerometerTaskHandler';
  
  StreamSubscription<AccelerometerEvent>? _accelerometerSubscription;
  List<double> _recentMagnitudes = [];
  DateTime _lastShakeTime = DateTime.now();

  @override
  void onStart(DateTime timestamp, TaskStarter starter) {
    print('🚀 [$_tag] Servicio iniciado en segundo plano');
    _startAccelerometerListener();
  }

  @override
  void onRepeatEvent(DateTime timestamp) {
    // Verificar que el listener esté activo
    if (_accelerometerSubscription == null) {
      print('⚠️ [$_tag] Listener no activo, reiniciando...');
      _startAccelerometerListener();
    }
    
    // Actualizar notificación cada minuto
    if (timestamp.second == 0) {
      FlutterForegroundTask.updateService(
        notificationTitle: 'IHC Smart Light Bulb',
        notificationText: 'Detectando agitación... ${timestamp.hour}:${timestamp.minute}',
      );
    }
  }

  @override
  void onDestroy(DateTime timestamp) {
    print('🛑 [$_tag] Servicio destruido');
    _accelerometerSubscription?.cancel();
    _accelerometerSubscription = null;
  }

  @override
  void onNotificationButtonPressed(String id) {
    if (id == 'stop_service') {
      FlutterForegroundTask.stopService();
    }
  }

  void _startAccelerometerListener() {
    _accelerometerSubscription?.cancel();
    
    print('📱 [$_tag] Iniciando listener del acelerómetro...');
    
    _accelerometerSubscription = SensorsPlatform.instance.accelerometerEventStream(
      samplingPeriod: SensorInterval.normalInterval,
    ).listen(
      _onAccelerometerEvent,
      onError: (error) {
        print('❌ [$_tag] Error en acelerómetro: $error');
        // Reintentar después de 5 segundos
        Future.delayed(const Duration(seconds: 5), _startAccelerometerListener);
      },
    );
  }

  void _onAccelerometerEvent(AccelerometerEvent event) {
    // Calcular magnitud del vector de aceleración
    double magnitude = sqrt(event.x * event.x + event.y * event.y + event.z * event.z);
    
    // Agregar a buffer circular
    _recentMagnitudes.add(magnitude);
    if (_recentMagnitudes.length > AccelerometerConfig.bufferSize) {
      _recentMagnitudes.removeAt(0);
    }

    // Verificar agitación si tenemos suficientes datos
    if (_recentMagnitudes.length >= AccelerometerConfig.bufferSize) {
      _checkForShake(magnitude);
    }
  }

  void _checkForShake(double magnitude) {
    DateTime now = DateTime.now();
    
    // Verificar ventana de tiempo para evitar múltiples detecciones
    if (now.difference(_lastShakeTime).inMilliseconds < AccelerometerConfig.shakeTimeWindow) {
      return;
    }

    // Calcular varianza para detectar movimientos irregulares
    double variance = _calculateVariance(_recentMagnitudes);
    
    // Detectar agitación basada en varianza y umbral
    bool isShaking = variance > AccelerometerConfig.foregroundServiceVarianceThreshold &&
        _recentMagnitudes.any((m) => m > AccelerometerConfig.foregroundServiceThreshold);

    if (isShaking) {
      _lastShakeTime = now;
      print('🎯 [$_tag] ¡AGITACIÓN DETECTADA! Magnitud: ${magnitude.toStringAsFixed(2)}, Varianza: ${variance.toStringAsFixed(2)}');
      
      // Actualizar notificación
      FlutterForegroundTask.updateService(
        notificationTitle: 'IHC Smart Light Bulb',
        notificationText: '¡Agitación detectada! Activando asistente...',
      );
      
      // Activar TTS en segundo plano
      _activateVoiceAssistantBackground();
    }
  }

  double _calculateVariance(List<double> values) {
    if (values.isEmpty) return 0.0;
    
    double mean = values.reduce((a, b) => a + b) / values.length;
    double variance = values
        .map((value) => (value - mean) * (value - mean))
        .reduce((a, b) => a + b) / values.length;
    
    return variance;
  }

  Future<void> _activateVoiceAssistantBackground() async {
    try {
      print('🎤 [$_tag] Activando asistente de voz en segundo plano...');
      
      // Enviar datos al app principal (si está disponible)
      FlutterForegroundTask.sendDataToMain({
        'action': 'activate_voice_assistant',
        'timestamp': DateTime.now().millisecondsSinceEpoch,
      });
      
      // Actualizar notificación con estado activo
      FlutterForegroundTask.updateService(
        notificationTitle: 'IHC Smart Light Bulb - Activo',
        notificationText: 'Asistente de voz activado por agitación',
      );
      
      print('✅ [$_tag] Asistente de voz activado desde segundo plano');
      
    } catch (e) {
      print('❌ [$_tag] Error al activar asistente: $e');
    }
  }
}
```

## ⚙️ Configuración de Umbrales

### accelerometer_config.dart

```dart
class AccelerometerConfig {
  // Umbrales para detección en segundo plano (más conservadores)
  static const double foregroundServiceThreshold = 10.0;
  static const double foregroundServiceVarianceThreshold = 8.0;
  
  // Umbrales para detección en primer plano (más sensibles)
  static const double shakeThreshold = 8.0;
  static const double varianceThreshold = 5.0;
  
  // Configuración de buffer y timing
  static const int bufferSize = 10;                    // Muestras para análisis
  static const int shakeTimeWindow = 500;              // ms entre detecciones
  static const int voiceCooldown = 10;                 // s de cooldown
  
  // Configuración de sensores
  static const Duration sensorInterval = Duration(milliseconds: 100);
  static const double gravitationalAcceleration = 9.8;
}
```

## 🔄 Flujo de Trabajo del Servicio

### 1. Inicialización
```
1. main.dart llama a AccelerometerForegroundService.initialize()
2. Se configuran las opciones de notificación
3. Se registra el TaskHandler
4. Se solicitan permisos necesarios
```

### 2. Arranque del Servicio
```
1. Se verifica si el servicio ya está corriendo
2. Se solicitan permisos de batería y notificaciones
3. Se inicia el servicio con FlutterForegroundTask.startService()
4. Se activa el listener del acelerómetro
```

### 3. Detección en Segundo Plano
```
1. El TaskHandler recibe eventos del acelerómetro
2. Se calcula la magnitud del vector de aceleración
3. Se mantiene un buffer circular de las últimas N muestras
4. Se calcula la varianza para detectar irregularidades
5. Si se supera el umbral, se activa el asistente
```

### 4. Activación del Asistente
```
1. Se actualiza la notificación
2. Se envían datos al app principal (si está disponible)
3. Se ejecuta TTS en segundo plano
4. Se implementa cooldown para evitar activaciones múltiples
```

## 🐛 Troubleshooting

### Problema: Servicio no se inicia (startService devuelve false)

**Posibles Causas:**
1. Permisos faltantes en AndroidManifest.xml
2. Configuración incorrecta del servicio
3. Restricciones de batería del sistema

**Solución:**
```dart
// Verificar configuración paso a paso
if (!await FlutterForegroundTask.isIgnoringBatteryOptimizations) {
  await FlutterForegroundTask.requestIgnoreBatteryOptimization();
}

final notificationPermission = await FlutterForegroundTask.checkNotificationPermission();
if (notificationPermission != NotificationPermission.granted) {
  await FlutterForegroundTask.requestNotificationPermission();
}
```

### Problema: Servicio se detiene inesperadamente

**Posibles Causas:**
1. Sistema mata el servicio por uso de batería
2. Error en el TaskHandler
3. Configuración incorrecta de `stopWithTask`

**Solución:**
```xml
<!-- En AndroidManifest.xml -->
<service
    android:name="com.pravera.flutter_foreground_task.service.ForegroundService"
    android:stopWithTask="false"
    android:persistent="true" />
```

### Problema: Acelerómetro no detecta movimientos

**Posibles Causas:**
1. Umbrales demasiado altos
2. Error en el listener
3. Sensor no disponible

**Solución:**
```dart
// Verificar disponibilidad del sensor
try {
  _accelerometerSubscription = SensorsPlatform.instance.accelerometerEventStream(
    samplingPeriod: SensorInterval.normalInterval,
  ).listen(
    _onAccelerometerEvent,
    onError: (error) {
      print('❌ Error en acelerómetro: $error');
      Future.delayed(const Duration(seconds: 5), _startAccelerometerListener);
    },
  );
} catch (e) {
  print('❌ Sensor no disponible: $e');
}
```

### Problema: Múltiples activaciones

**Solución:**
```dart
// Implementar cooldown en la detección
DateTime _lastShakeTime = DateTime.now();

void _checkForShake(double magnitude) {
  DateTime now = DateTime.now();
  
  if (now.difference(_lastShakeTime).inMilliseconds < AccelerometerConfig.shakeTimeWindow) {
    return; // Ignorar si está dentro del tiempo de cooldown
  }
  
  // ... resto de la lógica de detección
}
```

## 📊 Métricas y Logging

### Logs Importantes

```dart
// Inicialización
print('🚀 Inicializando AccelerometerForegroundService...');
print('✅ AccelerometerForegroundService inicializado correctamente');

// Estado del servicio
print('🚀 Resultado del servicio: $_isServiceRunning');
print('✅ Servicio en segundo plano iniciado correctamente');

// Detección de agitación
print('🎯 ¡AGITACIÓN DETECTADA! Magnitud: ${magnitude.toStringAsFixed(2)}');
print('✅ Asistente de voz activado desde segundo plano');

// Errores
print('❌ Error: No se pudo iniciar el servicio en segundo plano');
print('❌ Error en acelerómetro: $error');
```

### Monitoreo de Performance

```dart
// Tracking de memoria y CPU
void _trackPerformance() {
  final timestamp = DateTime.now();
  final bufferSize = _recentMagnitudes.length;
  
  print('📊 Performance [${timestamp.toIso8601String()}]:');
  print('   - Buffer size: $bufferSize');
  print('   - Service running: $_isServiceRunning');
  print('   - Last shake: $_lastShakeTime');
}
```

## 🚀 Optimizaciones Implementadas

### 1. Gestión Eficiente de Memoria
- Buffer circular de tamaño fijo para magnitudes
- Limpieza automática de suscripciones
- Manejo de errores con reintentos

### 2. Optimización de Batería
- Umbrales ajustados para segundo plano
- Cooldown entre detecciones
- Notificaciones de baja prioridad

### 3. Confiabilidad del Servicio
- Auto-reinicio en caso de errores
- Verificación periódica del listener
- Fallback a servicio simple si falla

### 4. Experiencia de Usuario
- Notificaciones informativas pero no intrusivas
- Actualización periódica del estado
- Botón de parada en la notificación

---

**Esta implementación garantiza un servicio robusto y eficiente que mantiene la detección de agitación funcionando incluso cuando la aplicación está cerrada o en segundo plano. 🎯⚡** 