class VoiceState {
  final bool isListening;
  final String recognizedText;
  final String processedText;
  final String language; // 'es-ES' o 'en-US'

  const VoiceState({
    this.isListening = false,
    this.recognizedText = '',
    this.processedText = '',
    this.language = 'es-ES',
  });

  VoiceState copyWith({
    bool? isListening,
    String? recognizedText,
    String? processedText,
    String? language,
  }) {
    return VoiceState(
      isListening: isListening ?? this.isListening,
      recognizedText: recognizedText ?? this.recognizedText,
      processedText: processedText ?? this.processedText,
      language: language ?? this.language,
    );
  }
}
