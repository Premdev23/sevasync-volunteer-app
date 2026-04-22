import 'package:flutter/material.dart';
import '../../../theme/app_theme.dart';
import '../../../widgets/widgets.dart';
import '../../../models/models.dart';
import '../../../services/volunteer_service.dart';

class TaskHistoryScreen extends StatefulWidget {
  const TaskHistoryScreen({super.key});
  @override
  State<TaskHistoryScreen> createState() => _TaskHistoryScreenState();
}

class _TaskHistoryScreenState extends State<TaskHistoryScreen> {
  bool _loading = true;
  String? _error;
  List<VolunteerTask> _completed = [];

  int get _thisMonth {
    final now = DateTime.now();
    return _completed.where((t) => t.createdAt.year == now.year && t.createdAt.month == now.month).length;
  }
  int get _taskTypes => _completed.map((t) => t.type ?? 'Other').toSet().length;

  @override
  void initState() { super.initState(); _load(); }

  Future<void> _load() async {
    setState(() { _loading = true; _error = null; });
    try {
      final tasks = await VolunteerService.getTasks(status: 'completed');
      if (mounted) setState(() => _completed = tasks);
    } catch (e) {
      if (mounted) setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
          const Text('Task History'),
          Text('${_completed.length} tasks completed',
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
              ? ErrorRetry(title: 'Could not load history', message: _error, onRetry: _load)
              : RefreshIndicator(onRefresh: _load, color: AppColors.teal,
                  child: ListView(padding: const EdgeInsets.all(16), children: [
                    // Stats row
                    Container(
                      decoration: BoxDecoration(color: AppColors.tealLight.withOpacity(0.5),
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(color: AppColors.teal.withOpacity(0.15))),
                      child: IntrinsicHeight(child: Row(children: [
                        _statCell('✅', '${_completed.length}', 'Total Completed', AppColors.green),
                        VerticalDivider(width: 1, color: AppColors.teal.withOpacity(0.2)),
                        _statCell('📅', '$_thisMonth', 'This Month', AppColors.teal),
                        VerticalDivider(width: 1, color: AppColors.teal.withOpacity(0.2)),
                        _statCell('📋', '$_taskTypes', 'Task Types', AppColors.orange),
                      ]))),
                    const SizedBox(height: 16),

                    if (_completed.isEmpty)
                      Container(padding: const EdgeInsets.all(40),
                        decoration: BoxDecoration(color: AppColors.surface,
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(color: AppColors.border)),
                        child: const Column(children: [
                          Icon(Icons.assignment_outlined, size: 48, color: AppColors.textSecondary),
                          SizedBox(height: 14),
                          Text('No completed tasks yet', style: TextStyle(fontSize: 17,
                              fontWeight: FontWeight.w700, color: AppColors.textPrimary)),
                          SizedBox(height: 8),
                          Text("Once you complete your assigned tasks, they'll appear here as your impact history.",
                              textAlign: TextAlign.center,
                              style: TextStyle(color: AppColors.textSecondary, fontSize: 13, height: 1.5)),
                        ]))
                    else
                      ..._completed.map((t) => _historyCard(t)),
                  ])),
    );
  }

  Widget _statCell(String emoji, String value, String label, Color color) {
    return Expanded(child: Padding(
      padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 8),
      child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
        Text(emoji, style: const TextStyle(fontSize: 24)),
        const SizedBox(height: 6),
        Text(value, style: TextStyle(fontSize: 26, fontWeight: FontWeight.w800, color: color)),
        const SizedBox(height: 4),
        Text(label, textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 11, color: AppColors.textSecondary, fontWeight: FontWeight.w600)),
      ])));
  }

  Widget _historyCard(VolunteerTask task) {
    final pc = AppColors.priorityColor(task.priority);
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: AppColors.surface, borderRadius: BorderRadius.circular(14),
          border: Border.all(color: AppColors.border)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          // Badges
          Expanded(child: Wrap(spacing: 6, children: [
            if (task.type != null) _pill(task.type!, AppColors.teal, AppColors.tealLight),
            _pill(task.priority, pc, AppColors.priorityBg(task.priority)),
            _pill('✓ Completed', AppColors.green, AppColors.greenLight),
          ])),
          Text(_fmtDate(task.createdAt),
              style: const TextStyle(fontSize: 12, color: AppColors.textSecondary, fontWeight: FontWeight.w600)),
        ]),
        const SizedBox(height: 10),
        Text(task.title, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15, color: AppColors.textPrimary)),
        if (task.location != null) ...[
          const SizedBox(height: 6),
          Row(children: [
            const Icon(Icons.location_on, size: 13, color: AppColors.teal),
            const SizedBox(width: 4),
            Flexible(child: Text(task.location!,
                style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
                overflow: TextOverflow.ellipsis)),
          ]),
        ],
        if (task.instructions != null) ...[
          const SizedBox(height: 4),
          Row(children: [
            const Text('📝 ', style: TextStyle(fontSize: 12)),
            Flexible(child: Text(task.instructions!,
                style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
                maxLines: 2, overflow: TextOverflow.ellipsis)),
          ]),
        ],
      ]),
    );
  }

  Widget _pill(String label, Color color, Color bg) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 3),
    decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withOpacity(0.3))),
    child: Text(label, style: TextStyle(color: color, fontSize: 10, fontWeight: FontWeight.w700)));

  String _fmtDate(DateTime dt) {
    const m = ['Jan','Feb','Mar','Apr','May','Jun','Jul','Aug','Sep','Oct','Nov','Dec'];
    return '${dt.day} ${m[dt.month-1]} ${dt.year}';
  }
}
