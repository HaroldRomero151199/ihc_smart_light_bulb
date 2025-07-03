# IHC Smart Light - Integración Simplificada con Serverpod

## 🔄 Flujo Simple del Sistema

### 1. **Detección de Agitación**
- Acelerómetro detecta movimiento → Activa TTS

### 2. **Captura de Voz (STT)**  
- Convierte audio a texto → Ejemplo: "encender luz"

### 3. **Procesamiento en Backend**
- Llama SOLO a: `client.smartLight.listen(comando)`
- Retorna: `"procesando comando encender luz"`

### 4. **Respuesta al Usuario (TTS)**
- TTS reproduce la respuesta del backend

## 🛠️ Código Simplificado

### BackendService (solo 20 líneas)
```dart
class BackendService {
  static Client? _client;

  static Future<void> initialize() async {
    _client = Client('http://localhost:8080/');
    _client!.connectivityMonitor = FlutterConnectivityMonitor();
  }

  static Future<String> processVoiceCommand(String command) async {
    if (_client == null) await initialize();
    
    // Solo usa el método generado
    final response = await _client!.smartLight.listen(command);
    return response;
  }
}
```

### VoiceService (solo 10 líneas para backend)
```dart
Future<void> _processVoiceCommand(String voiceCommand) async {
  // Envía al backend y obtiene respuesta
  String response = await BackendService.processVoiceCommand(voiceCommand);
  
  // Reproduce la respuesta
  await speakText(response, _currentLanguage);
}
```

### Endpoint del Servidor (ya existe)
```dart
// En ihc_smart_light_server/lib/src/smart_light/endpoint/smart_light_endpoint.dart
class SmartLightEndpoint extends Endpoint {
  Future<String> listen(Session session, String command) async {
    return 'procesando comando $command';
  }
}
```

## 🧪 Cómo Probar

### 1. Inicia el servidor Serverpod
```bash
cd ihc_smart_light_server
dart bin/main.dart
```

### 2. Ejecuta la app
```bash
cd ihc_smart_light_bulb
flutter run
```

### 3. Prueba el flujo completo
- **Agita el dispositivo** → TTS: "Hola, te estoy escuchando"
- **Di un comando**: "encender luz"
- **Escucha**: "procesando comando encender luz"

### 4. O prueba manualmente
- Presiona "Probar Comando de Voz"
- Ve la respuesta en pantalla

## 🔧 Configuración

### Para dispositivo físico
```dart
// En backend_service.dart, línea 7
_client = Client('http://TU_IP_COMPUTADORA:8080/');
```

### Para emulador
```dart
// En backend_service.dart, línea 7  
_client = Client('http://localhost:8080/');
```

## ✅ Lo que funciona

- ✅ Agitación → TTS → STT → Backend → TTS
- ✅ Botón de prueba manual
- ✅ Muestra respuesta en UI
- ✅ Solo usa el método generado: `smartLight.listen()`

## 🎯 Resultado Final

```
Usuario agita dispositivo
    ↓
TTS: "Hola, te estoy escuchando"
    ↓  
Usuario: "encender luz"
    ↓
STT: "encender luz"
    ↓
Backend: client.smartLight.listen("encender luz")
    ↓
Respuesta: "procesando comando encender luz"
    ↓
TTS: "procesando comando encender luz"
```

¡Simple y directo! 🚀 