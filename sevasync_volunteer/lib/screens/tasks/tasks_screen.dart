import 'package:flutter/material.dart';
import '../../../theme/app_theme.dart';
import '../../../widgets/widgets.dart';
import '../../../models/models.dart';
import '../../../services/volunteer_service.dart';

class TasksScreen extends StatefulWidget {
  const TasksScreen({super.key});
  @override
  State<TasksScreen> createState() => _TasksScreenState();
}

class _TasksScreenState extends State<TasksScreen> {
  bool    _loading = true;
  String? _error;
  String  _filter = 'all';   // all | pending | active | completed
  VolunteerTask? _selected;

  List<VolunteerTask> _all = [];

  List<VolunteerTask> get _filtered {
    if (_filter == 'all')       return _all;
    if (_filter == 'pending')   return _all.where((t) => t.status == 'assigned' || t.status == 'unassigned').toList();
    if (_filter == 'active')    return _all.where((t) => t.status == 'in_progress').toList();
    if (_filter == 'completed') return _all.where((t) => t.status == 'completed').toList();
    return _all;
  }

  int _count(String s) {
    if (s == 'all') return _all.length;
    if (s == 'pending') return _all.where((t) => t.status == 'assigned' || t.status == 'unassigned').length;
    if (s == 'active') return _all.where((t) => t.status == 'in_progress').length;
    return _all.where((t) => t.status == s).length;
  }

  @override
  void initState() { super.initState(); _load(); }

  Future<void> _load() async {
    setState(() { _loading = true; _error = null; });
    try {
      final tasks = await VolunteerService.getTasks();
      if (!mounted) return;
      setState(() { _all = tasks; _selected = null; });
    } catch (e) {
      if (mounted) setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final active  = _all.where((t) => t.status == 'in_progress').length;
    final done    = _all.where((t) => t.status == 'completed').length;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
          const Text('My Tasks', style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800)),
          Text('$active active · $done completed',
              style: const TextStyle(fontSize: 11, color: AppColors.textSecondary)),
        ]),
        actions: [
          TextButton.icon(onPressed: _load,
            icon: const Icon(Icons.refresh, size: 14, color: AppColors.teal),
            label: const Text('Refresh', style: TextStyle(color: AppColors.teal, fontSize: 12))),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator(color: AppColors.teal))
          : _error != null
              ? ErrorRetry(title: 'Could not load tasks', message: _error, onRetry: _load)
              : Column(children: [
                  // Filter tabs
                  Container(color: AppColors.surface, padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                    child: SingleChildScrollView(scrollDirection: Axis.horizontal,
                      child: Row(children: [
                        _filterChip('all',       'All Tasks',   _count('all')),
                        const SizedBox(width: 8),
                        _filterChip('pending',   'Assigned',    _count('pending')),
                        const SizedBox(width: 8),
                        _filterChip('active',    'In Progress', _count('active')),
                        const SizedBox(width: 8),
                        _filterChip('completed', 'Completed',   _count('completed')),
                      ]),
                    )),
                  const Divider(height: 0),

                  // Content
                  Expanded(child: LayoutBuilder(builder: (ctx, constraints) {
                    // Wide layout: task list left, detail right (like web)
                    if (constraints.maxWidth > 650) {
                      return Row(children: [
                        SizedBox(width: constraints.maxWidth * 0.5,
                          child: _taskList()),
                        const VerticalDivider(width: 1),
                        Expanded(child: _detailPanel()),
                      ]);
                    }
                    // Narrow: just list, tap opens bottom sheet
                    return _taskList();
                  })),
                ]),
    );
  }

  Widget _filterChip(String key, String label, int count) {
    final selected = _filter == key;
    return GestureDetector(
      onTap: () => setState(() { _filter = key; _selected = null; }),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
        decoration: BoxDecoration(
          color: selected ? AppColors.teal : AppColors.surface2,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: selected ? AppColors.teal : AppColors.border),
        ),
        child: Text('$label ($count)',
          style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600,
              color: selected ? Colors.white : AppColors.textSecondary)),
      ),
    );
  }

  Widget _taskList() {
    if (_filtered.isEmpty) {
      return Center(child: Padding(padding: const EdgeInsets.all(24),
        child: EmptyState(icon: Icons.task_outlined,
            message: _filter == 'all'
                ? 'No tasks assigned yet.\nYour admin will assign tasks soon!'
                : 'No ${_filter == 'pending' ? 'assigned' : _filter} tasks.')));
    }
    return RefreshIndicator(onRefresh: _load, color: AppColors.teal,
      child: ListView.separated(
        padding: const EdgeInsets.all(16),
        itemCount: _filtered.length,
        separatorBuilder: (_, __) => const SizedBox(height: 10),
        itemBuilder: (_, i) {
          final t = _filtered[i];
          final isSelected = _selected?.id == t.id;
          return GestureDetector(
            onTap: () => setState(() => _selected = isSelected ? null : t),
            child: Container(
              decoration: isSelected ? BoxDecoration(
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: AppColors.teal, width: 2),
              ) : null,
              child: TaskCard(task: t, onStatusUpdate: () { _load(); }),
            ),
          );
        },
      ),
    );
  }

  Widget _detailPanel() {
    if (_selected == null) {
      return Container(color: AppColors.background,
        child: const Center(child: Column(mainAxisSize: MainAxisSize.min, children: [
          Icon(Icons.assignment_outlined, size: 48, color: AppColors.textSecondary),
          SizedBox(height: 12),
          Text('Select a task to see full details and take action',
              textAlign: TextAlign.center,
              style: TextStyle(color: AppColors.textSecondary, fontSize: 13)),
        ])));
    }
    final t = _selected!;
    final pc = AppColors.priorityColor(t.priority);
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          _badge(t.priority.toUpperCase(), pc),
          const SizedBox(width: 8),
          _badge(_statusLabel(t.status), _statusColor(t.status)),
        ]),
        const SizedBox(height: 14),
        Text(t.title, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: AppColors.textPrimary)),
        if (t.instructions != null) ...[
          const SizedBox(height: 10),
          Text(t.instructions!, style: const TextStyle(color: AppColors.textSecondary, fontSize: 13, height: 1.6)),
        ],
        const SizedBox(height: 16),
        if (t.location != null) _detailRow(Icons.location_on_outlined, AppColors.teal, t.location!),
        const SizedBox(height: 8),
        _detailRow(Icons.calendar_today_outlined, AppColors.orange,
            'Created ${_fmt(t.createdAt)}'),
        if (t.dueDate != null) ...[
          const SizedBox(height: 8),
          _detailRow(Icons.schedule_outlined, AppColors.error, 'Due ${_fmt(t.dueDate!)}'),
        ],
        const SizedBox(height: 24),
        if (t.status != 'completed') ...[
          const Text('Update Status', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13)),
          const SizedBox(height: 10),
          Row(children: [
            if (t.status != 'active')
              Expanded(child: OutlinedButton(
                onPressed: () => _updateStatus(t, 'in_progress'),
                style: OutlinedButton.styleFrom(foregroundColor: AppColors.orange,
                    side: const BorderSide(color: AppColors.orange)),
                child: const Text('Mark In Progress'))),
            if (t.status != 'active') const SizedBox(width: 10),
            Expanded(child: ElevatedButton(
              onPressed: () => _updateStatus(t, 'completed'),
              style: ElevatedButton.styleFrom(backgroundColor: AppColors.green, foregroundColor: Colors.white),
              child: const Text('Mark Completed'))),
          ]),
        ] else
          Container(width: double.infinity, padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(color: AppColors.greenLight, borderRadius: BorderRadius.circular(10),
                border: Border.all(color: AppColors.green.withOpacity(0.3))),
            child: const Row(mainAxisAlignment: MainAxisAlignment.center, children: [
              Icon(Icons.check_circle, color: AppColors.green, size: 18),
              SizedBox(width: 8),
              Text('Task Completed', style: TextStyle(color: AppColors.green, fontWeight: FontWeight.w700)),
            ])),
      ]),
    );
  }

  Future<void> _updateStatus(VolunteerTask t, String status) async {
    await VolunteerService.updateTaskStatus(t.id, status);
    await _load();
  }

  Widget _badge(String label, Color color) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
    decoration: BoxDecoration(color: color.withOpacity(0.12), borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withOpacity(0.35))),
    child: Text(label, style: TextStyle(color: color, fontSize: 11, fontWeight: FontWeight.w700)));

  Widget _detailRow(IconData icon, Color color, String text) => Row(children: [
    Icon(icon, size: 14, color: color),
    const SizedBox(width: 8),
    Expanded(child: Text(text, style: const TextStyle(fontSize: 13, color: AppColors.textSecondary))),
  ]);

  String _statusLabel(String s) => s == 'active' ? 'In Progress' : s[0].toUpperCase() + s.substring(1);
  Color _statusColor(String s) {
    switch (s) {
      case 'active':    return AppColors.orange;
      case 'completed': return AppColors.green;
      default:          return AppColors.textSecondary;
    }
  }

  String _fmt(DateTime dt) {
    const m = ['Jan','Feb','Mar','Apr','May','Jun','Jul','Aug','Sep','Oct','Nov','Dec'];
    return '${m[dt.month-1]} ${dt.day}, ${dt.year}';
  }
}
