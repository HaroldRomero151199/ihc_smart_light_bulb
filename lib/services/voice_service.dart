import 'package:speech_to_text/speech_to_text.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:permission_handler/permission_handler.dart';
import 'dart:async';
import 'accelerometer_service.dart';
import '../config/accelerometer_config.dart';

class VoiceService {
  final SpeechToText _speechToText = SpeechToText();
  final FlutterTts _flutterTts = FlutterTts();
  bool _isAutoListening = false;
  Function(String)? _onResultCallback;
  String _currentLanguage = 'es-ES';
  Function()? _onShakeDetected;

  SimpleAccelerometerService _simpleAccelerometerService =
      SimpleAccelerometerService();
  bool _useSimpleService = false;

  Future<void> initialize() async {
    await _initializeSpeech();
    await _requestPermissions();
    await _initializeAccelerometerService();
  }

  Future<void> _initializeAccelerometerService() async {
    try {
      await AccelerometerForegroundService.initialize();
      bool serviceStarted = await AccelerometerForegroundService.startService();

      if (serviceStarted) {
        _useSimpleService = false;
        // El servicio en segundo plano maneja la detección automáticamente
      } else {
        _useSimpleService = true;
        await _simpleAccelerometerService.initialize();
        bool simpleStarted =
            await _simpleAccelerometerService.startSimpleTest(() {
          _activateVoiceAssistant();
        });
      }
    } catch (e) {
      _useSimpleService = true;
      await _simpleAccelerometerService.initialize();
      await _simpleAccelerometerService.startSimpleTest(() {
        _activateVoiceAssistant();
      });
    }
  }

  Future<void> _activateVoiceAssistant() async {
    _onShakeDetected?.call();

    if (!_isAutoListening) {
      _isAutoListening = true;

      String activationMessage = _currentLanguage.startsWith('es')
          ? 'Hola, te estoy escuchando'
          : 'Hello, I\'m listening to you';

      await speakText(activationMessage, _currentLanguage);

      await Future.delayed(Duration(seconds: VoiceConfig.activationDelay));
      if (_onResultCallback != null) {
        await startListening(_onResultCallback!, _currentLanguage);
      }

      await Future.delayed(Duration(seconds: VoiceConfig.listeningCooldown));
      _isAutoListening = false;
    }
  }

  Future<void> initializeTts(String language) async {
    _currentLanguage = language;
    await _flutterTts.setLanguage(language);
    await _flutterTts.setSpeechRate(0.5);
    await _flutterTts.setVolume(1.0);
    await _flutterTts.setPitch(1.0);
  }

  Future<void> _requestPermissions() async {
    await Permission.microphone.request();
    await Permission.speech.request();
  }

  Future<void> _initializeSpeech() async {
    await _speechToText.initialize();
  }

  Future<bool> startListening(
      Function(String) onResult, String language) async {
    _onResultCallback = onResult;
    _currentLanguage = language;

    bool available = await _speechToText.initialize();
    if (available) {
      await _speechToText.listen(
        onResult: (result) => onResult(result.recognizedWords),
        localeId: language,
      );
      return true;
    }
    return false;
  }

  Future<void> stopListening() async {
    await _speechToText.stop();
  }

  Future<void> speakText(String text, String language) async {
    await _flutterTts.setLanguage(language);
    await _flutterTts.speak(text);
  }

  void enableShakeToActivate() {
    _isAutoListening = false;
  }

  void disableShakeToActivate() {
    _isAutoListening = true;
  }

  void setShakeDetectedCallback(Function() callback) {
    _onShakeDetected = callback;
  }

  bool isAccelerometerServiceRunning() {
    if (_useSimpleService) {
      return _simpleAccelerometerService.isRunning();
    } else {
      return true;
    }
  }

  void dispose() {
    _flutterTts.stop();
  }

  void stopAccelerometerService() {
    if (_useSimpleService) {
      _simpleAccelerometerService.stopMonitoring();
    } else {
      AccelerometerForegroundService.stopService();
    }
  }
}
