import 'package:speech_to_text/speech_to_text.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:permission_handler/permission_handler.dart';
import 'dart:async';
import 'accelerometer_service.dart';
import 'backend_service.dart';
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

      print(
          '⏰ Waiting ${VoiceConfig.activationDelay} seconds before listening...');
      await Future.delayed(Duration(seconds: VoiceConfig.activationDelay));

      print(
          '🎤 MICROPHONE ACTIVE - You have ${VoiceConfig.listeningDuration} seconds to speak!');
      print(
          '💬 Say your command clearly - I will send EVERYTHING to backend...');

      // Start listening and process the command when received
      await startListening((recognizedText) {
        print('🗣️ User said: "$recognizedText"');
        print('📤 Sending EVERYTHING to backend: "$recognizedText"');
        _processVoiceCommand(recognizedText);
      }, _currentLanguage);

      print(
          '⏰ Listening window closed. Waiting ${VoiceConfig.listeningCooldown} seconds...');
      await Future.delayed(Duration(seconds: VoiceConfig.listeningCooldown));
      _isAutoListening = false;
    }
  }

  /// Process voice command through backend and respond with TTS
  Future<void> _processVoiceCommand(String voiceCommand) async {
    if (voiceCommand.trim().isEmpty) {
      print('⚠️ Empty voice command received');
      await speakText('No escuché nada, intenta de nuevo', _currentLanguage);
      return;
    }

    print('🎤 FULL Voice command received: "$voiceCommand"');
    print('📤 Sending COMPLETE command to backend...');

    try {
      // Send EVERYTHING the user said to backend - no filtering, no changes
      String response = await BackendService.processVoiceCommand(voiceCommand);

      print('📥 Backend responded with: "$response"');
      print('🔊 TTS will say EXACTLY what backend responded...');

      // Stop any current speech before speaking new response
      await _flutterTts.stop();

      // Wait a bit to ensure microphone is closed
      await Future.delayed(Duration(milliseconds: 800));

      // Speak EXACTLY what the backend responded - no modifications
      await speakText(response, _currentLanguage);

      print('✅ TTS completed - user heard exactly: "$response"');
    } catch (e) {
      print('❌ Error processing command: $e');
      await speakText('Error al procesar comando', _currentLanguage);
    }
  }

  Future<void> initializeTts(String language) async {
    _currentLanguage = language;
    await _flutterTts.setLanguage(language);
    await _flutterTts
        .setSpeechRate(0.6); // Slightly faster for better understanding
    await _flutterTts.setVolume(1.0); // Maximum volume
    await _flutterTts.setPitch(1.0);

    // Set additional TTS settings for better audio
    await _flutterTts.awaitSpeakCompletion(true);

    print('🔊 TTS initialized for language: $language');
  }

  Future<void> _requestPermissions() async {
    print('🔐 Requesting microphone permission...');

    PermissionStatus micStatus = await Permission.microphone.request();
    print('🎤 Microphone permission: $micStatus');

    if (micStatus != PermissionStatus.granted) {
      print('❌ Microphone permission not granted!');
    } else {
      print('✅ Microphone permission granted');
    }

    PermissionStatus speechStatus = await Permission.speech.request();
    print('🗣️ Speech permission: $speechStatus');
  }

  Future<void> _initializeSpeech() async {
    print('🎵 Initializing Speech to Text service...');

    bool available = await _speechToText.initialize(
      onError: (error) => print('❌ STT Error: $error'),
      onStatus: (status) => print('📊 STT Status: $status'),
    );

    if (available) {
      print('✅ Speech to Text initialized successfully');
      var locales = await _speechToText.locales();
      print(
          '🌐 Available locales: ${locales.map((l) => l.localeId).take(5).toList()}');
    } else {
      print('❌ Speech to Text initialization failed');
    }
  }

  Future<bool> startListening(
      Function(String) onResult, String language) async {
    _onResultCallback = onResult;
    _currentLanguage = language;

    print('🎤 Initializing Speech to Text...');
    bool available = await _speechToText.initialize();

    if (!available) {
      print('❌ Speech to Text not available!');
      return false;
    }

    print('✅ Speech to Text available, starting to listen...');

    try {
      await _speechToText.listen(
        onResult: (result) {
          print('🎯 STT Result: "${result.recognizedWords}"');
          if (result.recognizedWords.isNotEmpty) {
            onResult(result.recognizedWords);
          }
        },
        localeId: language,
        listenFor:
            Duration(seconds: VoiceConfig.listeningDuration), // 15 SEGUNDOS
        pauseFor: Duration(seconds: 3),
        partialResults: true,
      );

      print('🎤 Started listening successfully!');
      return true;
    } catch (e) {
      print('❌ Error starting to listen: $e');
      return false;
    }
  }

  Future<void> stopListening() async {
    await _speechToText.stop();
  }

  Future<void> speakText(String text, String language) async {
    if (text.trim().isEmpty) {
      print('⚠️ Warning: Trying to speak empty text');
      return;
    }

    print('🎵 TTS Speaking: "$text"');

    await _flutterTts.setLanguage(language);
    await _flutterTts.setVolume(1.0); // Ensure max volume

    // Speak and wait for completion
    await _flutterTts.speak(text);

    // Additional wait to ensure audio completes
    int textLength = text.length;
    int estimatedDuration =
        (textLength / 10 * 1000).round(); // ~100ms per character
    await Future.delayed(
        Duration(milliseconds: estimatedDuration.clamp(1000, 5000)));

    print('✅ TTS finished speaking: "$text"');
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
