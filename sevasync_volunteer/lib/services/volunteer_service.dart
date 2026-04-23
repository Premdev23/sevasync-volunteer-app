import 'dart:typed_data';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/models.dart';

class VolunteerService {
  VolunteerService._();
  static SupabaseClient get _db => Supabase.instance.client;
  static String get _uid => _db.auth.currentUser!.id;

  // ── Auth ──────────────────────────────────────────────────────────────────
  static Future<void> signOut() => _db.auth.signOut();

  // ── Profile ───────────────────────────────────────────────────────────────
  static Future<VolunteerProfile> getProfile() async {
    final row = await _db.from('profiles').select().eq('id', _uid).single();
    // Also try to get avatar from storage
    String? avatarUrl;
    try {
      avatarUrl = _db.storage.from('avatars').getPublicUrl('$_uid/avatar.jpg');
    } catch (_) {}
    return VolunteerProfile.fromJson({...row, if (avatarUrl != null) 'avatar_url': avatarUrl});
  }

  static Future<void> setStatus(String status) =>
      _db.from('profiles').update({'status': status}).eq('id', _uid);

  static Future<void> updateProfile({
    String? name, String? phone, String? region,
    List<String>? skills, List<String>? availableDays,
  }) async {
    final updates = <String, dynamic>{};
    if (name != null)          updates['name']           = name;
    if (phone != null)         updates['phone']          = phone;
    if (region != null)        updates['region']         = region;
    if (skills != null)        updates['skills']         = skills;
    if (availableDays != null) updates['available_days'] = availableDays;
    if (updates.isNotEmpty) {
      await _db.from('profiles').update(updates).eq('id', _uid);
    }
  }

  static Future<String?> uploadAvatar(List<int> rawBytes) async {
    final bytes = Uint8List.fromList(rawBytes);
    try {
      await _db.storage.from('avatars').uploadBinary(
        '$_uid/avatar.jpg',
        bytes,
        fileOptions: const FileOptions(contentType: 'image/jpeg', upsert: true),
      );
      return _db.storage.from('avatars').getPublicUrl('$_uid/avatar.jpg');
    } catch (_) {
      return null;
    }
  }

  // ── Tasks ─────────────────────────────────────────────────────────────────
  static Future<List<VolunteerTask>> getTasks({String? status}) async {
    var q = _db.from('tasks').select().eq('volunteer_id', _uid);
    if (status != null) q = q.eq('status', status);
    final rows = await q.order('created_at', ascending: false);
    return rows.map<VolunteerTask>(VolunteerTask.fromJson).toList();
  }

  static Future<void> updateTaskStatus(String taskId, String status) =>
      _db.from('tasks').update({
        'status': status,
        if (status == 'completed') 'completed_at': DateTime.now().toIso8601String(),
      }).eq('id', taskId);

  // ── Notifications ─────────────────────────────────────────────────────────
  static Future<List<NotificationItem>> getNotifications() async {
    final rows = await _db.from('notifications').select()
        .eq('user_id', _uid).order('created_at', ascending: false);
    return rows.map<NotificationItem>(NotificationItem.fromJson).toList();
  }

  static Future<void> markNotificationRead(String id) =>
      _db.from('notifications').update({'read': true}).eq('id', id);

  static Future<void> markAllRead() =>
      _db.from('notifications').update({'read': true})
          .eq('user_id', _uid).eq('read', false);

  // ── Messages ──────────────────────────────────────────────────────────────
  static Future<List<VolunteerProfile>> getAdmins() async {
    try {
      final rows = await _db.from('profiles').select()
          .inFilter('role', ['admin', 'super-admin']).order('name');
      final admins = rows.map<VolunteerProfile>(VolunteerProfile.fromJson).toList();
      if (admins.isNotEmpty) return admins;
    } catch (_) {}
    try {
      final own = await _db.from('profiles').select('admin_id').eq('id', _uid).single();
      final adminId = own['admin_id'] as String?;
      if (adminId != null) {
        final row = await _db.from('profiles').select().eq('id', adminId).single();
        return [VolunteerProfile.fromJson(row)];
      }
    } catch (_) {}
    return [];
  }

  static Future<List<ChatMessage>> getMessages(String adminId) async {
    final rows = await _db.from('messages').select()
        .or('and(from_id.eq.$_uid,to_id.eq.$adminId),and(from_id.eq.$adminId,to_id.eq.$_uid)')
        .order('created_at', ascending: true);
    return rows.map<ChatMessage>(ChatMessage.fromJson).toList();
  }

  static Future<void> sendMessage(String toId, String text) =>
      _db.from('messages').insert({'from_id': _uid, 'to_id': toId, 'text': text, 'read': false});

  static Future<void> markMessagesRead(String fromId) =>
      _db.from('messages').update({'read': true})
          .eq('from_id', fromId).eq('to_id', _uid).eq('read', false);

  static Future<List<AdminConversation>> getConversations() async {
    final admins = await getAdmins();
    final List<AdminConversation> result = [];
    for (final admin in admins) {
      try {
        final msgs = await getMessages(admin.id);
        final unread = msgs.where((m) => m.fromId != _uid && !m.read).length;
        result.add(AdminConversation(admin: admin, messages: msgs, unreadCount: unread));
      } catch (_) {
        result.add(AdminConversation(admin: admin, messages: [], unreadCount: 0));
      }
    }
    return result;
  }

  // ── Dashboard stats ───────────────────────────────────────────────────────
  static Future<DashboardStats> getDashboardStats() async {
    final results = await Future.wait([getTasks(), getNotifications()]);
    final tasks  = results[0] as List<VolunteerTask>;
    final notifs = results[1] as List<NotificationItem>;
    return DashboardStats(
      total:               tasks.length,
      active:              tasks.where((t) => t.status == 'in_progress').length,
      completed:           tasks.where((t) => t.status == 'completed').length,
      unreadNotifications: notifs.where((n) => !n.isRead).length,
    );
  }
}

class DashboardStats {
  final int total, active, completed, unreadNotifications;
  const DashboardStats({required this.total, required this.active,
      required this.completed, required this.unreadNotifications});
  static const empty = DashboardStats(total:0,active:0,completed:0,unreadNotifications:0);
}

class AdminConversation {
  final VolunteerProfile admin;
  final List<ChatMessage> messages;
  final int unreadCount;
  const AdminConversation({required this.admin, required this.messages, required this.unreadCount});
  ChatMessage? get lastMessage => messages.isNotEmpty ? messages.last : null;
}
