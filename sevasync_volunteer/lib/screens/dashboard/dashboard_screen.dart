import 'package:flutter/material.dart';
import '../../../theme/app_theme.dart';
import '../../../widgets/widgets.dart';
import '../../../models/models.dart';
import '../../../services/volunteer_service.dart';

class DashboardScreen extends StatefulWidget {
  final Function(int)? onNavigate;
  const DashboardScreen({super.key, this.onNavigate});
  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  bool _loading = true;
  VolunteerProfile?      _profile;
  List<VolunteerTask>    _tasks  = [];
  List<NotificationItem> _notifs = [];
  DashboardStats         _stats  = DashboardStats.empty;

  @override
  void initState() { super.initState(); _load(); }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final results = await Future.wait([
        VolunteerService.getProfile(),
        VolunteerService.getTasks(),
        VolunteerService.getNotifications(),
        VolunteerService.getDashboardStats(),
      ]);
      if (!mounted) return;
      setState(() {
        _profile = results[0] as VolunteerProfile;
        _tasks   = (results[1] as List<VolunteerTask>).take(3).toList();
        _notifs  = (results[2] as List<NotificationItem>).take(4).toList();
        _stats   = results[3] as DashboardStats;
      });
    } catch (_) {}
    finally { if (mounted) setState(() => _loading = false); }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        leadingWidth: 64,
        leading: Padding(
          padding: const EdgeInsets.all(6),
          // Bigger logo
          child: Image.asset('assets/images/logo.jpeg', fit: BoxFit.contain)),
        title: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
          RichText(text: const TextSpan(children: [
            TextSpan(text: 'Volunteer ', style: TextStyle(fontSize: 16,
                fontWeight: FontWeight.w800, color: AppColors.textPrimary)),
            TextSpan(text: 'Dashboard', style: TextStyle(fontSize: 16,
                fontWeight: FontWeight.w800, color: AppColors.teal)),
          ])),
          Text('Welcome, ${_profile?.name ?? 'Volunteer'}!',
              style: const TextStyle(fontSize: 11, color: AppColors.textSecondary)),
        ]),
        actions: [
          Container(margin: const EdgeInsets.symmetric(vertical: 10),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
            decoration: BoxDecoration(color: AppColors.greenLight,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: AppColors.green.withOpacity(0.4))),
            child: Row(mainAxisSize: MainAxisSize.min, children: [
              Container(width: 7, height: 7,
                  decoration: const BoxDecoration(color: AppColors.green, shape: BoxShape.circle)),
              const SizedBox(width: 5),
              const Text('active', style: TextStyle(color: AppColors.green,
                  fontSize: 12, fontWeight: FontWeight.w700)),
            ])),
          TextButton.icon(onPressed: _load,
            icon: const Icon(Icons.refresh, size: 14, color: AppColors.teal),
            label: const Text('Refresh', style: TextStyle(color: AppColors.teal, fontSize: 12))),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator(color: AppColors.teal))
          : RefreshIndicator(color: AppColors.teal, onRefresh: _load,
              child: SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.all(16),
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  // Welcome banner
                  Container(width: double.infinity, padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(color: AppColors.tealLight,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: AppColors.teal.withOpacity(0.2))),
                    child: Text(
                      'Welcome back, ${_profile?.name ?? 'Volunteer'} · You have ${_stats.active} active tasks',
                      style: const TextStyle(color: AppColors.teal, fontSize: 13))),
                  const SizedBox(height: 20),

                  const Text('My Dashboard', style: TextStyle(fontSize: 22,
                      fontWeight: FontWeight.w800, color: AppColors.textPrimary)),
                  const SizedBox(height: 14),

                  GridView.count(crossAxisCount: 2, shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    crossAxisSpacing: 14, mainAxisSpacing: 14, childAspectRatio: 1.6,
                    children: [
                      StatCard(label: 'COMPLETED', value: '${_stats.completed}',
                          icon: Icons.check_box_outlined, iconColor: AppColors.green,
                          bgColor: AppColors.greenLight),
                      StatCard(label: 'ACTIVE', value: '${_stats.active}',
                          icon: Icons.run_circle_outlined, iconColor: AppColors.orange,
                          bgColor: AppColors.orangeLight),
                      StatCard(label: 'NOTIFICATIONS', value: '${_stats.unreadNotifications}',
                          icon: Icons.notifications_outlined, iconColor: AppColors.teal,
                          bgColor: AppColors.tealLight),
                      StatCard(label: 'TOTAL TASKS', value: '${_stats.total}',
                          icon: Icons.assignment_outlined, iconColor: AppColors.textSecondary),
                    ]),
                  const SizedBox(height: 28),

                  LayoutBuilder(builder: (ctx, constraints) {
                    final wide = constraints.maxWidth > 700;
                    if (wide) {
                      return Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Expanded(child: _tasksSection()),
                        const SizedBox(width: 20),
                        Expanded(child: Column(children: [
                          _notifSection(), const SizedBox(height: 20),
                          if (_profile != null) _profileCard(),
                          const SizedBox(height: 20),
                          _quickActionsCard(),
                        ])),
                      ]);
                    }
                    return Column(children: [
                      _tasksSection(), const SizedBox(height: 24),
                      _notifSection(), const SizedBox(height: 24),
                      if (_profile != null) _profileCard(), const SizedBox(height: 24),
                      _quickActionsCard(),
                    ]);
                  }),
                ]))),
    );
  }

  Widget _tasksSection() {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
        const Text('My Tasks', style: TextStyle(fontSize: 17,
            fontWeight: FontWeight.w800, color: AppColors.textPrimary)),
        TextButton(onPressed: () => widget.onNavigate?.call(1),
            child: const Text('View all →', style: TextStyle(color: AppColors.teal, fontSize: 12))),
      ]),
      const SizedBox(height: 10),
      if (_tasks.isEmpty)
        Container(width: double.infinity, padding: const EdgeInsets.all(40),
          decoration: BoxDecoration(color: AppColors.surface,
              borderRadius: BorderRadius.circular(14), border: Border.all(color: AppColors.border)),
          child: const Column(children: [
            Icon(Icons.assignment_outlined, size: 40, color: AppColors.textSecondary),
            SizedBox(height: 10),
            Text('No tasks assigned yet. Your admin will assign tasks soon!',
                textAlign: TextAlign.center,
                style: TextStyle(color: AppColors.textSecondary, fontSize: 13)),
          ]))
      else
        Column(children: _tasks.map((t) => Padding(
          padding: const EdgeInsets.only(bottom: 10),
          child: TaskCard(task: t, onStatusUpdate: _load))).toList()),
    ]);
  }

  Widget _notifSection() {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
        const Text('Notifications', style: TextStyle(fontSize: 17,
            fontWeight: FontWeight.w800, color: AppColors.textPrimary)),
        Container(padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
          decoration: BoxDecoration(color: AppColors.tealLight, borderRadius: BorderRadius.circular(20)),
          child: Text('${_stats.unreadNotifications} new',
              style: const TextStyle(color: AppColors.teal, fontSize: 11, fontWeight: FontWeight.w700))),
      ]),
      const SizedBox(height: 10),
      Container(
        decoration: BoxDecoration(color: AppColors.surface, borderRadius: BorderRadius.circular(14),
            border: Border.all(color: AppColors.border)),
        child: _notifs.isEmpty
            ? const Padding(padding: EdgeInsets.all(24),
                child: Center(child: Text('No notifications',
                    style: TextStyle(color: AppColors.textSecondary, fontSize: 13))))
            : Column(children: [
                for (int i = 0; i < _notifs.length; i++) ...[
                  NotifTile(notif: _notifs[i]),
                  if (i < _notifs.length - 1) const Divider(height: 0, indent: 68),
                ],
              ]),
      ),
    ]);
  }

  Widget _profileCard() {
    final p = _profile!;
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      const Text('My Profile', style: TextStyle(fontSize: 17,
          fontWeight: FontWeight.w800, color: AppColors.textPrimary)),
      const SizedBox(height: 10),
      Container(padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(color: AppColors.surface, borderRadius: BorderRadius.circular(14),
            border: Border.all(color: AppColors.border)),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            GradientAvatar(initials: p.initials, imageUrl: p.avatarUrl, radius: 24),
            const SizedBox(width: 12),
            Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(p.name, style: const TextStyle(fontWeight: FontWeight.w700,
                  fontSize: 15, color: AppColors.textPrimary)),
              Text('${_cap(p.role)} · ${p.region ?? ''}',
                  style: const TextStyle(color: AppColors.textSecondary, fontSize: 12)),
            ]),
          ]),
          if (p.skills.isNotEmpty) ...[
            const SizedBox(height: 12),
            const Text('Skills:', style: TextStyle(color: AppColors.textSecondary,
                fontSize: 11, fontWeight: FontWeight.w600)),
            const SizedBox(height: 6),
            Wrap(spacing: 6, runSpacing: 6, children: p.skills.map((s) => Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(color: AppColors.tealLight,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: AppColors.teal.withOpacity(0.3))),
              child: Text(s, style: const TextStyle(fontSize: 11, color: AppColors.teal,
                  fontWeight: FontWeight.w600)))).toList()),
          ],
        ])),
    ]);
  }

  Widget _quickActionsCard() {
    // index: 0=Dashboard,1=Tasks,2=Alerts,3=Messages,4=Profile,5=History
    final actions = [
      ('View all my tasks',       Icons.assignment_outlined,   AppColors.teal,   1),
      ('Task history',            Icons.history,                AppColors.orange, 5),
      ('Update profile & skills', Icons.person_outline,         AppColors.green,  4),
      ('Notifications',           Icons.notifications_outlined, AppColors.teal,   2),
    ];

    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      const Text('Quick Actions', style: TextStyle(fontSize: 17,
          fontWeight: FontWeight.w800, color: AppColors.textPrimary)),
      const SizedBox(height: 10),
      Container(
        decoration: BoxDecoration(color: AppColors.surface, borderRadius: BorderRadius.circular(14),
            border: Border.all(color: AppColors.border)),
        child: Column(children: actions.asMap().entries.map((e) {
          final i = e.key; final a = e.value;
          return Column(children: [
            ListTile(
              leading: Icon(a.$2, color: a.$3, size: 20),
              title: Text(a.$1, style: const TextStyle(fontSize: 13, color: AppColors.textPrimary)),
              trailing: const Icon(Icons.arrow_forward, color: AppColors.textSecondary, size: 16),
              // ✅ Navigate to the correct tab on tap
              onTap: () => widget.onNavigate?.call(a.$4),
            ),
            if (i < actions.length - 1) const Divider(height: 0, indent: 52),
          ]);
        }).toList()),
      ),
    ]);
  }

  String _cap(String s) => s.isNotEmpty ? '${s[0].toUpperCase()}${s.substring(1)}' : s;
}
