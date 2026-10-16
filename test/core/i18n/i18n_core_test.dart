// The core words come out in German (core/i18n): the text producers under
// lib/src/core and lib/src/utils follow the widget language, as RN's
// __tests__/core/i18nCore.test.ts and Android's I18nCoreTest. German under
// setWidgetLanguage('de'), the web's own strings; the owner's own words kept
// as written and the stock English shown translated; the record and server
// texts left in English. A sweep then reads every producer under "de" and
// fails on any English table value (test/i18n_sweep.dart).
import 'package:conferbot_flutter/src/core/agent/agent_bot.dart';
import 'package:conferbot_flutter/src/core/agent/answer_feedback.dart';
import 'package:conferbot_flutter/src/core/customization/customizations.dart';
import 'package:conferbot_flutter/src/core/customization/greeting.dart';
import 'package:conferbot_flutter/src/core/customization/launcher.dart';
import 'package:conferbot_flutter/src/core/customization/launcher_idle_call.dart';
import 'package:conferbot_flutter/src/core/customization/mascot_moods.dart';
import 'package:conferbot_flutter/src/core/flow/calendar.dart';
import 'package:conferbot_flutter/src/core/flow/inputs.dart' as inputs;
import 'package:conferbot_flutter/src/core/flow/rich.dart' show weekdayName;
import 'package:conferbot_flutter/src/core/home/home.dart';
import 'package:conferbot_flutter/src/core/i18n/i18n.dart';
import 'package:conferbot_flutter/src/core/live_chat/email_transcript.dart';
import 'package:conferbot_flutter/src/core/live_chat/handover_state.dart';
import 'package:conferbot_flutter/src/core/live_chat/live_chat.dart';
import 'package:conferbot_flutter/src/core/live_chat/live_events.dart';
import 'package:conferbot_flutter/src/core/live_chat/reply_time.dart';
import 'package:conferbot_flutter/src/core/requests/requests.dart';
import 'package:conferbot_flutter/src/core/waiting/games_card.dart';
import 'package:conferbot_flutter/src/core/waiting/games_logic.dart';
import 'package:conferbot_flutter/src/core/waiting/wait_articles.dart';
import 'package:conferbot_flutter/src/core/waiting/waiting_games.dart';
import 'package:conferbot_flutter/src/utils/validation_utils.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/intl.dart';

import '../../i18n_sweep.dart';

String de(String key, [Map<String, Object?>? vars]) => I18n.tFor('de', key, vars);

/// A fake clock for the games card.
class _Clock {
  int now = 0;
  int _id = 0;
  final Map<int, ({void Function() fn, int at})> timers = {};
  Object set(void Function() fn, Duration after) {
    timers[++_id] = (fn: fn, at: now + after.inMilliseconds);
    return _id;
  }

  void clear(Object t) => timers.remove(t);
  void tick(int ms) {
    final until = now + ms;
    while (true) {
      final due = timers.entries.where((e) => e.value.at <= until).toList()
        ..sort((a, b) => a.value.at != b.value.at ? a.value.at.compareTo(b.value.at) : a.key.compareTo(b.key));
      if (due.isEmpty) break;
      timers.remove(due.first.key);
      now = due.first.value.at;
      due.first.value.fn();
    }
    now = until;
  }
}

GamesCard? _card(_Clock k, {dynamic customizations = const <String, dynamic>{}, String mode = 'offer'}) => GamesCard.create(GamesCardOptions(
      customizations: customizations,
      rng: () => 0.3,
      setTimer: k.set,
      clearTimer: k.clear,
      now: () => k.now.toDouble(),
      mode: mode,
    ));

/// The words a game's board draws.
List<String> _boardWords(Board? b) => switch (b) {
      RpsBoard b => b.hands.map((h) => h.name).toList(),
      ChoiceBoard b => [b.q, ...b.options, if (b.tag != null) b.tag!],
      ReactionBoard b => [b.line],
      ScrambleBoard b => [b.hint, b.skipLabel],
      _ => const [],
    };

List<String> _stateWords(GamesCardState s) => [s.title, s.meta, s.status, ...s.chips.map((c) => c.name), ...s.foot.map((f) => f.label), ..._boardWords(s.board)];

// Owner-typed values the producers are fed below.
const _owner = ['Ada', 'Sales', 'Pip', 'Jamie', 'Jo', 'a@b.co', 'Acme'];

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() => I18n.setWidgetLanguage('de', const []));
  tearDown(I18n.debugReset);

  final now = DateTime(2026, 10, 16, 15);
  final nowMs = now.millisecondsSinceEpoch;

  test('Helpful and its reasons', () {
    expect(Helpful.ask, 'Hilfreich?');
    expect(Helpful.reasons.map((r) => r.$2).toList(),
        [de('helpful.reason.wrong'), de('helpful.reason.outdated'), de('helpful.reason.unanswered'), de('helpful.reason.other')]);
    expect(Helpful.ratedLabel(const AnswerFeedback(true)), de('helpful.rated.up'));
    expect(Helpful.ratedLabel(const AnswerFeedback(false, 'outdated')), '${de('helpful.rated.down')} · ${de('helpful.reason.outdated')}');
    expect(Helpful.talkToPersonAsk, de('chat.talkToPersonAsk'));
    expect(AgentBotParser.feedbackReasons.map((r) => r.$2).toList(), Helpful.reasons.map((r) => r.$2).toList());
    expect(AgentBotParser.replyTimeoutText, de('chat.replyTimeout'));
    expect(AgentBotParser.replyTimeoutNotice(now).text, de('chat.replyTimeout'));
    expect(AgentBotParser.defaultGreeting, de('agent.defaultGreeting'));
    expect(AgentBotParser.defaultAgentName, de('agent.defaultName'));
  });

  test('handover lines, joins and leaves', () {
    expect(HandoverRecord.lineText(), de('handover.pending'));
    expect(HandoverRecord.lineText(HandoverOutcome.joined), de('handover.joined'));
    expect(HandoverRecord.lineText(HandoverOutcome.cancelled), de('handover.cancelled'));
    expect(HandoverRecord.joinedText('Ada'), 'Ada${de('system.joined')}');
    expect(HandoverRecord.joinedText(''), '${de('agent.anAgent')}${de('system.joined')}');
    expect(HandoverRecord.agentLeftText(null, false), '${de('agent.theAgent')}${de('system.left')}');
    expect(HandoverRecord.agentLeftText('Ada', true), de('handover.pending'));
    expect(HandoverRecord.handedOverNoteText(HandoverRecord.handedOverNote), de('system.handedOverNote'));
    expect(HandoverRecord.handedOverNoteText('Own note'), 'Own note');
  });

  test('live events and the closed chat, the record keeping English', () {
    expect(LiveEvents.requeuedText(), de('takeover.requeued'));
    expect(LiveEvents.requeuedText('Sales'), de('takeover.requeuedTeam', {'team': 'Sales'}));
    expect(LiveEvents.blockedText(const {}), de('system.closed'));
    expect(LiveEvents.blockedText({'message': 'Gesperrt'}), 'Gesperrt');
    expect(LiveEvents.newChatLabel, 'Neuen Chat starten');
    final ended = LiveEvents.closedStateOf([
      {'type': 'agent-joined-message'},
      {'type': 'agent-chat-ended'},
    ]);
    expect(ended?.text, de('system.chatEnded'));
    // Stored on the record in English, as the web and RN store them.
    expect(LiveEvents.requeuedDefault, 'Connecting you to another agent...');
    expect(LiveEvents.closedText, 'This conversation has been closed.');
    // The requeued line's own entry is written in the visitor's language, as RN's requeuedEntry.
    expect(LiveEvents.requeuedEntry(null)['text'], de('takeover.requeued'));
    expect(HandoverRecord.handedOverNote, 'They can see your conversation so far');
    expect(WaitText.recordText, 'Resolved while waiting');
  });

  test("email transcript: the server's reason only in English", () {
    expect(EmailTranscript.title, de('chat.menu.emailChat'));
    expect(EmailTranscript.sent('a@b.co'), de('mailchat.sent', {'email': 'a@b.co'}));
    const limited = TranscriptEmailResult(false, 'Too many requests');
    expect(EmailTranscript.errorOf(limited), de('form.sendFailed'));
    expect(EmailTranscript.errorOf(null), de('form.sendFailed'));
    I18n.setWidgetLanguage('en', const []);
    expect(EmailTranscript.errorOf(limited), 'Too many requests');
  });

  test('queue, receipts, the waiting card and the rating', () {
    expect(LiveChat.queueLine(const QueueStatus(status: 'waiting', position: 1)), de('queue.next'));
    expect(LiveChat.queueLine(const QueueStatus(status: 'waiting', position: 3)), de('queue.position', {'n': 3, 'ord': '3rd'}));
    expect(LiveChat.queueLine(null), de('queue.connecting'));
    expect(LiveChat.queueSubline(null), de('queue.soon'));
    expect(LiveChat.receiptLabel(ReceiptState.seen), de('receipt.seen'));
    expect(LiveChat.handoverWaitingLine(const HandoverWaiting(offline: false, reason: 'busy', askEmail: false)),
        '${de('sdk.waiting.busy')} ${de('sdk.waiting.leaveEmail')}');
    // "Friday 9:00" in German: the day name and the language's clock.
    final friday = DateTime(2026, 10, 23, 9).toUtc().toIso8601String();
    expect(LiveChat.backAtLabel(friday, now: now), 'Freitag ${DateFormat.jm('de').format(DateTime(2026, 10, 23, 9))}');
    expect(LiveChat.csatConfigOf({'enabled': true})?.titleText, de('csat.title'));
    expect(LiveChat.csatConfigOf({'enabled': true, 'feedbackPlaceholder': 'Tell us more...'})?.feedbackPlaceholder, de('csat.placeholder'));
    expect(LiveChat.csatConfigOf({'enabled': true, 'titleText': 'Wie war es?'})?.titleText, 'Wie war es?');
    expect(LiveChat.talkToPersonAsk, de('chat.talkToPersonAsk'));
  });

  test('reply time on the header and the home card, with German day names', () {
    expect(ReplyTime.headerStatus(null), de('status.online'));
    expect(ReplyTime.phrases['few_minutes'], de('reply.phrase.few_minutes'));
    final online = {'mode': 'auto', 'handover': true, 'state': 'online', 'bucket': 'few_minutes'};
    expect(ReplyTime.homePeople(online).text, de('reply.usually', {'phrase': de('reply.phrase.few_minutes')}));
    expect(ReplyTime.headerStatus(online), de('reply.typicallyShort', {'phrase': de('reply.phrase.few_minutes')}));
    final away = {'mode': 'auto', 'handover': true, 'state': 'away', 'leaveMessage': true};
    expect(ReplyTime.headerStatus(away), '${de('status.online')} · ${de('reply.teamByEmail')}');
    // Back on Monday: the German day name.
    final monday = DateTime(2026, 10, 19, 9).toUtc().toIso8601String();
    final when = ReplyTime.backWhen(monday, now: now);
    expect(when, startsWith('Montag '));
    expect(ReplyTime.homePeople({...away, 'backAt': monday}, now: now).text, de('reply.teamBackAt', {'when': when}));
    final tomorrow = DateTime(2026, 10, 17, 9).toUtc().toIso8601String();
    expect(ReplyTime.backWhen(tomorrow, now: now), startsWith('${de('reply.tomorrow')} '));
  });

  test('home: its words, the ask parts, the model lines', () {
    expect(HomeText.helpCentre, de('home.helpCentre'));
    expect(HomeText.welcomeBackName('Jamie'), de('home.welcomeBackName', {'name': 'Jamie'}));
    final (before, after) = HomeText.askQueryParts();
    expect('${before}Q$after', de('home.askQuery', {'query': 'Q'}));
    expect(salutation(9), de('home.goodMorning'));
    final m = homeModel(
      c: {'enableInitialPage': true, 'initialPageTitle': 'Hi there 👋'},
      botName: 'Acme',
      hour: 20,
      now: nowMs,
    )!;
    expect(m.hello, de('home.goodEvening'));
    expect(m.title, de('home.title'));
    expect(m.description, de('home.description'));
    expect(m.talk.button, de('home.chatWithUs'));
    expect(homeModel(c: {'enableInitialPage': true, 'initialPageCardButtonText': 'Los gehts'}, now: nowMs)!.talk.button, 'Los gehts');
  });

  test('requests: words, states and when, in German', () {
    expect(RequestsText.title, de('requests.title'));
    expect(RequestsText.seeAll(4), de('requests.seeAll', {'n': 4}));
    expect(stateWords[RequestState.solved]!.label, de('requests.solved.label'));
    expect(whenWords(nowMs - 5 * 60000, nowMs), de('when.minutesAgo', {'n': 5}));
    expect(whenWords(nowMs - 10000, nowMs), de('when.justNow'));
    expect(whenWords(nowMs - 3 * 3600000, nowMs), de('when.hoursAgo', {'n': 3}));
    expect(whenWords(DateTime(2026, 10, 15, 12).millisecondsSinceEpoch, nowMs), de('when.yesterday'));
    expect(whenWords(DateTime(2026, 10, 12, 12).millisecondsSinceEpoch, nowMs), 'Montag');
    expect(whenWords(DateTime(2026, 1, 3, 12).millisecondsSinceEpoch, nowMs), '3. Jan.');
    expect(whenWords(DateTime(2025, 1, 3, 12).millisecondsSinceEpoch, nowMs), '3. Jan. 2025');
    const r = RequestSummary(id: '1', title: 'Order', status: 'open', lastFrom: 'team', lastText: '', teamName: 'Ada', lastAt: '1');
    expect(rowLine(r, const {}, nowMs), startsWith(de('requests.newReplyFrom', {'name': 'Ada'})));
  });

  test('the idle call, the games and their lists', () {
    expect(idleCallLine('knock', null), de('idle.knock'));
    expect(idleCallLine('psst', ''), de('idle.psst'));
    expect(idleCallLine('psst', 'Hallo!'), 'Hallo!');
    expect(gamesCatalogue.first.name, de('games.rps.name'));
    expect(offerLine(defaultOfferText), de('games.offer'));
    expect(offerLine('Spiel?'), 'Spiel?');
    expect(handName['rock'], de('games.rps.rock'));
    expect(quizVerdict(3, 3), de('games.verdict.perfect'));
    expect(reactionVerdict(200), de('games.reaction.fast'));
    expect(triviaFor('de').first.q, isNot(triviaFor('en').first.q));
    expect(wordsFor('de').map((w) => w.hint).toList(), isNot(wordsFor('en').map((w) => w.hint).toList()));
    expect(wordsFor('xx').map((w) => w.w).toList(), wordsFor('en').map((w) => w.w).toList());
    expect(GamesText.pausedNamed('Ada'), de('games.paused.named', {'name': 'Ada'}));
    // The emoji riddles are English wordplay: not offered in German.
    expect(gamesForLanguage(gamesCatalogue, 'de').map((g) => g.id), isNot(contains('emoji')));
    expect(gamesForLanguage(gamesCatalogue, 'en').map((g) => g.id), contains('emoji'));
    expect(
        _card(_Clock(), customizations: {
          'waitingGames': {
            'games': ['emoji']
          }
        }),
        isNull);
    final card = _card(_Clock())!;
    expect(card.state.title, de('games.offer'));
    expect(card.state.chips.map((c) => c.id), isNot(contains('emoji')));
    // The default offer as stored stays English.
    expect(defaultOfferText, 'While you wait - fancy a quick game? 🎮');
    expect(waitingGamesOf(const {}).offerText, defaultOfferText);
    // The ordinal is English's own ("3rd" goes into {ord}).
    expect(LiveChat.ordinal(3), '3rd');
    expect(WaitText.title, de('wait.title'));
    expect(WaitText.leftHelped, de('queue.leftHelped'));
  });

  test('steps: dates, weekdays and validation', () {
    final tue = DateTime.utc(2026, 10, 20, 12);
    expect(longDate(tue, 'UTC', visitorLocale()), 'Dienstag, 20. Oktober 2026');
    // The bot's own date stays en-US, as the web keeps it.
    expect(longDate(tue, 'UTC'), 'Tuesday, October 20, 2026');
    expect(weekdayName(2), 'Dienstag');
    expect(inputs.en.emailInvalid, de('validation.email'));
    expect(inputs.numberProblem('abc', const {}), de('validation.numberLike'));
    expect(
        inputs.numberProblem('1', {
          'enableConditions': {'minVal': 5}
        }),
        de('validation.numberMin', {'min': '5'}));
    expect(inputs.fileTypesWords(['image/', 'pdf']), '${de('file.images')} ${de('common.or')} PDF');
    expect(inputs.ownerTextOr('Please enter a valid email address', inputs.en.emailInvalid), de('validation.email'));
    expect(inputs.ownerTextOr('Bitte prüfen', inputs.en.emailInvalid), 'Bitte prüfen');
    expect(inputs.phoneErrorText(const {}), de('validation.phone'));
    expect(ValidationUtils.validateEmail('').errorMessage, de('sdk.validation.emailRequired'));
    expect(ValidationUtils.validateEmail('x').errorMessage, de('validation.email'));
    expect(ValidationUtils.validateNumber('1', min: 5).errorMessage, de('sdk.validation.numberAtLeast', {'min': '5.0'}));
    expect(ValidationUtils.validateRequired(null).errorMessage, de('sdk.validation.fieldRequired', {'field': de('sdk.validation.thisField')}));
  });

  test('launcher, typing, tagline and the greeting', () {
    expect(Launcher.resolve(const {}).label, de('home.chatWithUs'));
    expect(Launcher.resolve({'launcherLabel': 'Fragen?'}).label, 'Fragen?');
    expect(typingLabel('mascot', 'Pip'), de('typing.named', {'name': 'Pip'}));
    expect(typingLabel('dots', ''), de('typing.typing'));
    expect(Customizations.resolve({'enableTagline': true, 'tagline': "We're here to help"}).tagline, de('header.tagline'));
    expect(Customizations.resolve({'enableTagline': true, 'tagline': 'Immer da'}).tagline, 'Immer da');
    const facts = GreetingFacts(returning: false, signedIn: false);
    expect(Greeting.decide({'chatIconCta': true, 'chatIconCtaText': 'Hi 👋, how can I help?'}, facts)?.text, de('greeting.stock'));
    expect(Greeting.decide({'chatIconCta': true, 'chatIconCtaText': 'Moin!'}, facts)?.text, 'Moin!');
  });

  test('sweep: every core text producer under de has no English', () {
    final texts = <String>[
      Helpful.ask, Helpful.groupLabel, Helpful.yes, Helpful.no, Helpful.ratedUp, Helpful.ratedDown, Helpful.thanks,
      Helpful.sorry, Helpful.whatWentWrong, Helpful.comment, Helpful.sendFeedback, Helpful.retry, Helpful.thanksComment,
      Helpful.talkToPerson, Helpful.talkToPersonAsk, ...Helpful.reasons.map((r) => r.$2),
      AgentBotParser.replyTimeoutText, AgentBotParser.defaultGreeting, AgentBotParser.defaultAgentName,
      HandoverRecord.lineText(), ...HandoverOutcome.values.map(HandoverRecord.lineText),
      HandoverRecord.joinedText(null), HandoverRecord.agentLeftText(null, false), HandoverRecord.handedOverNoteText(HandoverRecord.handedOverNote),
      LiveEvents.requeuedText(), LiveEvents.requeuedText('Sales'), LiveEvents.blockedText(null), LiveEvents.closedLabel,
      LiveEvents.chatEndedLabel, LiveEvents.newChatLabel,
      for (final p in [1, 2, 3, null]) LiveChat.queueLine(QueueStatus(status: 'waiting', position: p)),
      LiveChat.queueSubline(null), LiveChat.talkToPersonAsk,
      ...ReceiptState.values.map(LiveChat.receiptLabel),
      LiveChat.handoverWaitingLine(HandoverWaiting(offline: true, reason: 'offline', backAt: DateTime(2026, 10, 17, 9).toUtc().toIso8601String(), askEmail: true), now: now),
      LiveChat.handoverWaitingLine(const HandoverWaiting(offline: true, reason: 'offline', askEmail: true, email: 'a@b.co')),
      LiveChat.handoverWaitingLine(const HandoverWaiting(offline: false, reason: 'busy', askEmail: false)),
      LiveChat.backAtLabel(DateTime(2026, 10, 19, 9, 30).toUtc().toIso8601String(), now: now)!,
      EmailTranscript.menuLabel, EmailTranscript.title, EmailTranscript.sub, EmailTranscript.placeholder, EmailTranscript.label,
      EmailTranscript.send, EmailTranscript.sending, EmailTranscript.cancel, EmailTranscript.checkEmail, EmailTranscript.sendFailed,
      EmailTranscript.sent('a@b.co'), EmailTranscript.errorOf(const TranscriptEmailResult(false, 'Too many requests')),
      WaitText.label, WaitText.title, WaitText.settledTitle, WaitText.read, WaitText.solved, WaitText.done, WaitText.leftHelped,
      RequestsText.title, RequestsText.one, RequestsText.back, RequestsText.loading, RequestsText.loadFailed, RequestsText.tryAgain,
      RequestsText.empty, RequestsText.you, RequestsText.supportTeam, RequestsText.replyPlaceholder, RequestsText.reopenPlaceholder,
      RequestsText.yourReply, RequestsText.send, RequestsText.sending, RequestsText.notSent, RequestsText.locked, RequestsText.newReply,
      RequestsText.newReplyFrom('Ada'), RequestsText.seeAll(3), RequestsText.menu(1),
      for (final w in stateWords.values) ...[w.label, w.detail],
      for (final ago in [10000, 5 * 60000, 3600000, 3 * 3600000, 30 * 3600000, 3 * 86400000, 40 * 86400000, 400 * 86400000]) whenWords(nowMs - ago, nowMs),
      ...ReplyTime.phrases.values,
      ReplyTime.answersInstantly, ReplyTime.answersAlways, ReplyTime.awayNow, ReplyTime.offline, ReplyTime.byEmail, ReplyTime.offlineNow,
      ReplyTime.usuallyInstantly, ReplyTime.teamRepliesByEmail, ReplyTime.teamAwayRightNow,
      ...idleCallLineKeys.keys.map((k) => idleCallLine(k, null)),
      Launcher.defaultLabel, Launcher.resolve(const {}).label, typingLabel('mascot', 'Pip'), typingLabel('dots', ''),
      Customizations.resolve({'enableTagline': true, 'tagline': "We're here to help"}).tagline!,
      ...gamesCatalogue.expand((g) => [g.name, g.blurb]),
      offerLine(defaultOfferText), ...handName.values,
      Verdict.perfect, Verdict.tough, Verdict.close, Verdict.notBad, Verdict.nice,
      ...[100, 300, 400, 900].map(reactionVerdict),
      for (final q in triviaFor('de')) ...[q.q, q.a, ...q.wrong],
      for (final w in wordsFor('de')) w.hint,
      GamesText.card, GamesText.close, GamesText.pick, GamesText.again, GamesText.another, GamesText.notNow,
      GamesText.pausedNamed('Ada'), GamesText.pausedSomeone, GamesText.pausedSaved, GamesText.resume,
      HomeText.title, HomeText.description, HomeText.onlineNow, HomeText.support, HomeText.chatWithUs, HomeText.ourAssistant,
      HomeText.resume, HomeText.continueConversation, HomeText.askAgain, HomeText.helpCentre, HomeText.recentArticles, HomeText.seeAll,
      HomeText.searchPlaceholder, HomeText.searchLabel, HomeText.noMatch('x'), HomeText.askInstead, HomeText.chatInstead,
      HomeText.askPlaceholder, HomeText.askLabel('Pip'), HomeText.answersRightAway('Pip'), HomeText.wellHelp, HomeText.articles,
      HomeText.welcomeBackName('Jo'), HomeText.welcomeBack, HomeText.requestsTitle, HomeText.requestsSeeAll(3),
      HomeText.rated('4.5', 12, HomeText.reviews), HomeText.ourTeam, HomeText.customerLogo, HomeText.close, HomeText.back,
      ...[5, 13, 19, 23].map(salutation),
      longDate(DateTime.utc(2026, 10, 20, 12), 'UTC', visitorLocale()),
      for (var d = 0; d < 7; d++) weekdayName(d),
      inputs.en.emailInvalid, inputs.en.emailTypo('a@b.co'), inputs.en.phoneInvalid, inputs.en.numberLike, inputs.en.numberBetween(1, 5),
      inputs.en.numberMin(1), inputs.en.numberMax(5), inputs.en.link, inputs.en.numberInvalid, inputs.en.urlInvalid,
      inputs.en.uploadOverSize(10), inputs.en.uploadNotAllowed('PDF'), inputs.en.uploadRetry, inputs.en.skipped, inputs.en.done,
      inputs.en.somethingWrong, inputs.fileTypesWords(['image/', 'video/']),
      inputs.fileUploadProblem({'name': 'a.exe', 'size': 10}, {
        'allowedFileTypes': ['image/']
      })!,
      for (final r in [
        ValidationUtils.validateEmail(''), ValidationUtils.validateEmail('x'), ValidationUtils.validatePhoneNumber(''),
        ValidationUtils.validatePhoneNumber('x'), ValidationUtils.validateUrl(''), ValidationUtils.validateUrl('nope'),
        ValidationUtils.validateNumber(''), ValidationUtils.validateNumber('x'), ValidationUtils.validateNumber('1', min: 5),
        ValidationUtils.validateNumber('9', max: 5), ValidationUtils.validateDate(''), ValidationUtils.validateDate('x'),
        ValidationUtils.validateRequired(''), ValidationUtils.validateLength('a', minLength: 3), ValidationUtils.validateLength('abcdef', maxLength: 2),
        ValidationUtils.validateByType('', fieldType: 'text'),
      ])
        r.errorMessage ?? '',
    ];
    final csat = LiveChat.csatConfigOf({'enabled': true})!;
    texts.addAll([csat.titleText, csat.subtitleText, csat.thankYouText, csat.feedbackPlaceholder]);
    final rts = <Map<String, dynamic>?>[
      {'mode': 'auto', 'handover': true, 'state': 'online', 'bucket': 'few_minutes'},
      {'mode': 'auto', 'handover': true, 'state': 'away', 'backAt': DateTime(2026, 10, 16, 18).toUtc().toIso8601String()},
      {'mode': 'auto', 'handover': true, 'state': 'away', 'backAt': DateTime(2026, 10, 17, 9).toUtc().toIso8601String()},
      {'mode': 'auto', 'handover': true, 'state': 'away', 'backAt': DateTime(2026, 10, 20, 9, 30).toUtc().toIso8601String()},
      {'mode': 'auto', 'handover': true, 'state': 'away', 'backAt': DateTime(2026, 11, 20, 9, 30).toUtc().toIso8601String()},
      {'mode': 'auto', 'handover': true, 'state': 'away', 'leaveMessage': false},
      {'mode': 'auto', 'handover': true, 'state': 'offline', 'leaveMessage': true},
      {'mode': 'auto', 'handover': true, 'state': 'offline', 'leaveMessage': false},
      null,
    ];
    for (final rt in rts) {
      for (final agent in [false, true]) {
        texts.add(ReplyTime.headerStatus(rt, agentBot: agent, now: now) ?? '');
        texts.add(ReplyTime.homePeople(rt, agent: agent, now: now).text);
        texts.add(ReplyTime.homeLine(rt, agent: agent, now: now)?.text ?? '');
      }
    }
    // The home model with every card on.
    final m = homeModel(
      c: {
        'enableInitialPage': true,
        'enableKnowledgeBase': true,
        'homeRating': {'average': 4.6, 'count': 1},
        'replyTime': rts.first,
      },
      botName: 'Acme',
      agent: null,
      recentArticles: [
        {'_id': 'a1', 'title': 'Acme', 'description': 'Acme', 'published': true},
      ],
      memory: VisitorMemory(at: nowMs - 60000, name: 'Jo', topic: 'Acme', session: 's'),
      requests: [
        for (var i = 0; i < 3; i++)
          RequestSummary(id: '$i', title: 'Acme', status: i == 0 ? 'solved' : 'open', lastFrom: i == 1 ? 'team' : 'you', lastText: '', teamName: '', lastAt: '${nowMs - i * 3600000}'),
      ],
      now: nowMs,
    )!;
    texts.addAll([m.hello, m.title, m.description, m.talk.title, m.talk.button, m.talk.status ?? '', m.talk.tagline ?? '', m.ask?.placeholder ?? '', m.ask?.label ?? '']);
    texts.addAll([m.talk.rating?.label ?? '', m.requests?.seeAll ?? '', ...?m.requests?.rows.map((r) => r.line), m.help?.title ?? '', m.resume?.line ?? '']);
    texts.add(Greeting.decide({'chatIconCta': true, 'chatIconCtaText': 'Hi 👋, how can I help?'}, const GreetingFacts(returning: false, signedIn: false))!.text);
    // Each game opened and played a little: its title, score, status and board.
    for (final id in gamesForLanguage(gamesCatalogue, 'de').map((g) => g.id)) {
      final k = _Clock();
      final card = _card(k)!;
      texts.addAll(_stateWords(card.state));
      card.open(id);
      texts.addAll(_stateWords(card.state));
      for (final a in const <GameInput>[RpsInput('rock'), TttInput(0), MemoryInput(0), MemoryInput(1), ChoiceInput(0), ReactionInput(), TileInput(0), SkipInput()]) {
        card.input(a);
        k.tick(5000);
        texts.addAll(_stateWords(card.state));
      }
      card.wrapUp('Ada');
      texts.addAll(_stateWords(card.state));
    }
    texts.addAll(_stateWords(_card(_Clock(), mode: 'menu')!.state));

    final drawn = texts.where((s) => s.trim().isNotEmpty).toList();
    expect(drawn.length, greaterThan(300));
    expect(englishIn(drawn, _owner), isEmpty);
    // The sweep bites: the same words in English are caught.
    expect(englishIn([I18n.tFor('en', 'wait.title')]), isNotEmpty);
    expect(englishIn([I18n.tFor('en', 'games.rps.intro')]), isNotEmpty);
  });

  test('under en the core keeps its English', () {
    I18n.setWidgetLanguage('en', const []);
    expect(Helpful.ask, 'Helpful?');
    expect(LiveChat.queueLine(const QueueStatus(status: 'waiting', position: 3)), "You're 3rd in line");
    expect(whenWords(nowMs - 5 * 60000, nowMs), '5 min ago');
    expect(whenWords(DateTime(2026, 1, 3, 12).millisecondsSinceEpoch, nowMs), '3 Jan');
    expect(GamesText.notNow, 'Not now');
    expect(Launcher.resolve(const {}).label, 'Chat with us');
    expect(_card(_Clock())!.state.title, defaultOfferText);
    expect(gamesForLanguage(gamesCatalogue, I18n.language).map((g) => g.id), contains('emoji'));
  });
}
