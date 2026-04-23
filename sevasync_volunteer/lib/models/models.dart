class VolunteerTask {
  final String id, title, status, priority;
  final String? instructions, location, type, needId;
  final DateTime? dueDate;
  final DateTime createdAt;

  const VolunteerTask({required this.id, required this.title, required this.status,
      required this.priority, this.instructions, this.location, this.type,
      this.needId, this.dueDate, required this.createdAt});

  factory VolunteerTask.fromJson(Map<String, dynamic> j) => VolunteerTask(
    id:           j['id'] as String,
    title:        (j['title'] as String?) ?? 'Untitled',
    instructions: j['instructions'] as String?,
    status:       (j['status'] as String?) ?? 'assigned',
    priority:     (j['priority'] as String?) ?? 'medium',
    location:     j['location'] as String?,
    type:         j['type'] as String?,
    needId:       j['need_id'] as String?,
    dueDate:      j['due_date'] != null ? DateTime.parse(j['due_date']) : null,
    createdAt:    DateTime.parse(j['created_at'] as String),
  );

  String get statusLabel {
    switch (status) {
      case 'in_progress': return 'In Progress';
      case 'unassigned':  return 'Unassigned';
      case 'assigned':    return 'Assigned';
      case 'completed':   return 'Completed';
      case 'cancelled':   return 'Cancelled';
      default:            return status;
    }
  }
  bool get isCompleted => status == 'completed';
  bool get isActive    => status == 'in_progress';
}

class NotificationItem {
  final String id, title, type;
  final String? body;
  final bool isRead;
  final DateTime createdAt;

  const NotificationItem({required this.id, required this.title, required this.type,
      this.body, required this.isRead, required this.createdAt});

  factory NotificationItem.fromJson(Map<String, dynamic> j) => NotificationItem(
    id:        j['id'] as String,
    title:     (j['title'] as String?) ?? '',
    body:      j['body'] as String?,
    type:      (j['type'] as String?) ?? 'alert',
    isRead:    (j['read'] as bool?) ?? false,
    createdAt: DateTime.parse(j['created_at'] as String),
  );

  String get content => body != null && body!.isNotEmpty ? '$title\n$body' : title;
  NotificationItem markRead() => NotificationItem(
      id: id, title: title, type: type, body: body, isRead: true, createdAt: createdAt);
}

class VolunteerProfile {
  final String id, name, role, status;
  final String? email, region, phone, avatarUrl;
  final List<String> skills, availableDays;
  final DateTime? joinedAt;

  const VolunteerProfile({required this.id, required this.name, required this.role,
      required this.status, this.email, this.region, this.phone, this.avatarUrl,
      required this.skills, required this.availableDays, this.joinedAt});

  factory VolunteerProfile.fromJson(Map<String, dynamic> j) {
    List<String> arr(dynamic raw) {
      if (raw == null) return [];
      if (raw is List) return raw.map((e) => e.toString()).toList();
      if (raw is String) return raw.replaceAll(RegExp(r'[{}"]'), '')
          .split(',').where((s) => s.trim().isNotEmpty).map((s) => s.trim()).toList();
      return [];
    }
    return VolunteerProfile(
      id:            j['id'] as String,
      name:          (j['name'] ?? 'Volunteer') as String,
      email:         j['email'] as String?,
      role:          (j['role'] as String?) ?? 'volunteer',
      region:        j['region'] as String?,
      phone:         j['phone'] as String?,
      avatarUrl:     j['avatar_url'] as String?,
      skills:        arr(j['skills']),
      status:        (j['status'] as String?) ?? 'active',
      availableDays: arr(j['available_days']),
      joinedAt:      j['joined_at'] != null ? DateTime.parse(j['joined_at']) : null,
    );
  }

  bool get isActive => status == 'active';
  String get initials {
    final p = name.trim().split(' ');
    return p.length >= 2 ? '${p.first[0]}${p.last[0]}'.toUpperCase()
        : name.isNotEmpty ? name[0].toUpperCase() : 'V';
  }
  VolunteerProfile copyWith({String? status, String? avatarUrl}) => VolunteerProfile(
    id: id, name: name, email: email, role: role, region: region,
    phone: phone, skills: skills, availableDays: availableDays, joinedAt: joinedAt,
    status: status ?? this.status, avatarUrl: avatarUrl ?? this.avatarUrl,
  );
}

class ChatMessage {
  final String id, fromId, toId, text;
  final bool read;
  final DateTime createdAt;

  const ChatMessage({required this.id, required this.fromId, required this.toId,
      required this.text, required this.read, required this.createdAt});

  factory ChatMessage.fromJson(Map<String, dynamic> j) => ChatMessage(
    id:        j['id'] as String,
    fromId:    (j['from_id'] as String?) ?? '',
    toId:      (j['to_id'] as String?) ?? '',
    text:      (j['text'] as String?) ?? '',
    read:      (j['read'] as bool?) ?? false,
    createdAt: DateTime.parse(j['created_at'] as String),
  );
}
