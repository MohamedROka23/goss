import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../app/theme.dart';
import '../../models/chat_models.dart';
import '../../providers/app_provider.dart';
import '../../services/chat_store.dart';
import '../chat/chat_screen.dart';

/// Unified support inbox (صندوق الدعم): every team member with the `chat`
/// permission sees all customer conversations, approves the pending requests
/// and answers them. Fully backed by Firestore + E2E encryption.
class AdminChatTab extends StatefulWidget {
  const AdminChatTab({super.key});

  @override
  State<AdminChatTab> createState() => _AdminChatTabState();
}

class _AdminChatTabState extends State<AdminChatTab> {
  @override
  void initState() {
    super.initState();
    // Make sure THIS device's public key is enrolled so it can decrypt the
    // conversations sealed to the team.
    Future.microtask(() => ChatStore.ensureStaffKey());
  }

  @override
  Widget build(BuildContext context) {
    final en = !context.watch<AppProvider>().isArabic;
    return StreamBuilder<List<ChatConversation>>(
      stream: ChatStore.conversations(),
      builder: (context, snap) {
        final conversations = snap.data ?? const <ChatConversation>[];
        if (snap.hasError) {
          return Center(child: Text(en ? 'Could not load support chat' : 'تعذّر تحميل شات الدعم'));
        }

        final pending = conversations.where((c) => c.status == ChatStatus.pending).toList();
        final active = conversations.where((c) => c.status == ChatStatus.open).toList();
        final closed = conversations.where((c) => c.status == ChatStatus.closed).toList();

        if (conversations.isEmpty) {
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
                        ? 'No customer conversations yet.\nThey appear here when a customer asks for chat support.'
                        : 'لا توجد محادثات من العملاء بعد.\nتظهر هنا عندما يطلب العميل محادثة دعم.',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: context.mutedColor),
                  ),
                ],
              ),
            ),
          );
        }

        final sections = <(String, List<ChatConversation>)>[
          (en ? 'Pending requests' : 'طلبات بانتظار الموافقة', pending),
          (en ? 'Open' : 'مفتوحة', active),
          (en ? 'Closed' : 'مغلقة', closed),
        ];

        return ListView(
          padding: const EdgeInsets.all(12),
          children: [
            for (final section in sections)
              if (section.$2.isNotEmpty) ...[
                Padding(
                  padding: const EdgeInsets.fromLTRB(4, 4, 4, 8),
                  child: Text(
                    section.$1,
                    style: TextStyle(
                      fontWeight: FontWeight.w800,
                      fontSize: 13,
                      color: context.mutedColor,
                    ),
                  ),
                ),
                for (final c in section.$2) _ChatRow(conversation: c),
                const SizedBox(height: 12),
              ],
          ],
        );
      },
    );
  }
}

class _ChatRow extends StatelessWidget {
  const _ChatRow({required this.conversation});

  final ChatConversation conversation;

  @override
  Widget build(BuildContext context) {
    final en = !context.watch<AppProvider>().isArabic;
    final pending = conversation.status == ChatStatus.pending;
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      elevation: 0.5,
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: pending ? GossColors.amber : Theme.of(context).colorScheme.primary,
          child: const Icon(Icons.headset_mic_outlined, color: Colors.white, size: 20),
        ),
        title: Text(
          conversation.customerName.isEmpty ? (en ? 'Customer' : 'عميل') : conversation.customerName,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(fontWeight: pending ? FontWeight.w800 : FontWeight.w600),
        ),
        subtitle: Text(
          en ? 'Tap to read the encrypted chat' : 'اضغط لفتح المحادثة المشفّرة',
          style: TextStyle(color: context.mutedColor, fontSize: 12),
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (pending)
              IconButton(
                tooltip: en ? 'Accept request' : 'موافقة على الطلب',
                icon: const Icon(Icons.check_circle_outline, color: Color(0xFF2E9E5B)),
                onPressed: () => _run(context, () => ChatStore.approve(conversation.id)),
              ),
            PopupMenuButton<String>(
              tooltip: en ? 'Actions' : 'إجراءات',
              onSelected: (v) {
                switch (v) {
                  case 'approve':
                    _run(context, () => ChatStore.approve(conversation.id));
                  case 'close':
                    _run(context, () => ChatStore.close(conversation.id));
                  case 'reopen':
                    _run(context, () => ChatStore.setStatus(conversation.id, ChatStatus.open));
                  case 'delete':
                    _confirmDelete(context);
                }
              },
              itemBuilder: (context) => [
                if (pending)
                  PopupMenuItem(
                    value: 'approve',
                    child: Text(en ? 'Accept request' : 'موافقة على الطلب'),
                  ),
                if (conversation.status == ChatStatus.open)
                  PopupMenuItem(
                    value: 'close',
                    child: Text(en ? 'Close conversation' : 'إغلاق المحادثة'),
                  ),
                if (conversation.status == ChatStatus.closed)
                  PopupMenuItem(
                    value: 'reopen',
                    child: Text(en ? 'Reopen conversation' : 'إعادة فتح المحادثة'),
                  ),
                if (!pending)
                  const PopupMenuDivider(),
                PopupMenuItem(
                  value: 'delete',
                  child: Text(
                    en ? 'Delete conversation' : 'حذف المحادثة',
                    style: TextStyle(color: GossColors.red),
                  ),
                ),
              ],
            ),
            const Icon(Icons.chevron_right, color: Colors.white24),
          ],
        ),
        onTap: () {
          Navigator.of(context).push(
            MaterialPageRoute(
              builder: (_) => ChatScreen(conversation: conversation, role: 'admin'),
            ),
          );
        },
      ),
    );
  }

  /// Runs a status change; surfaces the (Arabic) failure as a snack bar.
  Future<void> _run(BuildContext context, Future<String?> Function() action) async {
    final messenger = ScaffoldMessenger.of(context);
    final err = await action();
    if (err != null) {
      messenger.showSnackBar(SnackBar(content: Text(err, textAlign: TextAlign.start)));
    }
  }

  Future<void> _confirmDelete(BuildContext context) async {
    final en = !context.watch<AppProvider>().isArabic;
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(en ? 'Delete this conversation?' : 'حذف هذه المحادثة؟'),
        content: Text(
          en
              ? 'This permanently removes the conversation and all of its messages. This cannot be undone.'
              : 'سيتم حذف المحادثة وكل رسائلها نهائيًا. لا يمكن التراجع عن هذه العملية.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: Text(en ? 'Cancel' : 'إلغاء'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: GossColors.red),
            onPressed: () => Navigator.of(context).pop(true),
            child: Text(en ? 'Delete' : 'حذف'),
          ),
        ],
      ),
    );
    if (ok != true || !context.mounted) return;
    final messenger = ScaffoldMessenger.of(context);
    final err = await ChatStore.deleteConversation(conversation.id);
    if (context.mounted) {
      messenger.showSnackBar(
        SnackBar(
          content: Text(
            err ?? (en ? 'Conversation deleted' : 'تم حذف المحادثة'),
            textAlign: TextAlign.start,
          ),
        ),
      );
    }
  }
}