// Configuración global para el acelerómetro
class AccelerometerConfig {
  // Umbrales de detección
  static const double shakeThreshold = 8.0;
  static const double varianceThreshold = 5.0;
  static const double simpleTestThreshold = 13.0;

  // Configuración de buffer
  static const int bufferSize = 10;

  // Ventanas de tiempo (en milisegundos)
  static const int shakeTimeWindow = 500;
  static const int simpleTestTimeWindow = 10000; // 10 segundos

  // Umbrales de detección para diferentes servicios
  static const double foregroundServiceThreshold = 10.0;
  static const double foregroundServiceVarianceThreshold = 8.0;

  // Configuración de timers y delays (en segundos)
  static const int healthCheckInterval = 10;
  static const int serviceRestartDelay = 2;
  static const int activationCooldown = 8;
  static const int keepAliveInterval = 25;
  static const int appKeepAliveInterval = 30;
  static const int shakeCheckInterval = 2;
  static const int voiceCooldown = 10;
  static const int foregroundServiceCheckInterval = 1;
  static const int foregroundServiceRestartDelay = 2;
  static const int foregroundServiceKeepAliveInterval = 30;
  static const int foregroundServiceHealthCheckInterval = 15;
}

// Configuración para el servicio de voz
class VoiceConfig {
  static const int activationDelay = 2;
  static const int listeningCooldown = 8;
  static const int shakeDetectionCooldown = 10;
  static const int shakeCheckInterval = 500; // milisegundos
}

// Configuración para la UI
class UIConfig {
  static const int statusUpdateInterval = 1;
  static const int serviceCheckInterval = 5;
  static const int shakeIndicatorDuration = 3;
  static const int shakeIndicatorReset = 5;
  static const int snackbarDuration = 2;
}
