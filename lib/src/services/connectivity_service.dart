import 'dart:async';
import 'dart:io';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/foundation.dart';

import '../utils/logger.dart';

/// Service for monitoring network connectivity status.
/// Provides real-time updates on connection state changes with:
/// - Stream-based updates for reactive UI
/// - Actual internet verification (not just network interface check)
/// - Connection type detection (WiFi, Mobile, Ethernet, etc.)
/// - Automatic retry and recovery mechanisms
class ConnectivityService with ChangeNotifier {
  static ConnectivityService? _instance;
  static ConnectivityService get instance {
    _instance ??= ConnectivityService._internal();
    return _instance!;
  }

  ConnectivityService._internal() {
    _initialize();
  }

  /// For testing purposes - creates isolated instance
  @visibleForTesting
  factory ConnectivityService.forTesting() {
    return ConnectivityService._internal();
  }

  /// Reset singleton for testing
  @visibleForTesting
  static void resetInstance() {
    _instance?.dispose();
    _instance = null;
  }

  final Connectivity _connectivity = Connectivity();
  StreamSubscription<List<ConnectivityResult>>? _subscription;

  bool _isOnline = true;
  bool _isInitialized = false;
  bool _isVerifying = false;
  ConnectivityResult _currentResult = ConnectivityResult.none;
  DateTime? _lastVerificationTime;
  Timer? _verificationTimer;

  // Configuration
  static const Duration _verificationInterval = Duration(seconds: 30);
  static const Duration _verificationTimeout = Duration(seconds: 10);
  static const Duration _debounceInterval = Duration(milliseconds: 500);

  // Debounce timer for rapid connectivity changes
  Timer? _debounceTimer;
  List<ConnectivityResult>? _pendingResult;

  // Stream controllers for reactive updates
  final StreamController<bool> _onlineStatusController =
      StreamController<bool>.broadcast();
  final StreamController<ConnectivityResult> _connectivityResultController =
      StreamController<ConnectivityResult>.broadcast();
  final StreamController<ConnectivityChange> _connectivityChangeController =
      StreamController<ConnectivityChange>.broadcast();

  /// Whether the device is currently online
  bool get isOnline => _isOnline;

  /// Whether the service has been initialized
  bool get isInitialized => _isInitialized;

  /// Whether currently verifying internet access
  bool get isVerifying => _isVerifying;

  /// Current connectivity result
  ConnectivityResult get currentResult => _currentResult;

  /// Stream of online status changes (true = online, false = offline)
  Stream<bool> get onlineStatus => _onlineStatusController.stream;

  /// Stream of connectivity result changes
  Stream<ConnectivityResult> get connectivityResultStream =>
      _connectivityResultController.stream;

  /// Stream of detailed connectivity changes
  Stream<ConnectivityChange> get onConnectivityChange =>
      _connectivityChangeController.stream;

  /// Initialize the connectivity service
  Future<void> _initialize() async {
    if (_isInitialized) return;

    try {
      // Get initial connectivity status
      final results = await _connectivity.checkConnectivity();
      await _handleConnectivityChange(results, isInitial: true);

      // Listen for changes with error handling
      _subscription = _connectivity.onConnectivityChanged.listen(
        (results) => _handleConnectivityChange(results),
        onError: (error) {
          connectivityLogger.warning('Connectivity stream error: $error');
          // Assume online on error to avoid blocking
          _updateOnlineStatus(true);
        },
      );

      // Start periodic verification for accurate status
      _startPeriodicVerification();

      _isInitialized = true;
      connectivityLogger.debug('Connectivity service initialized. Online: $_isOnline');
    } catch (e) {
      connectivityLogger.error('Failed to initialize connectivity: $e');
      // Assume online on initialization failure to avoid blocking
      _isOnline = true;
      _isInitialized = true;
    }
  }

  /// Handle connectivity change event with debouncing
  Future<void> _handleConnectivityChange(
    List<ConnectivityResult> results, {
    bool isInitial = false,
  }) async {
    // Debounce rapid changes (e.g., WiFi -> Mobile transition)
    if (!isInitial) {
      _pendingResult = results;
      _debounceTimer?.cancel();
      _debounceTimer = Timer(_debounceInterval, () {
        _processConnectivityChange(_pendingResult!);
        _pendingResult = null;
      });
      return;
    }

    await _processConnectivityChange(results);
  }

  /// Process connectivity change after debouncing
  Future<void> _processConnectivityChange(List<ConnectivityResult> results) async {
    // Take the first result (most relevant)
    final result = results.isNotEmpty ? results.first : ConnectivityResult.none;
    final previousResult = _currentResult;
    _currentResult = result;
    _connectivityResultController.add(result);

    final wasOnline = _isOnline;
    final isNowOnline = _isConnectedResult(result);

    if (isNowOnline != wasOnline) {
      // Verify actual internet access before updating status
      if (isNowOnline) {
        final hasInternet = await _verifyInternetAccess();
        _updateOnlineStatus(hasInternet);
      } else {
        _updateOnlineStatus(false);
      }

      // Emit detailed change event
      _connectivityChangeController.add(ConnectivityChange(
        isOnline: _isOnline,
        previousResult: previousResult,
        currentResult: result,
        timestamp: DateTime.now(),
      ));
    }
  }

  /// Check if connectivity result indicates internet connection
  bool _isConnectedResult(ConnectivityResult result) {
    switch (result) {
      case ConnectivityResult.wifi:
      case ConnectivityResult.mobile:
      case ConnectivityResult.ethernet:
      case ConnectivityResult.vpn:
        return true;
      case ConnectivityResult.bluetooth:
        // Bluetooth may or may not provide internet
        return false;
      case ConnectivityResult.none:
      case ConnectivityResult.other:
        return false;
      default:
        return false;
    }
  }

  /// Update online status and notify listeners
  void _updateOnlineStatus(bool isOnline) {
    if (_isOnline != isOnline) {
      _isOnline = isOnline;
      _onlineStatusController.add(isOnline);
      notifyListeners();
      connectivityLogger.debug('Connectivity changed: ${isOnline ? "ONLINE" : "OFFLINE"}');
    }
  }

  /// Manually check connectivity status with verification.
  /// Returns true if online, false if offline.
  Future<bool> checkConnectivity() async {
    try {
      final results = await _connectivity.checkConnectivity();
      final result = results.isNotEmpty ? results.first : ConnectivityResult.none;
      final hasInterface = _isConnectedResult(result);

      if (hasInterface) {
        // Verify with actual network request for accuracy
        final hasInternet = await _verifyInternetAccess();
        if (hasInternet != _isOnline) {
          _updateOnlineStatus(hasInternet);
        }
        return hasInternet;
      }

      if (false != _isOnline) {
        _updateOnlineStatus(false);
      }
      return false;
    } catch (e) {
      connectivityLogger.warning('Error checking connectivity: $e');
      return _isOnline; // Return cached value on error
    }
  }

  /// Verify actual internet access by making a lightweight request.
  /// This catches cases where WiFi is connected but has no internet.
  Future<bool> _verifyInternetAccess() async {
    if (_isVerifying) return _isOnline;

    _isVerifying = true;
    try {
      // Try multiple hosts for reliability
      final hosts = ['conferbot.com', 'google.com', '1.1.1.1'];

      for (final host in hosts) {
        try {
          final result = await InternetAddress.lookup(host)
              .timeout(_verificationTimeout);
          if (result.isNotEmpty && result[0].rawAddress.isNotEmpty) {
            _lastVerificationTime = DateTime.now();
            return true;
          }
        } catch (_) {
          // Try next host
          continue;
        }
      }
      return false;
    } finally {
      _isVerifying = false;
    }
  }

  /// Start periodic internet verification
  void _startPeriodicVerification() {
    _verificationTimer?.cancel();
    _verificationTimer = Timer.periodic(_verificationInterval, (_) async {
      if (_isConnectedResult(_currentResult)) {
        final hasInternet = await _verifyInternetAccess();
        if (hasInternet != _isOnline) {
          _updateOnlineStatus(hasInternet);
        }
      }
    });
  }

  /// Wait for connection to be restored.
  /// Returns a future that completes when online.
  Future<void> waitForConnection({Duration? timeout}) async {
    if (_isOnline) return;

    final completer = Completer<void>();
    StreamSubscription<bool>? subscription;

    subscription = onlineStatus.listen((isOnline) {
      if (isOnline && !completer.isCompleted) {
        subscription?.cancel();
        completer.complete();
      }
    });

    if (timeout != null) {
      return completer.future.timeout(
        timeout,
        onTimeout: () {
          subscription?.cancel();
          throw TimeoutException('Waiting for connection timed out', timeout);
        },
      );
    }

    return completer.future;
  }

  /// Execute a callback when connection is restored.
  /// Useful for triggering actions when coming back online.
  void onConnectionRestored(VoidCallback callback) {
    late StreamSubscription<bool> subscription;
    subscription = onlineStatus.listen((isOnline) {
      if (isOnline) {
        callback();
        subscription.cancel();
      }
    });
  }

  /// Get a human-readable description of current connection type
  String get connectionTypeDescription {
    switch (_currentResult) {
      case ConnectivityResult.wifi:
        return 'WiFi';
      case ConnectivityResult.mobile:
        return 'Mobile Data';
      case ConnectivityResult.ethernet:
        return 'Ethernet';
      case ConnectivityResult.vpn:
        return 'VPN';
      case ConnectivityResult.bluetooth:
        return 'Bluetooth';
      case ConnectivityResult.none:
        return 'No Connection';
      case ConnectivityResult.other:
        return 'Other';
      default:
        return 'Unknown';
    }
  }

  /// Check if connection is metered (mobile data)
  bool get isMeteredConnection {
    return _currentResult == ConnectivityResult.mobile;
  }

  /// Check if connection is fast (WiFi or Ethernet)
  bool get isFastConnection {
    return _currentResult == ConnectivityResult.wifi ||
        _currentResult == ConnectivityResult.ethernet;
  }

  /// Dispose of resources
  @override
  void dispose() {
    _subscription?.cancel();
    _debounceTimer?.cancel();
    _verificationTimer?.cancel();
    _onlineStatusController.close();
    _connectivityResultController.close();
    _connectivityChangeController.close();
    super.dispose();
  }
}

/// Detailed connectivity change event
class ConnectivityChange {
  /// Whether currently online after the change
  final bool isOnline;

  /// Previous connectivity result
  final ConnectivityResult previousResult;

  /// Current connectivity result
  final ConnectivityResult currentResult;

  /// When the change occurred
  final DateTime timestamp;

  const ConnectivityChange({
    required this.isOnline,
    required this.previousResult,
    required this.currentResult,
    required this.timestamp,
  });

  /// Whether this was a connection restoration
  bool get wasRestored => isOnline && previousResult == ConnectivityResult.none;

  /// Whether this was a connection loss
  bool get wasLost => !isOnline && previousResult != ConnectivityResult.none;

  /// Whether connection type changed (e.g., WiFi to Mobile)
  bool get typeChanged => previousResult != currentResult && isOnline;

  @override
  String toString() {
    return 'ConnectivityChange(isOnline: $isOnline, $previousResult -> $currentResult)';
  }
}

/// Connectivity status for use in widgets
enum NetworkStatus {
  /// Device is online with good connectivity
  online,

  /// Device is offline
  offline,

  /// Connectivity is being checked
  checking,

  /// Device is online but with limited connectivity
  limited,
}

/// Extension to easily get NetworkStatus from ConnectivityService
extension ConnectivityServiceNetworkStatus on ConnectivityService {
  NetworkStatus get networkStatus {
    if (!isInitialized) return NetworkStatus.checking;
    if (isVerifying) return NetworkStatus.checking;
    return isOnline ? NetworkStatus.online : NetworkStatus.offline;
  }
}
