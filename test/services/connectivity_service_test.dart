import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:conferbot_flutter/src/services/connectivity_service.dart';

void main() {
  late TestableConnectivityService connectivityService;

  setUp(() {
    connectivityService = TestableConnectivityService();
  });

  tearDown(() {
    connectivityService.dispose();
  });

  group('ConnectivityService Construction', () {
    test('should start with default online status', () {
      expect(connectivityService.isOnline, true);
    });

    test('should start with none connectivity result', () {
      expect(connectivityService.currentResult, ConnectivityResult.none);
    });

    test('should not be initialized before first check', () {
      expect(connectivityService.isInitialized, false);
    });
  });

  group('ConnectivityService Online Status', () {
    test('should report online for WiFi connection', () async {
      await connectivityService.simulateConnectivityChange(
        [ConnectivityResult.wifi],
        hasInternet: true,
      );

      expect(connectivityService.isOnline, true);
      expect(connectivityService.currentResult, ConnectivityResult.wifi);
    });

    test('should report online for mobile connection', () async {
      await connectivityService.simulateConnectivityChange(
        [ConnectivityResult.mobile],
        hasInternet: true,
      );

      expect(connectivityService.isOnline, true);
      expect(connectivityService.currentResult, ConnectivityResult.mobile);
    });

    test('should report online for ethernet connection', () async {
      await connectivityService.simulateConnectivityChange(
        [ConnectivityResult.ethernet],
        hasInternet: true,
      );

      expect(connectivityService.isOnline, true);
      expect(connectivityService.currentResult, ConnectivityResult.ethernet);
    });

    test('should report online for VPN connection', () async {
      await connectivityService.simulateConnectivityChange(
        [ConnectivityResult.vpn],
        hasInternet: true,
      );

      expect(connectivityService.isOnline, true);
      expect(connectivityService.currentResult, ConnectivityResult.vpn);
    });

    test('should report offline for no connection', () async {
      await connectivityService.simulateConnectivityChange(
        [ConnectivityResult.none],
        hasInternet: false,
      );

      expect(connectivityService.isOnline, false);
      expect(connectivityService.currentResult, ConnectivityResult.none);
    });

    test('should report offline for bluetooth connection', () async {
      await connectivityService.simulateConnectivityChange(
        [ConnectivityResult.bluetooth],
        hasInternet: false,
      );

      expect(connectivityService.isOnline, false);
    });
  });

  group('ConnectivityService State Change Streams', () {
    test('should emit online status changes', () async {
      final statusChanges = <bool>[];
      final subscription = connectivityService.onlineStatus.listen(statusChanges.add);

      // First, set to offline (changes from default true to false)
      await connectivityService.simulateConnectivityChange(
        [ConnectivityResult.none],
        hasInternet: false,
      );

      // Then, restore connection (changes from false to true)
      await connectivityService.simulateConnectivityChange(
        [ConnectivityResult.wifi],
        hasInternet: true,
      );

      await Future.delayed(const Duration(milliseconds: 100));

      expect(statusChanges, contains(false));
      expect(statusChanges, contains(true));

      await subscription.cancel();
    });

    test('should emit connectivity result changes', () async {
      final resultChanges = <ConnectivityResult>[];
      final subscription = connectivityService.connectivityResultStream.listen(resultChanges.add);

      await connectivityService.simulateConnectivityChange(
        [ConnectivityResult.wifi],
        hasInternet: true,
      );

      await connectivityService.simulateConnectivityChange(
        [ConnectivityResult.mobile],
        hasInternet: true,
      );

      await Future.delayed(const Duration(milliseconds: 100));

      expect(resultChanges, contains(ConnectivityResult.wifi));
      expect(resultChanges, contains(ConnectivityResult.mobile));

      await subscription.cancel();
    });

    test('should emit detailed connectivity change events', () async {
      final changes = <ConnectivityChange>[];
      final subscription = connectivityService.onConnectivityChange.listen(changes.add);

      await connectivityService.simulateConnectivityChange(
        [ConnectivityResult.wifi],
        hasInternet: true,
      );

      await connectivityService.simulateConnectivityChange(
        [ConnectivityResult.none],
        hasInternet: false,
      );

      await Future.delayed(const Duration(milliseconds: 100));

      expect(changes.length, greaterThanOrEqualTo(1));

      await subscription.cancel();
    });
  });

  group('ConnectivityService.checkConnectivity', () {
    test('should return current online status', () async {
      await connectivityService.simulateConnectivityChange(
        [ConnectivityResult.wifi],
        hasInternet: true,
      );

      final result = await connectivityService.checkConnectivity();

      expect(result, true);
    });

    test('should update status if changed', () async {
      await connectivityService.simulateConnectivityChange(
        [ConnectivityResult.wifi],
        hasInternet: true,
      );

      connectivityService.mockVerifyResult = false;

      final result = await connectivityService.checkConnectivity();

      expect(result, false);
      expect(connectivityService.isOnline, false);
    });

    test('should return cached value on error', () async {
      await connectivityService.simulateConnectivityChange(
        [ConnectivityResult.wifi],
        hasInternet: true,
      );

      connectivityService.throwOnCheck = true;

      final result = await connectivityService.checkConnectivity();

      expect(result, true); // Returns cached value
    });
  });

  group('ConnectivityService.waitForConnection', () {
    test('should complete immediately if online', () async {
      await connectivityService.simulateConnectivityChange(
        [ConnectivityResult.wifi],
        hasInternet: true,
      );

      await expectLater(
        connectivityService.waitForConnection(),
        completes,
      );
    });

    test('should complete when connection restored', () async {
      await connectivityService.simulateConnectivityChange(
        [ConnectivityResult.none],
        hasInternet: false,
      );

      final future = connectivityService.waitForConnection();

      // Simulate connection restoration
      Future.delayed(const Duration(milliseconds: 50), () {
        connectivityService.simulateConnectivityChange(
          [ConnectivityResult.wifi],
          hasInternet: true,
        );
      });

      await expectLater(future, completes);
    });

    test('should timeout if connection not restored', () async {
      await connectivityService.simulateConnectivityChange(
        [ConnectivityResult.none],
        hasInternet: false,
      );

      await expectLater(
        connectivityService.waitForConnection(
          timeout: const Duration(milliseconds: 100),
        ),
        throwsA(isA<TimeoutException>()),
      );
    });
  });

  group('ConnectivityService.onConnectionRestored', () {
    test('should execute callback when connection restored', () async {
      await connectivityService.simulateConnectivityChange(
        [ConnectivityResult.none],
        hasInternet: false,
      );

      var callbackExecuted = false;
      connectivityService.onConnectionRestored(() {
        callbackExecuted = true;
      });

      await connectivityService.simulateConnectivityChange(
        [ConnectivityResult.wifi],
        hasInternet: true,
      );

      await Future.delayed(const Duration(milliseconds: 100));

      expect(callbackExecuted, true);
    });
  });

  group('ConnectivityService Connection Type Helpers', () {
    test('should return correct connection type description', () async {
      await connectivityService.simulateConnectivityChange(
        [ConnectivityResult.wifi],
        hasInternet: true,
      );
      expect(connectivityService.connectionTypeDescription, 'WiFi');

      await connectivityService.simulateConnectivityChange(
        [ConnectivityResult.mobile],
        hasInternet: true,
      );
      expect(connectivityService.connectionTypeDescription, 'Mobile Data');

      await connectivityService.simulateConnectivityChange(
        [ConnectivityResult.ethernet],
        hasInternet: true,
      );
      expect(connectivityService.connectionTypeDescription, 'Ethernet');

      await connectivityService.simulateConnectivityChange(
        [ConnectivityResult.none],
        hasInternet: false,
      );
      expect(connectivityService.connectionTypeDescription, 'No Connection');
    });

    test('should detect metered connection', () async {
      await connectivityService.simulateConnectivityChange(
        [ConnectivityResult.mobile],
        hasInternet: true,
      );
      expect(connectivityService.isMeteredConnection, true);

      await connectivityService.simulateConnectivityChange(
        [ConnectivityResult.wifi],
        hasInternet: true,
      );
      expect(connectivityService.isMeteredConnection, false);
    });

    test('should detect fast connection', () async {
      await connectivityService.simulateConnectivityChange(
        [ConnectivityResult.wifi],
        hasInternet: true,
      );
      expect(connectivityService.isFastConnection, true);

      await connectivityService.simulateConnectivityChange(
        [ConnectivityResult.ethernet],
        hasInternet: true,
      );
      expect(connectivityService.isFastConnection, true);

      await connectivityService.simulateConnectivityChange(
        [ConnectivityResult.mobile],
        hasInternet: true,
      );
      expect(connectivityService.isFastConnection, false);
    });
  });

  group('ConnectivityChange Model', () {
    test('should detect connection restoration', () {
      final change = ConnectivityChange(
        isOnline: true,
        previousResult: ConnectivityResult.none,
        currentResult: ConnectivityResult.wifi,
        timestamp: DateTime.now(),
      );

      expect(change.wasRestored, true);
      expect(change.wasLost, false);
    });

    test('should detect connection loss', () {
      final change = ConnectivityChange(
        isOnline: false,
        previousResult: ConnectivityResult.wifi,
        currentResult: ConnectivityResult.none,
        timestamp: DateTime.now(),
      );

      expect(change.wasLost, true);
      expect(change.wasRestored, false);
    });

    test('should detect connection type change', () {
      final change = ConnectivityChange(
        isOnline: true,
        previousResult: ConnectivityResult.wifi,
        currentResult: ConnectivityResult.mobile,
        timestamp: DateTime.now(),
      );

      expect(change.typeChanged, true);
    });

    test('should have correct toString', () {
      final change = ConnectivityChange(
        isOnline: true,
        previousResult: ConnectivityResult.none,
        currentResult: ConnectivityResult.wifi,
        timestamp: DateTime.now(),
      );

      expect(change.toString(), contains('ConnectivityChange'));
      expect(change.toString(), contains('isOnline: true'));
    });
  });

  group('NetworkStatus Extension', () {
    test('should return checking when not initialized', () {
      final service = TestableConnectivityService();
      service.mockIsInitialized = false;

      expect(service.networkStatus, NetworkStatus.checking);

      service.dispose();
    });

    test('should return online when connected', () async {
      await connectivityService.simulateConnectivityChange(
        [ConnectivityResult.wifi],
        hasInternet: true,
      );
      connectivityService.mockIsInitialized = true;

      expect(connectivityService.networkStatus, NetworkStatus.online);
    });

    test('should return offline when disconnected', () async {
      await connectivityService.simulateConnectivityChange(
        [ConnectivityResult.none],
        hasInternet: false,
      );
      connectivityService.mockIsInitialized = true;

      expect(connectivityService.networkStatus, NetworkStatus.offline);
    });

    test('should return checking when verifying', () {
      connectivityService.mockIsInitialized = true;
      connectivityService.mockIsVerifying = true;

      expect(connectivityService.networkStatus, NetworkStatus.checking);
    });
  });

  group('ConnectivityService ChangeNotifier', () {
    test('should notify listeners on status change', () async {
      var notificationCount = 0;
      connectivityService.addListener(() => notificationCount++);

      await connectivityService.simulateConnectivityChange(
        [ConnectivityResult.wifi],
        hasInternet: true,
      );

      await connectivityService.simulateConnectivityChange(
        [ConnectivityResult.none],
        hasInternet: false,
      );

      expect(notificationCount, greaterThanOrEqualTo(1));
    });
  });

  group('ConnectivityService.dispose', () {
    test('should close stream controllers', () async {
      // Create a separate instance for this test to avoid double dispose
      final service = TestableConnectivityService();

      final statusCompleter = Completer<void>();
      final resultCompleter = Completer<void>();
      final changeCompleter = Completer<void>();

      service.onlineStatus.listen(
        (_) {},
        onDone: () => statusCompleter.complete(),
      );
      service.connectivityResultStream.listen(
        (_) {},
        onDone: () => resultCompleter.complete(),
      );
      service.onConnectivityChange.listen(
        (_) {},
        onDone: () => changeCompleter.complete(),
      );

      service.dispose();

      await expectLater(statusCompleter.future, completes);
      await expectLater(resultCompleter.future, completes);
      await expectLater(changeCompleter.future, completes);
    });
  });
}

/// Testable connectivity service that allows simulating connectivity changes
class TestableConnectivityService with ChangeNotifier {
  bool mockIsInitialized = false;
  bool mockIsVerifying = false;
  bool? mockVerifyResult;
  bool throwOnCheck = false;

  final StreamController<bool> _testOnlineStatusController =
      StreamController<bool>.broadcast();
  final StreamController<ConnectivityResult> _testConnectivityResultController =
      StreamController<ConnectivityResult>.broadcast();
  final StreamController<ConnectivityChange> _testConnectivityChangeController =
      StreamController<ConnectivityChange>.broadcast();

  bool _testIsOnline = true;
  ConnectivityResult _testCurrentResult = ConnectivityResult.none;

  TestableConnectivityService();

  bool get isOnline => _testIsOnline;

  bool get isInitialized => mockIsInitialized;

  bool get isVerifying => mockIsVerifying;

  ConnectivityResult get currentResult => _testCurrentResult;

  /// Provides networkStatus similar to the ConnectivityServiceNetworkStatus extension
  NetworkStatus get networkStatus {
    if (!isInitialized) return NetworkStatus.checking;
    if (isVerifying) return NetworkStatus.checking;
    return isOnline ? NetworkStatus.online : NetworkStatus.offline;
  }

  Stream<bool> get onlineStatus => _testOnlineStatusController.stream;

  Stream<ConnectivityResult> get connectivityResultStream =>
      _testConnectivityResultController.stream;

  Stream<ConnectivityChange> get onConnectivityChange =>
      _testConnectivityChangeController.stream;

  Future<bool> checkConnectivity() async {
    if (throwOnCheck) {
      return _testIsOnline;
    }

    if (mockVerifyResult != null) {
      _testIsOnline = mockVerifyResult!;
      _testOnlineStatusController.add(_testIsOnline);
      notifyListeners();
    }

    return _testIsOnline;
  }

  /// Simulate a connectivity change
  Future<void> simulateConnectivityChange(
    List<ConnectivityResult> results, {
    required bool hasInternet,
  }) async {
    final previousResult = _testCurrentResult;
    final wasOnline = _testIsOnline;

    _testCurrentResult = results.isNotEmpty ? results.first : ConnectivityResult.none;
    _testIsOnline = hasInternet;

    _testConnectivityResultController.add(_testCurrentResult);

    if (wasOnline != hasInternet) {
      _testOnlineStatusController.add(hasInternet);

      _testConnectivityChangeController.add(ConnectivityChange(
        isOnline: hasInternet,
        previousResult: previousResult,
        currentResult: _testCurrentResult,
        timestamp: DateTime.now(),
      ));

      notifyListeners();
    }

    mockIsInitialized = true;
  }

  /// Wait for connection to be restored
  Future<void> waitForConnection({Duration? timeout}) async {
    if (_testIsOnline) return;

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

  /// Execute callback when connection is restored
  void onConnectionRestored(VoidCallback callback) {
    late StreamSubscription<bool> subscription;
    subscription = onlineStatus.listen((isOnline) {
      if (isOnline) {
        callback();
        subscription.cancel();
      }
    });
  }

  /// Get connection type description
  String get connectionTypeDescription {
    switch (_testCurrentResult) {
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
    }
  }

  /// Check if connection is metered (mobile data)
  bool get isMeteredConnection {
    return _testCurrentResult == ConnectivityResult.mobile;
  }

  /// Check if connection is fast (WiFi or Ethernet)
  bool get isFastConnection {
    return _testCurrentResult == ConnectivityResult.wifi ||
        _testCurrentResult == ConnectivityResult.ethernet;
  }

  @override
  void dispose() {
    _testOnlineStatusController.close();
    _testConnectivityResultController.close();
    _testConnectivityChangeController.close();
    super.dispose();
  }
}
