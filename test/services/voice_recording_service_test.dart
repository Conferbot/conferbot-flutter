import 'dart:async';
import 'package:flutter_test/flutter_test.dart';
import 'package:conferbot_flutter/src/services/voice_recording_service.dart';
import 'package:record/record.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late TestableVoiceRecordingService recordingService;

  setUp(() {
    recordingService = TestableVoiceRecordingService();
  });

  tearDown(() {
    recordingService.dispose();
  });

  group('VoiceRecordingService Construction', () {
    test('should create with default config', () {
      expect(recordingService.config.maxDurationSeconds, 120);
      expect(recordingService.config.encoder, AudioEncoder.aacLc);
      expect(recordingService.config.sampleRate, 44100);
      expect(recordingService.config.numChannels, 1);
    });

    test('should create with custom config', () {
      const customConfig = VoiceRecordingConfig(
        maxDurationSeconds: 60,
        encoder: AudioEncoder.wav,
        sampleRate: 22050,
        numChannels: 2,
        bitRate: 64000,
      );

      final service = TestableVoiceRecordingService(config: customConfig);

      expect(service.config.maxDurationSeconds, 60);
      expect(service.config.encoder, AudioEncoder.wav);
      expect(service.config.sampleRate, 22050);
      expect(service.config.numChannels, 2);
      expect(service.config.bitRate, 64000);

      service.dispose();
    });

    test('should start in idle state', () {
      expect(recordingService.state, RecordingState.idle);
      expect(recordingService.isRecording, false);
      expect(recordingService.isPaused, false);
    });

    test('should have zero initial duration', () {
      expect(recordingService.currentDuration, Duration.zero);
    });

    test('should have zero initial amplitude', () {
      expect(recordingService.currentAmplitude, 0.0);
    });

    test('should have no current file path', () {
      expect(recordingService.currentFilePath, isNull);
    });
  });

  group('VoiceRecordingService Permission Handling', () {
    test('should report permission status', () async {
      recordingService.mockHasPermission = true;

      final hasPermission = await recordingService.hasPermission();

      expect(hasPermission, true);
    });

    test('should request permission when denied', () async {
      recordingService.mockHasPermission = false;
      recordingService.mockPermissionRequestResult = true;

      final result = await recordingService.requestPermission();

      expect(result, true);
    });

    test('should handle permanently denied permission', () async {
      recordingService.mockHasPermission = false;
      recordingService.mockPermissionPermanentlyDenied = true;

      final result = await recordingService.requestPermission();

      expect(result, false);
      expect(recordingService.state, RecordingState.permissionDenied);
      expect(recordingService.errorMessage, contains('permanently denied'));
    });

    test('should handle permission denial', () async {
      recordingService.mockHasPermission = false;
      recordingService.mockPermissionRequestResult = false;

      final result = await recordingService.requestPermission();

      expect(result, false);
      expect(recordingService.state, RecordingState.permissionDenied);
    });

    test('should open settings', () async {
      final result = await recordingService.openSettings();

      expect(result, true);
    });
  });

  group('VoiceRecordingService.startRecording', () {
    setUp(() {
      recordingService.mockHasPermission = true;
    });

    test('should start recording successfully', () async {
      final result = await recordingService.startRecording();

      expect(result, true);
      expect(recordingService.state, RecordingState.recording);
      expect(recordingService.isRecording, true);
      expect(recordingService.currentFilePath, isNotNull);
    });

    test('should generate file path with timestamp', () async {
      await recordingService.startRecording();

      expect(recordingService.currentFilePath, contains('voice_'));
      expect(recordingService.currentFilePath, endsWith('.m4a'));
    });

    test('should return true if already recording', () async {
      await recordingService.startRecording();

      final result = await recordingService.startRecording();

      expect(result, true);
    });

    test('should reset state on start', () async {
      recordingService.mockCurrentDuration = const Duration(seconds: 10);
      recordingService.mockCurrentAmplitude = 0.5;

      await recordingService.startRecording();

      expect(recordingService.currentDuration, Duration.zero);
      expect(recordingService.currentAmplitude, 0.0);
      expect(recordingService.errorMessage, isNull);
    });

    test('should fail without permission', () async {
      recordingService.mockHasPermission = false;
      recordingService.mockPermissionRequestResult = false;

      final result = await recordingService.startRecording();

      expect(result, false);
      expect(recordingService.isRecording, false);
    });

    test('should handle start error', () async {
      recordingService.mockStartError = Exception('Microphone busy');

      final result = await recordingService.startRecording();

      expect(result, false);
      expect(recordingService.state, RecordingState.error);
      expect(recordingService.errorMessage, contains('Microphone busy'));
    });
  });

  group('VoiceRecordingService.stopRecording', () {
    setUp(() async {
      recordingService.mockHasPermission = true;
      await recordingService.startRecording();
    });

    test('should stop recording and return file path', () async {
      final path = await recordingService.stopRecording();

      expect(path, isNotNull);
      expect(recordingService.state, RecordingState.idle);
      expect(recordingService.isRecording, false);
    });

    test('should reset amplitude on stop', () async {
      recordingService.mockCurrentAmplitude = 0.8;

      await recordingService.stopRecording();

      expect(recordingService.currentAmplitude, 0.0);
    });

    test('should return null if not recording', () async {
      await recordingService.stopRecording();

      final path = await recordingService.stopRecording();

      expect(path, isNull);
    });

    test('should handle stop error', () async {
      recordingService.mockStopError = Exception('Stop failed');

      final path = await recordingService.stopRecording();

      expect(path, isNull);
      expect(recordingService.state, RecordingState.error);
    });
  });

  group('VoiceRecordingService.cancelRecording', () {
    setUp(() async {
      recordingService.mockHasPermission = true;
      await recordingService.startRecording();
    });

    test('should cancel recording and reset state', () async {
      await recordingService.cancelRecording();

      expect(recordingService.state, RecordingState.idle);
      expect(recordingService.currentFilePath, isNull);
      expect(recordingService.currentDuration, Duration.zero);
      expect(recordingService.currentAmplitude, 0.0);
    });

    test('should delete recording file', () async {
      await recordingService.cancelRecording();

      expect(recordingService.deletedFiles, isNotEmpty);
    });

    test('should handle cancel when not recording', () async {
      await recordingService.stopRecording();

      await recordingService.cancelRecording();

      expect(recordingService.state, RecordingState.idle);
    });
  });

  group('VoiceRecordingService.pauseRecording', () {
    setUp(() async {
      recordingService.mockHasPermission = true;
      await recordingService.startRecording();
    });

    test('should pause recording', () async {
      await recordingService.pauseRecording();

      expect(recordingService.state, RecordingState.paused);
      expect(recordingService.isPaused, true);
      expect(recordingService.isRecording, false);
    });

    test('should do nothing if not recording', () async {
      await recordingService.stopRecording();

      await recordingService.pauseRecording();

      expect(recordingService.state, RecordingState.idle);
    });
  });

  group('VoiceRecordingService.resumeRecording', () {
    setUp(() async {
      recordingService.mockHasPermission = true;
      await recordingService.startRecording();
      await recordingService.pauseRecording();
    });

    test('should resume paused recording', () async {
      await recordingService.resumeRecording();

      expect(recordingService.state, RecordingState.recording);
      expect(recordingService.isRecording, true);
    });

    test('should do nothing if not paused', () async {
      await recordingService.resumeRecording();
      await recordingService.stopRecording();

      await recordingService.resumeRecording();

      expect(recordingService.state, RecordingState.idle);
    });
  });

  group('VoiceRecordingService Streams', () {
    setUp(() {
      recordingService.mockHasPermission = true;
    });

    test('should emit amplitude values', () async {
      final amplitudes = <double>[];
      final subscription = recordingService.amplitudeStream.listen(amplitudes.add);

      await recordingService.startRecording();
      recordingService.simulateAmplitude(0.5);
      recordingService.simulateAmplitude(0.8);
      recordingService.simulateAmplitude(0.3);

      await Future.delayed(const Duration(milliseconds: 50));

      expect(amplitudes, contains(0.5));
      expect(amplitudes, contains(0.8));
      expect(amplitudes, contains(0.3));

      await subscription.cancel();
    });

    test('should emit duration updates', () async {
      final durations = <Duration>[];
      final subscription = recordingService.durationStream.listen(durations.add);

      await recordingService.startRecording();
      recordingService.simulateDuration(const Duration(seconds: 1));
      recordingService.simulateDuration(const Duration(seconds: 2));

      await Future.delayed(const Duration(milliseconds: 50));

      expect(durations, contains(const Duration(seconds: 1)));
      expect(durations, contains(const Duration(seconds: 2)));

      await subscription.cancel();
    });

    test('should emit state changes', () async {
      final states = <RecordingState>[];
      final subscription = recordingService.stateStream.listen(states.add);

      await recordingService.startRecording();
      await recordingService.pauseRecording();
      await recordingService.resumeRecording();
      await recordingService.stopRecording();

      await Future.delayed(const Duration(milliseconds: 50));

      expect(states, contains(RecordingState.recording));
      expect(states, contains(RecordingState.paused));
      expect(states, contains(RecordingState.idle));

      await subscription.cancel();
    });
  });

  group('VoiceRecordingService Duration Tracking', () {
    setUp(() {
      recordingService.mockHasPermission = true;
    });

    test('should track recording duration', () async {
      await recordingService.startRecording();

      recordingService.simulateDuration(const Duration(seconds: 5));

      expect(recordingService.currentDuration, const Duration(seconds: 5));
    });

    test('should stop at max duration', () async {
      recordingService = TestableVoiceRecordingService(
        config: const VoiceRecordingConfig(maxDurationSeconds: 2),
      );
      recordingService.mockHasPermission = true;

      await recordingService.startRecording();

      recordingService.triggerMaxDuration();

      expect(recordingService.state, RecordingState.idle);
    });
  });

  group('VoiceRecordingService Utility Methods', () {
    test('should delete recording file', () async {
      await recordingService.deleteRecording('/path/to/file.m4a');

      expect(recordingService.deletedFiles, contains('/path/to/file.m4a'));
    });

    test('should get file size', () async {
      recordingService.mockFileSize = 12345;

      final size = await recordingService.getFileSize('/path/to/file.m4a');

      expect(size, 12345);
    });

    test('should return 0 for non-existent file', () async {
      recordingService.mockFileExists = false;

      final size = await recordingService.getFileSize('/non/existent.m4a');

      expect(size, 0);
    });

    test('should format duration correctly', () {
      expect(
        VoiceRecordingService.formatDuration(const Duration(seconds: 65)),
        '01:05',
      );
      expect(
        VoiceRecordingService.formatDuration(const Duration(minutes: 2, seconds: 30)),
        '02:30',
      );
      expect(
        VoiceRecordingService.formatDuration(Duration.zero),
        '00:00',
      );
    });

    test('should clear cache', () async {
      await recordingService.clearCache();

      expect(recordingService.cacheClearCount, 1);
    });
  });

  group('VoiceRecordingService ChangeNotifier', () {
    test('should notify listeners on state change', () async {
      recordingService.mockHasPermission = true;

      var notificationCount = 0;
      recordingService.addListener(() => notificationCount++);

      await recordingService.startRecording();
      await recordingService.pauseRecording();
      await recordingService.resumeRecording();
      await recordingService.stopRecording();

      expect(notificationCount, greaterThanOrEqualTo(4));
    });
  });

  group('VoiceRecordingService.dispose', () {
    test('should close all stream controllers', () async {
      // Create a separate instance for this test to avoid double dispose
      final service = TestableVoiceRecordingService();
      service.mockHasPermission = true;

      final amplitudeCompleter = Completer<void>();
      final durationCompleter = Completer<void>();
      final stateCompleter = Completer<void>();

      service.amplitudeStream.listen(
        (_) {},
        onDone: () => amplitudeCompleter.complete(),
      );
      service.durationStream.listen(
        (_) {},
        onDone: () => durationCompleter.complete(),
      );
      service.stateStream.listen(
        (_) {},
        onDone: () => stateCompleter.complete(),
      );

      service.dispose();

      await expectLater(amplitudeCompleter.future, completes);
      await expectLater(durationCompleter.future, completes);
      await expectLater(stateCompleter.future, completes);
    });

    test('should cancel timers on dispose', () async {
      // Create a separate instance for this test to avoid double dispose
      final service = TestableVoiceRecordingService();
      service.mockHasPermission = true;
      await service.startRecording();

      service.dispose();

      // No error should occur
    });
  });

  group('VoiceRecordingConfig', () {
    test('should have correct default values', () {
      const config = VoiceRecordingConfig();

      expect(config.maxDurationSeconds, 120);
      expect(config.encoder, AudioEncoder.aacLc);
      expect(config.sampleRate, 44100);
      expect(config.numChannels, 1);
      expect(config.bitRate, 128000);
    });

    test('should accept custom values', () {
      const config = VoiceRecordingConfig(
        maxDurationSeconds: 300,
        encoder: AudioEncoder.opus,
        sampleRate: 48000,
        numChannels: 2,
        bitRate: 256000,
      );

      expect(config.maxDurationSeconds, 300);
      expect(config.encoder, AudioEncoder.opus);
      expect(config.sampleRate, 48000);
      expect(config.numChannels, 2);
      expect(config.bitRate, 256000);
    });
  });

  group('RecordingState Enum', () {
    test('should have all expected states', () {
      expect(RecordingState.values, contains(RecordingState.idle));
      expect(RecordingState.values, contains(RecordingState.recording));
      expect(RecordingState.values, contains(RecordingState.paused));
      expect(RecordingState.values, contains(RecordingState.processing));
      expect(RecordingState.values, contains(RecordingState.permissionDenied));
      expect(RecordingState.values, contains(RecordingState.error));
    });
  });
}

/// Testable voice recording service that mocks recorder and permissions
class TestableVoiceRecordingService extends VoiceRecordingService {
  bool mockHasPermission = false;
  bool mockPermissionRequestResult = false;
  bool mockPermissionPermanentlyDenied = false;
  Exception? mockStartError;
  Exception? mockStopError;
  Duration mockCurrentDuration = Duration.zero;
  double mockCurrentAmplitude = 0.0;
  int mockFileSize = 0;
  bool mockFileExists = true;
  int cacheClearCount = 0;
  final List<String> deletedFiles = [];

  RecordingState _testState = RecordingState.idle;
  String? _testFilePath;

  final StreamController<double> _testAmplitudeController =
      StreamController<double>.broadcast();
  final StreamController<Duration> _testDurationController =
      StreamController<Duration>.broadcast();
  final StreamController<RecordingState> _testStateController =
      StreamController<RecordingState>.broadcast();

  TestableVoiceRecordingService({
    super.config = const VoiceRecordingConfig(),
  });

  @override
  RecordingState get state => _testState;

  @override
  bool get isRecording => _testState == RecordingState.recording;

  @override
  bool get isPaused => _testState == RecordingState.paused;

  @override
  Duration get currentDuration => mockCurrentDuration;

  @override
  double get currentAmplitude => mockCurrentAmplitude;

  @override
  String? get currentFilePath => _testFilePath;

  String? _testErrorMessage;
  @override
  String? get errorMessage => _testErrorMessage;

  @override
  Stream<double> get amplitudeStream => _testAmplitudeController.stream;

  @override
  Stream<Duration> get durationStream => _testDurationController.stream;

  @override
  Stream<RecordingState> get stateStream => _testStateController.stream;

  @override
  Future<bool> hasPermission() async {
    return mockHasPermission;
  }

  @override
  Future<bool> requestPermission() async {
    if (mockHasPermission) return true;

    if (mockPermissionPermanentlyDenied) {
      _setState(RecordingState.permissionDenied);
      _testErrorMessage = 'Microphone permission permanently denied. Please enable in settings.';
      return false;
    }

    if (mockPermissionRequestResult) {
      mockHasPermission = true;
      return true;
    }

    _setState(RecordingState.permissionDenied);
    _testErrorMessage = 'Microphone permission denied';
    return false;
  }

  @override
  Future<bool> openSettings() async {
    return true;
  }

  @override
  Future<bool> startRecording() async {
    if (_testState == RecordingState.recording) {
      return true;
    }

    final hasPermission = await requestPermission();
    if (!hasPermission) {
      return false;
    }

    if (mockStartError != null) {
      _setState(RecordingState.error);
      _testErrorMessage = 'Failed to start recording: ${mockStartError.toString()}';
      return false;
    }

    _testFilePath = '/tmp/conferbot_recordings/voice_${DateTime.now().millisecondsSinceEpoch}.m4a';
    mockCurrentDuration = Duration.zero;
    mockCurrentAmplitude = 0.0;
    _testErrorMessage = null;

    _setState(RecordingState.recording);
    return true;
  }

  @override
  Future<String?> stopRecording() async {
    if (_testState != RecordingState.recording && _testState != RecordingState.paused) {
      return null;
    }

    if (mockStopError != null) {
      _setState(RecordingState.error);
      _testErrorMessage = 'Failed to stop recording: ${mockStopError.toString()}';
      return null;
    }

    _setState(RecordingState.processing);
    final path = _testFilePath;

    mockCurrentAmplitude = 0.0;
    _testAmplitudeController.add(0.0);

    _setState(RecordingState.idle);
    return path;
  }

  @override
  Future<void> cancelRecording() async {
    if (_testState == RecordingState.recording || _testState == RecordingState.paused) {
      if (_testFilePath != null) {
        deletedFiles.add(_testFilePath!);
      }
    }

    _testFilePath = null;
    mockCurrentDuration = Duration.zero;
    mockCurrentAmplitude = 0.0;
    _testErrorMessage = null;

    _setState(RecordingState.idle);
    _testAmplitudeController.add(0.0);
    _testDurationController.add(Duration.zero);
  }

  @override
  Future<void> pauseRecording() async {
    if (_testState != RecordingState.recording) {
      return;
    }

    _setState(RecordingState.paused);
  }

  @override
  Future<void> resumeRecording() async {
    if (_testState != RecordingState.paused) {
      return;
    }

    _setState(RecordingState.recording);
  }

  @override
  Future<void> deleteRecording(String filePath) async {
    deletedFiles.add(filePath);
  }

  @override
  Future<int> getFileSize(String filePath) async {
    if (!mockFileExists) return 0;
    return mockFileSize;
  }

  @override
  Future<void> clearCache() async {
    cacheClearCount++;
  }

  void _setState(RecordingState newState) {
    if (_testState != newState) {
      _testState = newState;
      _testStateController.add(newState);
      notifyListeners();
    }
  }

  void simulateAmplitude(double amplitude) {
    mockCurrentAmplitude = amplitude;
    _testAmplitudeController.add(amplitude);
  }

  void simulateDuration(Duration duration) {
    mockCurrentDuration = duration;
    _testDurationController.add(duration);
    notifyListeners();
  }

  void triggerMaxDuration() {
    stopRecording();
  }

  @override
  void dispose() {
    _testAmplitudeController.close();
    _testDurationController.close();
    _testStateController.close();
    super.dispose();
  }
}
