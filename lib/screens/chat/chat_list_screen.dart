import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../app/theme.dart';
import '../../models/chat_models.dart';
import '../../providers/app_provider.dart';
import '../../security/app_security.dart';
import '../../services/chat_store.dart';
import 'chat_screen.dart';

/// Customer side: list of this account's support conversations plus the button
/// to ask for a NEW chat ("طلب محادثة"). When the user taps it, a `pending`
/// conversation is created on Firestore and the team approves it.
class ChatListScreen extends StatefulWidget {
  const ChatListScreen({super.key});

  @override
  State<ChatListScreen> createState() => _ChatListScreenState();
}

class _ChatListScreenState extends State<ChatListScreen> {
  bool _opening = false;
  String? _listFor;

  @override
  void initState() {
    super.initState();
    Future.microtask(() async {
      await ChatStore.ensureCustomerKey();
      final uid = await chatCustomerId();
      if (mounted) setState(() => _listFor = uid);
    });
  }

  Future<void> _startChat() async {
    if (_opening) return;
    setState(() => _opening = true);
    try {
      final prefs = await SharedPreferences.getInstance();
      var name = prefs.getString('goss-chat-name');
      if (name == null || AppSecurity.sanitizeText(name).isEmpty) {
        name = await _askName();
        if (name == null) return; // cancelled
        final safe = AppSecurity.sanitizeText(name);
        await prefs.setString('goss-chat-name', safe);
        name = safe;
      }
      final customerId = await chatCustomerId();
      final result = await ChatStore.createRequest(
        customerId: customerId,
        customerName: name,
      );
      if (!mounted) return;
      if (result.conversationId != null) {
        final conv = ChatConversation(
          id: result.conversationId!,
          customerId: customerId,
          customerName: name,
          participants: [customerId],
          ephPubB64: '',
          wrappedKeys: const {},
          wrapNonces: const {},
          wrapMacs: const {},
          status: ChatStatus.pending,
          lastSender: customerId,
        );
        Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) => ChatScreen(conversation: conv, role: 'customer'),
          ),
        );
      } else {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(result.failure ?? '')));
      }
    } finally {
      if (mounted) setState(() => _opening = false);
    }
  }

  Future<String?> _askName() {
    final ctrl = TextEditingController();
    final en = !context.read<AppProvider>().isArabic;
    return showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(en ? 'Your name' : 'اسمك'),
        content: TextField(
          controller: ctrl,
          autofocus: true,
          textInputAction: TextInputAction.done,
          decoration: InputDecoration(
            hintText: en ? 'e.g. Ahmed Co.' : 'مثال: شركة أحمد',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: Text(en ? 'Cancel' : 'إلغاء'),
          ),
          FilledButton(
            onPressed: () {
              final v = ctrl.text.trim();
              if (v.isEmpty) return;
              Navigator.of(context).pop(v);
            },
            child: Text(en ? 'Continue' : 'متابعة'),
          ),
        ],
      ),
    );
  }

  /// Moves the conversation lifecycle (open -> closed / closed -> open) from
  /// the list. Requires the participant rule on Firestore. Returns the snackbar
  /// on failure (an Arabic message from [ChatStore.setStatus]).
  Future<void> _setLifecycle(BuildContext context, ChatConversation c, ChatStatus s) async {
    final en = !context.read<AppProvider>().isArabic;
    final messenger = ScaffoldMessenger.of(context);
    final err = await ChatStore.setStatus(c.id, s);
    if (!mounted) return;
    messenger.showSnackBar(
      SnackBar(
        content: Text(
          err ??
              switch (s) {
                ChatStatus.closed => en ? 'Conversation closed' : 'أُغلقت المحادثة',
                ChatStatus.open => en ? 'Conversation reopened' : 'أُعيد فتح المحادثة',
                ChatStatus.pending => '',
              },
          textAlign: TextAlign.start,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final en = !context.watch<AppProvider>().isArabic;
    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(en ? 'Support chat' : 'شات خدمة العملاء'),
            Text(
              en ? 'End-to-end encrypted' : 'مشفّر بالكامل بين الطرفين',
              style: TextStyle(fontSize: 11, color: context.mutedColor),
            ),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _opening ? null : _startChat,
        icon: _opening
            ? const SizedBox.square(dimension: 18, child: CircularProgressIndicator(strokeWidth: 2))
            : const Icon(Icons.chat_bubble_outline),
        label: Text(en ? 'New conversation' : 'طلب محادثة جديدة'),
      ),
      body: StreamBuilder<List<ChatConversation>>(
        stream: ChatStore.conversations(onlyForUid: _listFor),
        builder: (context, snap) {
          if (snap.hasError) {
            return Center(child: Text(en ? 'Could not load chat' : 'تعذّر تحميل المحادثات'));
          }
          final items = snap.data ?? const <ChatConversation>[];
          if (items.isEmpty) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(32),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.forum_outlined, size: 56, color: context.mutedColor),
                    const SizedBox(height: 12),
                    Text(
                      en
                          ? 'No conversations yet.\nTap the button below to ask for support.'
                          : 'لا توجد محادثات بعد.\nاضغط الزر بالأسفل لطلب الدعم.',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: context.mutedColor),
                    ),
                  ],
                ),
              ),
            );
          }
          return ListView.separated(
            padding: const EdgeInsets.fromLTRB(12, 8, 12, 88),
            itemCount: items.length,
            separatorBuilder: (_, _) => const SizedBox(height: 8),
            itemBuilder: (context, i) {
              final c = items[i];
              return Card(
                margin: EdgeInsets.zero,
                elevation: 0.5,
                child: ListTile(
                  leading: const CircleAvatar(
                    child: Icon(Icons.headset_mic_outlined),
                  ),
                  title: Text(
                    c.status == ChatStatus.pending
                        ? en
                            ? 'Pending request'
                            : 'طلب محادثة قيد الانتظار'
                        : c.customerName.isEmpty
                            ? (en ? 'Support chat' : 'محادثة دعم')
                            : c.customerName,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  subtitle: Text(
                    c.lastSender == c.customerId
                        ? (en ? 'You sent a message' : 'أنت أرسلت رسالة')
                        : (en ? 'Support team' : 'فريق الدعم'),
                    maxLines: 1,
                    style: TextStyle(color: context.mutedColor, fontSize: 12.5),
                  ),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      _StatusChip(status: c.status, en: en),
                      PopupMenuButton<String>(
                        tooltip: en ? 'Actions' : 'إجراءات',
                        onSelected: (v) {
                          switch (v) {
                            case 'close':
                              _setLifecycle(context, c, ChatStatus.closed);
                            case 'reopen':
                              _setLifecycle(context, c, ChatStatus.open);
                          }
                        },
                        itemBuilder: (context) => [
                          if (c.status == ChatStatus.pending)
                            PopupMenuItem(
                              value: 'close',
                              child: Text(en ? 'Cancel request' : 'إلغاء الطلب'),
                            ),
                          if (c.status == ChatStatus.open)
                            PopupMenuItem(
                              value: 'close',
                              child: Text(en ? 'Close conversation' : 'إغلاق المحادثة'),
                            ),
                          if (c.status == ChatStatus.closed)
                            PopupMenuItem(
                              value: 'reopen',
                              child: Text(en ? 'Reopen conversation' : 'إعادة فتح المحادثة'),
                            ),
                        ],
                      ),
                    ],
                  ),
                  onTap: () {
                    Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => ChatScreen(conversation: c, role: 'customer'),
                      ),
                    );
                  },
                ),
              );
            },
          );
        },
      ),
    );
  }
}

class _StatusChip extends StatelessWidget {
  const _StatusChip({required this.status, required this.en});

  final ChatStatus status;
  final bool en;

  @override
  Widget build(BuildContext context) {
    final (color, label) = switch (status) {
      ChatStatus.pending => (GossColors.amber, en ? 'Pending' : 'قيد الانتظار'),
      ChatStatus.open => (const Color(0xFF2E9E5B), en ? 'Open' : 'مفتوحة'),
      ChatStatus.closed => (context.mutedColor, en ? 'Closed' : 'مغلقة'),
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(label, style: TextStyle(color: color, fontSize: 11.5, fontWeight: FontWeight.w700)),
    );
  }
}