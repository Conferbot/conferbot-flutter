/// Google service integration handlers
///
/// Handles integrations with Google services:
/// - Google Sheets (read/write spreadsheet data)
/// - Gmail (send emails)
/// - Google Calendar (book appointments)
/// - Google Meet (create video meetings)
/// - Google Drive (upload/download files)
/// - Google Docs (create/update documents)
///
/// All handlers emit 'execute-integration' to the server via socket,
/// matching the web widget / Android SDK protocol.
library;

import '../../node_types.dart';
import '../legacy_handlers.dart';
import 'integration_base.dart';

/// Handler for google-sheets-node
/// Reads/writes to Google Sheets
class GoogleSheetsNodeHandler extends IntegrationNodeHandler {
  @override
  String get nodeType => NodeTypes.googleSheets;

  @override
  Future<NodeResult> process(Map<String, dynamic> nodeData, String nodeId) async {
    // Mirror widget logic: operation from nodeData.operation or
    // nodeData.inputs.operation, defaulting to "read"
    final inputs = getMap(nodeData, 'inputs');
    final operation = nodeData['operation']?.toString() ??
        inputs['operation']?.toString() ??
        'read';

    // The server dispatcher only accepts google-sheets-read-node /
    // google-sheets-write-node; a raw "google-sheets-node" is rejected.
    final serverNodeType = operation == 'write'
        ? 'google-sheets-write-node'
        : 'google-sheets-read-node';

    // Emit execute-integration to server and wait for result
    // (read operations return data that may be used by subsequent nodes)
    await emitExecuteIntegration(
      nodeData: nodeData,
      nodeId: nodeId,
      overrideNodeType: serverNodeType,
    );

    recordResponse(
      nodeId: nodeId,
      shape: 'google-sheets-$operation',
      type: nodeType,
      additionalData: {
        'operation': operation,
        'spreadsheetId': nodeData['spreadsheetId'],
        'sheetName': nodeData['sheetName'],
      },
    );

    return const Proceed();
  }
}

/// Handler for gmail-node
/// Sends email via Gmail
class GmailNodeHandler extends IntegrationNodeHandler {
  @override
  String get nodeType => NodeTypes.gmail;

  @override
  Future<NodeResult> process(Map<String, dynamic> nodeData, String nodeId) async {
    await emitExecuteIntegration(
      nodeData: nodeData,
      nodeId: nodeId,
      waitForResult: false,
    );

    recordResponse(
      nodeId: nodeId,
      shape: 'gmail-triggered',
      type: nodeType,
      additionalData: {
        'to': nodeData['to'],
        'subject': nodeData['subject'],
      },
    );

    return const Proceed();
  }
}

/// Handler for google-calendar-node
/// Books calendar appointments
class GoogleCalendarNodeHandler extends IntegrationNodeHandler {
  @override
  String get nodeType => NodeTypes.googleCalendar;

  @override
  Future<NodeResult> process(Map<String, dynamic> nodeData, String nodeId) async {
    final operation = getString(nodeData, 'operation', 'book');

    if (operation == 'book') {
      // Display calendar booking UI
      final timezone = getString(nodeData, 'timeZone', DateTime.now().timeZoneName);
      final answerKey = getString(nodeData, 'answerVariable', 'calendar_booking');

      state.addAnswerVariable(nodeId, answerKey);

      return DisplayUI(
        CalendarState(
          questionText: 'Select a date and time',
          showTimeSelection: true,
          timezone: timezone,
          nodeId: nodeId,
          answerKey: answerKey,
        ),
      );
    }

    return const Proceed();
  }

  @override
  Future<NodeResult> handleResponse(
    dynamic response,
    Map<String, dynamic> nodeData,
    String nodeId,
  ) async {
    final responseMap = response is Map<String, dynamic>
        ? response
        : {'date': response.toString()};

    final date = responseMap['date']?.toString() ?? '';
    final time = responseMap['time']?.toString() ?? '';
    final email = responseMap['email']?.toString();

    state.setAnswerVariable(nodeId, '$date $time');
    state.addToTranscript('user', 'Booked: $date at $time');

    // Emit execute-integration to server with the booking details
    await emitExecuteIntegration(
      nodeData: {
        ...nodeData,
        'date': date,
        'time': time,
        'attendeeEmail': email,
      },
      nodeId: nodeId,
    );

    recordResponse(
      nodeId: nodeId,
      shape: 'google-calendar-booking',
      text: '$date $time',
      type: nodeType,
      additionalData: {
        'date': date,
        'time': time,
        'attendeeEmail': email,
        'timezone': nodeData['timeZone'],
      },
    );

    return const Proceed();
  }
}

/// Handler for google-meet-node
/// Creates Google Meet meetings
class GoogleMeetNodeHandler extends IntegrationNodeHandler {
  @override
  String get nodeType => NodeTypes.googleMeet;

  @override
  Future<NodeResult> process(Map<String, dynamic> nodeData, String nodeId) async {
    final operation = getString(nodeData, 'operation', 'book');

    if (operation == 'book') {
      final timezone = getString(nodeData, 'timeZone', DateTime.now().timeZoneName);
      final answerKey = getString(nodeData, 'answerVariable', 'meet_booking');

      state.addAnswerVariable(nodeId, answerKey);

      return DisplayUI(
        CalendarState(
          questionText: 'Select a time for your meeting',
          showTimeSelection: true,
          timezone: timezone,
          nodeId: nodeId,
          answerKey: answerKey,
        ),
      );
    }

    return const Proceed();
  }

  @override
  Future<NodeResult> handleResponse(
    dynamic response,
    Map<String, dynamic> nodeData,
    String nodeId,
  ) async {
    final responseMap = response is Map<String, dynamic>
        ? response
        : {'date': response.toString()};

    // Emit execute-integration to server with the meeting details
    await emitExecuteIntegration(
      nodeData: {
        ...nodeData,
        ...Map<String, dynamic>.from(responseMap),
      },
      nodeId: nodeId,
    );

    recordResponse(
      nodeId: nodeId,
      shape: 'google-meet-booking',
      type: nodeType,
      additionalData: Map<String, dynamic>.from(responseMap),
    );

    return const Proceed();
  }
}

/// Handler for google-drive-node
/// Uploads/downloads from Google Drive
class GoogleDriveNodeHandler extends IntegrationNodeHandler {
  @override
  String get nodeType => NodeTypes.googleDrive;

  @override
  Future<NodeResult> process(Map<String, dynamic> nodeData, String nodeId) async {
    final operation = getString(nodeData, 'operation', 'upload');

    await emitExecuteIntegration(
      nodeData: nodeData,
      nodeId: nodeId,
    );

    recordResponse(
      nodeId: nodeId,
      shape: 'google-drive-$operation',
      type: nodeType,
      additionalData: {'operation': operation},
    );

    return const Proceed();
  }
}

/// Handler for google-docs-node
/// Creates/updates Google Docs
class GoogleDocsNodeHandler extends IntegrationNodeHandler {
  @override
  String get nodeType => NodeTypes.googleDocs;

  @override
  Future<NodeResult> process(Map<String, dynamic> nodeData, String nodeId) async {
    final operation = getString(nodeData, 'operation', 'create');

    await emitExecuteIntegration(
      nodeData: nodeData,
      nodeId: nodeId,
    );

    recordResponse(
      nodeId: nodeId,
      shape: 'google-docs-$operation',
      type: nodeType,
      additionalData: {
        'operation': operation,
        'title': nodeData['title'],
      },
    );

    return const Proceed();
  }
}
