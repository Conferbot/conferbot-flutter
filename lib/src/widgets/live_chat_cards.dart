import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../core/agent/agent_bot.dart';
import '../core/live_chat/live_chat.dart';
import '../core/live_chat/live_chat_extras.dart';
import '../models/message.dart';
import '../providers/conferbot_provider.dart';
import '../theme/conferbot_theme.dart';

/// The small cards and lines of a live chat, as on the web widget: the
/// owner's quick actions and "Talk to a person" above the composer, the AI's
/// follow-up email card, the queue position, the "nobody could join" email
/// ask, leave a message, a locked conversation, an agent's dropped
/// connection, an agent asking for a file, and the post-chat rating.
/// State is on [ConferBotProvider.liveChat] (core/live_chat).

class _LiveCard extends StatelessWidget {
  final ConferBotTheme theme;
  final List<Widget> children;
  const _LiveCard({required this.theme, required this.children});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      margin: EdgeInsets.only(left: theme.layout.avatarSize + 10),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: theme.colors.surface,
        border: Border.all(color: theme.colors.divider),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: children),
    );
  }
}

Widget _title(ConferBotTheme theme, String text) =>
    Text(text, style: TextStyle(color: theme.colors.text, fontSize: 15, fontWeight: FontWeight.w600));

Widget _sub(ConferBotTheme theme, String text) => Padding(
      padding: const EdgeInsets.only(top: 2),
      child: Text(text, style: TextStyle(color: theme.colors.textSecondary, fontSize: 13)),
    );

Widget _body(ConferBotTheme theme, String text) => Text(text, style: TextStyle(color: theme.colors.text, fontSize: 14));

class _PrimaryButton extends StatelessWidget {
  final ConferBotTheme theme;
  final String label;
  final bool enabled;
  final bool busy;
  final VoidCallback onTap;
  const _PrimaryButton({required this.theme, required this.label, required this.onTap, this.enabled = true, this.busy = false});

  @override
  Widget build(BuildContext context) {
    // Readable on the brand colour, whatever it is.
    final onPrimary = theme.colors.primary.computeLuminance() > 0.5 ? Colors.black : Colors.white;
    return Material(
      color: enabled ? theme.colors.primary : theme.colors.primary.withOpacity(0.45),
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: enabled && !busy ? onTap : null,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          child: Center(
            widthFactor: 1,
            heightFactor: 1,
            child: busy
                ? SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: onPrimary))
                : Text(label, style: TextStyle(color: onPrimary, fontSize: 14, fontWeight: FontWeight.w600)),
          ),
        ),
      ),
    );
  }
}

class _OutlineButton extends StatelessWidget {
  final ConferBotTheme theme;
  final String label;
  final VoidCallback onTap;
  const _OutlineButton({required this.theme, required this.label, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(12),
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        decoration: BoxDecoration(border: Border.all(color: theme.colors.divider), borderRadius: BorderRadius.circular(12)),
        child: Text(label, style: TextStyle(color: theme.colors.text, fontSize: 14)),
      ),
    );
  }
}

class _Field extends StatelessWidget {
  final ConferBotTheme theme;
  final TextEditingController controller;
  final String placeholder;
  final int minLines;
  final bool email;
  const _Field({required this.theme, required this.controller, required this.placeholder, this.minLines = 1, this.email = false});

  @override
  Widget build(BuildContext context) {
    final border = OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide(color: theme.colors.divider));
    return TextField(
      controller: controller,
      minLines: minLines,
      maxLines: minLines == 1 ? 1 : 6,
      keyboardType: email ? TextInputType.emailAddress : TextInputType.multiline,
      autocorrect: !email,
      cursorColor: theme.colors.primary,
      style: TextStyle(fontSize: 15, color: theme.colors.text),
      decoration: InputDecoration(
        isDense: true,
        hintText: placeholder,
        hintStyle: TextStyle(color: theme.colors.textSecondary, fontSize: 15),
        filled: true,
        fillColor: theme.colors.background,
        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        border: border,
        enabledBorder: border,
        focusedBorder: border.copyWith(borderSide: BorderSide(color: theme.colors.primary)),
      ),
    );
  }
}

/// An email field (and an optional message) with one button. [onSubmit] reports ok.
class _EmailForm extends StatefulWidget {
  final ConferBotTheme theme;
  final String button;
  final String? messagePlaceholder;
  final String initialEmail;
  final String initialMessage;
  final Future<bool> Function(String email, String message) onSubmit;
  const _EmailForm({
    required this.theme,
    required this.button,
    required this.onSubmit,
    this.messagePlaceholder,
    this.initialEmail = '',
    this.initialMessage = '',
  });

  @override
  State<_EmailForm> createState() => _EmailFormState();
}

class _EmailFormState extends State<_EmailForm> {
  late final _email = TextEditingController(text: widget.initialEmail);
  late final _message = TextEditingController(text: widget.initialMessage);
  bool _busy = false;
  String? _error;

  @override
  void dispose() {
    _email.dispose();
    _message.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!LiveChat.isEmail(_email.text)) return setState(() => _error = 'Please enter a valid email.');
    if (widget.messagePlaceholder != null && _message.text.trim().isEmpty) {
      return setState(() => _error = 'Please write a short message.');
    }
    setState(() {
      _error = null;
      _busy = true;
    });
    final ok = await widget.onSubmit(_email.text.trim(), _message.text.trim());
    if (!mounted) return;
    setState(() {
      _busy = false;
      if (!ok) _error = 'That did not go through. Please try again.';
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = widget.theme;
    return Padding(
      padding: const EdgeInsets.only(top: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (widget.messagePlaceholder != null) ...[
            _Field(theme: theme, controller: _message, placeholder: widget.messagePlaceholder!, minLines: 3),
            const SizedBox(height: 8),
          ],
          Row(
            children: [
              Expanded(child: _Field(theme: theme, controller: _email, placeholder: 'you@example.com', email: true)),
              const SizedBox(width: 8),
              _PrimaryButton(theme: theme, label: widget.button, busy: _busy, onTap: _submit),
            ],
          ),
          if (_error != null)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Text(_error!, style: TextStyle(color: theme.colors.error, fontSize: 12)),
            ),
        ],
      ),
    );
  }
}

/// The owner's quick actions (and "Talk to a person") above the composer,
/// as on the web (quickActions.ts): from the first AI answer on. "Talk to a
/// person" only while no handover is under way and nobody is here
/// (ConferBotProvider.offerTalkToPerson); it goes on tap and never comes
/// back, and the owner's links stay.
class QuickActionsStrip extends StatelessWidget {
  final ConferBotProvider provider;
  final ConferBotTheme theme;
  const QuickActionsStrip({super.key, required this.provider, required this.theme});

  @override
  Widget build(BuildContext context) {
    final shown = [...provider.record, ...provider.paginatedMessages];
    final aiAnswered = shown.any((m) => m is AgentMessageRecord && m.agentDetails.isAIAgent);
    if (!aiAnswered) return const SizedBox.shrink();
    final actions = AgentBotParser.quickActionsOf(provider.serverCustomizations);
    final human = provider.offerTalkToPerson;
    if (actions.isEmpty && !human) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      child: SizedBox(
        width: double.infinity,
        child: Wrap(
          spacing: 6,
          runSpacing: 6,
          children: [
            for (final a in actions)
              _Pill(
                theme: theme,
                label: '${a.label} ↗',
                onTap: () {
                  provider.trackConversion('quick-action:${a.label}', AgentBotParser.conversionEventOf(a.label, a.url));
                  final uri = Uri.tryParse(a.url);
                  if (uri != null) launchUrl(uri, mode: LaunchMode.externalApplication);
                },
              ),
            if (human) _Pill(key: const ValueKey('cb-talk-to-person'), theme: theme, label: 'Talk to a person', onTap: provider.talkToPerson),
          ],
        ),
      ),
    );
  }
}

class _Pill extends StatelessWidget {
  final ConferBotTheme theme;
  final String label;
  final VoidCallback onTap;
  const _Pill({super.key, required this.theme, required this.label, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: theme.colors.botBubble,
      shape: const StadiumBorder(),
      child: InkWell(
        customBorder: const StadiumBorder(),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
          child: Text(label, style: TextStyle(color: theme.colors.botBubbleText, fontSize: 13, fontWeight: FontWeight.w600)),
        ),
      ),
    );
  }
}

/// The handover step while it waits for a person: where they stand, about
/// how long, and Leave queue (queue-self-resolve: the team stops seeing
/// them waiting, and the flow carries on).
class HandoverWaitCard extends StatelessWidget {
  final LiveChatExtras liveChat;
  final ConferBotTheme theme;
  final String? message;

  /// Leave the queue (ConferBotProvider.leaveQueue); no action when null.
  final VoidCallback? onLeave;
  const HandoverWaitCard({super.key, required this.liveChat, required this.theme, this.message, this.onLeave});

  @override
  Widget build(BuildContext context) {
    final queue = liveChat.queue;
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: theme.spacing.chatContentPadding),
      child: _LiveCard(
        theme: theme,
        children: [
          Row(
            children: [
              SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: theme.colors.primary)),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [_title(theme, LiveChat.queueLine(queue)), _sub(theme, LiveChat.queueSubline(queue))],
                ),
              ),
            ],
          ),
          if (message != null && message!.trim().isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Text(message!, style: TextStyle(color: theme.colors.textSecondary, fontSize: 13)),
            ),
          if (onLeave != null)
            Align(
              alignment: Alignment.centerRight,
              child: TextButton(
                key: const ValueKey('cb-leave-queue'),
                onPressed: onLeave,
                style: TextButton.styleFrom(
                  foregroundColor: theme.colors.textSecondary,
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                  minimumSize: const Size(0, 32),
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
                child: const Text('Leave queue', style: TextStyle(fontSize: 13)),
              ),
            ),
        ],
      ),
    );
  }
}

/// The post-chat rating, from the bot's csatConfig.
class _CsatCard extends StatefulWidget {
  final LiveChatExtras liveChat;
  final ConferBotTheme theme;
  const _CsatCard({required this.liveChat, required this.theme});

  @override
  State<_CsatCard> createState() => _CsatCardState();
}

const _faces = ['\u{1F61E}', '\u{1F615}', '\u{1F610}', '\u{1F642}', '\u{1F604}'];

class _CsatCardState extends State<_CsatCard> {
  Object? _value;
  final _feedback = TextEditingController();

  @override
  void dispose() {
    _feedback.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final c = widget.liveChat.csatConfig!;
    final theme = widget.theme;
    if (widget.liveChat.csatSent) return _LiveCard(theme: theme, children: [_title(theme, c.thankYouText)]);
    final List<Object> options = switch (c.ratingType) {
      'thumbs' => [true, false],
      'nps' => [for (var i = 0; i <= 10; i++) i],
      _ => [1, 2, 3, 4, 5],
    };
    return _LiveCard(
      theme: theme,
      children: [
        _title(theme, c.titleText),
        _sub(theme, c.subtitleText),
        const SizedBox(height: 10),
        Wrap(
          spacing: 6,
          runSpacing: 6,
          children: [
            for (final o in options)
              if (c.ratingType == 'stars')
                Semantics(
                  label: '$o out of 5',
                  button: true,
                  child: GestureDetector(
                    onTap: () => setState(() => _value = o),
                    child: Text(
                      '★',
                      style: TextStyle(
                        fontSize: 30,
                        color: _value != null && (o as int) <= (_value as int) ? const Color(0xFFF5A623) : theme.colors.divider,
                      ),
                    ),
                  ),
                )
              else
                _choice(theme, o, c.ratingType),
          ],
        ),
        if (_value != null && c.showFeedbackInput) ...[
          const SizedBox(height: 10),
          _Field(theme: theme, controller: _feedback, placeholder: c.feedbackPlaceholder, minLines: 2),
        ],
        const SizedBox(height: 10),
        Row(
          children: [
            Expanded(
              child: _PrimaryButton(
                theme: theme,
                label: 'Send',
                enabled: _value != null,
                onTap: () => widget.liveChat.submitRating(_value!, _feedback.text),
              ),
            ),
            const SizedBox(width: 8),
            _OutlineButton(theme: theme, label: 'Not now', onTap: widget.liveChat.dismissCsat),
          ],
        ),
      ],
    );
  }

  Widget _choice(ConferBotTheme theme, Object o, String type) {
    final chosen = o == _value;
    final label = switch (type) {
      'thumbs' => o == true ? 'Yes' : 'No',
      'emoji' => _faces[(o as int) - 1],
      _ => o.toString(),
    };
    return InkWell(
      customBorder: const StadiumBorder(),
      onTap: () => setState(() => _value = o),
      child: Container(
        constraints: const BoxConstraints(minWidth: 36),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
        decoration: ShapeDecoration(
          color: chosen ? theme.colors.primary : Colors.transparent,
          shape: StadiumBorder(side: BorderSide(color: chosen ? theme.colors.primary : theme.colors.divider)),
        ),
        child: Text(
          label,
          textAlign: TextAlign.center,
          style: TextStyle(fontSize: 14, color: chosen ? (theme.colors.primary.computeLuminance() > 0.5 ? Colors.black : Colors.white) : theme.colors.text),
        ),
      ),
    );
  }
}

/// A centred system line (locked, connection dropped), above the composer.
class LiveSystemLine extends StatelessWidget {
  final ConferBotTheme theme;
  final String text;
  const LiveSystemLine({super.key, required this.theme, required this.text});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Center(
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: ShapeDecoration(color: theme.colors.systemBubble, shape: const StadiumBorder()),
          child: Text(text, textAlign: TextAlign.center, style: TextStyle(color: theme.colors.systemBubbleText, fontSize: 12)),
        ),
      ),
    );
  }
}

/// Everything a live chat adds below the messages, in the web widget's
/// order: the receipt, then the cards.
class LiveChatFooter extends StatelessWidget {
  final ConferBotProvider provider;
  final ConferBotTheme theme;
  final VoidCallback? onUpload;
  const LiveChatFooter({super.key, required this.provider, required this.theme, this.onUpload});

  @override
  Widget build(BuildContext context) {
    final live = provider.liveChat;
    final agent = provider.currentAgent;
    final personHere = provider.isLiveChatMode && agent != null && !agent.id.startsWith('ai-agent-');
    final receipt = live.visitorReceipt(personHere: personHere);
    final leaveOn = provider.serverCustomizations?['chatLeaveMessage'] != false;
    final cards = <Widget>[
      if (live.handoverWaiting != null)
        _LiveCard(
          theme: theme,
          children: [
            _body(theme, LiveChat.handoverWaitingLine(live.handoverWaiting!)),
            if (live.handoverWaiting!.email == null && live.handoverWaiting!.askEmail)
              _EmailForm(theme: theme, button: 'Send', onSubmit: (email, _) => live.shareEmailForReply(email)),
          ],
        ),
      if (leaveOn && live.leftMessageTo != null)
        _LiveCard(theme: theme, children: [
          _title(theme, "Message sent. We'll reply to you at ${live.leftMessageTo}."),
          _sub(theme, 'Replies will reach your inbox, and show here if you come back.'),
        ])
      else if (leaveOn && live.noAgentsAvailable)
        _LeaveMessageCard(liveChat: live, theme: theme),
      if (live.fileRequestedBy != null)
        _LiveCard(theme: theme, children: [
          _body(theme, '${live.fileRequestedBy} asked you to send a file'),
          if (onUpload != null) ...[
            const SizedBox(height: 10),
            _PrimaryButton(theme: theme, label: 'Choose a file', onTap: onUpload!),
          ],
        ]),
      if (live.leadEmail != null)
        _LiveCard(theme: theme, children: [_body(theme, "Thanks! We'll follow up at ${live.leadEmail}")])
      else if (live.leadCardOpen)
        _LiveCard(theme: theme, children: [
          _title(theme, 'Want us to follow up?'),
          _sub(theme, 'Leave your email and the team will get back to you.'),
          _EmailForm(
            theme: theme,
            button: 'Send',
            onSubmit: (email, _) async {
              live.captureLeadEmail(email);
              return true;
            },
          ),
        ]),
      if (live.csatConfig != null && live.csatOpen) _CsatCard(liveChat: live, theme: theme),
    ];
    if (receipt == null && cards.isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: theme.spacing.chatContentPadding, vertical: 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (receipt != null)
            Padding(
              padding: const EdgeInsets.only(bottom: 4),
              child: Text(
                LiveChat.receiptLabel(receipt.state),
                textAlign: TextAlign.right,
                style: TextStyle(color: theme.colors.textSecondary, fontSize: 11),
              ),
            ),
          for (var i = 0; i < cards.length; i++) ...[if (i > 0) const SizedBox(height: 8), cards[i]],
        ],
      ),
    );
  }
}

/// No one is available: leave a message, answered by email.
class _LeaveMessageCard extends StatelessWidget {
  final LiveChatExtras liveChat;
  final ConferBotTheme theme;
  const _LeaveMessageCard({required this.liveChat, required this.theme});

  @override
  Widget build(BuildContext context) {
    // Their email if known, and what they last asked in their own words.
    final prefill = liveChat.leaveMessagePrefill();
    return _LiveCard(
      theme: theme,
      children: [
        _title(theme, 'Leave a message'),
        _sub(theme, "No one is available right now. We'll reply by email."),
        _EmailForm(
          theme: theme,
          button: 'Send',
          messagePlaceholder: 'How can we help?',
          initialEmail: prefill.email,
          initialMessage: prefill.message,
          onSubmit: liveChat.leaveMessage,
        ),
        Padding(
          padding: const EdgeInsets.only(top: 8),
          child: GestureDetector(
            onTap: liveChat.skipLeaveMessage,
            child: Text('Not now', style: TextStyle(color: theme.colors.textSecondary, fontSize: 13)),
          ),
        ),
      ],
    );
  }
}

/// Above the composer: a locked conversation, an agent's dropped
/// connection, then the quick actions.
class LiveChatComposerTop extends StatelessWidget {
  final ConferBotProvider provider;
  final ConferBotTheme theme;
  const LiveChatComposerTop({super.key, required this.provider, required this.theme});

  @override
  Widget build(BuildContext context) {
    final live = provider.liveChat;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (live.lockedBy != null) LiveSystemLine(theme: theme, text: 'This conversation has been locked'),
        if (live.agentConnectionLost != null)
          LiveSystemLine(theme: theme, text: "${live.agentConnectionLost}'s connection dropped. Hang on, they should be right back."),
        QuickActionsStrip(provider: provider, theme: theme),
      ],
    );
  }
}
