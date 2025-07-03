import 'package:flutter/material.dart';
import '../models/voice_state.dart';
import '../services/voice_service.dart';
import '../services/global_accelerometer_service.dart';
import '../config/accelerometer_config.dart';
import 'dart:async';

class VoiceAssistantScreen extends StatefulWidget {
  const VoiceAssistantScreen({super.key});

  @override
  State<VoiceAssistantScreen> createState() => _VoiceAssistantScreenState();
}

class _VoiceAssistantScreenState extends State<VoiceAssistantScreen> {
  final VoiceService _voiceService = VoiceService();
  VoiceState _state = const VoiceState();
  bool _shakeToActivate = true;
  bool _accelerometerServiceRunning = false;
  String _accelerometerData = 'Esperando datos...';
  bool _shakeDetected = false;
  final Map<String, String> _languages = {
    'Español': 'es-ES',
    'English': 'en-US',
  };

  @override
  void initState() {
    super.initState();
    _initializeVoiceService();
    _checkAccelerometerService();
    _startAccelerometerMonitoring();
  }

  Future<void> _initializeVoiceService() async {
    await _voiceService.initialize();
    await _voiceService.initializeTts(_state.language);
    _voiceService.setShakeDetectedCallback(_showShakeDetected);
    if (_shakeToActivate) {
      _voiceService.enableShakeToActivate();
    }
  }

  Future<void> _checkAccelerometerService() async {
    bool isRunning = GlobalAccelerometerService.instance.isRunning();
    setState(() {
      _accelerometerServiceRunning = isRunning;
    });

    Timer.periodic(Duration(seconds: UIConfig.serviceCheckInterval), (timer) {
      bool currentStatus = GlobalAccelerometerService.instance.isRunning();
      if (currentStatus != _accelerometerServiceRunning) {
        setState(() {
          _accelerometerServiceRunning = currentStatus;
        });
      }
    });
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

  void _onShakeToActivateChanged(bool value) {
    setState(() {
      _shakeToActivate = value;
    });

    if (value) {
      _voiceService.enableShakeToActivate();
    } else {
      _voiceService.disableShakeToActivate();
    }
  }

  void _startAccelerometerMonitoring() {
    Timer.periodic(Duration(seconds: UIConfig.statusUpdateInterval), (timer) {
      _updateAccelerometerData();
    });
  }

  void _updateAccelerometerData() {
    String status =
        _accelerometerServiceRunning ? '✅ Activo (Global)' : '❌ Inactivo';

    setState(() {
      _accelerometerData =
          'Sensor de acelerómetro: $status - ${DateTime.now().toString().substring(11, 19)}';
    });
  }

  void _showShakeDetected() {
    setState(() {
      _shakeDetected = true;
    });

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('¡Agitación detectada! Activando asistente...'),
        backgroundColor: Colors.green,
        duration: Duration(seconds: UIConfig.snackbarDuration),
      ),
    );

    Future.delayed(Duration(seconds: UIConfig.shakeIndicatorDuration), () {
      if (mounted) {
        setState(() {
          _shakeDetected = false;
        });
      }
    });
  }

  @override
  void dispose() {
    super.dispose();
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
                    value: _languages.entries
                        .firstWhere((entry) => entry.value == _state.language)
                        .key,
                    items: _languages.keys.map((String language) {
                      return DropdownMenuItem<String>(
                        value: language,
                        child: Text(language),
                      );
                    }).toList(),
                    onChanged: (String? newValue) {
                      if (newValue != null) {
                        _onLanguageChanged(_languages[newValue]);
                      }
                    },
                  ),
                ],
              ),
              const SizedBox(height: 16),
              SwitchListTile(
                title: const Text('Activar por agitación'),
                value: _shakeToActivate,
                onChanged: _onShakeToActivateChanged,
              ),
              const SizedBox(height: 16),
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    children: [
                      Text(
                        'Estado del Sensor',
                        style: Theme.of(context).textTheme.headlineSmall,
                      ),
                      const SizedBox(height: 16),
                      Text(_accelerometerData),
                      const SizedBox(height: 16),
                      Row(
                        children: [
                          Icon(
                            _accelerometerServiceRunning
                                ? Icons.check_circle
                                : Icons.error,
                            color: _accelerometerServiceRunning
                                ? Colors.green
                                : Colors.red,
                          ),
                          const SizedBox(width: 8),
                          Text(
                            _accelerometerServiceRunning
                                ? 'Activo'
                                : 'Inactivo',
                            style: TextStyle(
                              color: _accelerometerServiceRunning
                                  ? Colors.green
                                  : Colors.red,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),
              if (_shakeDetected)
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.green.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.green),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.waves, color: Colors.green),
                      const SizedBox(width: 8),
                      Text(
                        '¡Agitación detectada!',
                        style: TextStyle(
                            color: Colors.green, fontWeight: FontWeight.bold),
                      ),
                    ],
                  ),
                ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: ElevatedButton(
                      onPressed: _state.isListening ? null : _startListening,
                      child: Text(_state.isListening
                          ? 'Escuchando...'
                          : 'Iniciar Escucha'),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: _state.isListening ? _stopListening : null,
                      child: const Text('Detener'),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              if (_state.recognizedText.isNotEmpty)
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Texto Reconocido:',
                          style: Theme.of(context).textTheme.titleMedium,
                        ),
                        const SizedBox(height: 8),
                        Text(_state.recognizedText),
                      ],
                    ),
                  ),
                ),
              if (_state.processedText.isNotEmpty)
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Respuesta:',
                          style: Theme.of(context).textTheme.titleMedium,
                        ),
                        const SizedBox(height: 8),
                        Text(_state.processedText),
                      ],
                    ),
                  ),
                ),
              ],
        ),
      ),
    );
  }
}
