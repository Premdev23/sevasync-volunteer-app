import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
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
  bool _loading  = true;
  bool _editMode = false;
  bool _saving   = false;
  String? _error;
  VolunteerProfile? _profile;
  String? _localAvatarUrl;

  // Edit state — only populated when entering edit mode
  String _editName   = '';
  String _editPhone  = '';
  String _editRegion = '';
  List<String> _editSkills = [];
  List<bool>   _editAvail  = List.filled(7, false);

  // Phone validation
  String? _phoneError;

  final _nameCtrl   = TextEditingController();
  final _phoneCtrl  = TextEditingController();
  final _regionCtrl = TextEditingController();
  final _skillCtrl  = TextEditingController();

  static const _days    = ['MON','TUE','WED','THU','FRI','SAT','SUN'];
  static const _dayKeys = ['Monday','Tuesday','Wednesday','Thursday','Friday','Saturday','Sunday'];

  @override
  void initState() { super.initState(); _load(); }

  @override
  void dispose() {
    _nameCtrl.dispose(); _phoneCtrl.dispose();
    _regionCtrl.dispose(); _skillCtrl.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() { _loading = true; _error = null; });
    try {
      final results = await Future.wait([
        VolunteerService.getProfile(),
        VolunteerService.getDashboardStats(),
      ]);
      if (!mounted) return;
      final p = results[0] as VolunteerProfile;
      setState(() {
        _profile        = p;
        _localAvatarUrl = p.avatarUrl;
        _editMode       = false; // always exit edit on reload
      });
    } catch (e) {
      if (mounted) setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _enterEditMode() {
    final p = _profile!;
    // Copy current values into edit state fresh
    _editName   = p.name;
    _editPhone  = p.phone ?? '';
    _editRegion = p.region ?? '';
    _editSkills = List.from(p.skills);
    _editAvail  = List.generate(7, (i) =>
        p.availableDays.any((d) => d.toLowerCase() == _dayKeys[i].toLowerCase()));
    // Set controllers once
    _nameCtrl.text   = _editName;
    _phoneCtrl.text  = _editPhone;
    _regionCtrl.text = _editRegion;
    _phoneError = null;
    setState(() => _editMode = true);
  }

  void _cancelEdit() {
    _nameCtrl.clear(); _phoneCtrl.clear(); _regionCtrl.clear();
    setState(() { _editMode = false; _phoneError = null; });
  }

  String? _validatePhone(String phone) {
    if (phone.isEmpty) return null; // phone is optional
    final digits = phone.replaceAll(RegExp(r'\D'), '');
    if (digits.length < 7)  return 'Phone number too short (min 7 digits)';
    if (digits.length > 15) return 'Phone number too long (max 15 digits)';
    if (!RegExp(r'^[+\d][\d\s\-().]+$').hasMatch(phone)) {
      return 'Only digits, spaces, +, -, ( ) allowed';
    }
    return null;
  }

  Future<void> _save() async {
    // Validate phone
    final phoneErr = _validatePhone(_phoneCtrl.text.trim());
    if (phoneErr != null) {
      setState(() => _phoneError = phoneErr);
      return;
    }
    setState(() { _saving = true; _phoneError = null; });
    try {
      final selectedDays = List.generate(7, (i) => i)
          .where((i) => _editAvail[i]).map((i) => _dayKeys[i]).toList();
      await VolunteerService.updateProfile(
        name:          _nameCtrl.text.trim(),
        phone:         _phoneCtrl.text.trim(),
        region:        _regionCtrl.text.trim(),
        skills:        _editSkills,
        availableDays: selectedDays,
      );
      await _load();
      _showSnack('✅ Profile saved successfully!', AppColors.green);
    } catch (e) {
      _showSnack('❌ Save failed: $e', AppColors.red);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _pickPhoto() async {
    try {
      final file = await ImagePicker().pickImage(source: ImageSource.gallery, imageQuality: 80);
      if (file == null) return;
      setState(() => _saving = true);
      final bytes = Uint8List.fromList(await file.readAsBytes());
      final url   = await VolunteerService.uploadAvatar(bytes);
      if (url != null && mounted) {
        setState(() => _localAvatarUrl = '$url?t=${DateTime.now().millisecondsSinceEpoch}');
        _showSnack('📸 Photo updated!', AppColors.green);
      } else {
        _showSnack('Upload failed. Create "avatars" bucket in Supabase Storage.', AppColors.orange);
      }
    } catch (e) {
      _showSnack('Could not pick photo: $e', AppColors.red);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  void _showSnack(String msg, Color color) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(msg), backgroundColor: color, behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))));
  }

  void _showAddSkillDialog() {
    _skillCtrl.clear();
    showDialog(context: context, builder: (_) => AlertDialog(
      backgroundColor: AppColors.surface,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      title: const Row(children: [
        Icon(Icons.psychology_outlined, color: AppColors.teal, size: 22),
        SizedBox(width: 8),
        Text('Add Skill', style: TextStyle(fontWeight: FontWeight.w700)),
      ]),
      content: TextField(
        controller: _skillCtrl, autofocus: true,
        textCapitalization: TextCapitalization.words,
        decoration: const InputDecoration(hintText: 'e.g. First Aid, Cooking, Driving...'),
        onSubmitted: (_) { _addSkill(); Navigator.pop(context); },
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
        ElevatedButton(onPressed: () { _addSkill(); Navigator.pop(context); },
            child: const Text('Add Skill')),
      ]));
  }

  void _addSkill() {
    final s = _skillCtrl.text.trim();
    if (s.isNotEmpty && !_editSkills.contains(s)) setState(() => _editSkills.add(s));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Column(crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min, children: [
          Text('My Profile', style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800)),
          Text('Manage your personal information and availability',
              style: TextStyle(fontSize: 11, color: AppColors.textSecondary)),
        ]),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator(color: AppColors.teal))
          : _error != null || _profile == null
              ? _buildError()
              : RefreshIndicator(onRefresh: _load, color: AppColors.teal,
                  child: LayoutBuilder(builder: (ctx, constraints) {
                    final wide = constraints.maxWidth > 650;
                    if (wide) {
                      return SingleChildScrollView(padding: const EdgeInsets.all(20),
                        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                          Expanded(flex: 3, child: Column(children: [
                            _editBar(), const SizedBox(height: 16),
                            _avatarCard(), const SizedBox(height: 16),
                            _personalInfoCard(),
                          ])),
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
                        _editBar(), const SizedBox(height: 14),
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

  // ── Cool Edit / Save bar ───────────────────────────────────────────────────
  Widget _editBar() {
    if (_editMode) {
      return Row(children: [
        Expanded(child: OutlinedButton.icon(
          onPressed: _cancelEdit,
          icon: const Icon(Icons.close, size: 16),
          label: const Text('Cancel'),
          style: OutlinedButton.styleFrom(
              foregroundColor: AppColors.textSecondary,
              side: const BorderSide(color: AppColors.border),
              padding: const EdgeInsets.symmetric(vertical: 13)))),
        const SizedBox(width: 12),
        Expanded(flex: 2, child: ElevatedButton.icon(
          onPressed: _saving ? null : _save,
          icon: _saving
              ? const SizedBox(width: 16, height: 16,
                  child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
              : const Icon(Icons.check_circle_outline, size: 18),
          label: const Text('Save Changes', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700)),
          style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.green, foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 14)))),
      ]);
    }

    // Cool gradient Edit Profile button
    return GestureDetector(
      onTap: _enterEditMode,
      child: Container(
        width: double.infinity, height: 52,
        decoration: BoxDecoration(
          gradient: const LinearGradient(
              colors: [AppColors.teal, AppColors.green],
              begin: Alignment.centerLeft, end: Alignment.centerRight),
          borderRadius: BorderRadius.circular(12),
          boxShadow: [BoxShadow(color: AppColors.teal.withOpacity(0.35),
              blurRadius: 10, offset: const Offset(0, 4))]),
        child: const Row(mainAxisAlignment: MainAxisAlignment.center, children: [
          Icon(Icons.edit_outlined, color: Colors.white, size: 20),
          SizedBox(width: 10),
          Text('Edit Profile', style: TextStyle(color: Colors.white,
              fontSize: 16, fontWeight: FontWeight.w700, letterSpacing: 0.3)),
        ])));
  }

  // ── Avatar card ────────────────────────────────────────────────────────────
  Widget _avatarCard() {
    final p = _profile!;
    return _card(child: Column(children: [
      Stack(children: [
        GradientAvatar(initials: p.initials, imageUrl: _localAvatarUrl, radius: 44),
        Positioned(bottom: 0, right: 0,
          child: GestureDetector(onTap: _pickPhoto,
            child: Container(padding: const EdgeInsets.all(7),
              decoration: BoxDecoration(
                gradient: const LinearGradient(colors: [AppColors.teal, AppColors.green]),
                shape: BoxShape.circle,
                border: Border.all(color: Colors.white, width: 2)),
              child: const Icon(Icons.camera_alt, size: 14, color: Colors.white)))),
      ]),
      const SizedBox(height: 12),
      // Show edited name if in edit mode
      Text(_editMode ? _nameCtrl.text : p.name,
          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: AppColors.textPrimary)),
      const SizedBox(height: 4),
      Text('${_cap(p.role)} · ${_editMode ? (_regionCtrl.text.isEmpty ? 'Unknown' : _regionCtrl.text) : (p.region ?? 'Unknown Region')}',
          style: const TextStyle(color: AppColors.textSecondary, fontSize: 13)),
      const SizedBox(height: 12),
      GestureDetector(
        onTap: () async {
          await VolunteerService.setStatus(p.isActive ? 'inactive' : 'active');
          await _load();
        },
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 7),
          decoration: BoxDecoration(
            color: p.isActive ? AppColors.greenLight : AppColors.surface2,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: p.isActive ? AppColors.green.withOpacity(0.4) : AppColors.border)),
          child: Row(mainAxisSize: MainAxisSize.min, children: [
            Container(width: 8, height: 8, margin: const EdgeInsets.only(right: 6),
                decoration: BoxDecoration(
                    color: p.isActive ? AppColors.green : AppColors.textSecondary,
                    shape: BoxShape.circle)),
            Text(p.isActive ? 'active' : 'unavailable',
                style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700,
                    color: p.isActive ? AppColors.green : AppColors.textSecondary)),
          ]))),
    ]));
  }

  // ── Personal info card ─────────────────────────────────────────────────────
  Widget _personalInfoCard() {
    final p = _profile!;
    return _card(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      const Text('Personal Information',
          style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700)),
      const SizedBox(height: 16),

      // Full Name
      _fieldLabel('Full Name'),
      _editMode
          ? TextField(controller: _nameCtrl,
              textCapitalization: TextCapitalization.words,
              style: const TextStyle(fontSize: 13),
              decoration: const InputDecoration(
                  prefixIcon: Icon(Icons.person_outline, color: AppColors.teal, size: 18),
                  contentPadding: EdgeInsets.symmetric(horizontal: 14, vertical: 12)))
          : _displayField(p.name, Icons.person_outline),
      const SizedBox(height: 14),

      // Email (always read-only)
      _fieldLabel('Email'),
      _displayField(p.email ?? '—', Icons.email_outlined),
      const SizedBox(height: 14),

      // Phone with validation
      _fieldLabel('Phone'),
      _editMode
          ? Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              TextField(
                controller: _phoneCtrl,
                keyboardType: TextInputType.phone,
                inputFormatters: [
                  FilteringTextInputFormatter.allow(RegExp(r'[0-9+\-\s().]')),
                  LengthLimitingTextInputFormatter(16),
                ],
                style: const TextStyle(fontSize: 13),
                onChanged: (v) => setState(() => _phoneError = _validatePhone(v)),
                decoration: InputDecoration(
                  prefixIcon: const Icon(Icons.phone_outlined, color: AppColors.teal, size: 18),
                  hintText: '+91 98765 43210',
                  contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                  errorText: _phoneError,
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: BorderSide(
                        color: _phoneError != null ? AppColors.red : AppColors.teal, width: 2)),
                )),
              if (_phoneError == null && _phoneCtrl.text.isNotEmpty)
                const Padding(padding: EdgeInsets.only(top: 4, left: 4),
                  child: Row(children: [
                    Icon(Icons.check_circle, color: AppColors.green, size: 14),
                    SizedBox(width: 4),
                    Text('Valid phone number', style: TextStyle(color: AppColors.green, fontSize: 11)),
                  ])),
            ])
          : _displayField(p.phone?.isEmpty ?? true ? '—' : p.phone!, Icons.phone_outlined),
      const SizedBox(height: 14),

      // Region
      _fieldLabel('Region / Area'),
      _editMode
          ? TextField(controller: _regionCtrl,
              textCapitalization: TextCapitalization.words,
              style: const TextStyle(fontSize: 13),
              decoration: const InputDecoration(
                  prefixIcon: Icon(Icons.location_on_outlined, color: AppColors.teal, size: 18),
                  hintText: 'e.g. Mumbai North',
                  contentPadding: EdgeInsets.symmetric(horizontal: 14, vertical: 12)))
          : _displayField(p.region ?? '—', Icons.location_on_outlined),
    ]));
  }

  Widget _fieldLabel(String label) => Padding(
    padding: const EdgeInsets.only(bottom: 6),
    child: Text(label, style: const TextStyle(fontSize: 12, color: AppColors.textSecondary,
        fontWeight: FontWeight.w600)));

  Widget _displayField(String value, IconData icon) => Container(
    width: double.infinity,
    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
    decoration: BoxDecoration(color: AppColors.surface2, borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppColors.border)),
    child: Row(children: [
      Icon(icon, size: 16, color: AppColors.textSecondary),
      const SizedBox(width: 10),
      Expanded(child: Text(value,
          style: const TextStyle(fontSize: 13, color: AppColors.textPrimary))),
    ]));

  // ── Skills card ────────────────────────────────────────────────────────────
  Widget _skillsCard() {
    return _card(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
        const Text('Skills', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700)),
        if (_editMode) TextButton.icon(
            onPressed: _showAddSkillDialog,
            icon: const Icon(Icons.add_circle_outline, size: 16),
            label: const Text('Add', style: TextStyle(fontSize: 12))),
      ]),
      const SizedBox(height: 12),
      _editMode
          ? Wrap(spacing: 8, runSpacing: 8, children: [
              ..._editSkills.map((s) => Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(color: AppColors.tealLight,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: AppColors.teal.withOpacity(0.3))),
                child: Row(mainAxisSize: MainAxisSize.min, children: [
                  Text(s, style: const TextStyle(fontSize: 12, color: AppColors.teal,
                      fontWeight: FontWeight.w600)),
                  const SizedBox(width: 6),
                  GestureDetector(onTap: () => setState(() => _editSkills.remove(s)),
                    child: const Icon(Icons.close, size: 14, color: AppColors.teal)),
                ]))),
              GestureDetector(onTap: _showAddSkillDialog,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(color: AppColors.surface2,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: AppColors.border)),
                  child: const Row(mainAxisSize: MainAxisSize.min, children: [
                    Icon(Icons.add, size: 14, color: AppColors.textSecondary),
                    SizedBox(width: 4),
                    Text('Add Skill', style: TextStyle(fontSize: 12, color: AppColors.textSecondary)),
                  ]))),
            ])
          : _profile!.skills.isEmpty
              ? const Text('No skills listed.',
                  style: TextStyle(color: AppColors.textSecondary, fontSize: 13))
              : Wrap(spacing: 8, runSpacing: 8, children: _profile!.skills.map((s) =>
                  Container(padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(color: AppColors.tealLight,
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: AppColors.teal.withOpacity(0.3))),
                    child: Text(s, style: const TextStyle(fontSize: 12, color: AppColors.teal,
                        fontWeight: FontWeight.w600)))).toList()),
    ]));
  }

  // ── Weekly availability ────────────────────────────────────────────────────
  Widget _availabilityCard() {
    final avail = _editMode ? _editAvail
        : List.generate(7, (i) => _profile!.availableDays
            .any((d) => d.toLowerCase() == _dayKeys[i].toLowerCase()));
    return _card(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Row(children: [
        const Text('Weekly Availability', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700)),
        if (_editMode) ...[
          const Spacer(),
          const Text('Tap to toggle', style: TextStyle(fontSize: 11, color: AppColors.textSecondary)),
        ],
      ]),
      const SizedBox(height: 14),
      Row(children: List.generate(7, (i) {
        final on = avail[i];
        return Expanded(child: GestureDetector(
          onTap: _editMode ? () => setState(() => _editAvail[i] = !on) : null,
          child: AnimatedContainer(duration: const Duration(milliseconds: 200),
            margin: const EdgeInsets.symmetric(horizontal: 2),
            padding: const EdgeInsets.symmetric(vertical: 10),
            decoration: BoxDecoration(
              color: on ? AppColors.teal : AppColors.surface2,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: on ? AppColors.teal : AppColors.border),
              boxShadow: on ? [BoxShadow(color: AppColors.teal.withOpacity(0.3),
                  blurRadius: 4, offset: const Offset(0,2))] : null),
            child: Column(children: [
              Text(_days[i], style: TextStyle(fontSize: 9, fontWeight: FontWeight.w700,
                  color: on ? Colors.white : AppColors.textSecondary)),
              const SizedBox(height: 3),
              Text(on ? '✓' : '—', style: TextStyle(fontSize: 11,
                  color: on ? Colors.white : AppColors.textSecondary, fontWeight: FontWeight.bold)),
            ]))));
      })),
    ]));
  }

  // ── Account info ───────────────────────────────────────────────────────────
  Widget _accountInfoCard() {
    final p = _profile!;
    return _card(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      const Text('Account Info', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700)),
      const SizedBox(height: 12),
      _infoRow(Icons.email_outlined,    AppColors.teal,    p.email ?? '—'),
      const SizedBox(height: 8),
      _infoRow(Icons.badge_outlined,    AppColors.orange,  'Role: ${_cap(p.role)}'),
      const SizedBox(height: 8),
      _infoRow(Icons.circle,            p.isActive ? AppColors.green : AppColors.textSecondary,
          'Status: ${p.status}'),
      if (p.joinedAt != null) ...[
        const SizedBox(height: 8),
        _infoRow(Icons.calendar_today,  AppColors.textSecondary, 'Joined: ${_fmtDate(p.joinedAt!)}'),
      ],
    ]));
  }

  Widget _infoRow(IconData icon, Color color, String text) => Row(children: [
    Icon(icon, size: 16, color: color),
    const SizedBox(width: 10),
    Expanded(child: Text(text, style: const TextStyle(fontSize: 13, color: AppColors.textSecondary))),
  ]);

  // ── Sign out ───────────────────────────────────────────────────────────────
  Widget _signOutButton() => SizedBox(width: double.infinity,
    child: OutlinedButton.icon(
      onPressed: _signOut,
      icon: const Icon(Icons.logout, size: 16, color: AppColors.red),
      label: const Text('Sign Out',
          style: TextStyle(color: AppColors.red, fontWeight: FontWeight.w700, fontSize: 15)),
      style: OutlinedButton.styleFrom(
          side: const BorderSide(color: AppColors.red),
          padding: const EdgeInsets.symmetric(vertical: 14))));

  Future<void> _signOut() async {
    final ok = await showDialog<bool>(context: context, builder: (_) => AlertDialog(
      backgroundColor: AppColors.surface,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      title: const Text('Sign Out'),
      content: const Text('Are you sure you want to sign out?',
          style: TextStyle(color: AppColors.textSecondary)),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
        ElevatedButton(
          style: ElevatedButton.styleFrom(backgroundColor: AppColors.red, foregroundColor: Colors.white),
          onPressed: () => Navigator.pop(context, true), child: const Text('Sign Out')),
      ]));
    if (ok == true) await VolunteerService.signOut();
  }

  Widget _buildError() => Center(child: Padding(padding: const EdgeInsets.all(24),
    child: Column(mainAxisSize: MainAxisSize.min, children: [
      const Icon(Icons.person_off_outlined, color: AppColors.textSecondary, size: 48),
      const SizedBox(height: 12),
      Text(_error != null ? 'Could not load profile' : 'No profile found',
          style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15)),
      const SizedBox(height: 6),
      Text(_error ?? 'Please add a profiles row in Supabase.',
          textAlign: TextAlign.center,
          style: const TextStyle(color: AppColors.textSecondary, fontSize: 12)),
      const SizedBox(height: 16),
      ElevatedButton.icon(onPressed: _load,
          icon: const Icon(Icons.refresh, size: 16), label: const Text('Retry')),
    ])));

  Widget _card({required Widget child}) => Container(
    width: double.infinity, padding: const EdgeInsets.all(18),
    decoration: BoxDecoration(color: AppColors.surface, borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.border),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04),
            blurRadius: 8, offset: const Offset(0,2))]),
    child: child);

  String _cap(String s) => s.isNotEmpty ? '${s[0].toUpperCase()}${s.substring(1)}' : s;
  String _fmtDate(DateTime dt) {
    const m = ['Jan','Feb','Mar','Apr','May','Jun','Jul','Aug','Sep','Oct','Nov','Dec'];
    return '${dt.day} ${m[dt.month-1]} ${dt.year}';
  }
}
