import 'package:flutter/material.dart';
import '../models/voice_state.dart';
import '../services/voice_service.dart';

class VoiceAssistantScreen extends StatefulWidget {
  const VoiceAssistantScreen({super.key});

  @override
  State<VoiceAssistantScreen> createState() => _VoiceAssistantScreenState();
}

class _VoiceAssistantScreenState extends State<VoiceAssistantScreen> {
  final VoiceService _voiceService = VoiceService();
  VoiceState _state = const VoiceState();
  final Map<String, String> _languages = {
    'Español': 'es-ES',
    'English': 'en-US',
  };

  @override
  void initState() {
    super.initState();
    _initializeVoiceService();
  }

  Future<void> _initializeVoiceService() async {
    await _voiceService.initialize();
    await _voiceService.initializeTts(_state.language);
  }

  Future<void> _startListening() async {
    if (!_state.isListening) {
      final success = await _voiceService.startListening((text) {
        setState(() {
          _state = _state.copyWith(recognizedText: text);
        });
      }, _state.language);

      if (success) {
        setState(() {
          _state = _state.copyWith(isListening: true);
        });
      }
    }
  }

  Future<void> _stopListening() async {
    if (_state.isListening) {
      await _voiceService.stopListening();
      setState(() {
        _state = _state.copyWith(isListening: false);
      });
      await _processText(_state.recognizedText);
    }
  }

  Future<void> _processText(String text) async {
    // Por ahora solo repetimos el texto
    setState(() {
      _state = _state.copyWith(processedText: text);
    });
    await _voiceService.speakText(text, _state.language);
  }

  void _onLanguageChanged(String? newLang) async {
    if (newLang != null) {
      setState(() {
        _state = _state.copyWith(language: newLang);
      });
      await _voiceService.initializeTts(newLang);
    }
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
            Row(
              children: [
                const Text('Idioma: ',
                    style: TextStyle(fontWeight: FontWeight.bold)),
                const SizedBox(width: 8),
                DropdownButton<String>(
                  value: _state.language,
                  items: _languages.entries
                      .map((entry) => DropdownMenuItem<String>(
                            value: entry.value,
                            child: Text(entry.key),
                          ))
                      .toList(),
                  onChanged: _onLanguageChanged,
                ),
              ],
            ),
            const SizedBox(height: 16),
            _buildTextCard(
              title: 'Texto Reconocido:',
              text: _state.recognizedText.isEmpty
                  ? 'No hay texto'
                  : _state.recognizedText,
            ),
            const SizedBox(height: 16),
            _buildTextCard(
              title: 'Texto Procesado:',
              text: _state.processedText.isEmpty
                  ? 'No hay texto procesado'
                  : _state.processedText,
            ),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _state.isListening ? _stopListening : _startListening,
        tooltip: _state.isListening ? 'Detener' : 'Escuchar',
        child: Icon(_state.isListening ? Icons.mic_off : Icons.mic),
      ),
    );
  }

  Widget _buildTextCard({required String title, required String text}) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Text(text),
          ],
        ),
      ),
    );
  }

  @override
  void dispose() {
    _voiceService.dispose();
    super.dispose();
  }
}
