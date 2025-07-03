import 'package:serverpod_flutter/serverpod_flutter.dart';
import 'package:ihc_smart_light_client/ihc_smart_light_client.dart';

/// Simple service to handle Serverpod backend communication
class BackendService {
  static Client? _client;

  /// Initialize the Serverpod client
  static Future<void> initialize() async {
    // Option 1: Use environment variable
    const serverUrl = String.fromEnvironment('SERVER_URL',
        defaultValue: 'http://192.168.1.5:8080/');

    // Option 2: Or hardcode your computer's IP here
    // _client = Client('http://YOUR_COMPUTER_IP:8080/');

    _client = Client(serverUrl);
    _client!.connectivityMonitor = FlutterConnectivityMonitor();
    print('✅ Serverpod client initialized with: $serverUrl');
  }

  /// Send voice command to backend and get response
  static Future<String> processVoiceCommand(String command) async {
    if (_client == null) {
      await initialize();
    }

    print('📤 Sending to backend: "$command"');

    try {
      // Use the generated client method - send EXACTLY what user said
      final response = await _client!.smartLight.listen(command);
      print('📥 Backend returned: "$response"');
      print('✅ Backend communication successful');
      return response;
    } catch (e) {
      print('❌ Backend error: $e');
      return 'Error: No se pudo procesar el comando';
    }
  }
}
