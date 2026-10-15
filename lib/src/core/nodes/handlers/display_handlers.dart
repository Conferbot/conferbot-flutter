/// The steps that show something and move on: welcome, message, image,
/// video, audio, file, html, user-redirect - and navigate, which waits for
/// Done (React Native src/core/nodes/handlers/DisplayNodeHandlers.ts).
/// Field names and behaviour follow the flow-node spec (nodes.spec.json)
/// and the web widget's ts/chat/displayStep.ts. The engine paces the typing
/// dots and moves on (images and videos when their media settles, at
/// 4000 ms at most).
library;

import '../../flow/inputs.dart' show linkHref;
import '../../flow/js.dart' show jsNumber;
import '../../flow/text.dart' show fillLinkVariables, fillVariables, sanitizeOwnerHtml, stripHtmlAndDecode;
import '../../state/chat_state.dart';
import '../node_handler.dart';
import '../node_ui_state.dart';
import 'flow_kit.dart';

/// Where a redirect / navigate link goes: answers filled in, a same-site
/// path kept (web redirectHref).
String redirectHref(dynamic link, ChatState state) {
  final filled = fillLinkVariables(link, state.lookupVariable);
  final href = linkHref(filled);
  if (href.isNotEmpty) return href;
  return RegExp(r'^[/#?](?!/)').hasMatch(filled) ? filled : '';
}

/// The file name a download card shows, from the URL.
String _fileNameOf(String url) {
  try {
    final path = url.split(RegExp(r'[?#]'))[0];
    final name = Uri.decodeComponent(path.substring(path.lastIndexOf('/') + 1));
    return name.isNotEmpty ? name : 'download';
  } catch (_) {
    return 'download';
  }
}

String _str(dynamic v) => v is String ? v.trim() : '';

/// welcome-node: data.text, then data.image unless disableImage.
class WelcomeNodeHandler extends BaseNodeHandler {
  @override
  String get nodeType => 'welcome-node';

  @override
  Future<NodeResult> handle(FlowNode node, ChatState state) async {
    final data = node.data;
    final text = shownText(state, data['text']);
    botSay(state, text, node.id, nodeType);
    final image = _str(data['image']);
    if (image.isNotEmpty && data['disableImage'] != true) {
      botSay(state, '', node.id, nodeType, {'imageUrl': image});
    }
    return NodeResult.displayUI(MessageUIState(text: text, nodeId: node.id));
  }
}

/// message-node: data.text, filled from the answers. Blank text is skipped
/// by the engine.
class MessageHandler extends BaseNodeHandler {
  @override
  String get nodeType => 'message-node';

  @override
  Future<NodeResult> handle(FlowNode node, ChatState state) async {
    final text = shownText(state, node.data['text']);
    botSay(state, text, node.id, nodeType);
    return NodeResult.displayUI(MessageUIState(text: text, nodeId: node.id));
  }
}

/// image-node: data.image (not filled). Moves on when it loads, or at the cap.
class ImageHandler extends BaseNodeHandler {
  @override
  String get nodeType => 'image-node';

  @override
  Future<NodeResult> handle(FlowNode node, ChatState state) async {
    final url = (node.data['image'] ?? '').toString().trim();
    botSay(state, '', node.id, nodeType, {'imageUrl': url, 'mediaNodeId': node.id});
    return NodeResult.displayUI(ImageUIState(url: url, altText: 'Image', nodeId: node.id));
  }
}

/// video-node: data.video (an mp4), allowDownload only when true.
class VideoHandler extends BaseNodeHandler {
  @override
  String get nodeType => 'video-node';

  @override
  Future<NodeResult> handle(FlowNode node, ChatState state) async {
    final url = _str(node.data['video']);
    botSay(state, url, node.id, nodeType,
        {'videoUrl': url, 'mediaNodeId': node.id, 'allowDownload': node.data['allowDownload'] == true});
    return NodeResult.displayUI(VideoUIState(url: url, autoplay: true, nodeId: node.id));
  }
}

/// audio-node: data.audio. Some live nodes saved a list there, which the web
/// does not read (a broken player) - the step still moves on.
class AudioHandler extends BaseNodeHandler {
  @override
  String get nodeType => 'audio-node';

  @override
  Future<NodeResult> handle(FlowNode node, ChatState state) async {
    final url = _str(node.data['audio']);
    botSay(state, url, node.id, nodeType, {'audioUrl': url});
    return NodeResult.displayUI(AudioUIState(url: url, nodeId: node.id));
  }
}

/// file-node: a download card for data.file, named from the URL.
class FileHandler extends BaseNodeHandler {
  @override
  String get nodeType => 'file-node';

  @override
  Future<NodeResult> handle(FlowNode node, ChatState state) async {
    final url = _str(node.data['file']);
    final filename = url.isNotEmpty ? _fileNameOf(url) : 'download';
    botSay(state, url, node.id, nodeType, {'fileUrl': url, 'fileName': filename});
    return NodeResult.displayUI(FileUIState(url: url, fileName: filename, nodeId: node.id));
  }
}

/// html-node: data.html, answers filled (escaped), then sanitised.
class HTMLHandler extends BaseNodeHandler {
  @override
  String get nodeType => 'html-node';

  @override
  Future<NodeResult> handle(FlowNode node, ChatState state) async {
    final content = sanitizeOwnerHtml(fillVariables(node.data['html'] ?? '', state.lookupVariable));
    botSay(state, shownText(state, content), node.id, nodeType, {'html': content});
    return NodeResult.displayUI(HtmlUIState(htmlContent: content, nodeId: node.id));
  }
}

/// user-redirect-node: a link card - redirectPrompt as its label, data.link
/// as where it goes. It never navigates by itself; the flow moves on.
class RedirectHandler extends BaseNodeHandler {
  @override
  String get nodeType => 'user-redirect-node';

  @override
  Future<NodeResult> handle(FlowNode node, ChatState state) async {
    final data = node.data;
    final href = redirectHref(data['link'], state);
    final prompt = data['redirectPrompt'];
    final label = fillVariables(stripHtmlAndDecode(prompt == null || prompt == '' ? '' : prompt), state.lookupVariable,
            mode: 'raw')
        .trim();
    botSay(state, href.isNotEmpty ? '$label\n$href' : label, node.id, nodeType, {
      'linkUrl': href,
      'linkLabel': label,
      'openInNewTab': data['openInNewTab'] ?? true,
    });
    return NodeResult.displayUI(MessageUIState(text: label, nodeId: node.id));
  }
}

/// navigate-node: the prompt, one button per navigateOptions link (blank
/// ones hidden) and Done. A link opens its page and does not move on; Done
/// moves on after 600 ms.
class NavigateHandler extends BaseNodeHandler {
  @override
  String get nodeType => 'navigate-node';

  List<Map<String, dynamic>> _options(Map<String, dynamic> data) {
    final list = data['navigateOptions'];
    if (list is! List) return const [];
    return list
        .whereType<Map>()
        .map((o) => Map<String, dynamic>.from(o))
        .where((o) => (o['navigateText'] ?? '').toString().trim().isNotEmpty)
        .toList();
  }

  String _doneLabel(Map<String, dynamic> data) {
    final d = (data['doneNavigatingText'] ?? '').toString().trim();
    return d.isNotEmpty ? d : 'Done';
  }

  String _linkText(dynamic text, ChatState state) =>
      fillVariables(stripHtmlAndDecode(text ?? ''), state.lookupVariable, mode: 'raw').trim();

  SingleChoiceUIState _ui(FlowNode node, ChatState state) {
    final data = node.data;
    final options = _options(data);
    final choices = <ChoiceOption>[
      for (var i = 0; i < options.length; i++)
        ChoiceOption(
          id: 'link-$i',
          text: _linkText(options[i]['navigateText'], state),
          value: redirectHref(options[i]['navigateLink'], state),
          url: redirectHref(options[i]['navigateLink'], state),
        ),
      ChoiceOption(id: 'done', text: _doneLabel(data), value: 'done'),
    ];
    return SingleChoiceUIState(
      questionText: shownText(state, data['navigatePrompt']),
      choices: choices,
      nodeId: node.id,
    );
  }

  @override
  Future<NodeResult> handle(FlowNode node, ChatState state) async {
    final prompt = shownText(state, node.data['navigatePrompt']);
    if (prompt.isNotEmpty) botSay(state, prompt, node.id, nodeType);
    return NodeResult.displayUI(_ui(node, state), awaitInput: true);
  }

  @override
  Future<NodeResult> handleResponse(dynamic response, FlowNode node, ChatState state) async {
    final data = node.data;
    final r = response is Map ? response : const {};
    final id = (r['buttonId'] ?? '').toString();
    final isLink = r['action'] == 'link' || id.startsWith('link-');
    if (isLink) {
      final idx = r['action'] == 'link' ? jsNumber(r['index']) : jsNumber(id.substring(5));
      final options = _options(data);
      if (idx.isFinite && idx == idx.truncateToDouble() && idx >= 0 && idx < options.length) {
        final option = options[idx.toInt()];
        pushAnswer(
          state,
          {
            'id': node.id,
            'shape': 'user-navigate-link-click',
            'text': _linkText(option['navigateText'], state),
            'url': redirectHref(option['navigateLink'], state),
          },
          node.ctx.now(),
        );
      }
      // A link opens its page; the step keeps waiting for Done.
      return NodeResult.displayUI(_ui(node, state), awaitInput: true);
    }
    final text = _doneLabel(data);
    pushAnswer(state, {'id': node.id, 'shape': 'user-navigate-done', 'text': text}, node.ctx.now());
    userSay(state, text, node.id);
    return NodeResult.delayedProceed(null, 600);
  }
}

/// The display steps.
final List<NodeHandler> displayHandlers = [
  WelcomeNodeHandler(),
  MessageHandler(),
  ImageHandler(),
  VideoHandler(),
  AudioHandler(),
  FileHandler(),
  HTMLHandler(),
  RedirectHandler(),
  NavigateHandler(),
];
