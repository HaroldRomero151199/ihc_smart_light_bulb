import 'package:speech_to_text/speech_to_text.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:permission_handler/permission_handler.dart';

class VoiceService {
  final SpeechToText _speechToText = SpeechToText();
  final FlutterTts _flutterTts = FlutterTts();

  // Inicializar los servicios de voz
  Future<void> initialize() async {
    await _initializeSpeech();
    await _requestPermissions();
  }

  // Inicializar TTS con idioma
  Future<void> initializeTts(String language) async {
    await _flutterTts.setLanguage(language);
    await _flutterTts.setSpeechRate(0.5);
    await _flutterTts.setVolume(1.0);
    await _flutterTts.setPitch(1.0);
  }

  // Solicitar permisos necesarios
  Future<void> _requestPermissions() async {
    await Permission.microphone.request();
    await Permission.speech.request();
  }

  // Inicializar el reconocimiento de voz
  Future<void> _initializeSpeech() async {
    await _speechToText.initialize();
  }

  // Iniciar la escucha con idioma
  Future<bool> startListening(
    Function(String) onResult,
    String language,
  ) async {
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

  // Detener la escucha
  Future<void> stopListening() async {
    await _speechToText.stop();
  }

  // Hablar el texto con idioma
  Future<void> speakText(String text, String language) async {
    await _flutterTts.setLanguage(language);
    await _flutterTts.speak(text);
  }

  // Limpiar recursos
  void dispose() {
    _flutterTts.stop();
  }
}
