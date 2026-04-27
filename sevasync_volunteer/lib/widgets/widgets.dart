import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import 'proof_dialog.dart';
import '../theme/app_theme.dart';
import '../models/models.dart';
import '../services/volunteer_service.dart';

// ── Open Google Maps ──────────────────────────────────────────────────────────
Future<void> openInMaps(String location) async {
  final encoded = Uri.encodeComponent(location);

  // Try geo: scheme first (opens Google Maps app on Android directly)
  final geoUrl = Uri.parse('geo:0,0?q=$encoded');
  if (await canLaunchUrl(geoUrl)) {
    await launchUrl(geoUrl);
    return;
  }

  // Fallback: Google Maps via external app
  final mapsUrl = Uri.parse('https://maps.google.com/maps?q=$encoded');
  if (await canLaunchUrl(mapsUrl)) {
    await launchUrl(mapsUrl, mode: LaunchMode.externalApplication);
    return;
  }

  // Last resort: browser
  final browserUrl = Uri.parse('https://www.google.com/maps/search/?api=1&query=$encoded');
  await launchUrl(browserUrl, mode: LaunchMode.externalApplication);
}

// ── Gradient Avatar ───────────────────────────────────────────────────────────
class GradientAvatar extends StatelessWidget {
  final String initials;
  final String? imageUrl;
  final double radius;
  const GradientAvatar({super.key, required this.initials, this.imageUrl, this.radius = 24});

  @override
  Widget build(BuildContext context) {
    if (imageUrl != null && imageUrl!.isNotEmpty) {
      return ClipOval(child: Image.network(imageUrl!,
          width: radius * 2, height: radius * 2, fit: BoxFit.cover,
          errorBuilder: (_, __, ___) => _gradient()));
    }
    return _gradient();
  }

  Widget _gradient() => Container(
    width: radius * 2, height: radius * 2,
    decoration: const BoxDecoration(
      gradient: LinearGradient(colors: [AppColors.teal, AppColors.green],
          begin: Alignment.topLeft, end: Alignment.bottomRight),
      shape: BoxShape.circle),
    child: Center(child: Text(initials,
        style: TextStyle(color: Colors.white, fontWeight: FontWeight.w800,
            fontSize: radius * 0.75))));
}

// ── Stat Card ─────────────────────────────────────────────────────────────────
class StatCard extends StatelessWidget {
  final String label, value;
  final IconData icon;
  final Color iconColor;
  final Color? bgColor;
  const StatCard({super.key, required this.label, required this.value,
      required this.icon, required this.iconColor, this.bgColor});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: bgColor ?? AppColors.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.border),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04),
            blurRadius: 8, offset: const Offset(0,2))]),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
          Text(label, style: const TextStyle(color: AppColors.textSecondary,
              fontSize: 10, fontWeight: FontWeight.w700, letterSpacing: 0.8)),
          Container(padding: const EdgeInsets.all(7),
            decoration: BoxDecoration(color: iconColor.withOpacity(0.12),
                borderRadius: BorderRadius.circular(10)),
            child: Icon(icon, color: iconColor, size: 16)),
        ]),
        const Spacer(),
        Text(value, style: TextStyle(fontSize: 30, fontWeight: FontWeight.w800, color: iconColor)),
      ]));
  }
}

// ── Task Card ─────────────────────────────────────────────────────────────────
class TaskCard extends StatelessWidget {
  final VolunteerTask task;
  final VoidCallback? onStatusUpdate;
  const TaskCard({super.key, required this.task, this.onStatusUpdate});

  @override
  Widget build(BuildContext context) {
    final pc = AppColors.priorityColor(task.priority);
    return Stack(children: [
      Container(
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppColors.border),
          boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04),
              blurRadius: 6, offset: const Offset(0,2))]),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(18, 14, 14, 14),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Wrap(spacing: 6, runSpacing: 4, children: [
              if (task.type != null) _pill(task.type!, AppColors.teal, AppColors.tealLight),
              _pill(task.priority, pc, AppColors.priorityBg(task.priority)),
              _pill(task.statusLabel, _statusColor(task.status),
                  _statusColor(task.status).withOpacity(0.1)),
            ]),
            const SizedBox(height: 10),
            Text(task.title, style: const TextStyle(fontWeight: FontWeight.w700,
                fontSize: 14, color: AppColors.textPrimary)),
            const SizedBox(height: 8),
            Row(children: [
              if (task.location != null) ...[
                const Icon(Icons.location_on, size: 12, color: AppColors.teal),
                const SizedBox(width: 3),
                Flexible(child: Text(task.location!,
                    style: const TextStyle(color: AppColors.textSecondary, fontSize: 12),
                    overflow: TextOverflow.ellipsis)),
                const SizedBox(width: 10),
              ],
              const Icon(Icons.schedule, size: 12, color: AppColors.textSecondary),
              const SizedBox(width: 3),
              Text(_fmt(task.dueDate ?? task.createdAt),
                  style: const TextStyle(color: AppColors.textSecondary, fontSize: 12)),
            ]),
            const SizedBox(height: 10),
            Wrap(spacing: 8, runSpacing: 6, children: [
              if (task.isCompleted)
                _actionBtn('✓ Completed', AppColors.green, AppColors.greenLight, null)
              else ...[
                if (task.status != 'in_progress')
                  _actionBtn('Start Task', AppColors.teal, AppColors.tealLight, () async {
                    await VolunteerService.updateTaskStatus(task.id, 'in_progress');
                    onStatusUpdate?.call();
                  }),
                if (task.status == 'in_progress')
                  Builder(builder: (ctx) => _actionBtn(
                    '✓ Mark Complete & Submit Proof',
                    AppColors.orange, AppColors.orangeLight, () async {
                      final submitted = await showProofDialog(ctx, task);
                      if (submitted) onStatusUpdate?.call();
                    })),
              ],
              // Directions — opens Google Maps
              if (task.location != null)
                _actionBtn('🗺 Directions', AppColors.teal, AppColors.tealLight,
                    () => openInMaps(task.location!))
              else
                _actionBtn('🗺 Directions', AppColors.textSecondary,
                    AppColors.surface2, null),
            ]),
          ]),
        ),
      ),
      Positioned(left: 0, top: 0, bottom: 0,
        child: Container(width: 4, decoration: BoxDecoration(
          color: pc,
          borderRadius: const BorderRadius.only(
              topLeft: Radius.circular(12), bottomLeft: Radius.circular(12))))),
    ]);
  }

  Widget _pill(String label, Color color, Color bg) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 3),
    decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withOpacity(0.3))),
    child: Text(label, style: TextStyle(color: color, fontSize: 10, fontWeight: FontWeight.w700)));

  Widget _actionBtn(String label, Color color, Color bg, VoidCallback? onTap) =>
      GestureDetector(onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(8),
              border: Border.all(color: color.withOpacity(0.3))),
          child: Text(label, style: TextStyle(color: color, fontSize: 11, fontWeight: FontWeight.w600))));

  Color _statusColor(String s) {
    switch (s) {
      case 'in_progress': return AppColors.orange;
      case 'completed':   return AppColors.green;
      case 'cancelled':   return AppColors.red;
      default:            return AppColors.textSecondary;
    }
  }
  String _fmt(DateTime dt) {
    const m = ['Jan','Feb','Mar','Apr','May','Jun','Jul','Aug','Sep','Oct','Nov','Dec'];
    return '${m[dt.month-1]} ${dt.day}';
  }
}

// ── Notification Tile ─────────────────────────────────────────────────────────
class NotifTile extends StatelessWidget {
  final NotificationItem notif;
  final VoidCallback? onTap;
  const NotifTile({super.key, required this.notif, this.onTap});

  @override
  Widget build(BuildContext context) {
    return InkWell(onTap: onTap,
      child: Container(
        color: notif.isRead ? Colors.transparent : AppColors.tealLight.withOpacity(0.4),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Row(children: [
          Container(width: 36, height: 36, margin: const EdgeInsets.only(right: 12),
            decoration: BoxDecoration(color: _color.withOpacity(0.12),
                borderRadius: BorderRadius.circular(8)),
            child: Center(child: Text(_emoji, style: const TextStyle(fontSize: 16)))),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(notif.title, style: TextStyle(fontSize: 13, color: AppColors.textPrimary,
                fontWeight: notif.isRead ? FontWeight.normal : FontWeight.w600),
                maxLines: 1, overflow: TextOverflow.ellipsis),
            if (notif.body != null && notif.body!.isNotEmpty) ...[
              const SizedBox(height: 2),
              Text(notif.body!, style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
                  maxLines: 2, overflow: TextOverflow.ellipsis),
            ],
            const SizedBox(height: 3),
            Text(_timeAgo(notif.createdAt),
                style: const TextStyle(fontSize: 11, color: AppColors.textSecondary)),
          ])),
          if (!notif.isRead) Container(width: 8, height: 8, margin: const EdgeInsets.only(left: 8),
              decoration: const BoxDecoration(color: AppColors.teal, shape: BoxShape.circle)),
        ])));
  }

  String get _emoji {
    switch (notif.type) {
      case 'task_assigned': return '📋';
      case 'task_update':   return '🔄';
      case 'message':       return '💬';
      case 'alert':         return '🔔';
      case 'milestone':     return '🏆';
      default:              return '🔔';
    }
  }
  Color get _color {
    switch (notif.type) {
      case 'task_assigned': return AppColors.teal;
      case 'alert':         return AppColors.red;
      case 'milestone':     return AppColors.green;
      default:              return AppColors.orange;
    }
  }
  String _timeAgo(DateTime dt) {
    final d = DateTime.now().difference(dt);
    if (d.inMinutes < 60) return '${d.inMinutes}m ago';
    if (d.inHours < 24)   return '${d.inHours}h ago';
    return '${d.inDays}d ago';
  }
}

// ── Shared ────────────────────────────────────────────────────────────────────
class EmptyState extends StatelessWidget {
  final IconData icon;
  final String message;
  const EmptyState({super.key, required this.icon, required this.message});

  @override
  Widget build(BuildContext context) => Container(
    width: double.infinity, padding: const EdgeInsets.all(40),
    decoration: BoxDecoration(color: AppColors.surface,
        borderRadius: BorderRadius.circular(14), border: Border.all(color: AppColors.border)),
    child: Column(children: [
      Container(padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(color: AppColors.tealLight, shape: BoxShape.circle),
        child: Icon(icon, size: 36, color: AppColors.teal)),
      const SizedBox(height: 14),
      Text(message, textAlign: TextAlign.center,
          style: const TextStyle(color: AppColors.textSecondary, fontSize: 13, height: 1.6)),
    ]));
}

class SectionHeader extends StatelessWidget {
  final String title;
  final Widget? trailing;
  const SectionHeader({super.key, required this.title, this.trailing});
  @override
  Widget build(BuildContext context) => Row(
    mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
      Text(title, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800,
          color: AppColors.textPrimary)),
      if (trailing != null) trailing!]);
}

class ErrorRetry extends StatelessWidget {
  final String title;
  final String? message;
  final VoidCallback onRetry;
  const ErrorRetry({super.key, required this.title, this.message, required this.onRetry});
  @override
  Widget build(BuildContext context) => Center(child: Padding(padding: const EdgeInsets.all(24),
    child: Column(mainAxisSize: MainAxisSize.min, children: [
      Container(padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(color: AppColors.orangeLight, shape: BoxShape.circle),
        child: const Icon(Icons.wifi_off_outlined, color: AppColors.orange, size: 36)),
      const SizedBox(height: 14),
      Text(title, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15)),
      if (message != null) ...[
        const SizedBox(height: 6),
        Text(message!, textAlign: TextAlign.center,
            style: const TextStyle(color: AppColors.textSecondary, fontSize: 12))],
      const SizedBox(height: 18),
      ElevatedButton.icon(onPressed: onRetry,
          icon: const Icon(Icons.refresh, size: 16), label: const Text('Try Again')),
    ])));
}
