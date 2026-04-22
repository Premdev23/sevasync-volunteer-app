import 'package:flutter/material.dart';
import '../../../theme/app_theme.dart';
import '../../../models/models.dart';
import '../../../services/volunteer_service.dart';
import '../../../widgets/widgets.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});
  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  bool    _loading = true;
  String? _error;
  VolunteerProfile? _profile;
  int _tasksCompleted = 0;
  int _tasksActive    = 0;

  // Weekly availability – days with checkmark (hardcoded like web for now)
  final List<bool> _availability = [true, true, false, true, true, false, true]; // Mon–Sun

  @override
  void initState() { super.initState(); _load(); }

  Future<void> _load() async {
    setState(() { _loading = true; _error = null; });
    try {
      final results = await Future.wait([
        VolunteerService.getProfile(),
        VolunteerService.getDashboardStats(),
      ]);
      if (!mounted) return;
      final stats = results[1] as DashboardStats;
      setState(() {
        _profile        = results[0] as VolunteerProfile;
        _tasksCompleted = stats.completed;
        _tasksActive    = stats.active;
      });
    } catch (e) {
      if (mounted) setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _toggleActive() async {
    final p = _profile; if (p == null) return;
    try {
      await VolunteerService.setStatus(p.isActive ? 'inactive' : 'active');
      setState(() => _profile = p.copyWith(status: p.isActive ? 'inactive' : 'active'));
    } catch (_) {}
  }

  Future<void> _signOut() async {
    final ok = await showDialog<bool>(context: context,
      builder: (_) => AlertDialog(
        backgroundColor: AppColors.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Sign Out'),
        content: const Text('Are you sure you want to sign out?',
            style: TextStyle(color: AppColors.textSecondary)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.error, foregroundColor: Colors.white),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Sign Out')),
        ]));
    if (ok == true) await VolunteerService.signOut();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
          const Text('My Profile', style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800)),
          const Text('Manage your personal information and availability',
              style: TextStyle(fontSize: 11, color: AppColors.textSecondary)),
        ]),
        actions: [
          Container(margin: const EdgeInsets.symmetric(vertical: 10, horizontal: 8),
            child: ElevatedButton.icon(
              onPressed: () {},
              icon: const Icon(Icons.edit, size: 14),
              label: const Text('Edit Profile', style: TextStyle(fontSize: 12)),
              style: ElevatedButton.styleFrom(minimumSize: Size.zero,
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8)),
            )),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator(color: AppColors.teal))
          : _error != null || _profile == null
              ? _buildError()
              : RefreshIndicator(onRefresh: _load, color: AppColors.teal,
                  child: LayoutBuilder(builder: (ctx, constraints) {
                    if (constraints.maxWidth > 650) {
                      return SingleChildScrollView(padding: const EdgeInsets.all(20),
                        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                          Expanded(flex: 3, child: Column(children: [
                            _avatarCard(), const SizedBox(height: 16), _personalInfoCard()])),
                          const SizedBox(width: 16),
                          Expanded(flex: 2, child: Column(children: [
                            _skillsCard(), const SizedBox(height: 16),
                            _availabilityCard(), const SizedBox(height: 16),
                            _accountInfoCard(), const SizedBox(height: 16),
                            _signOutButton(),
                          ])),
                        ]));
                    }
                    return SingleChildScrollView(padding: const EdgeInsets.all(16),
                      child: Column(children: [
                        _avatarCard(), const SizedBox(height: 14),
                        _skillsCard(), const SizedBox(height: 14),
                        _availabilityCard(), const SizedBox(height: 14),
                        _personalInfoCard(), const SizedBox(height: 14),
                        _accountInfoCard(), const SizedBox(height: 14),
                        _signOutButton(),
                      ]));
                  })),
    );
  }

  // ── Avatar card (like web: centered avatar, name, role, active pill) ───────
  Widget _avatarCard() {
    final p = _profile!;
    return _card(child: Column(children: [
      CircleAvatar(radius: 38, backgroundColor: AppColors.teal,
        child: Text(p.initials,
            style: const TextStyle(fontSize: 26, fontWeight: FontWeight.w800, color: Colors.white))),
      const SizedBox(height: 12),
      Text(p.name, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: AppColors.textPrimary)),
      const SizedBox(height: 4),
      Text('${_cap(p.role)} · ${p.region ?? 'Unknown Region'}',
          style: const TextStyle(color: AppColors.textSecondary, fontSize: 13)),
      const SizedBox(height: 12),
      GestureDetector(onTap: _toggleActive,
        child: Container(padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
          decoration: BoxDecoration(
            color: p.isActive ? AppColors.greenLight : AppColors.surface2,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: p.isActive ? AppColors.green.withOpacity(0.4) : AppColors.border)),
          child: Row(mainAxisSize: MainAxisSize.min, children: [
            Container(width: 8, height: 8, margin: const EdgeInsets.only(right: 6),
                decoration: BoxDecoration(
                    color: p.isActive ? AppColors.green : AppColors.textSecondary, shape: BoxShape.circle)),
            Text(p.isActive ? 'active' : 'unavailable',
                style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700,
                    color: p.isActive ? AppColors.green : AppColors.textSecondary)),
          ]))),
    ]));
  }

  // ── Personal information form (read-only display) ─────────────────────────
  Widget _personalInfoCard() {
    final p = _profile!;
    return _card(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      const Text('Personal Information', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700)),
      const SizedBox(height: 16),
      _formField('Full Name',    p.name),
      const SizedBox(height: 12),
      _formField('Email',        p.email ?? ''),
      const SizedBox(height: 12),
      _formField('Phone',        ''),
      const SizedBox(height: 12),
      _formField('Region / Area', p.region ?? ''),
    ]));
  }

  Widget _formField(String label, String value) {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text(label, style: const TextStyle(fontSize: 12, color: AppColors.textSecondary, fontWeight: FontWeight.w600)),
      const SizedBox(height: 6),
      Container(width: double.infinity, padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(color: AppColors.surface2, borderRadius: BorderRadius.circular(10),
            border: Border.all(color: AppColors.border)),
        child: Text(value.isEmpty ? '' : value,
            style: const TextStyle(fontSize: 13, color: AppColors.textPrimary))),
    ]);
  }

  // ── Skills ────────────────────────────────────────────────────────────────
  Widget _skillsCard() {
    final skills = _profile?.skills ?? [];
    return _card(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      const Text('Skills', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700)),
      const SizedBox(height: 12),
      if (skills.isEmpty)
        const Text('No skills listed.', style: TextStyle(color: AppColors.textSecondary, fontSize: 13))
      else Wrap(spacing: 8, runSpacing: 8, children: skills.map((s) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(color: AppColors.tealLight, borderRadius: BorderRadius.circular(20),
            border: Border.all(color: AppColors.teal.withOpacity(0.3))),
        child: Text(s, style: const TextStyle(fontSize: 12, color: AppColors.teal, fontWeight: FontWeight.w600))
      )).toList()),
    ]));
  }

  // ── Weekly availability (like web) ────────────────────────────────────────
  Widget _availabilityCard() {
    const days = ['MON', 'TUE', 'WED', 'THU', 'FRI', 'SAT', 'SUN'];
    return _card(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      const Text('Weekly Availability', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700)),
      const SizedBox(height: 14),
      Row(children: List.generate(7, (i) {
        final available = _availability[i];
        return Expanded(child: GestureDetector(
          onTap: () => setState(() => _availability[i] = !_availability[i]),
          child: Container(margin: const EdgeInsets.symmetric(horizontal: 2),
            padding: const EdgeInsets.symmetric(vertical: 8),
            decoration: BoxDecoration(
              color: available ? AppColors.teal : AppColors.surface2,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: available ? AppColors.teal : AppColors.border)),
            child: Column(children: [
              Text(days[i], style: TextStyle(fontSize: 9, fontWeight: FontWeight.w700,
                  color: available ? Colors.white : AppColors.textSecondary)),
              const SizedBox(height: 2),
              Text(available ? '✓' : '—', style: TextStyle(fontSize: 11,
                  color: available ? Colors.white : AppColors.textSecondary)),
            ])),
        ));
      })),
    ]));
  }

  // ── Account info ──────────────────────────────────────────────────────────
  Widget _accountInfoCard() {
    final p = _profile!;
    return _card(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      const Text('Account Info', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700)),
      const SizedBox(height: 12),
      _infoRow('📧', p.email ?? '—'),
      const SizedBox(height: 8),
      _infoRow('🪪', 'Role: ${_cap(p.role)}'),
      const SizedBox(height: 8),
      _infoRow('🟢', 'Status: ${p.isActive ? 'active' : 'inactive'}'),
    ]));
  }

  Widget _infoRow(String emoji, String text) => Row(children: [
    Text(emoji, style: const TextStyle(fontSize: 14)),
    const SizedBox(width: 10),
    Expanded(child: Text(text, style: const TextStyle(fontSize: 13, color: AppColors.textSecondary))),
  ]);

  Widget _signOutButton() {
    return SizedBox(width: double.infinity,
      child: OutlinedButton.icon(
        onPressed: _signOut,
        icon: const Icon(Icons.logout, size: 16, color: AppColors.error),
        label: const Text('Sign Out', style: TextStyle(color: AppColors.error, fontWeight: FontWeight.w700)),
        style: OutlinedButton.styleFrom(
            side: const BorderSide(color: AppColors.error),
            padding: const EdgeInsets.symmetric(vertical: 14))));
  }

  Widget _buildError() {
    return Center(child: Padding(padding: const EdgeInsets.all(24),
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        const Icon(Icons.person_off_outlined, color: AppColors.textSecondary, size: 48),
        const SizedBox(height: 12),
        Text(_error != null ? 'Could not load profile' : 'No profile found',
            style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15)),
        const SizedBox(height: 6),
        Text(_error ?? 'Please add a profiles row in Supabase for your user ID.',
            textAlign: TextAlign.center,
            style: const TextStyle(color: AppColors.textSecondary, fontSize: 12)),
        const SizedBox(height: 16),
        ElevatedButton.icon(onPressed: _load,
            icon: const Icon(Icons.refresh, size: 16), label: const Text('Retry')),
        const SizedBox(height: 10),
        OutlinedButton.icon(onPressed: _signOut,
            icon: const Icon(Icons.logout, size: 16, color: AppColors.error),
            label: const Text('Sign Out', style: TextStyle(color: AppColors.error)),
            style: OutlinedButton.styleFrom(side: const BorderSide(color: AppColors.error))),
      ])));
  }

  Widget _card({required Widget child}) => Container(width: double.infinity,
    padding: const EdgeInsets.all(18),
    decoration: BoxDecoration(color: AppColors.surface, borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.border),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 8, offset: const Offset(0,2))]),
    child: child);

  String _cap(String s) => s.isNotEmpty ? '${s[0].toUpperCase()}${s.substring(1)}' : s;
}
