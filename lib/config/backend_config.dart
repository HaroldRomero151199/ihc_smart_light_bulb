/// Configuration for Serverpod backend connection
class BackendConfig {
  // Base URLs for different environments
  static const String _devBaseUrl = 'http://localhost:8080';
  static const String _stagingBaseUrl = 'https://staging-api.ihc-smartbulb.com';
  static const String _productionBaseUrl = 'https://api.ihc-smartbulb.com';

  /// Current environment mode
  static const BackendEnvironment environment = BackendEnvironment.development;

  /// Get the base URL based on current environment
  static String get baseUrl {
    switch (environment) {
      case BackendEnvironment.development:
        return _devBaseUrl;
      case BackendEnvironment.staging:
        return _stagingBaseUrl;
      case BackendEnvironment.production:
        return _productionBaseUrl;
    }
  }

  /// API endpoints
  static const String voiceEndpoint = '/voice/process';
  static const String healthEndpoint = '/health';
  static const String statusEndpoint = '/status';

  /// Complete URLs
  static String get voiceUrl => '$baseUrl$voiceEndpoint';
  static String get healthUrl => '$baseUrl$healthEndpoint';
  static String get statusUrl => '$baseUrl$statusEndpoint';

  /// Request timeout configurations
  static const Duration connectTimeout = Duration(seconds: 10);
  static const Duration receiveTimeout = Duration(seconds: 30);
  static const Duration sendTimeout = Duration(seconds: 15);

  /// Retry configuration
  static const int maxRetries = 3;
  static const Duration retryDelay = Duration(seconds: 2);

  /// Headers
  static const Map<String, String> defaultHeaders = {
    'Content-Type': 'application/json',
    'Accept': 'application/json',
    'User-Agent': 'IHC-SmartBulb-Flutter/1.0.0',
  };

  /// API versioning
  static const String apiVersion = 'v1';
  static const String appVersion = '1.0.0';

  /// Authentication (if needed in the future)
  static String? _apiKey;
  static String? _sessionToken;

  /// Set API key for authentication
  static void setApiKey(String apiKey) {
    _apiKey = apiKey;
  }

  /// Set session token for authentication
  static void setSessionToken(String token) {
    _sessionToken = token;
  }

  /// Get authentication headers
  static Map<String, String> get authHeaders {
    final headers = Map<String, String>.from(defaultHeaders);

    if (_apiKey != null) {
      headers['X-API-Key'] = _apiKey!;
    }

    if (_sessionToken != null) {
      headers['Authorization'] = 'Bearer $_sessionToken';
    }

    return headers;
  }

  /// Debug configuration
  static const bool enableLogging = true;
  static const bool enableDebugMode = true;

  /// Cache configuration
  static const Duration cacheTimeout = Duration(minutes: 5);
  static const bool enableCache = false; // Voice responses shouldn't be cached

  /// Device information headers
  static Map<String, String> getDeviceHeaders({
    String? deviceId,
    String? platform,
    String? appVersion,
  }) {
    final headers = Map<String, String>.from(authHeaders);

    if (deviceId != null) {
      headers['X-Device-ID'] = deviceId;
    }

    if (platform != null) {
      headers['X-Platform'] = platform;
    }

    if (appVersion != null) {
      headers['X-App-Version'] = appVersion;
    }

    return headers;
  }

  /// Validate configuration
  static bool get isConfigurationValid {
    // Check if required configurations are set
    return baseUrl.isNotEmpty && voiceEndpoint.isNotEmpty;
  }

  /// Get debug information
  static Map<String, dynamic> get debugInfo {
    return {
      'environment': environment.name,
      'baseUrl': baseUrl,
      'voiceUrl': voiceUrl,
      'apiVersion': apiVersion,
      'appVersion': appVersion,
      'hasApiKey': _apiKey != null,
      'hasSessionToken': _sessionToken != null,
      'enableLogging': enableLogging,
      'enableDebugMode': enableDebugMode,
    };
  }
}

/// Backend environment enumeration
enum BackendEnvironment {
  development,
  staging,
  production,
}

/// Extension for BackendEnvironment
extension BackendEnvironmentExtension on BackendEnvironment {
  String get name {
    switch (this) {
      case BackendEnvironment.development:
        return 'development';
      case BackendEnvironment.staging:
        return 'staging';
      case BackendEnvironment.production:
        return 'production';
    }
  }

  bool get isDevelopment => this == BackendEnvironment.development;
  bool get isStaging => this == BackendEnvironment.staging;
  bool get isProduction => this == BackendEnvironment.production;
}
