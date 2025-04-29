// Template for config.dart
// Usage:    
// 1. Copy this file and rename it to config.dart
// 2. Replace the placeholder values with your own API keys
// 3. Ensure config.dart is added to .gitignore to avoid committing sensitive information

class AppConfig {
  // Suno API configuration 
  // Local API service
  static const String sunoApiBaseUrl = 'http://localhost:3000/api';
  
  // Backup API endpoint - also using local service on different port
  static const String sunoApiBaseUrlBackup = 'http://127.0.0.1:3000/api';
  
  // Vercel deployed API (commented out, available if needed)
  // static const String sunoApiVercelUrl = 'https://your-vercel-url.vercel.app/api';
  
  // API request settings
  static const int apiRequestTimeoutSeconds = 30;  // Local server responds faster, can reduce timeout
  
  // Music generation request timeout settings
  static const int generateMusicTimeoutSeconds = 300;  // 5 minutes
  static const int pollStatusIntervalSeconds = 3;     // Polling interval
  static const int maxPollAttempts = 60;            // 60 attempts (maximum 3 minutes total waiting time)
  
  // Stability AI configuration
  static const String stabilityApiKey = "YOUR_STABILITY_API_KEY";  // Replace with your API key
  static const int defaultGenerationSteps = 30;
  static const int defaultAudioDurationSeconds = 60;
  static const String defaultAudioFormat = "mp3";
  
  // DeepSeek API Configuration
  static const String deepSeekApiKey = "YOUR_DEEPSEEK_API_KEY";  // Replace with your API key
  static const String deepSeekApiEndpoint = "https://api.deepseek.com/v1/chat/completions";
  
  
  // Helper method: Validate API key
  static bool isStabilityApiKeyValid() {
    return stabilityApiKey.isNotEmpty && 
           stabilityApiKey.startsWith("sk-") && 
           stabilityApiKey.length > 20;
  }
  
  // Helper method: Get API key status information
  static String getStabilityApiKeyStatus() {
    if (stabilityApiKey.isEmpty) {
      return "API key is empty";
    } else if (!stabilityApiKey.startsWith("sk-")) {
      return "API key format is incorrect, should start with 'sk-'";
    } else if (stabilityApiKey.length < 20) {
      return "API key is too short, possibly not a valid key";
    } else {
      return "API key format is valid, length: ${stabilityApiKey.length}";
    }
  }
  
  // Stability AI API base URL
  static const String stabilityApiBaseUrl = "https://api.stability.ai";
  static const String stabilityAudioEndpoint = "/v2beta/audio/generations";
  
  // Get full API URL
  static String getStabilityAudioUrl() {
    return "$stabilityApiBaseUrl$stabilityAudioEndpoint";
  }
  
  // Helper method: Validate DeepSeek API key
  static bool isDeepSeekApiKeyValid() {
    return deepSeekApiKey.isNotEmpty && 
           deepSeekApiKey.length > 10;
  }
  
  // Diagnostic information: Display summary of all configurations
  static Map<String, dynamic> getDiagnosticInfo() {
    return {
      "stabilityApiKeyValid": isStabilityApiKeyValid(),
      "stabilityApiKeyStatus": getStabilityApiKeyStatus(),
      "stabilityApiKeyLength": stabilityApiKey.length,
      "stabilityApiKeyPrefix": stabilityApiKey.isNotEmpty ? 
          stabilityApiKey.substring(0, stabilityApiKey.length > 5 ? 5 : stabilityApiKey.length) : "",
      "stabilityApiUrl": getStabilityAudioUrl(),
      "timeoutSettings": {
        "apiRequestTimeoutSeconds": apiRequestTimeoutSeconds,
        "generateMusicTimeoutSeconds": generateMusicTimeoutSeconds,
        "pollStatusIntervalSeconds": pollStatusIntervalSeconds,
        "maxPollAttempts": maxPollAttempts,
      },
      "generationDefaults": {
        "steps": defaultGenerationSteps,
        "durationSeconds": defaultAudioDurationSeconds,
        "format": defaultAudioFormat,
      }
    };
  }
} 