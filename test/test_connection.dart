#!/usr/bin/env dart

/**
 * Test Script for Conferbot Flutter SDK
 * Tests connection to embed server on localhost:8001
 *
 * Run with: dart test/test_connection.dart
 */

import 'dart:async';
import 'dart:io';
import 'package:socket_io_client/socket_io_client.dart' as io;

// Configuration
const String socketUrl = 'http://localhost:8001';
const String testApiKey = 'test_api_key';
const String testBotId = 'test_bot_id';

void main() async {
  print('🚀 Starting Conferbot SDK Connection Test\n');
  print('Configuration:');
  print('  Socket URL: $socketUrl');
  print('  API Key: $testApiKey');
  print('  Bot ID: $testBotId\n');

  // Create socket instance
  print('📡 Connecting to embed server...');

  final socket = io.io(
    socketUrl,
    io.OptionBuilder()
        .setTransports(['websocket', 'polling'])
        .enableReconnection()
        .setReconnectionAttempts(5)
        .setReconnectionDelay(1000)
        .setReconnectionDelayMax(5000)
        .setTimeout(20000)
        .enableAutoConnect()
        .setExtraHeaders({
          'X-API-Key': testApiKey,
          'X-Bot-ID': testBotId,
        })
        .build(),
  );

  // Track if test completed
  bool testCompleted = false;

  // Connection event handlers
  socket.onConnect((_) {
    print('✅ Socket connected successfully!');
    print('   Socket ID: ${socket.id}');
    print('   Connected: ${socket.connected}\n');

    // Test: Get chatbot data
    print('📤 Emitting: get-chatbot-data');
    socket.emit('get-chatbot-data', {'botId': testBotId});
  });

  socket.onConnectError((error) {
    print('❌ Connection error: $error');
    print('   Make sure embed server is running on port 8001');
    testCompleted = true;
    socket.disconnect();
    exit(1);
  });

  socket.onDisconnect((reason) {
    print('\n🔌 Disconnected: $reason');
    if (!testCompleted) {
      print('   Unexpected disconnect');
    }
  });

  socket.on('reconnect_attempt', (attemptNumber) {
    print('🔄 Reconnection attempt $attemptNumber...');
  });

  socket.on('reconnect', (_) {
    print('✅ Reconnected successfully!');
  });

  socket.onError((error) {
    print('❌ Socket error: $error');
  });

  // Listen for server responses
  socket.on('fetched-chatbot-data', (data) {
    print('📥 Received: fetched-chatbot-data');
    print('   Data: $data');
    print('\n✅ Test completed successfully!');
    print('   Socket connection is working correctly.\n');

    // Disconnect after successful test
    testCompleted = true;
    Future.delayed(Duration(seconds: 1), () {
      print('🔌 Disconnecting...');
      socket.disconnect();
      exit(0);
    });
  });

  socket.on('bot-response', (data) {
    print('📥 Received: bot-response');
    if (data is Map) {
      print('   Message: ${data['text'] ?? data}');
    } else {
      print('   Message: $data');
    }
  });

  socket.on('agent-message', (data) {
    print('📥 Received: agent-message');
    if (data is Map) {
      print('   Agent: ${data['agent']?['name']}');
      print('   Message: ${data['message']}');
    }
  });

  socket.on('agent-accepted', (data) {
    print('📥 Received: agent-accepted');
    if (data is Map) {
      print('   Agent: ${data['agent']?['name']}');
    }
  });

  socket.on('agent-left', (_) {
    print('📥 Received: agent-left');
  });

  // Handle Ctrl+C
  ProcessSignal.sigint.watch().listen((_) {
    print('\n\n⚠️  Test interrupted by user');
    testCompleted = true;
    socket.disconnect();
    exit(0);
  });

  // Timeout after 10 seconds if no response
  Timer(Duration(seconds: 10), () {
    if (!testCompleted) {
      print('\n❌ Test timed out - no response from server');
      print('   Possible issues:');
      print('   - Embed server not running on port 8001');
      print('   - Firewall blocking connection');
      print('   - Invalid API key or bot ID\n');
      testCompleted = true;
      socket.disconnect();
      exit(1);
    }
  });

  // Keep the script running
  await Future.delayed(Duration(seconds: 15));
}
