// initiate-handover carries the step's settings, as the web widget sends
// them (RN #59): enableHandoverEmail (an explicit false keeps the team's
// email off), the sound settings, and the step's assignment overrides.
import 'package:conferbot_flutter/src/core/agent/agent_handover.dart';
import 'package:conferbot_flutter/src/core/state/chat_state.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final state = ChatState.instance;

  setUp(() {
    state.reset();
    state.initialize(chatSessionId: 's1', visitorId: 'v1', botId: 'b1', workspaceId: 'w1');
  });

  test('the step\'s email, sound and assignment settings go with the request', () {
    final p = AgentHandover.payload(state, {
      'maxWaitTime': '0.5',
      'assignmentType': 'manual',
      'agentAssignmentStrategy': 'round-robin',
      'assignedAgents': ['u1'],
      'enableHandoverEmail': false,
      'enableHandoverSound': true,
      'checkedSoundTab': 'library',
      'selectedSound': 'chime',
      'customHandoverSoundUrl': '',
      'assignmentMethod': 'skills',
      'requiredSkills': ['billing'],
    })!;
    expect(p['chatSessionId'], 's1');
    expect(p['maxWaitTime'], 0.5);
    expect(p['assignmentType'], 'manual');
    expect(p['assignmentStrategy'], 'round-robin');
    expect(p['enableHandoverEmail'], isFalse);
    expect(p['enableHandoverSound'], isTrue);
    expect(p['checkedSoundTab'], 'library');
    expect(p['selectedSound'], 'chime');
    expect(p['assignmentMethod'], 'skills');
    expect(p['requiredSkills'], ['billing']);
    expect((p['chatMetaData'] as Map)['botId'], 'b1');
  });

  test('a step that follows the workspace sends no assignment override', () {
    final p = AgentHandover.payload(state, {'assignmentMethod': 'workspace', 'requiredSkills': []})!;
    expect(p.containsKey('assignmentMethod'), isFalse);
    expect(p.containsKey('requiredSkills'), isFalse);
    expect(p['enableHandoverEmail'], isNull);
  });

  test('extra fields (an agent bot\'s silent start) are kept', () {
    expect(AgentHandover.payload(state, const {}, extra: const {'silentStart': true})!['silentStart'], isTrue);
  });
}
