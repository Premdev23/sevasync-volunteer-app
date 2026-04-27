import 'package:flutter/material.dart';
import 'theme/app_theme.dart';
import 'screens/dashboard/dashboard_screen.dart';
import 'screens/tasks/tasks_screen.dart';
import 'screens/notifications/notifications_screen.dart';
import 'screens/messages/messages_screen.dart';
import 'screens/profile/profile_screen.dart';
import 'screens/history/task_history_screen.dart';
import 'services/volunteer_service.dart';

class MainShell extends StatefulWidget {
  const MainShell({super.key});
  @override
  State<MainShell> createState() => _MainShellState();
}

class _MainShellState extends State<MainShell> {
  int  _index     = 0;
  int  _taskBadge = 0;
  int  _notifBadge = 0;
  int  _msgBadge  = 0;
  bool _polling   = true;

  void _navigateTo(int index) => setState(() => _index = index);

  @override
  void initState() { super.initState(); _startPolling(); }

  @override
  void dispose() { _polling = false; super.dispose(); }

  Future<void> _startPolling() async {
    while (_polling && mounted) {
      try {
        final stats  = await VolunteerService.getDashboardStats();
        final convos = await VolunteerService.getConversations();
        final msgUnread = convos.fold(0, (s, c) => s + c.unreadCount);
        if (mounted) setState(() {
          _taskBadge  = stats.active;
          _notifBadge = stats.unreadNotifications;
          _msgBadge   = msgUnread;
        });
      } catch (_) {}
      await Future.delayed(const Duration(seconds: 15));
    }
  }

  @override
  Widget build(BuildContext context) {
    // Pass navigation callback to Dashboard; rebuild screens each time
    // so callback is always fresh (screens are lightweight, IndexedStack caches render)
    final screens = [
      DashboardScreen(onNavigate: _navigateTo),
      const TasksScreen(),
      const NotificationsScreen(),
      const MessagesScreen(),
      const ProfileScreen(),
      const TaskHistoryScreen(),
    ];

    return Scaffold(
      body: IndexedStack(index: _index, children: screens),
      bottomNavigationBar: Container(
        decoration: const BoxDecoration(
            border: Border(top: BorderSide(color: AppColors.border))),
        child: BottomNavigationBar(
          currentIndex: _index,
          onTap: (i) async {
            setState(() => _index = i);
            // Refresh message badge immediately when tapping Messages tab
            if (i == 3) {
              await Future.delayed(const Duration(milliseconds: 800));
              if (mounted) {
                try {
                  final convos = await VolunteerService.getConversations();
                  final unread = convos.fold(0, (s, c) => s + c.unreadCount);
                  if (mounted) setState(() => _msgBadge = unread);
                } catch (_) {}
              }
            }
          },
          items: [
            const BottomNavigationBarItem(
              icon: Icon(Icons.dashboard_outlined), activeIcon: Icon(Icons.dashboard),
              label: 'Dashboard'),
            BottomNavigationBarItem(
              icon: _BadgeIcon(icon: Icons.task_outlined, count: _taskBadge),
              activeIcon: _BadgeIcon(icon: Icons.task, count: _taskBadge),
              label: 'My Tasks'),
            BottomNavigationBarItem(
              icon: _BadgeIcon(icon: Icons.notifications_outlined, count: _notifBadge),
              activeIcon: _BadgeIcon(icon: Icons.notifications, count: _notifBadge),
              label: 'Alerts'),
            BottomNavigationBarItem(
              icon: _BadgeIcon(icon: Icons.chat_bubble_outline, count: _msgBadge),
              activeIcon: _BadgeIcon(icon: Icons.chat_bubble, count: _msgBadge),
              label: 'Messages'),
            const BottomNavigationBarItem(
              icon: Icon(Icons.person_outline), activeIcon: Icon(Icons.person),
              label: 'Profile'),
            const BottomNavigationBarItem(
              icon: Icon(Icons.history_outlined), activeIcon: Icon(Icons.history),
              label: 'History'),
          ],
        ),
      ),
    );
  }
}

class _BadgeIcon extends StatelessWidget {
  final IconData icon;
  final int count;
  const _BadgeIcon({required this.icon, required this.count});
  @override
  Widget build(BuildContext context) {
    return Stack(clipBehavior: Clip.none, children: [
      Icon(icon),
      if (count > 0) Positioned(right: -6, top: -4,
        child: Container(
          padding: const EdgeInsets.all(3),
          constraints: const BoxConstraints(minWidth: 16, minHeight: 16),
          decoration: const BoxDecoration(color: AppColors.teal, shape: BoxShape.circle),
          child: Text(count > 9 ? '9+' : '$count',
              style: const TextStyle(color: Colors.white, fontSize: 9, fontWeight: FontWeight.w700),
              textAlign: TextAlign.center))),
    ]);
  }
}
