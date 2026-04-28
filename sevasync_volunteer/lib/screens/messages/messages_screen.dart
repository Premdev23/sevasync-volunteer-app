import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../theme/app_theme.dart';
import '../../../models/models.dart';
import '../../../services/volunteer_service.dart';

class MessagesScreen extends StatefulWidget {
  /// Called whenever unread count changes so MainShell badge updates instantly
  final void Function(int remaining)? onUnreadChanged;
  const MessagesScreen({super.key, this.onUnreadChanged});
  @override
  State<MessagesScreen> createState() => _MessagesScreenState();
}

class _MessagesScreenState extends State<MessagesScreen> {
  bool _loading = true;
  String? _error;
  List<AdminConversation> _convos = [];
  AdminConversation? _selected;
  final _msgCtrl = TextEditingController();
  final _scrollCtrl = ScrollController();
  bool _sending = false;
  String _search = '';

  String get _uid => Supabase.instance.client.auth.currentUser!.id;

  List<AdminConversation> get _filtered => _search.isEmpty ? _convos
      : _convos.where((c) => c.admin.name.toLowerCase().contains(_search.toLowerCase())).toList();

  int get _totalUnread => _convos.fold(0, (s, c) => s + c.unreadCount);

  @override
  void initState() { super.initState(); _load(); }

  @override
  void dispose() { _msgCtrl.dispose(); _scrollCtrl.dispose(); super.dispose(); }

  Future<void> _load() async {
    setState(() { _loading = true; _error = null; });
    try {
      final convos = await VolunteerService.getConversations();
      if (!mounted) return;
      setState(() => _convos = convos);
      // Re-select if already had one open
      if (_selected != null) {
        final updated = convos.where((c) => c.admin.id == _selected!.admin.id);
        if (updated.isNotEmpty) setState(() => _selected = updated.first);
      }
    } catch (e) {
      if (mounted) setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _selectAdmin(AdminConversation convo) async {
    setState(() => _selected = convo);
    // Immediately zero-out unread count locally so badge updates instantly
    _clearUnreadLocally(convo.admin.id);
    // Then persist to DB
    await VolunteerService.markMessagesRead(convo.admin.id);
    _scrollToBottom();
  }

  /// Update local state immediately so bottom nav badge drops to 0 without
  /// waiting for the next 15-second polling cycle
  void _clearUnreadLocally(String adminId) {
    final updated = _convos.map((c) {
      if (c.admin.id != adminId) return c;
      final readMsgs = c.messages.map((m) =>
        m.fromId == adminId
            ? ChatMessage(id: m.id, fromId: m.fromId, toId: m.toId,
                text: m.text, read: true, createdAt: m.createdAt)
            : m
      ).toList();
      return AdminConversation(admin: c.admin, messages: readMsgs, unreadCount: 0);
    }).toList();

    setState(() => _convos = updated);

    // Notify MainShell with remaining total unread so badge updates instantly
    final remaining = updated.fold(0, (s, c) => s + c.unreadCount);
    widget.onUnreadChanged?.call(remaining);
  }

  Future<void> _sendMessage() async {
    final text = _msgCtrl.text.trim();
    if (text.isEmpty || _selected == null || _sending) return;
    setState(() => _sending = true);
    _msgCtrl.clear();
    try {
      await VolunteerService.sendMessage(_selected!.admin.id, text);
      await _load();
      _scrollToBottom();
    } catch (_) {}
    finally { if (mounted) setState(() => _sending = false); }
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollCtrl.hasClients) {
        _scrollCtrl.animateTo(_scrollCtrl.position.maxScrollExtent,
            duration: const Duration(milliseconds: 300), curve: Curves.easeOut);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
          Row(children: [
            const Text('💬 ', style: TextStyle(fontSize: 16)),
            const Text('Support Center', style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800)),
          ]),
          Text('Communicate directly with ${_convos.length} Admin(s)',
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
              ? _buildError()
              : LayoutBuilder(builder: (ctx, constraints) {
                  final wide = constraints.maxWidth > 600;
                  if (wide) {
                    return Row(children: [
                      SizedBox(width: 300, child: _adminList()),
                      const VerticalDivider(width: 1),
                      Expanded(child: _chatPanel()),
                    ]);
                  }
                  return _selected == null ? _adminList() : _chatPanel();
                }),
    );
  }

  // ── Admin list ────────────────────────────────────────────────────────────
  Widget _adminList() {
    return Column(children: [
      // Search
      Padding(
        padding: const EdgeInsets.all(12),
        child: TextField(
          onChanged: (v) => setState(() => _search = v),
          decoration: const InputDecoration(
            hintText: 'Search admins...',
            prefixIcon: Icon(Icons.search, size: 18, color: AppColors.textSecondary),
            contentPadding: EdgeInsets.symmetric(vertical: 10),
          ),
        ),
      ),
      Expanded(child: _filtered.isEmpty
          ? const Center(child: Text('No admins found',
              style: TextStyle(color: AppColors.textSecondary)))
          : ListView.separated(
              itemCount: _filtered.length,
              separatorBuilder: (_, __) => const Divider(height: 0),
              itemBuilder: (_, i) => _adminTile(_filtered[i]),
            )),
    ]);
  }

  Widget _adminTile(AdminConversation convo) {
    final isSelected = _selected?.admin.id == convo.admin.id;
    final last = convo.lastMessage;
    return InkWell(
      onTap: () => _selectAdmin(convo),
      child: Container(
        color: isSelected ? AppColors.tealLight : Colors.transparent,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Row(children: [
          _avatar(convo.admin),
          const SizedBox(width: 12),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              Expanded(child: Text(convo.admin.name,
                  style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13,
                      color: isSelected ? AppColors.teal : AppColors.textPrimary))),
              if (last != null) Text(_timeAgo(last.createdAt),
                  style: const TextStyle(fontSize: 11, color: AppColors.textSecondary)),
            ]),
            const SizedBox(height: 2),
            Row(children: [
              Expanded(child: Text(
                last != null ? last.text : 'Start conversation',
                style: TextStyle(fontSize: 12, color: AppColors.textSecondary,
                    fontWeight: convo.unreadCount > 0 ? FontWeight.w600 : FontWeight.normal),
                maxLines: 1, overflow: TextOverflow.ellipsis)),
              if (convo.unreadCount > 0) Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: const BoxDecoration(color: AppColors.teal, shape: BoxShape.circle),
                child: Text('${convo.unreadCount}',
                    style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.w700))),
            ]),
          ])),
        ]),
      ),
    );
  }

  // ── Chat panel ────────────────────────────────────────────────────────────
  Widget _chatPanel() {
    if (_selected == null) {
      return Container(color: AppColors.background,
        child: const Center(child: Column(mainAxisSize: MainAxisSize.min, children: [
          Text('💬', style: TextStyle(fontSize: 48)),
          SizedBox(height: 12),
          Text('Admin Support', style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700,
              color: AppColors.textPrimary)),
          SizedBox(height: 6),
          Text('Select an admin to request resources or provide updates',
              textAlign: TextAlign.center,
              style: TextStyle(color: AppColors.textSecondary, fontSize: 13)),
        ])));
    }

    final msgs = _selected!.messages;

    return Column(children: [
      // Chat header
      Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: const BoxDecoration(
          color: AppColors.surface,
          border: Border(bottom: BorderSide(color: AppColors.border))),
        child: Row(children: [
          // Back button on mobile
          if (MediaQuery.of(context).size.width < 600)
            IconButton(onPressed: () => setState(() => _selected = null),
                icon: const Icon(Icons.arrow_back, size: 20)),
          _avatar(_selected!.admin),
          const SizedBox(width: 12),
          Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(_selected!.admin.name,
                style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14)),
            const Text('Admin Support',
                style: TextStyle(color: AppColors.teal, fontSize: 12, fontWeight: FontWeight.w600)),
          ]),
        ]),
      ),

      // Messages
      Expanded(child: msgs.isEmpty
          ? const Center(child: Text('No messages yet. Say hello! 👋',
              style: TextStyle(color: AppColors.textSecondary, fontSize: 13)))
          : ListView.builder(
              controller: _scrollCtrl,
              padding: const EdgeInsets.all(16),
              itemCount: msgs.length,
              itemBuilder: (_, i) => _messageBubble(msgs[i]),
            )),

      // Input bar
      Container(
        padding: const EdgeInsets.all(12),
        decoration: const BoxDecoration(
          color: AppColors.surface,
          border: Border(top: BorderSide(color: AppColors.border))),
        child: Row(children: [
          Expanded(child: TextField(
            controller: _msgCtrl,
            textInputAction: TextInputAction.send,
            onSubmitted: (_) => _sendMessage(),
            maxLines: null,
            decoration: InputDecoration(
              hintText: 'Type a message...',
              contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(24),
                  borderSide: const BorderSide(color: AppColors.border)),
              enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(24),
                  borderSide: const BorderSide(color: AppColors.border)),
              focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(24),
                  borderSide: const BorderSide(color: AppColors.teal, width: 2)),
              fillColor: AppColors.surface2,
            ),
          )),
          const SizedBox(width: 8),
          GestureDetector(
            onTap: _sendMessage,
            child: Container(
              padding: const EdgeInsets.all(12),
              decoration: const BoxDecoration(color: AppColors.teal, shape: BoxShape.circle),
              child: _sending
                  ? const SizedBox(width: 18, height: 18,
                      child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                  : const Icon(Icons.send_rounded, color: Colors.white, size: 18)),
          ),
        ]),
      ),
    ]);
  }

  Widget _messageBubble(ChatMessage msg) {
    final isMine = msg.fromId == _uid;
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        mainAxisAlignment: isMine ? MainAxisAlignment.end : MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          if (!isMine) ...[
            _avatar(_selected!.admin, size: 28),
            const SizedBox(width: 8),
          ],
          Column(
            crossAxisAlignment: isMine ? CrossAxisAlignment.end : CrossAxisAlignment.start,
            children: [
              // ← Now calls _buildBubble which renders images, proof cards etc.
              _buildBubble(context, msg, isMine),
              const SizedBox(height: 3),
              Text(_timeLabel(msg.createdAt),
                  style: const TextStyle(fontSize: 10, color: AppColors.textSecondary)),
            ]),
        ],
      ),
    );
  }

  Widget _buildBubble(BuildContext ctx, ChatMessage msg, bool isMine) {
    final maxW = MediaQuery.of(ctx).size.width * 0.62;
    final bubbleColor = isMine ? AppColors.teal : AppColors.surface;
    final textColor   = isMine ? Colors.white : AppColors.textPrimary;
    final border      = isMine ? null : Border.all(color: AppColors.border);
    final radius = BorderRadius.only(
      topLeft: const Radius.circular(16), topRight: const Radius.circular(16),
      bottomLeft: Radius.circular(isMine ? 16 : 4),
      bottomRight: Radius.circular(isMine ? 4 : 16));

    // Detect [PROOF_OF_WORK] message with [IMG:url] — show special card
    if (msg.text.startsWith('[PROOF_OF_WORK]')) {
      final imgMatch = RegExp(r'\[IMG:(https?://[^\]]+)\]').firstMatch(msg.text);
      final imgUrl   = imgMatch?.group(1);
      final noteText = msg.text
          .replaceFirst('[PROOF_OF_WORK]', '')
          .replaceAll(RegExp(r'\[IMG:[^\]]+\]'), '')
          .trim();

      return Container(
        constraints: BoxConstraints(maxWidth: maxW),
        decoration: BoxDecoration(color: bubbleColor, borderRadius: radius, border: border,
            boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 4)]),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          // Header tag
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: isMine ? Colors.white.withOpacity(0.15) : AppColors.orangeLight,
              borderRadius: const BorderRadius.vertical(top: Radius.circular(16))),
            child: Row(mainAxisSize: MainAxisSize.min, children: [
              const Text('📋 ', style: TextStyle(fontSize: 11)),
              Text('PROOF OF WORK',
                  style: TextStyle(fontSize: 10, fontWeight: FontWeight.w800,
                      color: isMine ? Colors.white : AppColors.orange)),
            ])),
          Padding(
            padding: const EdgeInsets.all(12),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(noteText, style: TextStyle(fontSize: 13, color: textColor, height: 1.4)),
              // Show image if present
              if (imgUrl != null) ...[
                const SizedBox(height: 8),
                ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: Image.network(imgUrl,
                    width: maxW - 24, fit: BoxFit.cover,
                    loadingBuilder: (_, child, progress) => progress == null ? child
                        : Container(height: 100, color: Colors.black12,
                            child: const Center(child: CircularProgressIndicator(strokeWidth: 2))),
                    errorBuilder: (_, __, ___) => Container(
                      height: 60, color: Colors.black12,
                      child: Center(child: Text('Image unavailable',
                          style: TextStyle(fontSize: 11, color: textColor.withOpacity(0.6))))),
                  )),
              ],
            ])),
        ]));
    }

    // Detect [VERIFICATION_APPROVED] / [VERIFICATION_REJECTED]
    if (msg.text.contains('[VERIFICATION_APPROVED]') || msg.text.contains('VERIFIED')) {
      return Container(
        constraints: BoxConstraints(maxWidth: maxW),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(color: AppColors.greenLight, borderRadius: radius,
            border: Border.all(color: AppColors.green.withOpacity(0.3))),
        child: Row(children: [
          const Text('✅ ', style: TextStyle(fontSize: 14)),
          Expanded(child: Text(msg.text.replaceAll('[VERIFICATION_APPROVED]', '').trim(),
              style: const TextStyle(fontSize: 13, color: AppColors.green, fontWeight: FontWeight.w600))),
        ]));
    }

    if (msg.text.contains('[VERIFICATION_REJECTED]') || msg.text.contains('REJECTED')) {
      return Container(
        constraints: BoxConstraints(maxWidth: maxW),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(color: AppColors.redLight, borderRadius: radius,
            border: Border.all(color: AppColors.red.withOpacity(0.3))),
        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Text('❌ ', style: TextStyle(fontSize: 14)),
          Expanded(child: Text(msg.text.replaceAll('[VERIFICATION_REJECTED]', '').trim(),
              style: const TextStyle(fontSize: 13, color: AppColors.red, fontWeight: FontWeight.w600))),
        ]));
    }

    // Default bubble
    return Container(
      constraints: BoxConstraints(maxWidth: maxW),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(color: bubbleColor, borderRadius: radius, border: border,
          boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04),
              blurRadius: 4, offset: const Offset(0, 1))]),
      child: Text(msg.text, style: TextStyle(fontSize: 13, color: textColor, height: 1.4)));
  }

  Widget _avatar(VolunteerProfile p, {double size = 36}) {
    return Container(
      width: size, height: size,
      decoration: const BoxDecoration(
        gradient: LinearGradient(colors: [AppColors.teal, AppColors.green], begin: Alignment.topLeft, end: Alignment.bottomRight),
        shape: BoxShape.circle),
      child: Center(child: Text(p.initials,
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.w800,
              fontSize: size * 0.38))));
  }

  Widget _buildError() => Center(child: Padding(padding: const EdgeInsets.all(24),
    child: Column(mainAxisSize: MainAxisSize.min, children: [
      const Icon(Icons.wifi_off_outlined, color: AppColors.textSecondary, size: 48),
      const SizedBox(height: 12),
      const Text('Could not load messages', style: TextStyle(fontWeight: FontWeight.w700)),
      const SizedBox(height: 6),
      Text(_error!, textAlign: TextAlign.center,
          style: const TextStyle(color: AppColors.textSecondary, fontSize: 12)),
      const SizedBox(height: 16),
      ElevatedButton.icon(onPressed: _load,
          icon: const Icon(Icons.refresh, size: 16), label: const Text('Retry')),
    ])));

  String _timeAgo(DateTime dt) {
    final diff = DateTime.now().difference(dt);
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    return '${diff.inDays}d ago';
  }

  String _timeLabel(DateTime dt) {
    final now = DateTime.now();
    if (dt.day == now.day) return '${dt.hour.toString().padLeft(2,'0')}:${dt.minute.toString().padLeft(2,'0')}';
    final diff = now.difference(dt);
    if (diff.inDays == 1) return 'Yesterday';
    if (diff.inDays < 7) return ['Mon','Tue','Wed','Thu','Fri','Sat','Sun'][dt.weekday - 1];
    return '${dt.day} ${['Jan','Feb','Mar','Apr','May','Jun','Jul','Aug','Sep','Oct','Nov','Dec'][dt.month-1]}';
  }
}
