import 'package:flutter/material.dart';
import 'package:just_audio/just_audio.dart';
import 'package:logger/logger.dart';
import '../services/suno_api_service.dart';
import '../models/suno_music.dart';
import 'dart:developer' as developer;
import '../utils/config.dart';
import 'dart:async'; // Timer and Stopwatch
import 'dart:io'; // Add SocketException support
import 'package:flutter/services.dart'; // Add Clipboard support
import '../services/stability_audio_service.dart';
import 'package:path_provider/path_provider.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import '../models/music_item.dart';
import '../services/music_library_manager.dart';
import '../services/audio_player_manager.dart';
import '../theme/pixel_theme.dart';

class CreateScreen extends StatefulWidget {
  const CreateScreen({Key? key}) : super(key: key);

  @override
  _CreateScreenState createState() => _CreateScreenState();
}

class _CreateScreenState extends State<CreateScreen> {
  final TextEditingController _promptController = TextEditingController();
  late SunoApiService _apiService;
  final Logger _logger = Logger();
  final AudioPlayer _audioPlayer = AudioPlayer();
  final AudioPlayerManager _audioPlayerManager = AudioPlayerManager();
  
  bool _isLoading = false;
  bool _isApiConnected = false;
  String? _errorMessage;
  SunoMusic? _generatedMusic;
  String? _generatedMusicId;
  String _statusMessage = "";
  
  // Add API credit information status
  int? _remainingCredits;
  int? _dailyLimit;
  bool _isLoadingCredits = false;
  
  // Add audio playback status tracking
  bool _isPlaying = false;
  
  // Add variable for cancelling polling
  bool _isCancelled = false;
  Timer? _pollingTimer;
  
  // API service address
  String _currentApiUrl = AppConfig.sunoApiBaseUrl;
  bool _usingBackupUrl = false;
  
  // Add new variables
  StabilityAudioService? _stabilityService;
  final int _generationSteps = 30; // Fixed at 30 steps, cannot be adjusted
  int _durationSeconds = AppConfig.defaultAudioDurationSeconds;

  @override
  void initState() {
    super.initState();
    
    // Initialize the API service (missing this line may cause other errors)
    // Even though we only use Stability AI now, other methods may still depend on this service
    _apiService = SunoApiService(baseUrl: AppConfig.sunoApiBaseUrl);
    
    // Output diagnostic information
    final diagnostics = AppConfig.getDiagnosticInfo();
    developer.log('Stability AI configuration diagnostic information:');
    developer.log('API key status: ${diagnostics["stabilityApiKeyStatus"]}');
    developer.log('API URL: ${diagnostics["stabilityApiUrl"]}');
    
    try {
      developer.log('Starting to initialize StabilityAudioService...');
      if (AppConfig.isStabilityApiKeyValid()) {
        developer.log('API key format validation passed');
        
        // Try to create a service instance
        try {
          final apiKey = AppConfig.stabilityApiKey;
          developer.log('Creating service instance, using API key: ${apiKey.substring(0, 5)}...');
          
          _stabilityService = StabilityAudioService(apiKey: apiKey);
          developer.log('StabilityAudioService instance created successfully');
        } catch (serviceError) {
          developer.log('Failed to create service instance: $serviceError', error: serviceError);
          setState(() {
            _errorMessage = "Failed to create Stability AI service instance: $serviceError";
          });
        }
      } else {
        developer.log('API key validation failed: ${AppConfig.getStabilityApiKeyStatus()}');
        setState(() {
          _errorMessage = "Stability API key is invalid: ${AppConfig.getStabilityApiKeyStatus()}";
        });
      }
    } catch (e) {
      developer.log('Overall initialization process error: $e', error: e);
      setState(() {
        _errorMessage = "Failed to initialize Stability AI service: $e";
      });
    }
    
    // Add Audio playing status listening
    _audioPlayer.playerStateStream.listen((state) {
      setState(() {
        _isPlaying = state.playing;
      });
    });
    
    // Listen to the audio playback status change
    _audioPlayerManager.addListener(_onAudioPlayerChanged);
    
    // Ensure default duration is 60 seconds
    _durationSeconds = 60;
  }

  @override
  void dispose() {
    _promptController.dispose();
    _audioPlayer.dispose();
    _cancelPolling();
    _stabilityService?.dispose();
    _audioPlayerManager.removeListener(_onAudioPlayerChanged);
    super.dispose();
  }

  void _onAudioPlayerChanged() {
    if (mounted) {
      setState(() {});
    }
  }

  // Cancel polling and generation process
  void _cancelPolling() {
    if (_pollingTimer != null && _pollingTimer!.isActive) {
      _pollingTimer!.cancel();
    }
    _isCancelled = true;
    developer.log('Music generation process cancelled');
  }
  
  // Cancel music generation
  void _cancelGeneration() {
    _cancelPolling();
    setState(() {
      _isLoading = false;
      _statusMessage = "Generation cancelled";
    });
    developer.log('User cancelled music generation');
  }

  // Generate music
  Future<void> _generateMusic() async {
    final prompt = _promptController.text.trim();
    if (prompt.isEmpty) {
      setState(() {
        _errorMessage = 'Please enter a prompt';
      });
      return;
    }

    // Reset cancellation status
    _isCancelled = false;

    setState(() {
      _isLoading = true;
      _errorMessage = null;
      _generatedMusic = null;
      _statusMessage = "Sending generation request...";
    });

    try {
      // Add timer to detect if request is stuck
      Timer requestTimer = Timer(Duration(seconds: 5), () {
        if (_isLoading && _statusMessage == "Sending generation request...") {
          developer.log('Request seems stuck, showing prompt information');
          setState(() {
            _statusMessage = "Sending generation request... (Request is taking longer than expected, still waiting for response)";
          });
          
          // Add a second timer to check if request is really stuck
          Timer(Duration(seconds: 15), () {
            if (_isLoading && _statusMessage.startsWith("Sending generation request...")) {
              setState(() {
                _statusMessage = "Sending generation request... (Server is taking a long time to respond, you may continue waiting or cancel)";
              });
            }
          });
        }
      });
      
      // Send generation request
      developer.log('Starting music generation request, prompt: $prompt');
      final Stopwatch stopwatch = Stopwatch()..start();
      
      final response = await _apiService.generateMusic(prompt);
      
      stopwatch.stop();
      developer.log('Generation request completed in ${stopwatch.elapsed.inMilliseconds} ms');
      
      // Cancel timer
      requestTimer.cancel();
      
      // Log detailed response structure for debugging
      developer.log('Received generation response: $response');
      developer.log('Response structure - Type: ${response.runtimeType}, Keys: ${response.keys.toList()}');
      
      // Check if cancelled
      if (_isCancelled) {
        developer.log('Generation request cancelled');
        return;
      }
      
      // Get generated music ID
      final musicId = getMusicId(response);
      if (musicId != null) {
        _generatedMusicId = musicId;
        developer.log('Received music ID: $_generatedMusicId');
        
        // Poll for music generation status
        setState(() {
          _statusMessage = "Generation started, waiting for result... (ID: $_generatedMusicId)";
        });
        await _pollMusicStatus(_generatedMusicId!);
      } else {
        throw Exception('Cant get music ID from response');
      }
    } on TimeoutException catch (e) {
      // Check if cancelled
      if (_isCancelled) {
        developer.log('Generation request cancelled');
        return;
      }
      
      developer.log('Music generation request timed out: $e', error: e);
      setState(() {
        _isLoading = false;
        _errorMessage = 'Request timed out: Server response time exceeded ${AppConfig.generateMusicTimeoutSeconds} seconds. The server might be busy or experiencing issues.';
        _statusMessage = "";
      });
      
      _showRetryDialog();
    } on SocketException catch (e) {
      if (_isCancelled) return;
      
      developer.log('Network connection error: $e', error: e);
      setState(() {
        _isLoading = false;
        _errorMessage = 'Network error: Unable to connect to API service. Error: ${e.message}';
        _statusMessage = "";
      });
      
      _showTryBackupDialog();
    } catch (e) {
      // Check if cancelled
      if (_isCancelled) {
        developer.log('Generation request cancelled');
        return;
      }
      
      developer.log('Error generating music: $e', error: e);
      
      // Check if it's a 500 error
      if (e.toString().contains('500')) {
        developer.log('Detected 500 server error, checking API quota status');
        // Check API quota status, help diagnose problems
        try { 
          final quotaInfo = await _apiService.getApiLimits();
          
          int? remainingCredits;
          if (quotaInfo.containsKey('remaining_credits')) {
            remainingCredits = quotaInfo['remaining_credits'];
          } else if (quotaInfo.containsKey('credits') && quotaInfo['credits'] is Map) {
            remainingCredits = quotaInfo['credits']['remaining'];
          }
          
          if (remainingCredits != null && remainingCredits < 5) {
            // Insufficient credits, show specific error message
            setState(() {
              _isLoading = false;
              _errorMessage = 'Music generation failed: Insufficient credits (remaining: $remainingCredits). Each generation requires at least 5-10 credits.';
              _statusMessage = "";
            });
            return;
          } else {
            // Sufficient credits,
            setState(() {
              _isLoading = false;
              _errorMessage = 'Server error (500): The Suno API server encountered an internal error. This could be due to server load or temporary issues. Try again later.';
              _statusMessage = "";
            });
          }
        } catch (quotaError) {
          // Unable to get quota information, fallback to general error
          setState(() {
            _isLoading = false;
            _errorMessage = 'Server error (500): Could not determine cause. Check your network connection and Suno account status.';
            _statusMessage = "";
          });
        }
      } else {
        setState(() {
          _isLoading = false;
          _errorMessage = 'Error generating music: ${e.toString()}';
          _statusMessage = "";
        });
      }
      
      // If specific error messages that suggest API server issues
      if (e.toString().contains('Failed host lookup') || 
          e.toString().contains('Connection refused') ||
          e.toString().contains('Cannot connect')) {
        _showTryBackupDialog();
      }
    }
  }
  
  // Show retry dialog
  void _showRetryDialog() {
    if (!mounted) return;
    
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Request Timeout'),
        content: const Text('Music generation request timed out. Do you want to retry or try using the backup API address?'),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.of(context).pop();
            },
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              Navigator.of(context).pop();
              _generateMusic();
            },
            child: const Text('Retry'),
          ),
          TextButton(
            onPressed: () {
              Navigator.of(context).pop();
              _switchApiUrl();
              Future.delayed(Duration(seconds: 1), () {
                if (_isApiConnected) {
                  _generateMusic();
                }
              });
            },
            child: const Text('Use Backup Address'),
          ),
        ],
      ),
    );
  }

  // Poll music generation status
  Future<void> _pollMusicStatus(String id) async {
    bool isCompleted = false;
    int attempts = 0;
    final maxAttempts = AppConfig.maxPollAttempts;
    final pollInterval = Duration(seconds: AppConfig.pollStatusIntervalSeconds);
    final totalEstimatedTime = maxAttempts * pollInterval.inSeconds; // Total polling time in seconds
    
    developer.log('Starting music status polling, ID: $id, max attempts: $maxAttempts, polling interval: ${pollInterval.inSeconds} seconds');
    developer.log('Total maximum polling time: ${totalEstimatedTime ~/ 60} minutes ${totalEstimatedTime % 60} seconds');
    
    // Display ID in the UI for manual reference
    setState(() {
      _statusMessage = "Starting music generation. ID: $id (Total wait time up to ${totalEstimatedTime ~/ 60} min)";
    });
    
    // Async polling method that can be cancelled
    Future<void> pollOnce() async {
      if (_isCancelled || isCompleted || attempts >= maxAttempts) {
        return;
      }
      
      try {
        final int remainingAttempts = maxAttempts - attempts;
        final int remainingTimeSeconds = remainingAttempts * pollInterval.inSeconds;
        final int remainingMinutes = remainingTimeSeconds ~/ 60;
        final int remainingSeconds = remainingTimeSeconds % 60;
        
        developer.log('Polling attempt ${attempts + 1}/$maxAttempts (Remaining time: ~${remainingMinutes}m ${remainingSeconds}s)');
        setState(() {
          _statusMessage = "Generating... attempt ${attempts + 1}/$maxAttempts (Est. remaining: ${remainingMinutes}m ${remainingSeconds}s)";
        });
        
        final musicInfo = await _apiService.getMusicInfo(id);
        developer.log('Music status response: $musicInfo');
        developer.log('Response structure - Type: ${musicInfo.runtimeType}, Keys: ${musicInfo.keys.toList()}');
        
        if (_isCancelled) {
          return; // Check if cancelled during info retrieval
        }
        
        // Try different response formats to find the status
        Map<String, dynamic>? itemToUse;
        String statusMessage = "unknown";
        
        // Format 1: Response has 'items' array
        if (musicInfo.containsKey('items') && 
            musicInfo['items'] is List && 
            musicInfo['items'].isNotEmpty) {
          
          final item = musicInfo['items'][0];
          if (item is Map) {
            itemToUse = Map<String, dynamic>.from(item);
            statusMessage = item['status'] ?? "unknown";
          }
        } 
        // Format 2: Response is the item itself
        else if (musicInfo.containsKey('id') && musicInfo.containsKey('status')) {
          itemToUse = musicInfo;
          statusMessage = musicInfo['status'] ?? "unknown";
        }
        // Format 3: Response has a different structure
        else {
          developer.log('Unknown response format, raw response: $musicInfo');
          // Try to find any status field in the response
          String? status;
          if (musicInfo.containsKey('status')) {
            status = musicInfo['status'];
            statusMessage = status ?? "unknown";
          } else {
            // Look for status in any nested objects
            musicInfo.forEach((key, value) {
              if (value is Map && value.containsKey('status')) {
                status = value['status'];
                statusMessage = status ?? "unknown";
              }
            });
          }
          
          if (status != null) {
            itemToUse = {'id': id, 'status': status};
          }
        }
        
        // Log the status message
        developer.log('Current status: $statusMessage (Attempt ${attempts + 1}/$maxAttempts)');
        
        // Process the found item if any
        if (itemToUse != null) {
          final status = itemToUse['status'];
          developer.log('Current music status: $status');
          
          if (status == 'complete') {
            developer.log('Music generation completed!');
            isCompleted = true;
            
            // Create SunoMusic object from the item
            final sunoMusic = SunoMusic.fromJson(itemToUse);
            developer.log('Generated music information: title=${sunoMusic.title}, audioUrl=${sunoMusic.audioUrl}');
            
            setState(() {
              _generatedMusic = sunoMusic;
              _isLoading = false;
              _statusMessage = "Generation completed!";
            });
            
            // Auto-play the generated music
            if (sunoMusic.audioUrl.isNotEmpty) {
              developer.log('Starting music playback: ${sunoMusic.audioUrl}');
              _playAudio(sunoMusic.audioUrl);
            } else {
              developer.log('Cannot play audio: audio URL is empty', error: 'Empty audio URL');
              setState(() {
                _errorMessage = 'Music generation completed, but no audio URL was provided';
              });
            }
          } else if (status == 'failed') {
            developer.log('Music generation failed', error: 'Status is failed');
            isCompleted = true;
            setState(() {
              _isLoading = false;
              _errorMessage = 'Music generation failed';
              _statusMessage = "Generation failed!";
            });
          } else {
            // Other status like 'processing' or 'submitted'
            developer.log('Music is being processed, status: $status');
            setState(() {
              _statusMessage = "AI is creating music, status: $status (Attempt ${attempts + 1}/$maxAttempts)";
            });
          }
        } else {
          developer.log('Could not find status information in the response');
          setState(() {
            _statusMessage = "Generating... (status unknown, attempt ${attempts + 1}/$maxAttempts)";
          });
        }
      } on TimeoutException catch (e) {
        developer.log('Music status polling timeout: $e', error: e);
        // Continue trying after timeout
        if (!_isCancelled && !isCompleted) {
          attempts++;
          _pollingTimer = Timer(pollInterval, pollOnce);
        }
        return;
      } on SocketException catch (e) {
        developer.log('Music status polling network error: $e', error: e);
        // Continue trying after network error
        if (!_isCancelled && !isCompleted) {
          attempts++;
          _pollingTimer = Timer(pollInterval, pollOnce);
        }
        return;
      } catch (e) {
        developer.log('Music status polling error: $e', error: e);
        developer.log('Error type: ${e.runtimeType}');
      }
      
      if (!isCompleted && !_isCancelled) {
        attempts++;
        developer.log('Waiting for ${pollInterval.inSeconds} seconds before checking status again...');
        // Use Timer instead of Future.delayed to allow cancellation
        _pollingTimer = Timer(pollInterval, () {
          if (!_isCancelled) {
            pollOnce();
          }
        });
      }
    }
    
    // Start first polling attempt
    await pollOnce();
    
    // If not completed but reached max attempts, and not cancelled
    if (!isCompleted && !_isCancelled && attempts >= maxAttempts) {
      developer.log('Music generation timed out', error: 'Reached max attempts');
      setState(() {
        _isLoading = false;
        _errorMessage = 'Music generation timed out after ${maxAttempts * pollInterval.inSeconds} seconds';
        _statusMessage = "Generation timed out!";
      });
      
      // Music might still be generating in the background, show info
      _showTimeoutInfoDialog(id);
    }
  }
  
  // Show timeout info dialog
  void _showTimeoutInfoDialog(String id) {
    if (!mounted) return;
    
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Generation Taking Longer Than Expected'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('The music generation process is taking longer than the maximum waiting time of ${AppConfig.maxPollAttempts * AppConfig.pollStatusIntervalSeconds} seconds.'),
            const SizedBox(height: 12),
            const Text('This doesn\'t mean the generation has failed. Suno API might still be processing your request in the background.'),
            const SizedBox(height: 12),
            Text('Music ID: $id', style: const TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 12),
            const Text('You can either:'),
            const Text('• Check the status again now'),
            const Text('• Continue waiting and check later'),
            const Text('• Try generating a different music piece'),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.of(context).pop();
            },
            child: const Text('Close'),
          ),
          TextButton(
            onPressed: () {
              Navigator.of(context).pop();
              // Check status again with current ID
              setState(() {
                _isLoading = true;
                _errorMessage = null;
                _statusMessage = "Checking status again...";
              });
              _pollMusicStatus(id);
            },
            child: const Text('Check Status Again'),
          ),
          TextButton(
            onPressed: () {
              Navigator.of(context).pop();
              // Copy ID to clipboard
              _copyIdToClipboard(id);
            },
            child: const Text('Copy ID for Later'),
          ),
        ],
      ),
    );
  }
  
  // Copy ID to clipboard
  void _copyIdToClipboard(String id) {
    // Use Flutter's Clipboard API
    Clipboard.setData(ClipboardData(text: id)).then((_) {
      developer.log('ID copied to clipboard: $id');
      
      // Show confirmation to user
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Music ID copied: $id'),
          duration: const Duration(seconds: 5),
          action: SnackBarAction(
            label: 'OK',
            onPressed: () {
              ScaffoldMessenger.of(context).hideCurrentSnackBar();
            },
          ),
        ),
      );
    });
  }

  // Play audio
  Future<void> _playAudio(String url) async {
    try {
      // Use a temporary ID, or use the actual music ID
      final tempId = 'temp_${DateTime.now().millisecondsSinceEpoch}';
      await _audioPlayerManager.playMusic(tempId, url);
    } catch (e) {
      developer.log('Failed to play audio: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to play audio: ${e.toString()}')),
        );
      }
    }
  }

  // Check API quota information
  Future<void> _checkApiQuota() async {
    try {
      setState(() {
        _isLoadingCredits = true;
      });
      
      developer.log('Checking API quota information...');
      final quotaInfo = await _apiService.getApiLimits();
      developer.log('API quota information received: $quotaInfo');
      
      // Try to extract key information from the returned data
      int? remainingCredits;
      int? dailyLimit;
      
      // Handle different possible response formats
      if (quotaInfo.containsKey('remaining_credits')) {
        remainingCredits = quotaInfo['remaining_credits'];
      } else if (quotaInfo.containsKey('credits') && quotaInfo['credits'] is Map) {
        remainingCredits = quotaInfo['credits']['remaining'];
        dailyLimit = quotaInfo['credits']['limit'];
      }
      
      // Update status
      setState(() {
        _remainingCredits = remainingCredits;
        _dailyLimit = dailyLimit;
        _isLoadingCredits = false;
        
        // If credits are low, show warning
        if (remainingCredits != null && remainingCredits < 50) {
          _errorMessage = 'Warning: Low API credits remaining ($remainingCredits). Music generation may fail.';
        }
      });
      
      // Record found information
      if (remainingCredits != null) {
        developer.log('Remaining API credits: $remainingCredits');
        if (dailyLimit != null) {
          developer.log('Daily credit limit: $dailyLimit');
        }
      } else {
        developer.log('Could not determine remaining API credits from response: $quotaInfo');
      }
    } catch (e) {
      developer.log('Error checking API quota: $e', error: e);
      setState(() {
        _isLoadingCredits = false;
      });
      // Don't show this error on UI, it's just diagnostic information
    }
  }

  // Modify existing _generateMusic method or add new method to use Stability AI
  Future<void> _generateMusicWithStability() async {
    if (_stabilityService == null) {
      setState(() {
        _errorMessage = 'Stability AI service not initialized, please check API key settings';
        _statusMessage = "";
      });
      return;
    }

    final prompt = _promptController.text.trim();
    if (prompt.isEmpty) {
      setState(() {
        _errorMessage = 'Please enter a prompt';
      });
      return;
    }

    // Reset cancellation status
    _isCancelled = false;

    setState(() {
      _isLoading = true;
      _errorMessage = null;
      _generatedMusic = null;
      _statusMessage = "Generating music with Stability AI...";
    });

    try {
      developer.log('Starting Stability AI music generation, prompt: $prompt');
      final Stopwatch stopwatch = Stopwatch()..start();
      
      // Call stability service to generate music
      final result = await _stabilityService!.generateMusic(
        prompt,
        steps: 30, // Directly hardcode to 30, not using _generationSteps
        durationSeconds: _durationSeconds,
      );
      
      stopwatch.stop();
      developer.log('Generation completed in ${stopwatch.elapsed.inMilliseconds} ms');
      
      // Check if cancelled
      if (_isCancelled) {
        developer.log('Generation request cancelled');
        return;
      }
      
      // Create SunoMusic object to be compatible with existing UI
      final music = SunoMusic(
        id: result['id'],
        title: result['title'],
        prompt: result['prompt'],
        audioUrl: result['audio_url'],
        status: result['status'],
        createdAt: DateTime.parse(result['created_at']),
      );
      
      // Update UI
      setState(() {
        _generatedMusic = music;
        _generatedMusicId = music.id;
        _isLoading = false;
        _statusMessage = "Music generation completed!";
      });
      
      // Auto-play the generated music
      if (music.audioUrl.isNotEmpty) {
        developer.log('Music generation successful, URL: ${music.audioUrl}', name: 'CreateScreen');
        
        // Determine the URL type
        String audioUrl = music.audioUrl;
        bool isLocalFile = audioUrl.startsWith('/') || 
                           (audioUrl.length > 1 && audioUrl[1] == ':') || // Windows path
                           audioUrl.startsWith('file://');
        
        // Do not automatically add the base URL, keep the original path
        // If it is a local file path, use it directly
        if (isLocalFile && !audioUrl.startsWith('file://')) {
          audioUrl = 'file://$audioUrl';
        }
        
        developer.log('Processed audio URL: $audioUrl', name: 'CreateScreen');
        
        // Create MusicItem object
        final musicItem = MusicItem(
          id: music.id,
          title: music.title.isEmpty ? 'Stability Music ${DateTime.now().toString().substring(0, 16)}' : music.title,
          prompt: prompt,
          audioUrl: audioUrl, // Use the processed URL
          status: 'complete',
          createdAt: DateTime.now(),
        );
        
        // Save to the music library
        try {
          developer.log('Music has been successfully saved and synchronized: ${musicItem.title}', name: 'CreateScreen');
          
          // Use the new addMusicAndSync method instead of the old addMusic
          await MusicLibraryManager().addMusicAndSync(musicItem);
          
          // Show success message
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: const Text('Music has been added and synchronized to the cloud'),
                action: SnackBarAction(
                  label: 'View',
                  onPressed: () {
                    Navigator.of(context).pushNamed('/library');
                  },
                ),
                duration: const Duration(seconds: 3),
              ),
            );
          }
        } catch (e) {
          developer.log('Failed to save music: $e', error: e, name: 'CreateScreen');
          developer.log('Exception type: ${e.runtimeType}', name: 'CreateScreen');
          
          // Show error message
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text('Failed to save music: ${e.toString()}')),
            );
          }
        }
      } else {
        developer.log('Cannot play audio: audio URL is empty', error: 'Empty audio URL');
        setState(() {
          _errorMessage = 'Music generation completed, but no audio URL was provided';
        });
      }
    } catch (e) {
      if (_isCancelled) return;
      
      developer.log('Error generating music with Stability AI: $e', error: e);
      setState(() {
        _isLoading = false;
        _errorMessage = 'Error generating music: ${e.toString()}';
        _statusMessage = "";
      });
      
      if (e.toString().contains('Failed host lookup') || 
          e.toString().contains('Connection refused')) {
        _showConnectionErrorDialog();
      } else {
        _showStabilityErrorDialog(e.toString());
      }
    }
  }

  // Show stability error dialog
  void _showStabilityErrorDialog(String error) {
    if (!mounted) return;
    
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Generation Failed'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Failed to generate music with Stability AI.'),
            const SizedBox(height: 8),
            Text('Error: $error', style: TextStyle(color: Colors.red)),
            const SizedBox(height: 12),
            Text('You could try:'),
            Text('• Using a different prompt'),
            Text('• Reducing the number of steps'),
            Text('• Checking your internet connection'),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.of(context).pop();
            },
            child: const Text('Close'),
          ),
          TextButton(
            onPressed: () {
              Navigator.of(context).pop();
              _generateMusicWithStability(); // Retry
            },
            child: const Text('Try Again'),
          ),
        ],
      ),
    );
  }

  // Test Stability API connection
  Future<void> _testStabilityApiConnection() async {
    if (_stabilityService == null) {
      setState(() {
        _isApiConnected = false;
        _isLoading = false;
        _errorMessage = 'Stability AI service not initialized, please check API key settings';
        _statusMessage = "";
      });
      _showConnectionErrorDialog();
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
      _statusMessage = "Testing Stability AI connection...";
    });

    try {
      developer.log('Testing Stability AI API connection...');
      final isConnected = await _stabilityService!.testConnection();
      developer.log('Stability AI connection test result: $isConnected');
      
      setState(() {
        _isApiConnected = isConnected;
        _isLoading = false;
        _statusMessage = isConnected ? "Stability AI connection successful" : "Stability AI connection failed";
      });
      
      if (!isConnected) {
        _showConnectionErrorDialog();
      }
    } catch (e) {
      developer.log('Stability AI connection test error: $e', error: e);
      setState(() {
        _isApiConnected = false;
        _isLoading = false;
        _errorMessage = 'Connection error: $e';
        _statusMessage = "";
      });
      _showConnectionErrorDialog();
    }
  }

  void _showConnectionErrorDialog() {
    if (!mounted) return;
    
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Connection Failed'),
        content: const Text('Unable to connect to Stability AI API. Please check your internet connection and API key.'),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.of(context).pop();
            },
            child: const Text('Close'),
          ),
          TextButton(
            onPressed: () {
              Navigator.of(context).pop();
              _testStabilityApiConnection();
            },
            child: const Text('Retry'),
          ),
        ],
      ),
    );
  }

  // 1. Add _showTryBackupDialog method
  void _showTryBackupDialog() {
    if (!mounted) return;
    
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Connection problem'),
        content: const Text('Unable to connect to the main API server. Do you want to continue trying or use Stability AI as a backup?'),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.of(context).pop();
            },
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              Navigator.of(context).pop();
              _testStabilityApiConnection();
            },
            child: const Text('Use Stability Stability AI'),
          ),
        ],
      ),
    );
  }

  // 2. Modify _switchApiUrl method to solve the problem that sunoApiBackupUrl does not exist
  void _switchApiUrl() {
    setState(() {
      // Since we only use Stability AI, here it is simplified to directly reconnect to the Stability API
      _statusMessage = "Switching to Stability AI service...";
    });
    
    developer.log('Since the Suno API is unavailable, switching to the Stability AI service...');
    
    // Directly test the Stability AI connection
    _testStabilityApiConnection();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Create Music', style: PixelTheme.titleStyle),
        backgroundColor: PixelTheme.surface,
        foregroundColor: PixelTheme.text,
        elevation: 0,
        titleSpacing: 12,
        actions: [
          Container(
            margin: const EdgeInsets.only(right: 8),
            decoration: BoxDecoration(
              border: Border.all(color: PixelTheme.text, width: 1),
              color: PixelTheme.surface,
            ),
            child: IconButton(
              icon: Icon(Icons.info_outline, color: PixelTheme.text, size: 18),
              onPressed: () {
                showDialog(
                  context: context,
                  builder: (context) => _buildPixelDialog(
                    title: 'About Stability AI',
                    content: 'You can describe the song you want to create.\n\nNOTE: This app uses Stability AI\'s Stable Audio API to generate music',
                  ),
                );
              },
              tooltip: 'About API',
            ),
          ),
        ],
      ),
      backgroundColor: PixelTheme.background,
      body: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
                decoration: BoxDecoration(
                  color: PixelTheme.surface,
                  border: PixelTheme.pixelBorder,
                  boxShadow: PixelTheme.cardShadow,
                ),
                child: Text(
                  'Stability AI Music Generator',
                  style: TextStyle(
                    fontSize: 18, 
                    fontWeight: FontWeight.bold,
                    ////fontFamily: 'DMMono',
                    color: PixelTheme.primary,
                  ),
                ),
              ),
              
              const SizedBox(height: 16),
              
              Container(
                decoration: BoxDecoration(
                  color: PixelTheme.surface,
                  border: PixelTheme.pixelBorder,
                ),
                child: Theme(
                  data: Theme.of(context).copyWith(
                    dividerColor: PixelTheme.text.withOpacity(0.2),
                    colorScheme: ColorScheme.light(
                      primary: PixelTheme.primary,
                    ),
                  ),
                  child: ExpansionTile(
                    title: Text('Generate Settings', 
                      style: TextStyle(
                        fontSize: 16,
                        ////fontFamily: 'DMMono',
                        fontWeight: FontWeight.bold,
                        color: PixelTheme.text,
                      ),
                    ),
                    initiallyExpanded: false,
                    children: [
                      ListTile(
                        title: Text('Duration (seconds)', style: PixelTheme.bodyStyle),
                        subtitle: SliderTheme(
                          data: SliderThemeData(
                            activeTrackColor: PixelTheme.primary,
                            inactiveTrackColor: PixelTheme.textLight.withOpacity(0.3),
                            thumbColor: PixelTheme.primary,
                            overlayColor: PixelTheme.primary.withOpacity(0.2),
                            trackHeight: 6,
                          ),
                          child: Slider(
                            value: _durationSeconds.toDouble(),
                            min: 10,
                            max: 60,
                            divisions: 10,
                            label: _durationSeconds.toString(),
                            onChanged: (value) {
                              setState(() {
                                _durationSeconds = value.round();
                              });
                            },
                          ),
                        ),
                        trailing: Container(
                          width: 40,
                          height: 30,
                          decoration: BoxDecoration(
                            border: Border.all(color: PixelTheme.text, width: 1),
                            color: PixelTheme.surface,
                          ),
                          alignment: Alignment.center,
                          child: Text(
                            '$_durationSeconds', 
                            style: TextStyle(
                              ////fontFamily: 'DMMono',
                              fontWeight: FontWeight.bold,
                              color: PixelTheme.text,
                            ),
                          ),
                        ),
                      ),
                      Padding(
                        padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                        child: Row(
                          children: [
                            Text('Quality Steps: ', style: PixelTheme.bodyStyle),
                            Text('30', style: TextStyle(fontWeight: FontWeight.bold)),
                            Expanded(
                              child: Text(
                                ' (fixed for optimal generation)', 
                                style: TextStyle(fontStyle: FontStyle.italic, fontSize: 12),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 8),
                      Padding(
                        padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                        child: Text(
                          'Estimated cost: ${(0.06 * 30 + 9).toStringAsFixed(1)} credits',
                          style: PixelTheme.labelStyle.copyWith(fontStyle: FontStyle.italic),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              
              const SizedBox(height: 16),
              
              Container(
                decoration: BoxDecoration(
                  color: PixelTheme.surface,
                  border: PixelTheme.pixelBorder,
                  boxShadow: PixelTheme.cardShadow,
                ),
                padding: const EdgeInsets.all(2),
                child: TextField(
                  controller: _promptController,
                  decoration: InputDecoration(
                    labelText: 'Describe the music you want',
                    hintText: 'For example: A 3/4 song with a cello, drums, and rhythmic clapping. Sad and melancholic mood.',
                    hintStyle: PixelTheme.labelStyle.copyWith(
                      color: PixelTheme.textLight.withOpacity(0.7),
                      fontSize: 15.0,
                    ),
                    labelStyle: TextStyle(
                      ////fontFamily: 'DMMono',
                      fontSize: 16.0,
                      color: PixelTheme.text,
                    ),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.zero,
                      borderSide: BorderSide(color: PixelTheme.text, width: 1),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.zero,
                      borderSide: BorderSide(color: PixelTheme.text, width: 1),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.zero,
                      borderSide: BorderSide(color: PixelTheme.primary, width: 2),
                    ),
                    filled: true,
                    fillColor: PixelTheme.surface,
                    contentPadding: EdgeInsets.all(12),
                  ),
                  style: PixelTheme.bodyStyle.copyWith(
                    fontSize: 16.0,
                  ),
                  maxLines: 3,
                  enabled: !_isLoading,
                ),
              ),
              
              const SizedBox(height: 16.0),
              
              SizedBox(
                width: double.infinity,
                child: _isLoading
                    ? ElevatedButton.icon(
                        onPressed: _cancelGeneration,
                        icon: const Icon(Icons.cancel, color: Colors.white, size: 18),
                        label: Text('Cancel Generation', style: PixelTheme.bodyStyle.copyWith(color: Colors.white)),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: PixelTheme.error,
                          padding: const EdgeInsets.symmetric(vertical: 16.0),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.zero,
                            side: BorderSide(color: PixelTheme.text, width: 2),
                          ),
                          elevation: 0,
                        ),
                      )
                    : ElevatedButton.icon(
                        onPressed: () {
                          developer.log('Generate Music button clicked');
                          
                          if (_stabilityService == null) {
                            _initializeStabilityService();
                          } else {
                            _generateMusicWithStability();
                          }
                        },
                        icon: Icon(Icons.music_note, color: Colors.white, size: 18),
                        label: Text('Generate Music', style: PixelTheme.bodyStyle.copyWith(color: Colors.white)),
                        style: ElevatedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 16.0),
                          backgroundColor: PixelTheme.primary,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.zero,
                            side: BorderSide(color: PixelTheme.text, width: 2),
                          ),
                          elevation: 0,
                          shadowColor: Colors.black.withOpacity(0.3),
                        ),
                      ),
              ),
              
              if (_isLoading) ...[
                const SizedBox(height: 16.0),
                Container(
                  decoration: BoxDecoration(
                    color: PixelTheme.surface,
                    border: Border.all(color: PixelTheme.text, width: 1),
                  ),
                  padding: const EdgeInsets.all(12),
                  child: Row(
                    children: [
                      Container(
                        width: 24,
                        height: 24,
                        padding: EdgeInsets.all(4),
                        child: CircularProgressIndicator(
                          strokeWidth: 2.0,
                          valueColor: AlwaysStoppedAnimation<Color>(PixelTheme.primary),
                        ),
                      ),
                      const SizedBox(width: 16.0),
                      Expanded(
                        child: Text(
                          _statusMessage,
                          style: PixelTheme.bodyStyle.copyWith(
                            color: PixelTheme.primary,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
              
              if (_errorMessage != null) ...[
                const SizedBox(height: 16.0),
                Container(
                  padding: const EdgeInsets.all(12.0),
                  decoration: BoxDecoration(
                    color: PixelTheme.surface,
                    borderRadius: BorderRadius.zero,
                    border: Border.all(color: PixelTheme.error, width: 2),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.error_outline, color: PixelTheme.error, size: 18),
                      const SizedBox(width: 12.0),
                      Expanded(
                        child: Text(
                          _errorMessage!,
                          style: PixelTheme.bodyStyle.copyWith(color: PixelTheme.error),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
              
              const SizedBox(height: 24.0),
              
              if (_generatedMusic != null) ...[
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
                  decoration: BoxDecoration(
                    color: PixelTheme.surface,
                    border: Border.all(color: PixelTheme.text, width: 2),
                  ),
                  child: Text(
                    'Generated Music:',
                    style: PixelTheme.titleStyle,
                  ),
                ),
                const SizedBox(height: 8.0),
                Container(
                  decoration: BoxDecoration(
                    color: PixelTheme.surface,
                    border: PixelTheme.pixelBorder,
                    boxShadow: PixelTheme.cardShadow,
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          _safeText(_generatedMusic!.title, 'No title music'),
                          style: PixelTheme.titleStyle,
                          overflow: TextOverflow.ellipsis,
                          maxLines: 2,
                        ),
                        const SizedBox(height: 12.0),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('Prompt:', style: PixelTheme.bodyStyle.copyWith(fontWeight: FontWeight.bold)),
                            const SizedBox(height: 4.0),
                            Container(
                              width: double.infinity,
                              padding: const EdgeInsets.all(8.0),
                              decoration: BoxDecoration(
                                color: PixelTheme.background,
                                border: Border.all(color: PixelTheme.text, width: 1),
                              ),
                              child: Text(
                                _safeText(_generatedMusic!.prompt, 'No prompt'),
                                style: PixelTheme.bodyStyle,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12.0),
                        Row(
                          children: [
                            Text('ID: ', style: PixelTheme.labelStyle.copyWith(fontWeight: FontWeight.bold)),
                            Expanded(
                              child: Text(
                                _generatedMusic!.id,
                                style: PixelTheme.labelStyle,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            Container(
                              width: 24,
                              height: 24,
                              decoration: BoxDecoration(
                                border: Border.all(color: PixelTheme.text, width: 1),
                                color: PixelTheme.surface,
                              ),
                              child: IconButton(
                                icon: Icon(Icons.copy, size: 14, color: PixelTheme.text),
                                onPressed: () => _copyIdToClipboard(_generatedMusic!.id),
                                tooltip: 'Copy ID',
                                padding: EdgeInsets.zero,
                                constraints: const BoxConstraints(),
                              ),
                            ),
                          ],
                        ),
                        Divider(height: 24, color: PixelTheme.text.withOpacity(0.3), thickness: 1),
                        Text('Audio Controls:', style: PixelTheme.bodyStyle.copyWith(fontWeight: FontWeight.bold)),
                        const SizedBox(height: 12.0),
                        _buildPixelAudioControls(),
                        if (_isPlaying) ...[
                          const SizedBox(height: 16.0),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Container(
                                width: 16,
                                height: 16,
                                padding: EdgeInsets.all(2),
                                child: CircularProgressIndicator(
                                  strokeWidth: 2.0,
                                  valueColor: AlwaysStoppedAnimation<Color>(PixelTheme.accent),
                                ),
                              ),
                              const SizedBox(width: 8.0),
                              Text('Playing...', style: PixelTheme.labelStyle.copyWith(color: PixelTheme.accent)),
                            ],
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
  
  // Pixel Style Dialog
  Widget _buildPixelDialog({required String title, required String content}) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.zero),
      elevation: 0,
      backgroundColor: Colors.transparent,
      child: Container(
        decoration: BoxDecoration(
          color: PixelTheme.surface,
          border: PixelTheme.pixelBorder,
          boxShadow: PixelTheme.cardShadow,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                border: Border(bottom: BorderSide(color: PixelTheme.text, width: 2)),
                color: PixelTheme.primary.withOpacity(0.1),
              ),
              child: Text(
                title,
                style: PixelTheme.titleStyle,
                textAlign: TextAlign.center,
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(16),
              child: Text(
                content,
                style: PixelTheme.bodyStyle,
              ),
            ),
            Container(
              width: double.infinity,
              decoration: BoxDecoration(
                border: Border(top: BorderSide(color: PixelTheme.text, width: 1)),
              ),
              child: TextButton(
                onPressed: () => Navigator.of(context).pop(),
                style: ButtonStyle(
                  backgroundColor: MaterialStateProperty.all(PixelTheme.surface),
                  foregroundColor: MaterialStateProperty.all(PixelTheme.text),
                  padding: MaterialStateProperty.all(EdgeInsets.symmetric(vertical: 12)),
                  shape: MaterialStateProperty.all(RoundedRectangleBorder(borderRadius: BorderRadius.zero)),
                ),
                child: Text('Close', style: PixelTheme.bodyStyle),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // Pixel Style Audio Controls Button
  Widget _buildPixelAudioControls() {
    final bool isPlaying = _audioPlayerManager.isPlaying;
    
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Container(
          margin: EdgeInsets.symmetric(horizontal: 8),
          decoration: BoxDecoration(
            color: PixelTheme.surface,
            border: Border.all(color: PixelTheme.text, width: 2),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.2),
                offset: const Offset(2, 2),
                blurRadius: 0,
              ),
            ],
          ),
          child: Material(
            color: isPlaying ? PixelTheme.accent : PixelTheme.primary,
            child: InkWell(
              onTap: () {
                if (isPlaying) {
                  _audioPlayerManager.pauseMusic();
                } else {
                  _audioPlayerManager.resumeMusic();
                }
              },
              child: Container(
                padding: EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      isPlaying ? Icons.pause : Icons.play_arrow, 
                      color: Colors.white,
                      size: 18,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      isPlaying ? 'Pause' : 'Play',
                      style: PixelTheme.bodyStyle.copyWith(color: Colors.white),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
        Container(
          margin: EdgeInsets.symmetric(horizontal: 8),
          decoration: BoxDecoration(
            color: PixelTheme.surface,
            border: Border.all(color: PixelTheme.text, width: 2),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.2),
                offset: const Offset(2, 2),
                blurRadius: 0,
              ),
            ],
          ),
          child: Material(
            color: PixelTheme.textLight,
            child: InkWell(
              onTap: () {
                _audioPlayerManager.stopMusic();
              },
              child: Container(
                padding: EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.stop, 
                      color: Colors.white,
                      size: 18,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      'Stop',
                      style: PixelTheme.bodyStyle.copyWith(color: Colors.white),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  String _safeText(String? text, String defaultValue) {
    if (text == null || text.isEmpty) {
      return defaultValue;
    }
    
    try {
      final filteredText = text
          .replaceAll(RegExp(r'[\p{Cc}\p{Cf}\p{Co}\p{Cn}]', unicode: true), '')
          .trim();
          
      if (filteredText.isEmpty || filteredText.length < text.length / 2) {
        developer.log('Detected potentially corrupted text: $text');
        return defaultValue;
      }
      
      if (filteredText.runes.where((rune) => 
        (rune < 32 || (rune > 126 && rune < 160)) && 
        rune != 10 && rune != 13).length > filteredText.length / 3) {
        developer.log('Text contains too many special characters: $text');
        return defaultValue;
      }
      
      return filteredText;
    } catch (e) {
      developer.log('Error processing text: $e', error: e);
      return defaultValue;
    }
  }

  String? getMusicId(dynamic response) {
    if (response is List && response.isNotEmpty) {
      final firstItem = response[0];
      if (firstItem is Map && firstItem.containsKey('id')) {
        return firstItem['id'].toString();
      }
    } else if (response is Map && response.containsKey('id')) {
      return response['id'].toString();
    }
    
    return null;
  }

  // Add this helper method for re-initializing the service
  Future<void> _initializeStabilityService() async {
    setState(() {
      _isLoading = true;
      _statusMessage = "Attempting to initialize Stability AI service...";
      _errorMessage = null;
    });
    
    try {
      developer.log('Attempting to initialize StabilityAudioService...');
      
      // Here we use a simple HTTP request to check the network connection
      try {
        final testResponse = await http.get(Uri.parse('https://api.stability.ai/v1/engines/list'));
        developer.log('Test API connection status code: ${testResponse.statusCode}');
      } catch (netError) {
        developer.log('API connection test failed: $netError');
      }
      
      final apiKey = AppConfig.stabilityApiKey;
      developer.log('API key diagnostic: ${AppConfig.getStabilityApiKeyStatus()}');
      
      _stabilityService = StabilityAudioService(apiKey: apiKey);
      developer.log('StabilityAudioService initialized successfully');
      
      setState(() {
        _isLoading = false;
        _statusMessage = "Stability AI service initialized successfully, now you can generate music";
        _errorMessage = null;
      });
    } catch (e) {
      developer.log('StabilityAudioService initialization failed: $e', error: e);
      setState(() {
        _isLoading = false;
        _errorMessage = "Failed to initialize Stability AI service: $e, please check the following points:\n1. Ensure the network connection is normal\n2. Whether the API key format is correct\n3. Whether the application has network permissions";
        _statusMessage = "Initialization failed";
      });
      
      // Show more diagnostic information
      _showDetailedErrorDialog("Initialization failed", e.toString());
    }
  }

  // Show detailed error information dialog
  void _showDetailedErrorDialog(String title, String errorMessage) {
    if (!mounted) return;
    
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(title),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Error details: $errorMessage'),
              const SizedBox(height: 16),
              const Text('API configuration information:'),
              Text('API key status: ${AppConfig.getStabilityApiKeyStatus()}'),
              Text('API URL: ${AppConfig.getStabilityAudioUrl()}'),
              const SizedBox(height: 16),
              const Text('Possible solutions:'),
              const Text('• Check the network connection'),
              const Text('• Confirm whether the API key is correct'),
              const Text('• Restart the application'),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              _initializeStabilityService();
            },
            child: const Text('Retry'),
          ),
        ],
      ),
    );
  }
} 