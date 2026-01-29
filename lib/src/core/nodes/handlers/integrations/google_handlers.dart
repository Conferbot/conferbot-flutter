/// Google service integration handlers
///
/// Handles integrations with Google services:
/// - Google Sheets (read/write spreadsheet data)
/// - Gmail (send emails)
/// - Google Calendar (book appointments)
/// - Google Meet (create video meetings)
/// - Google Drive (upload/download files)
/// - Google Docs (create/update documents)
library;

import '../../node_types.dart';
import '../legacy_handlers.dart';

/// Handler for google-sheets-node
/// Reads/writes to Google Sheets
class GoogleSheetsNodeHandler extends BaseNodeHandler {
  @override
  String get nodeType => NodeTypes.googleSheets;

  @override
  Future<NodeResult> process(Map<String, dynamic> nodeData, String nodeId) async {
    final operation = getString(nodeData, 'operation', 'write');

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

    // For read operations, column mappings should be handled via socket response
    return const Proceed();
  }
}

/// Handler for gmail-node
/// Sends email via Gmail
class GmailNodeHandler extends BaseNodeHandler {
  @override
  String get nodeType => NodeTypes.gmail;

  @override
  Future<NodeResult> process(Map<String, dynamic> nodeData, String nodeId) async {
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
class GoogleCalendarNodeHandler extends BaseNodeHandler {
  @override
  String get nodeType => NodeTypes.googleCalendar;

  @override
  Future<NodeResult> process(Map<String, dynamic> nodeData, String nodeId) async {
    final operation = getString(nodeData, 'operation', 'book');

    if (operation == 'book') {
      // Display calendar booking UI
      final timezone = getString(nodeData, 'timeZone', DateTime.now().timeZoneName);
      final answerKey = getString(nodeData, 'answerVariable', 'calendar_booking');

      state?.addAnswerVariable(nodeId, answerKey);

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

    state?.setAnswerVariable(nodeId, '$date $time');
    state?.addToTranscript('user', 'Booked: $date at $time');

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
class GoogleMeetNodeHandler extends BaseNodeHandler {
  @override
  String get nodeType => NodeTypes.googleMeet;

  @override
  Future<NodeResult> process(Map<String, dynamic> nodeData, String nodeId) async {
    final operation = getString(nodeData, 'operation', 'book');

    if (operation == 'book') {
      final timezone = getString(nodeData, 'timeZone', DateTime.now().timeZoneName);
      final answerKey = getString(nodeData, 'answerVariable', 'meet_booking');

      state?.addAnswerVariable(nodeId, answerKey);

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
class GoogleDriveNodeHandler extends BaseNodeHandler {
  @override
  String get nodeType => NodeTypes.googleDrive;

  @override
  Future<NodeResult> process(Map<String, dynamic> nodeData, String nodeId) async {
    final operation = getString(nodeData, 'operation', 'upload');

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
class GoogleDocsNodeHandler extends BaseNodeHandler {
  @override
  String get nodeType => NodeTypes.googleDocs;

  @override
  Future<NodeResult> process(Map<String, dynamic> nodeData, String nodeId) async {
    final operation = getString(nodeData, 'operation', 'create');

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
