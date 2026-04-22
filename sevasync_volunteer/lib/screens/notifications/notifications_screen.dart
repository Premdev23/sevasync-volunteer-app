import 'package:flutter/material.dart';
import '../../../theme/app_theme.dart';
import '../../../widgets/widgets.dart';
import '../../../models/models.dart';
import '../../../services/volunteer_service.dart';

class NotificationsScreen extends StatefulWidget {
  const NotificationsScreen({super.key});
  @override
  State<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends State<NotificationsScreen> {
  bool    _loading = true;
  String? _error;
  bool    _showUnreadOnly = false;
  List<NotificationItem> _all = [];

  List<NotificationItem> get _visible =>
      _showUnreadOnly ? _all.where((n) => !n.isRead).toList() : _all;
  int get _unreadCount => _all.where((n) => !n.isRead).length;

  @override
  void initState() { super.initState(); _load(); }

  Future<void> _load() async {
    setState(() { _loading = true; _error = null; });
    try {
      final notifs = await VolunteerService.getNotifications();
      if (mounted) setState(() => _all = notifs);
    } catch (e) {
      if (mounted) setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _markAllRead() async {
    try {
      await VolunteerService.markAllRead();
      setState(() => _all = _all.map((n) => n.markRead()).toList());
    } catch (_) {}
  }

  Future<void> _markRead(NotificationItem n) async {
    if (n.isRead) return;
    try {
      await VolunteerService.markNotificationRead(n.id);
      setState(() => _all = _all.map((x) => x.id == n.id ? x.markRead() : x).toList());
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
          const Text('Notifications', style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800)),
          Row(children: [
            Text('$_unreadCount unread · Live updates enabled',
                style: const TextStyle(fontSize: 11, color: AppColors.textSecondary)),
            const SizedBox(width: 6),
            Container(width: 6, height: 6,
                decoration: const BoxDecoration(color: AppColors.green, shape: BoxShape.circle)),
            const SizedBox(width: 3),
            const Text('Live', style: TextStyle(fontSize: 11, color: AppColors.green, fontWeight: FontWeight.w600)),
          ]),
        ]),
        actions: [
          if (!_loading && _unreadCount > 0)
            TextButton(onPressed: _markAllRead,
                child: const Text('Mark all read', style: TextStyle(color: AppColors.teal, fontSize: 12))),
          IconButton(onPressed: _load, icon: const Icon(Icons.refresh, size: 20, color: AppColors.textSecondary)),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator(color: AppColors.teal))
          : _error != null
              ? ErrorRetry(title: 'Could not load notifications', message: _error, onRetry: _load)
              : Column(children: [
                  // Unread filter bar
                  if (_all.isNotEmpty) Container(
                    color: AppColors.surface,
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    child: Row(children: [
                      GestureDetector(
                        onTap: () => setState(() => _showUnreadOnly = false),
                        child: Container(padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                          decoration: BoxDecoration(
                            color: !_showUnreadOnly ? AppColors.teal : AppColors.surface2,
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(color: !_showUnreadOnly ? AppColors.teal : AppColors.border)),
                          child: Text('All (${_all.length})',
                              style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600,
                                  color: !_showUnreadOnly ? Colors.white : AppColors.textSecondary)))),
                      const SizedBox(width: 8),
                      GestureDetector(
                        onTap: () => setState(() => _showUnreadOnly = true),
                        child: Container(padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                          decoration: BoxDecoration(
                            color: _showUnreadOnly ? AppColors.teal : AppColors.surface2,
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(color: _showUnreadOnly ? AppColors.teal : AppColors.border)),
                          child: Text('Unread ($_unreadCount)',
                              style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600,
                                  color: _showUnreadOnly ? Colors.white : AppColors.textSecondary)))),
                    ]),
                  ),
                  if (_all.isNotEmpty) const Divider(height: 0),

                  Expanded(child: _visible.isEmpty
                      ? Center(child: Padding(padding: const EdgeInsets.all(24),
                          child: Column(mainAxisSize: MainAxisSize.min, children: [
                            Container(padding: const EdgeInsets.all(20),
                              decoration: BoxDecoration(color: AppColors.orangeLight, shape: BoxShape.circle),
                              child: const Icon(Icons.notifications_outlined, color: AppColors.orange, size: 44)),
                            const SizedBox(height: 16),
                            const Text('All clear!', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: AppColors.textPrimary)),
                            const SizedBox(height: 8),
                            const Text(
                              'No notifications yet. New task assignments and updates will appear here in real-time.',
                              textAlign: TextAlign.center,
                              style: TextStyle(color: AppColors.textSecondary, fontSize: 13, height: 1.5)),
                          ])))
                      : RefreshIndicator(onRefresh: _load, color: AppColors.teal,
                          child: ListView.separated(
                            padding: const EdgeInsets.symmetric(vertical: 8),
                            itemCount: _visible.length,
                            separatorBuilder: (_, __) => const Divider(height: 0, indent: 68),
                            itemBuilder: (_, i) => NotifTile(
                                notif: _visible[i], onTap: () => _markRead(_visible[i])),
                          ))),
                ]),
    );
  }
}
