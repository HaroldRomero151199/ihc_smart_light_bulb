import 'package:flutter/material.dart';
import 'package:speech_to_text/speech_to_text.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:permission_handler/permission_handler.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Asistente de Voz',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.blue),
        useMaterial3: true,
      ),
      home: const VoiceAssistantPage(),
    );
  }
}

class VoiceAssistantPage extends StatefulWidget {
  const VoiceAssistantPage({super.key});

  @override
  State<VoiceAssistantPage> createState() => _VoiceAssistantPageState();
}

class _VoiceAssistantPageState extends State<VoiceAssistantPage> {
  final SpeechToText _speechToText = SpeechToText();
  final FlutterTts _flutterTts = FlutterTts();
  bool _isListening = false;
  String _recognizedText = '';
  String _processedText = '';

  @override
  void initState() {
    super.initState();
    _initSpeech();
    _initTts();
    _requestPermissions();
  }

  Future<void> _requestPermissions() async {
    await Permission.microphone.request();
    await Permission.speech.request();
  }

  Future<void> _initSpeech() async {
    await _speechToText.initialize();
  }

  Future<void> _initTts() async {
    await _flutterTts.setLanguage('es-ES');
    await _flutterTts.setSpeechRate(0.5);
    await _flutterTts.setVolume(1.0);
    await _flutterTts.setPitch(1.0);
  }

  Future<void> _startListening() async {
    if (!_isListening) {
      bool available = await _speechToText.initialize();
      if (available) {
        setState(() {
          _isListening = true;
        });
        await _speechToText.listen(
          onResult: (result) {
            setState(() {
              _recognizedText = result.recognizedWords;
            });
          },
          localeId: 'es_ES',
        );
      }
    }
  }

  Future<void> _stopListening() async {
    if (_isListening) {
      await _speechToText.stop();
      setState(() {
        _isListening = false;
      });
      // Here you would typically process the text with NLP
      _processText(_recognizedText);
    }
  }

  Future<void> _processText(String text) async {
    // TODO: Implement NLP processing here
    setState(() {
      _processedText = text; // For now, just echo the text
    });
    await _speakText(_processedText);
  }

  Future<void> _speakText(String text) async {
    await _flutterTts.speak(text);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Asistente de Voz'),
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Texto Reconocido:',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      _recognizedText.isEmpty
                          ? 'No hay texto'
                          : _recognizedText,
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Texto Procesado:',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      _processedText.isEmpty
                          ? 'No hay texto procesado'
                          : _processedText,
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _isListening ? _stopListening : _startListening,
        tooltip: _isListening ? 'Detener' : 'Escuchar',
        child: Icon(_isListening ? Icons.mic_off : Icons.mic),
      ),
    );
  }

  @override
  void dispose() {
    _flutterTts.stop();
    super.dispose();
  }
}
