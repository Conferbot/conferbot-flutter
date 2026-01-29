import 'dart:async';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:record/record.dart';
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';
import '../utils/logger.dart';

/// Voice recording configuration
class VoiceRecordingConfig {
  /// Maximum recording duration in seconds
  final int maxDurationSeconds;

  /// Audio encoder to use
  final AudioEncoder encoder;

  /// Sample rate in Hz
  final int sampleRate;

  /// Number of audio channels (1 = mono, 2 = stereo)
  final int numChannels;

  /// Bit rate in bits per second
  final int bitRate;

  const VoiceRecordingConfig({
    this.maxDurationSeconds = 120, // 2 minutes max
    this.encoder = AudioEncoder.aacLc,
    this.sampleRate = 44100,
    this.numChannels = 1, // Mono for voice
    this.bitRate = 128000,
  });
}

/// Recording state enumeration
enum RecordingState {
  /// Not recording, ready to start
  idle,

  /// Recording in progress
  recording,

  /// Recording paused
  paused,

  /// Processing/saving the recording
  processing,

  /// Permission denied
  permissionDenied,

  /// Error occurred
  error,
}

/// Voice recording service for audio capture
/// Handles microphone permissions, recording, and amplitude monitoring
class VoiceRecordingService extends ChangeNotifier {
  final VoiceRecordingConfig config;

  final AudioRecorder _recorder = AudioRecorder();

  // State
  RecordingState _state = RecordingState.idle;
  String? _currentFilePath;
  Duration _currentDuration = Duration.zero;
  double _currentAmplitude = 0.0;
  String? _errorMessage;

  // Timers
  Timer? _durationTimer;
  Timer? _amplitudeTimer;
  Timer? _maxDurationTimer;

  // Stream controllers
  final StreamController<double> _amplitudeController =
      StreamController<double>.broadcast();
  final StreamController<Duration> _durationController =
      StreamController<Duration>.broadcast();
  final StreamController<RecordingState> _stateController =
      StreamController<RecordingState>.broadcast();

  VoiceRecordingService({
    this.config = const VoiceRecordingConfig(),
  });

  // ========== Getters ==========

  /// Current recording state
  RecordingState get state => _state;

  /// Whether currently recording
  bool get isRecording => _state == RecordingState.recording;

  /// Whether recording is paused
  bool get isPaused => _state == RecordingState.paused;

  /// Current recording duration
  Duration get currentDuration => _currentDuration;

  /// Current amplitude (0.0 to 1.0)
  double get currentAmplitude => _currentAmplitude;

  /// Current file path being recorded to
  String? get currentFilePath => _currentFilePath;

  /// Error message if state is error
  String? get errorMessage => _errorMessage;

  // ========== Streams ==========

  /// Stream of amplitude values (0.0 to 1.0) for visualizer
  Stream<double> get amplitudeStream => _amplitudeController.stream;

  /// Stream of recording duration updates
  Stream<Duration> get durationStream => _durationController.stream;

  /// Stream of recording state changes
  Stream<RecordingState> get stateStream => _stateController.stream;

  // ========== Permission Handling ==========

  /// Check if microphone permission is granted
  Future<bool> hasPermission() async {
    final status = await Permission.microphone.status;
    return status.isGranted;
  }

  /// Request microphone permission
  /// Returns true if permission is granted
  Future<bool> requestPermission() async {
    try {
      // Check current status
      var status = await Permission.microphone.status;

      if (status.isGranted) {
        return true;
      }

      if (status.isDenied) {
        // Request permission
        status = await Permission.microphone.request();

        if (status.isGranted) {
          return true;
        }
      }

      if (status.isPermanentlyDenied) {
        // Permission permanently denied, user must enable in settings
        _setState(RecordingState.permissionDenied);
        _setError('Microphone permission permanently denied. Please enable in settings.');
        return false;
      }

      _setState(RecordingState.permissionDenied);
      _setError('Microphone permission denied');
      return false;
    } catch (e) {
      voiceLogger.error('Error requesting permission', e);
      _setState(RecordingState.error);
      _setError('Failed to request microphone permission');
      return false;
    }
  }

  /// Open app settings for permission management
  Future<bool> openSettings() async {
    return await openAppSettings();
  }

  // ========== Recording Control ==========

  /// Start recording audio
  /// Returns true if recording started successfully
  Future<bool> startRecording() async {
    if (_state == RecordingState.recording) {
      voiceLogger.debug('Already recording');
      return true;
    }

    try {
      // Check permission first
      final hasPermission = await requestPermission();
      if (!hasPermission) {
        return false;
      }

      // Generate file path
      final directory = await _getRecordingDirectory();
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final extension = _getFileExtension();
      _currentFilePath = '${directory.path}/voice_$timestamp.$extension';

      // Configure and start recording
      await _recorder.start(
        RecordConfig(
          encoder: config.encoder,
          sampleRate: config.sampleRate,
          numChannels: config.numChannels,
          bitRate: config.bitRate,
        ),
        path: _currentFilePath!,
      );

      // Reset state
      _currentDuration = Duration.zero;
      _currentAmplitude = 0.0;
      _errorMessage = null;

      // Start timers
      _startTimers();

      _setState(RecordingState.recording);
      voiceLogger.debug('Recording started', _currentFilePath);

      return true;
    } catch (e) {
      voiceLogger.error('Error starting recording', e);
      _setState(RecordingState.error);
      _setError('Failed to start recording: $e');
      return false;
    }
  }

  /// Stop recording and return the file path
  /// Returns the path to the recorded audio file, or null if failed
  Future<String?> stopRecording() async {
    if (_state != RecordingState.recording && _state != RecordingState.paused) {
      voiceLogger.debug('Not recording, cannot stop');
      return null;
    }

    try {
      _setState(RecordingState.processing);

      // Stop timers
      _stopTimers();

      // Stop recording
      final path = await _recorder.stop();

      _setState(RecordingState.idle);
      voiceLogger.debug('Recording stopped', path);

      // Reset amplitude
      _currentAmplitude = 0.0;
      _amplitudeController.add(0.0);

      return path ?? _currentFilePath;
    } catch (e) {
      voiceLogger.error('Error stopping recording', e);
      _setState(RecordingState.error);
      _setError('Failed to stop recording: $e');
      return null;
    }
  }

  /// Cancel the current recording and delete the file
  Future<void> cancelRecording() async {
    try {
      // Stop timers
      _stopTimers();

      // Stop recording if active
      if (_state == RecordingState.recording || _state == RecordingState.paused) {
        await _recorder.stop();
      }

      // Delete the file if it exists
      if (_currentFilePath != null) {
        final file = File(_currentFilePath!);
        if (await file.exists()) {
          await file.delete();
          voiceLogger.debug('Deleted cancelled recording', _currentFilePath);
        }
      }

      // Reset state
      _currentFilePath = null;
      _currentDuration = Duration.zero;
      _currentAmplitude = 0.0;
      _errorMessage = null;

      _setState(RecordingState.idle);
      _amplitudeController.add(0.0);
      _durationController.add(Duration.zero);
    } catch (e) {
      voiceLogger.error('Error cancelling recording', e);
      // Reset state anyway
      _setState(RecordingState.idle);
    }
  }

  /// Pause the current recording
  Future<void> pauseRecording() async {
    if (_state != RecordingState.recording) {
      return;
    }

    try {
      await _recorder.pause();
      _setState(RecordingState.paused);
      voiceLogger.debug('Recording paused');
    } catch (e) {
      voiceLogger.error('Error pausing recording', e);
    }
  }

  /// Resume a paused recording
  Future<void> resumeRecording() async {
    if (_state != RecordingState.paused) {
      return;
    }

    try {
      await _recorder.resume();
      _setState(RecordingState.recording);
      voiceLogger.debug('Recording resumed');
    } catch (e) {
      voiceLogger.error('Error resuming recording', e);
    }
  }

  // ========== Private Methods ==========

  /// Get the directory for storing recordings
  Future<Directory> _getRecordingDirectory() async {
    final tempDir = await getTemporaryDirectory();
    final recordingsDir = Directory('${tempDir.path}/conferbot_recordings');

    if (!await recordingsDir.exists()) {
      await recordingsDir.create(recursive: true);
    }

    return recordingsDir;
  }

  /// Get file extension based on encoder
  String _getFileExtension() {
    switch (config.encoder) {
      case AudioEncoder.aacLc:
      case AudioEncoder.aacHe:
      case AudioEncoder.aacEld:
        return 'm4a';
      case AudioEncoder.opus:
        return 'opus';
      case AudioEncoder.wav:
        return 'wav';
      case AudioEncoder.flac:
        return 'flac';
      default:
        return 'm4a';
    }
  }

  /// Start duration and amplitude timers
  void _startTimers() {
    // Duration timer - updates every 100ms
    _durationTimer = Timer.periodic(const Duration(milliseconds: 100), (_) {
      _currentDuration += const Duration(milliseconds: 100);
      _durationController.add(_currentDuration);
      notifyListeners();
    });

    // Amplitude timer - updates every 50ms for smooth visualizer
    _amplitudeTimer = Timer.periodic(const Duration(milliseconds: 50), (_) async {
      try {
        final amplitude = await _recorder.getAmplitude();
        // Convert dB to 0.0-1.0 range
        // Typical values: -160 (silence) to 0 (max)
        final dBValue = amplitude.current;
        // Normalize: assuming -60dB to 0dB as useful range
        double normalized = (dBValue + 60) / 60;
        normalized = normalized.clamp(0.0, 1.0);

        _currentAmplitude = normalized;
        _amplitudeController.add(normalized);
      } catch (e) {
        // Ignore amplitude errors during recording
      }
    });

    // Max duration timer
    _maxDurationTimer = Timer(
      Duration(seconds: config.maxDurationSeconds),
      () async {
        voiceLogger.debug('Max duration reached, stopping');
        await stopRecording();
      },
    );
  }

  /// Stop all timers
  void _stopTimers() {
    _durationTimer?.cancel();
    _durationTimer = null;

    _amplitudeTimer?.cancel();
    _amplitudeTimer = null;

    _maxDurationTimer?.cancel();
    _maxDurationTimer = null;
  }

  /// Set recording state and notify
  void _setState(RecordingState newState) {
    if (_state != newState) {
      _state = newState;
      _stateController.add(newState);
      notifyListeners();
    }
  }

  /// Set error message
  void _setError(String message) {
    _errorMessage = message;
    notifyListeners();
  }

  // ========== Utility Methods ==========

  /// Delete a recording file
  Future<void> deleteRecording(String filePath) async {
    try {
      final file = File(filePath);
      if (await file.exists()) {
        await file.delete();
        voiceLogger.debug('Deleted recording', filePath);
      }
    } catch (e) {
      voiceLogger.error('Error deleting recording', e);
    }
  }

  /// Get file size in bytes
  Future<int> getFileSize(String filePath) async {
    try {
      final file = File(filePath);
      if (await file.exists()) {
        return await file.length();
      }
    } catch (e) {
      voiceLogger.error('Error getting file size', e);
    }
    return 0;
  }

  /// Format duration for display (MM:SS)
  static String formatDuration(Duration duration) {
    final minutes = duration.inMinutes.remainder(60).toString().padLeft(2, '0');
    final seconds = duration.inSeconds.remainder(60).toString().padLeft(2, '0');
    return '$minutes:$seconds';
  }

  /// Clear all cached recordings
  Future<void> clearCache() async {
    try {
      final directory = await _getRecordingDirectory();
      if (await directory.exists()) {
        await directory.delete(recursive: true);
        voiceLogger.debug('Cache cleared');
      }
    } catch (e) {
      voiceLogger.error('Error clearing cache', e);
    }
  }

  // ========== Cleanup ==========

  @override
  void dispose() {
    _stopTimers();
    _recorder.dispose();
    _amplitudeController.close();
    _durationController.close();
    _stateController.close();
    super.dispose();
  }
}
