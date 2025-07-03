import 'package:flutter/material.dart';
import 'screens/voice_assistant_screen.dart';
import 'services/accelerometer_service.dart';
import 'services/voice_service.dart';
import 'config/app_lifecycle_config.dart';
import 'config/accelerometer_config.dart';
import 'dart:async';

// Servicios globales
VoiceService? globalVoiceService;
bool _canActivate = true;

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Configurar ciclo de vida de la aplicación
  AppLifecycleConfig.configureAppLifecycle();

  // Inicializar servicios globales
  await _initializeGlobalServices();

  runApp(const MyApp());
}

Future<void> _initializeGlobalServices() async {
  // Inicializar servicio de voz
  await _initializeVoiceService();

  // Inicializar servicio de acelerómetro
  await _initializeAccelerometerService();

  print('=== SERVICIOS GLOBALES INICIALIZADOS ===');
}

Future<void> _initializeVoiceService() async {
  print('🎤 Inicializando servicio de voz...');

  try {
    globalVoiceService = VoiceService();
    await globalVoiceService!.initialize();
    await globalVoiceService!.initializeTts('es-ES');
    globalVoiceService!.enableShakeToActivate();

    // Probar TTS
    await globalVoiceService!.speakText('Prueba de audio', 'es-ES');
    print('✅ Servicio de voz inicializado correctamente');
  } catch (e) {
    print('❌ Error al inicializar servicio de voz: $e');
    globalVoiceService = null;
  }
}

Future<void> _initializeAccelerometerService() async {
  print('📱 Inicializando servicio de acelerómetro con segundo plano...');

  try {
    // Intentar servicio en segundo plano primero (para funcionar cuando app está cerrada)
    await AccelerometerForegroundService.initialize();
    bool backgroundStarted =
        await AccelerometerForegroundService.startService();

    if (backgroundStarted) {
      print(
          '✅ Servicio en segundo plano iniciado - funciona app cerrada/abierta');
    } else {
      print('⚠️ Servicio segundo plano falló - usando servicio simple');

      // Fallback: usar servicio simple (solo funciona con app abierta)
      SimpleAccelerometerService simpleService = SimpleAccelerometerService();
      await simpleService.initialize();
      bool simpleStarted = await simpleService.startSimpleTest(() {
        _activateVoiceAssistant();
      });

      if (simpleStarted) {
        print('✅ Servicio simple iniciado - solo funciona con app abierta');
      } else {
        print('❌ Error: Ambos servicios fallaron');
      }
    }
  } catch (e) {
    print('❌ Error crítico al inicializar servicio de acelerómetro: $e');
  }
}

Future<void> _activateVoiceAssistant() async {
  if (!_canActivate) return;

  _canActivate = false;

  if (globalVoiceService != null) {
    try {
      await globalVoiceService!.speakText("Te estoy escuchando", 'es-ES');
      print('✅ Asistente de voz activado');
    } catch (e) {
      print('❌ Error al activar asistente: $e');
    }
  }

  // Esperar antes de nueva activación
  await Future.delayed(Duration(seconds: AccelerometerConfig.voiceCooldown));
  _canActivate = true;
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'IHC Smart Light Bulb',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.blue),
        useMaterial3: true,
      ),
      home: const VoiceAssistantScreen(),
    );
  }
}
