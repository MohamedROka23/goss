import 'dart:async';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';

import '../../models/chat_models.dart';
import '../../providers/app_provider.dart';
import '../../app/theme.dart';
import '../../services/chat_crypto.dart';
import '../../services/chat_store.dart';
import '../../services/notification_watcher.dart';

/// Shared one-to-one support chat screen.
///
/// The same widget powers the customer side (send photos from the camera,
/// talk to the team) and the admin side (approve/close + reply). Every message
/// is decrypted lazily inside the bubble with the conversation key that this
/// device owns; showing the raw encrypted payload to users is never done.
class ChatScreen extends StatefulWidget {
  const ChatScreen({
    super.key,
    required this.conversation,
    required this.role, // 'customer' | 'admin'
  });

  final ChatConversation conversation;
  final String role;

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final _textCtrl = TextEditingController();
  final _scrollCtrl = ScrollController();
  final _decrypted = <String, String>{};
  final _decryptedImages = <String, List<int>>{};

  String? _convKey;
  bool _undecryptable = false;
  bool _sending = false;
  bool _deleted = false;
  ChatConversation? _live;
  StreamSubscription<List<ChatMessage>>? _sub;
  StreamSubscription<ChatConversation?>? _convSub;

  /// Live conversation status: never taken from the stale widget snapshot so an
  /// approval / closure reflects here instantly on both sides.
  ChatStatus get _status => _live?.status ?? widget.conversation.status;

  bool get _isAdmin => widget.role == 'admin';
  String get _me => _isAdmin ? 'admin' : 'customer';

  @override
  void initState() {
    super.initState();
    // Suppress notification pops while the user is reading this conversation.
    NotificationWatcher.instance.currentConversation = widget.conversation.id;
    _resolveKey();
    _sub = ChatStore.messages(widget.conversation.id).listen((_) {
      if (mounted) _scrollToBottom();
    })..onError((_) {});
    _convSub = ChatStore.conversationStream(widget.conversation.id).listen((c) {
      if (!mounted) return;
      setState(() {
        _live = c;
        if (c == null) _deleted = true; // the conversation was deleted
      });
    });
  }

  @override
  void dispose() {
    if (NotificationWatcher.instance.currentConversation == widget.conversation.id) {
      NotificationWatcher.instance.currentConversation = null;
    }
    _sub?.cancel();
    _convSub?.cancel();
    _textCtrl.dispose();
    _scrollCtrl.dispose();
    super.dispose();
  }

  Future<void> _resolveKey() async {
    final key = await (_isAdmin
        ? ChatStore.openConversationKeyForTeam(widget.conversation)
        : ChatStore.openConversationKeyForCustomer(widget.conversation));
    if (!mounted) return;
    setState(() {
      _convKey = key;
      _undecryptable = key == null;
    });
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollCtrl.hasClients) {
        _scrollCtrl.animateTo(
          _scrollCtrl.position.maxScrollExtent,
          duration: const Duration(milliseconds: 240),
          curve: Curves.easeOut,
        );
      }
    });
  }

  /// Best-effort decrypt of one message. Results stay in memory per screen.
  Future<({String text, List<int>? bytes, bool failed})> _open(ChatMessage m) async {
    if (m.isImage) {
      final mediaKey = '${m.id}::${m.mediaNonce}';
      if (_decryptedImages.containsKey(mediaKey)) {
        return (text: '', bytes: _decryptedImages[mediaKey], failed: false);
      }
      final key = _convKey;
      if (key == null) return (text: '', bytes: null, failed: true);
      final bytes = await ChatCrypto.decryptBytes(key, m.mediaNonce, m.mediaData, m.mediaMac);
      if (bytes == null) return (text: '', bytes: null, failed: true);
      _decryptedImages[mediaKey] = bytes;
      return (text: '', bytes: bytes, failed: false);
    }
    if (_decrypted.containsKey(m.id)) return (text: _decrypted[m.id]!, bytes: null, failed: false);
    final key = _convKey;
    if (key == null) return (text: '', bytes: null, failed: true);
    final text = await ChatCrypto.decryptText(key, m.nonce, m.data, m.mac);
    if (text == null) return (text: '', bytes: null, failed: true);
    _decrypted[m.id] = text;
    return (text: text, bytes: null, failed: false);
  }

  Future<void> _sendText() async {
    final text = _textCtrl.text.trim();
    final key = _convKey;
    if (text.isEmpty || key == null || _sending) return;
    setState(() => _sending = true);
    final err = await ChatStore.sendText(
      conversationId: widget.conversation.id,
      senderRole: _me,
      convKeyB64: key,
      text: text,
    );
    if (!mounted) return;
    _textCtrl.clear();
    setState(() => _sending = false);
    if (err != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(err, textAlign: TextAlign.start)),
      );
    }
  }

  Future<void> _sendPhoto() async {
    final key = _convKey;
    if (key == null || _sending) return;
    final picker = ImagePicker();
    final file = await picker.pickImage(
      source: ImageSource.camera,
      maxWidth: 1600,
      maxHeight: 1600,
    );
    if (file == null || !mounted) return;
    setState(() => _sending = true);
    final err = await ChatStore.sendImage(
      conversationId: widget.conversation.id,
      senderRole: _me,
      convKeyB64: key,
      originalBytes: await file.readAsBytes(),
    );
    if (!mounted) return;
    setState(() => _sending = false);
    if (err != null) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(err)));
    }
  }

  Future<void> _approve() async {
    final messenger = ScaffoldMessenger.of(context);
    final err = await ChatStore.approve(widget.conversation.id);
    if (err == null || !mounted) return;
    messenger.showSnackBar(SnackBar(content: Text(err, textAlign: TextAlign.start)));
  }

  Future<void> _close() async {
    final messenger = ScaffoldMessenger.of(context);
    final err = await ChatStore.close(widget.conversation.id);
    if (err == null || !mounted) return;
    messenger.showSnackBar(SnackBar(content: Text(err, textAlign: TextAlign.start)));
  }

  Future<void> _reopen() async {
    final messenger = ScaffoldMessenger.of(context);
    final err = await ChatStore.setStatus(widget.conversation.id, ChatStatus.open);
    if (err == null || !mounted) return;
    messenger.showSnackBar(SnackBar(content: Text(err, textAlign: TextAlign.start)));
  }

  String _statusLabel(ChatStatus status, {required bool en}) {
    switch (status) {
      case ChatStatus.pending:
        return en ? 'Waiting for the team to accept' : 'بانتظار موافقة فريق الدعم';
      case ChatStatus.open:
        return en ? 'Chat open' : 'المحادثة مفتوحة';
      case ChatStatus.closed:
        return en ? 'Conversation closed' : 'أُغلقت المحادثة';
    }
  }

  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppProvider>();
    final en = !app.isArabic;
    final c = widget.conversation;

    Widget? header;
    if (_deleted) {
      header = Container(
        margin: const EdgeInsets.all(8),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: GossColors.red.withValues(alpha: 0.10),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Text(
          en
              ? 'This conversation was deleted by the team.'
              : 'حذف فريق الدعم هذه المحادثة.',
          style: TextStyle(color: GossColors.red, fontSize: 12.5),
        ),
      );
    } else if (_undecryptable) {
      header = Container(
        margin: const EdgeInsets.all(8),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: GossColors.red.withValues(alpha: 0.10),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Text(
          en
              ? 'This device cannot decrypt this conversation (it joined after the chat was created).'
              : 'هذا الجهاز لا يملك مفتاح هذه المحادثة (أُنشئت قبل تفعيل مفتاح هذا الجهاز).',
          style: TextStyle(color: GossColors.red, fontSize: 12.5),
        ),
      );
    } else if (_status == ChatStatus.pending) {
      header = Container(
        margin: const EdgeInsets.all(8),
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: GossColors.amber.withValues(alpha: 0.15),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Text(_statusLabel(ChatStatus.pending, en: en), style: const TextStyle(fontSize: 12.5)),
      );
    } else if (_status == ChatStatus.closed) {
      header = Container(
        margin: const EdgeInsets.all(8),
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: context.mutedColor.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Text(
          _statusLabel(ChatStatus.closed, en: en),
          style: TextStyle(fontSize: 12.5, color: context.mutedColor),
        ),
      );
    }

    final appBarActions = <Widget>[];
    if (!_deleted) {
      if (_status == ChatStatus.closed) {
        appBarActions.add(
          IconButton(
            tooltip: en ? 'Reopen conversation' : 'إعادة فتح المحادثة',
            icon: const Icon(Icons.replay_circle_filled),
            onPressed: _reopen,
          ),
        );
      }
      if (_isAdmin && _status != ChatStatus.closed) {
        appBarActions.add(
          IconButton(
            tooltip: en ? 'Close conversation' : 'إغلاق المحادثة',
            icon: const Icon(Icons.call_end),
            onPressed: _status == ChatStatus.closed ? null : _close,
          ),
        );
        if (_status == ChatStatus.pending) {
          appBarActions.add(
            TextButton.icon(
              onPressed: _approve,
              style: TextButton.styleFrom(foregroundColor: Colors.green.shade400),
              icon: const Icon(Icons.check_circle_outline, size: 18),
              label: Text(en ? 'Accept' : 'موافقة'),
            ),
          );
        }
      }
    }

    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(en ? 'Support chat' : 'شات خدمة العملاء'),
            if (!_isAdmin)
              Text(
                en ? 'Encrypted end-to-end' : 'مشفّر من طرف لطرف',
                style: TextStyle(fontSize: 11, color: context.mutedColor),
              ),
          ],
        ),
        actions: appBarActions,
      ),
      body: Column(
        children: [
          ?header,
          Expanded(
            child: StreamBuilder<List<ChatMessage>>(
              stream: ChatStore.messages(c.id),
              builder: (context, snap) {
                if (snap.hasError) {
                  return Center(child: Text(en ? 'Could not load messages' : 'تعذّر تحميل الرسائل'));
                }
                final messages = snap.data ?? const <ChatMessage>[];
                if (messages.isEmpty) {
                  final hint = switch (_status) {
                    ChatStatus.pending =>
                      en
                          ? 'Waiting for the team to accept your request.\nMessages can be sent once the conversation is open.'
                          : 'بانتظار موافقة فريق الدعم على الطلب.\nتُرسل الرسائل بعد فتح المحادثة.',
                    ChatStatus.closed =>
                      en ? 'This conversation is closed.' : 'أُغلقت هذه المحادثة.',
                    ChatStatus.open =>
                      en
                          ? 'No messages yet.\nSend the first message to the support team.'
                          : 'لا توجد رسائل بعد.\nأرسل أول رسالة لفريق الدعم.',
                  };
                  return Center(
                    child: Text(
                      _deleted
                          ? (en ? 'This conversation was deleted.' : 'حُذفت هذه المحادثة.')
                          : hint,
                      textAlign: TextAlign.center,
                      style: TextStyle(color: context.mutedColor),
                    ),
                  );
                }
                return ListView.builder(
                  controller: _scrollCtrl,
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                  itemCount: messages.length,
                  itemBuilder: (context, i) => _MessageBubble(
                    message: messages[i],
                    mine: messages[i].senderRole == _me,
                    open: _open,
                  ),
                );
              },
            ),
          ),
          _buildComposer(en),
        ],
      ),
    );
  }

  Widget _buildComposer(bool en) {
    final disabled = _deleted || _convKey == null || _status != ChatStatus.open || _sending;
    return SafeArea(
      top: false,
      child: Container(
        padding: const EdgeInsets.fromLTRB(8, 6, 8, 8),
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surfaceContainerHighest,
        ),
        child: Row(
          children: [
            IconButton(
              tooltip: en ? 'Take a photo' : 'التقاط صورة',
              icon: const Icon(Icons.photo_camera_outlined),
              onPressed: disabled ? null : _sendPhoto,
            ),
            Expanded(
              child: TextField(
                controller: _textCtrl,
                enabled: !disabled,
                textInputAction: TextInputAction.send,
                onSubmitted: (_) => _sendText(),
                decoration: InputDecoration(
                  hintText: en ? 'Write a message…' : 'اكتب رسالتك…',
                  isDense: true,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(22),
                    borderSide: BorderSide.none,
                  ),
                  filled: true,
                ),
              ),
            ),
            const SizedBox(width: 8),
            IconButton.filled(
              tooltip: en ? 'Send' : 'إرسال',
              icon: _sending
                  ? const SizedBox.square(dimension: 18, child: CircularProgressIndicator(strokeWidth: 2))
                  : const Icon(Icons.send),
              onPressed: disabled ? null : _sendText,
            ),
          ],
        ),
      ),
    );
  }
}

class _MessageBubble extends StatelessWidget {
  const _MessageBubble({
    required this.message,
    required this.mine,
    required this.open,
  });

  final ChatMessage message;
  final bool mine;
  final Future<({String text, List<int>? bytes, bool failed})> Function(ChatMessage) open;

  String _time() {
    final t = message.createdAt?.toLocal();
    if (t == null) return '';
    final h = t.hour.toString().padLeft(2, '0');
    final m = t.minute.toString().padLeft(2, '0');
    return '$h:$m';
  }

  @override
  Widget build(BuildContext context) {
    final bubbleColor = mine ? const Color(0xFF0D6EFD) : const Color(0xFF232947);
    final row = Align(
      alignment: mine ? AlignmentDirectional.centerEnd : AlignmentDirectional.centerStart,
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 3),
        padding: message.isImage ? EdgeInsets.zero : const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        constraints: BoxConstraints(maxWidth: MediaQuery.sizeOf(context).width * 0.78),
        decoration: message.isImage
            ? null
            : BoxDecoration(
                color: bubbleColor,
                borderRadius: BorderRadius.only(
                  topLeft: const Radius.circular(14),
                  topRight: const Radius.circular(14),
                  bottomRight: Radius.circular(mine ? 3 : 14),
                  bottomLeft: Radius.circular(mine ? 14 : 3),
                ),
              ),
        child: FutureBuilder<({String text, List<int>? bytes, bool failed})>(
          future: open(message),
          builder: (context, snap) {
            final data = snap.data;
            if (snap.connectionState != ConnectionState.done || data == null) {
              return const Padding(
                padding: EdgeInsets.all(10),
                child: SizedBox.square(dimension: 18, child: CircularProgressIndicator(strokeWidth: 2)),
              );
            }
            if (data.failed) {
              return Padding(
                padding: const EdgeInsets.all(10),
                child: Text(
                  '🔒',
                  style: TextStyle(color: mine ? Colors.white70 : Colors.white38),
                ),
              );
            }
            final content = <Widget>[
              if (data.bytes case final imgBytes?)
                ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: Image.memory(
                    Uint8List.fromList(imgBytes),
                    fit: BoxFit.cover,
                    gaplessPlayback: true,
                  ),
                ),
              if (data.text.isNotEmpty)
                Text(
                  data.text,
                  style: const TextStyle(color: Colors.white, fontSize: 14.5, height: 1.3),
                ),
              Padding(
                padding: const EdgeInsets.only(top: 2),
                child: Align(
                  alignment: AlignmentDirectional.centerEnd,
                  child: Text(
                    _time(),
                    style: TextStyle(color: mine ? Colors.white60 : Colors.white38, fontSize: 10),
                  ),
                ),
              ),
            ];
            return Column(crossAxisAlignment: CrossAxisAlignment.start, children: content);
          },
        ),
      ),
    );

    return row;
  }
}