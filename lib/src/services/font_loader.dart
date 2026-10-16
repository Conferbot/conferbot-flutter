/// The chat's web font (core/customization/owner_font.dart), fetched and
/// registered at run time. Ported from the React Native SDK
/// (utils/fontLoader.ts, hooks/useChatFont.ts).
///
/// The owner's catalog font, or the theme's, is read from Google Fonts'
/// css2 stylesheet with this SDK's own HTTP client: Google sends TrueType
/// files to a client that is not a browser, which is what Flutter loads.
/// Each upright face is downloaded once, kept on the device (the app's
/// support folder, conferbot-fonts/), and registered with [FontLoader] under
/// "CB Font <family>", every weight in the one family, so Flutter draws each
/// text with the face nearest its weight. On any failure (offline, a bad
/// file) the chat keeps the platform font; a later open tries again. A
/// system or unknown owner font is used by its name and needs no loading.
library;

import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';

import '../core/customization/owner_font.dart';

/// Registers a family's faces with the engine (FontLoader in the app).
typedef FontRegistrar = Future<void> Function(String family, List<Uint8List> faces);

Future<void> _registerWithFontLoader(String family, List<Uint8List> faces) async {
  final loader = FontLoader(family);
  for (final f in faces) {
    loader.addFont(Future.value(ByteData.view(f.buffer, f.offsetInBytes, f.lengthInBytes)));
  }
  await loader.load();
}

Future<Directory?> _defaultCacheDir() async {
  try {
    return Directory('${(await getApplicationSupportDirectory()).path}/conferbot-fonts');
  } catch (_) {
    return null;
  }
}

class ChatFontLoader {
  ChatFontLoader({http.Client? client, Future<Directory?> Function()? cacheDir, FontRegistrar? register})
      : _client = client,
        _cacheDir = cacheDir ?? _defaultCacheDir,
        _register = register ?? _registerWithFontLoader;

  /// The one loader the chat uses.
  static ChatFontLoader instance = ChatFontLoader();

  final http.Client? _client;
  final Future<Directory?> Function() _cacheDir;
  final FontRegistrar _register;
  final Map<String, Future<List<int>>> _pending = {};

  static String _safe(String s) => s.replaceAll(RegExp(r'[^a-zA-Z0-9]+'), '_');

  /// Fetch (or read from the device) and register [pick]'s upright faces.
  /// Resolves the weights now registered ([] when nothing could be).
  Future<List<int>> load(FontPick? pick) {
    final query = pick?.google;
    if (pick == null || query == null) return Future.value(const []);
    final key = '${pick.family}|$query';
    return _pending.putIfAbsent(key, () {
      final f = _load(pick.family, query).catchError((_) => const <int>[]);
      f.then((weights) {
        if (weights.isEmpty) _pending.remove(key);
      });
      return f;
    });
  }

  Future<List<int>> _load(String family, String query) async {
    final dir = await _cacheDir();
    final faces = await _fromDisk(dir, family, query) ?? await _fromGoogle(dir, family, query);
    if (faces.isEmpty) return const [];
    await _register(faceName(family, 400), faces.values.toList());
    return faces.keys.toList()..sort();
  }

  File? _index(Directory? dir, String family) => dir == null ? null : File('${dir.path}/${_safe(family)}.json');
  File? _face(Directory? dir, String family, int weight) => dir == null ? null : File('${dir.path}/${_safe(family)}-$weight.ttf');

  /// The faces kept from an earlier launch, when they are all there.
  Future<Map<int, Uint8List>?> _fromDisk(Directory? dir, String family, String query) async {
    try {
      final index = _index(dir, family);
      if (index == null || !await index.exists()) return null;
      final saved = jsonDecode(await index.readAsString());
      if (saved is! Map || saved['query'] != query || saved['weights'] is! List) return null;
      final out = <int, Uint8List>{};
      for (final w in (saved['weights'] as List).whereType<int>()) {
        final f = _face(dir, family, w)!;
        if (!await f.exists()) return null;
        out[w] = await f.readAsBytes();
      }
      return out.isEmpty ? null : out;
    } catch (_) {
      return null;
    }
  }

  Future<Map<int, Uint8List>> _fromGoogle(Directory? dir, String family, String query) async {
    final client = _client ?? http.Client();
    try {
      final res = await client.get(Uri.parse(googleFontUrl(query)));
      if (res.statusCode != 200) return const {};
      final faces = parseFontFaces(res.body).where((f) => f.style == 'normal');
      final out = <int, Uint8List>{};
      for (final face in faces) {
        if (out.containsKey(face.weight)) continue;
        final r = await client.get(Uri.parse(face.url));
        if (r.statusCode == 200 && r.bodyBytes.isNotEmpty) out[face.weight] = r.bodyBytes;
      }
      if (out.isNotEmpty) unawaited(_save(dir, family, query, out));
      return out;
    } finally {
      if (_client == null) client.close();
    }
  }

  Future<void> _save(Directory? dir, String family, String query, Map<int, Uint8List> faces) async {
    if (dir == null) return;
    try {
      await dir.create(recursive: true);
      for (final e in faces.entries) {
        await _face(dir, family, e.key)!.writeAsBytes(e.value, flush: true);
      }
      await _index(dir, family)!.writeAsString(jsonEncode({'query': query, 'weights': faces.keys.toList()}));
    } catch (_) {}
  }
}

/// The chat's fonts for the bot's settings, loaded (owned by the provider):
/// [body] for all of the chat's text, [display] for its headings; each is a
/// family name, or null for the platform font (no font set, or not loaded yet).
class ChatFont extends ChangeNotifier {
  ChatFont({ChatFontLoader? loader}) : _loader = loader;

  final ChatFontLoader? _loader;
  ChatFontLoader get _fonts => _loader ?? ChatFontLoader.instance;

  ChatFonts _picks = const ChatFonts(null, null);
  List<int> _bodyWeights = const [];
  List<int> _displayWeights = const [];
  bool _disposed = false;

  ChatFonts get picks => _picks;

  static String? _family(FontPick? pick, List<int> loaded) {
    if (pick == null) return null;
    if (pick.google == null) return pick.family;
    return loaded.isEmpty ? null : faceName(pick.family, 400);
  }

  String? get body => _family(_picks.body, _bodyWeights);
  String? get display => _family(_picks.display, _displayWeights);

  /// The owner's font and the theme's; loads what is new.
  void update(dynamic ownerFont, {String? themeFont, String? themeFontRole}) {
    final next = chatFontsFor(ownerFont, themeFont: themeFont, themeFontRole: themeFontRole);
    if (next == _picks) return;
    final bodyChanged = next.body != _picks.body;
    final displayChanged = next.display != _picks.display;
    _picks = next;
    if (bodyChanged) _bodyWeights = const [];
    if (displayChanged) _displayWeights = const [];
    _notify();
    if (bodyChanged) _loadInto(next.body, (w) => _bodyWeights = w, () => _picks.body == next.body);
    if (displayChanged) _loadInto(next.display, (w) => _displayWeights = w, () => _picks.display == next.display);
  }

  void _loadInto(FontPick? pick, void Function(List<int>) set, bool Function() stillWanted) {
    if (pick?.google == null) return;
    _fonts.load(pick).then((weights) {
      if (_disposed || !stillWanted() || weights.isEmpty) return;
      set(weights);
      _notify();
    });
  }

  void _notify() {
    if (!_disposed) notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }
}
