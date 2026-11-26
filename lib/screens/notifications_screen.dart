import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../models/app_notification.dart';
import '../providers/notification_provider.dart';
import '../widgets/ui_kit.dart';

class NotificationsScreen extends StatefulWidget {
  const NotificationsScreen({super.key});

  @override
  State<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends State<NotificationsScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => context.read<NotificationProvider>().load());
  }

  IconData _icon(AppNotification n) => switch (n.kind) {
        'request.accepted' => Icons.check_circle_outline,
        'request.declined' || 'request.cancelled_by_store' || 'request.expired' => Icons.cancel_outlined,
        'request.message' => Icons.chat_bubble_outline,
        _ => Icons.notifications_none,
      };

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<NotificationProvider>();
    final theme = Theme.of(context);
    final items = provider.items;
    return Scaffold(
      appBar: AppBar(
        title: const Text('Notifikasi'),
        actions: [
          if (provider.unreadCount > 0)
            TextButton(onPressed: provider.markAllRead, child: const Text('Tandai dibaca')),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: provider.load,
        child: items.isEmpty
            ? ListView(
                children: [
                  const SizedBox(height: 60),
                  provider.isLoading
                      ? const Center(child: CircularProgressIndicator())
                      : const EmptyState(
                          icon: Icons.notifications_none_rounded,
                          title: 'Belum ada notifikasi',
                          message: 'Kabar dari toko tentang permintaan sewamu akan muncul di sini.',
                        ),
                ],
              )
            : ListView.separated(
                itemCount: items.length,
                separatorBuilder: (_, _) => const Divider(height: 1),
                itemBuilder: (context, i) {
                  final n = items[i];
                  return ListTile(
                    tileColor: n.isRead ? null : theme.colorScheme.primary.withValues(alpha: 0.05),
                    leading: CircleAvatar(
                      backgroundColor: (n.isRead ? theme.colorScheme.onSurfaceVariant : theme.colorScheme.primary)
                          .withValues(alpha: 0.12),
                      child: Icon(_icon(n),
                          size: 20, color: n.isRead ? theme.colorScheme.onSurfaceVariant : theme.colorScheme.primary),
                    ),
                    title: Text(n.title, style: TextStyle(fontWeight: n.isRead ? FontWeight.normal : FontWeight.bold)),
                    subtitle: Text(
                      [if (n.body != null && n.body!.isNotEmpty) n.body!, DateFormat('d MMM HH:mm', 'id_ID').format(n.createdAt.toLocal())]
                          .join('\n'),
                    ),
                    isThreeLine: n.body != null && n.body!.isNotEmpty,
                    onTap: () {
                      provider.markRead(n);
                      final route = n.route;
                      if (route != null) context.push(route);
                    },
                  );
                },
              ),
      ),
    );
  }
}
