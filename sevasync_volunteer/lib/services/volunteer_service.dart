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
  // avatar_url is a TEXT column in profiles — read it directly
  static Future<VolunteerProfile> getProfile() async {
    final row = await _db.from('profiles').select().eq('id', _uid).single();
    return VolunteerProfile.fromJson(row);
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

  /// Upload avatar to 'avatars' bucket → save public URL into profiles.avatar_url column
  static Future<String?> uploadAvatar(Uint8List bytes) async {
    try {
      final path = '$_uid/avatar.jpg';
      await _db.storage.from('avatars').uploadBinary(
        path, bytes,
        fileOptions: const FileOptions(contentType: 'image/jpeg', upsert: true),
      );
      final url = _db.storage.from('avatars').getPublicUrl(path);
      // Save URL directly into the avatar_url TEXT column
      await _db.from('profiles').update({'avatar_url': url}).eq('id', _uid);
      return url;
    } catch (e) {
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

  // ── Proof of Work ─────────────────────────────────────────────────────────
  /// Upload proof photo to 'proofs' bucket, returns public URL
  static Future<String?> uploadProofPhoto(Uint8List bytes, String taskId) async {
    try {
      final fileName = 'proof_${taskId}_${DateTime.now().millisecondsSinceEpoch}.jpg';
      await _db.storage.from('proofs').uploadBinary(
        fileName, bytes,
        fileOptions: const FileOptions(contentType: 'image/jpeg', upsert: true),
      );
      return _db.storage.from('proofs').getPublicUrl(fileName);
    } catch (_) {
      return null; // proofs bucket may not exist yet — graceful fallback
    }
  }

  /// Submit proof: mark task complete + send [PROOF_OF_WORK] message to admin
  static Future<void> submitProof({
    required String taskId,
    required String taskTitle,
    required String notes,
    Uint8List? photoBytes,
  }) async {
    // 1. Mark task completed
    await _db.from('tasks').update({
      'status': 'completed',
      'completed_at': DateTime.now().toIso8601String(),
    }).eq('id', taskId);

    // 2. Find admin_id from the task itself first, then fallback
    String? adminId;
    try {
      final task = await _db.from('tasks').select('admin_id').eq('id', taskId).single();
      adminId = task['admin_id'] as String?;
    } catch (_) {}

    if (adminId == null) {
      final admins = await getAdmins();
      if (admins.isNotEmpty) adminId = admins.first.id;
    }
    if (adminId == null) return;

    // 3. Upload photo if provided → get URL
    String photoNote = '';
    if (photoBytes != null && photoBytes.isNotEmpty) {
      final url = await uploadProofPhoto(photoBytes, taskId);
      photoNote = url != null
          ? '\nPhoto proof: $url'
          : '\n[Photo attached — upload failed, no storage bucket]';
    }

    // 4. Send [PROOF_OF_WORK] message — text only (no image column in messages table)
    final message = '[PROOF_OF_WORK] Task: "$taskTitle" — $notes$photoNote';
    await _db.from('messages').insert({
      'from_id': _uid,
      'to_id':   adminId,
      'text':    message,
      'read':    false,
    });
  }

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
      _db.from('messages').insert({
        'from_id': _uid,
        'to_id':   toId,
        'text':    text,
        'read':    false,
      });

  /// Mark all messages FROM admin TO volunteer as read
  /// messages.read column = BOOLEAN
  static Future<void> markMessagesRead(String fromId) =>
      _db.from('messages')
          .update({'read': true})
          .eq('from_id', fromId)
          .eq('to_id', _uid)
          .eq('read', false);

  static Future<List<AdminConversation>> getConversations() async {
    final admins = await getAdmins();
    final List<AdminConversation> result = [];
    for (final admin in admins) {
      try {
        final msgs = await getMessages(admin.id);
        // Unread = messages FROM admin that volunteer hasn't read
        final unread = msgs.where((m) => m.fromId == admin.id && !m.read).length;
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

// ── Value objects ─────────────────────────────────────────────────────────────
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
