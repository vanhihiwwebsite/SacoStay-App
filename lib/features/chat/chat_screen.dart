import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../config/theme.dart';
import '../../config/environment.dart';
import '../../core/chat/chat_hub_service.dart';
import '../../core/storage/chat_contacts_storage.dart';
import '../../core/utils/media_url.dart';
import '../../core/utils/presence.dart';
import '../../features/auth/auth_provider.dart';
import '../../models/chat.dart';
import '../../models/shared_space.dart';
import '../../repositories/chat_repository.dart';
import '../../repositories/presence_repository.dart';
import '../../repositories/shared_space_repository.dart';

String _formatListTime(String? raw) {
  if (raw == null || raw.isEmpty) return '';
  final dt = DateTime.tryParse(raw);
  if (dt == null) return raw;
  return DateFormat('HH:mm').format(dt.toLocal());
}

String _roleLabel(ChatParticipant? peer, {required bool landlordShell}) {
  if (peer?.isLandlord ?? false) return 'Chủ trọ';
  if (landlordShell) return 'Người thuê';
  return 'Người tìm trọ';
}

({Color bg, Color text}) _roleBadgeColors(ChatParticipant? peer) {
  if (peer?.isLandlord ?? false) {
    return (bg: Colors.orange.shade100, text: Colors.orange.shade800);
  }
  return (bg: Colors.blue.shade100, text: Colors.blue.shade800);
}

bool _sameUserId(String a, String b) => a.trim().toLowerCase() == b.trim().toLowerCase();

class ChatScreen extends ConsumerStatefulWidget {
  const ChatScreen({super.key});

  @override
  ConsumerState<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends ConsumerState<ChatScreen> {
  final _hub = ChatHubService();
  final _messageController = TextEditingController();
  final _scrollController = ScrollController();

  List<ChatConversationSummary> _conversations = [];
  List<ChatMessage> _messages = [];
  final Map<String, ChatParticipant> _peers = {};
  String? _activeUserId;
  String? _currentUserId;
  bool _loadingList = true;
  bool _loadingMessages = false;
  bool _hubReady = false;
  bool _hubConnecting = false;
  bool _sending = false;
  bool _mobileThreadOpen = false;
  String? _error;
  bool _bootstrapped = false;
  List<SharedSpaceSummary> _sharedSpaces = [];
  bool _creatingSharedSpace = false;

  Timer? _convTimer;
  Timer? _msgTimer;
  Timer? _presenceTimer;

  bool get _isLandlordShell => ref.read(authControllerProvider).userRole == 'landlord';

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_bootstrapped) {
      _bootstrapped = true;
      _bootstrap();
    }
  }

  @override
  void dispose() {
    _convTimer?.cancel();
    _msgTimer?.cancel();
    _presenceTimer?.cancel();
    _messageController.dispose();
    _scrollController.dispose();
    _hub.disconnect();
    super.dispose();
  }

  Future<void> _bootstrap() async {
    final auth = ref.read(authControllerProvider);
    if (!auth.isLoggedIn) {
      setState(() => _loadingList = false);
      return;
    }

    _currentUserId = auth.user?.id;
    if (_currentUserId == null || _currentUserId!.isEmpty) {
      await ref.read(authControllerProvider.notifier).refreshProfile();
      _currentUserId = ref.read(authControllerProvider).user?.id;
    }

    await _loadStoredContacts();
    await _connectHub();
    await _loadConversations();
    _startPolling();
    if (!_isLandlordShell) {
      await _loadSharedSpaces();
    }

    if (!mounted) return;
    final params = GoRouterState.of(context).uri.queryParameters;
    final withId = params['with'];
    if (withId != null && withId.isNotEmpty) {
      _ensureConversation(
        withId,
        displayName: params['name'],
        avatarUrl: params['avatar'],
        role: params['role'],
      );
      await _selectConversation(withId);
    }
  }

  Future<void> _loadSharedSpaces() async {
    try {
      final spaces = await ref.read(sharedSpaceRepositoryProvider).listSpaces();
      if (mounted) setState(() => _sharedSpaces = spaces);
    } catch (_) {
      if (mounted) setState(() => _sharedSpaces = []);
    }
  }

  List<SharedSpaceSummary> _spacesWithPartner(String partnerId) {
    return _sharedSpaces.where((s) => _sameUserId(s.partnerId, partnerId)).toList();
  }

  bool _canShowSharedSpaceAction() {
    if (_isLandlordShell || _activeUserId == null) return false;
    final peer = _peers[_activeUserId!];
    return !(peer?.isLandlord ?? false);
  }

  bool _hasExistingSharedSpace() {
    final peerId = _activeUserId;
    if (peerId == null) return false;
    return _spacesWithPartner(peerId).isNotEmpty;
  }

  String? _activeSharedSpaceId() {
    final peerId = _activeUserId;
    if (peerId == null) return null;
    final spaces = _spacesWithPartner(peerId);
    return spaces.isEmpty ? null : spaces.first.id;
  }

  Future<void> _onSharedSpaceAction() async {
    final peerId = _activeUserId;
    if (peerId == null) return;

    if (_hasExistingSharedSpace()) {
      final spaceId = _activeSharedSpaceId();
      if (spaceId != null) {
        context.go('/shared-space?spaceId=${Uri.encodeComponent(spaceId)}');
      }
      return;
    }

    if (_creatingSharedSpace) return;
    setState(() => _creatingSharedSpace = true);
    try {
      final result = await ref.read(sharedSpaceRepositoryProvider).createSpace(peerId);
      await _loadSharedSpaces();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(result.message)));
        if (result.spaceId.isNotEmpty) {
          context.go('/shared-space?spaceId=${Uri.encodeComponent(result.spaceId)}');
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Không thể tạo không gian chung: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _creatingSharedSpace = false);
    }
  }

  void _startPolling() {
    _convTimer?.cancel();
    _msgTimer?.cancel();
    _presenceTimer?.cancel();

    _convTimer = Timer.periodic(const Duration(seconds: 20), (_) => _loadConversations());
    _msgTimer = Timer.periodic(const Duration(seconds: 12), (_) {
      if (_activeUserId != null) _reloadActiveMessages();
    });
    _presenceTimer = Timer.periodic(const Duration(seconds: 30), (_) => _refreshPresence());
    _refreshPresence();
  }

  Future<void> _connectHub() async {
    setState(() {
      _hubConnecting = true;
      _hubReady = false;
    });
    try {
      await _hub.connect(ref.read(tokenStorageProvider));
      _hub.onIncomingMessage(_handleIncomingMessage);
      if (mounted) {
        setState(() {
          _hubReady = true;
          _hubConnecting = false;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _hubReady = false;
          _hubConnecting = false;
        });
      }
    }
  }

  void _handleIncomingMessage(String senderId, String text) {
    if (text.trim().isEmpty || _currentUserId == null) return;

    if (_sameUserId(senderId, _currentUserId!)) {
      if (_activeUserId != null) _reloadActiveMessages();
      _loadConversations();
      return;
    }

    _ensureConversation(senderId);
    _updateConversationPreview(senderId, text);

    if (_activeUserId != null && _sameUserId(_activeUserId!, senderId)) {
      setState(() {
        _messages = [
          ..._messages,
          ChatMessage(
            id: 'live-${DateTime.now().millisecondsSinceEpoch}',
            senderId: senderId,
            text: text,
            isMine: false,
          ),
        ];
      });
      _scrollToBottom();
    }
    _loadConversations();
  }

  Future<void> _loadStoredContacts() async {
    final ownerId = _currentUserId;
    if (ownerId == null || ownerId.isEmpty) return;
    final stored = await ChatContactsStorage.load(ownerId);
    if (stored.isEmpty) return;
    setState(() {
      for (final c in stored) {
        _peers[c.id] = ChatParticipant(
          id: c.id,
          displayName: c.displayName,
          avatarUrl: c.avatarUrl,
          roles: c.role != null ? [c.role!] : const [],
        );
        _ensureConversation(
          c.id,
          displayName: c.displayName,
          avatarUrl: c.avatarUrl,
          role: c.role,
        );
      }
    });
  }

  void _ensureConversation(
    String userId, {
    String? displayName,
    String? avatarUrl,
    String? role,
  }) {
    final id = userId.trim();
    if (id.isEmpty) return;

    final cached = _peers[id];
    final name = (displayName != null && displayName.isNotEmpty)
        ? displayName
        : (cached?.displayName ?? 'Người dùng');
    final avatar = avatarUrl ?? cached?.avatarUrl;
    final roles = role != null ? [role] : (cached?.roles ?? const []);

    if (_currentUserId != null) {
      ChatContactsStorage.upsert(
        _currentUserId!,
        StoredChatContact(
          id: id,
          displayName: name,
          avatarUrl: avatar,
          role: role,
        ),
      );
    }

    _peers[id] = (cached ?? ChatParticipant(id: id, displayName: name)).copyWith(
      displayName: name,
      avatarUrl: avatar,
      roles: roles.isNotEmpty ? roles : (cached?.roles ?? const []),
    );

    if (_conversations.any((c) => _sameUserId(c.otherUserId, id))) return;
    setState(() {
      _conversations = [
        ChatConversationSummary(otherUserId: id, lastMessageText: '—'),
        ..._conversations,
      ];
    });
  }

  void _updateConversationPreview(String otherUserId, String text) {
    setState(() {
      _conversations = _conversations.map((c) {
        if (!_sameUserId(c.otherUserId, otherUserId)) return c;
        return ChatConversationSummary(
          otherUserId: c.otherUserId,
          lastMessageText: text,
          lastMessageAt: DateTime.now().toUtc().toIso8601String(),
        );
      }).toList();
    });
  }

  Future<void> _loadConversations() async {
    final list = await ref.read(chatRepositoryProvider).getConversations();
    list.sort((a, b) {
      final at = a.lastMessageAt ?? '';
      final bt = b.lastMessageAt ?? '';
      return bt.compareTo(at);
    });

    if (!mounted) return;
    setState(() {
      for (final c in list) {
        _ensureConversation(c.otherUserId);
        final idx = _conversations.indexWhere(
          (x) => _sameUserId(x.otherUserId, c.otherUserId),
        );
        if (idx >= 0) {
          _conversations[idx] = c;
        } else {
          _conversations.add(c);
        }
      }
      _conversations.sort((a, b) {
        final at = a.lastMessageAt ?? '';
        final bt = b.lastMessageAt ?? '';
        return bt.compareTo(at);
      });
      _loadingList = false;
    });

    for (final c in list) {
      _loadPeer(c.otherUserId);
    }
  }

  Future<void> _loadPeer(String userId) async {
    if (_peers.containsKey(userId) && _peers[userId]!.displayName != 'Người dùng') {
      return;
    }
    final peer = await ref.read(chatRepositoryProvider).fetchPeer(userId);
    if (!mounted) return;
    setState(() {
      _peers[userId] = _peers[userId]?.copyWith(
            displayName: peer.displayName,
            avatarUrl: peer.avatarUrl,
            roles: peer.roles,
          ) ??
          peer;
    });
  }

  Future<void> _refreshPresence() async {
    final ids = _conversations.map((c) => c.otherUserId).toList();
    if (_activeUserId != null &&
        !ids.any((id) => _sameUserId(id, _activeUserId!))) {
      ids.add(_activeUserId!);
    }
    if (ids.isEmpty) return;

    final items = await ref.read(presenceRepositoryProvider).fetchPresence(ids);
    if (!mounted) return;
    setState(() {
      for (final p in items) {
        final peer = _peers[p.userId];
        if (peer != null) {
          _peers[p.userId] = peer.copyWith(
            isOnline: p.isOnline,
            lastSeenAt: p.lastSeenAt,
          );
        }
      }
    });
  }

  Future<void> _selectConversation(String userId) async {
    final me = _currentUserId;
    if (me == null) return;

    _ensureConversation(userId);
    setState(() {
      _activeUserId = userId;
      _mobileThreadOpen = true;
      _loadingMessages = true;
      _messages = [];
      _error = null;
    });
    await _loadPeer(userId);
    await _reloadActiveMessages();
    _refreshPresence();
  }

  Future<void> _reloadActiveMessages() async {
    final peerId = _activeUserId;
    final me = _currentUserId;
    if (peerId == null || me == null) return;

    final msgs = await ref.read(chatRepositoryProvider).getHistory(peerId, me);
    if (!mounted || _activeUserId != peerId) return;
    setState(() {
      _messages = msgs;
      _loadingMessages = false;
    });
    _scrollToBottom();
  }

  Future<void> _sendMessage() async {
    final text = _messageController.text.trim();
    final peerId = _activeUserId;
    if (text.isEmpty || peerId == null || _sending) return;

    if (!_hubReady) {
      setState(() {
        _error = _hubConnecting
            ? 'Đang kết nối chat… thử lại sau vài giây.'
            : 'Chưa kết nối máy chủ chat (${Environment.chatHubUrl}). Đang thử lại…';
      });
      if (!_hubConnecting) await _connectHub();
      return;
    }

    setState(() {
      _sending = true;
      _error = null;
    });

    try {
      await _hub.sendPrivateMessage(peerId, text);
      _messageController.clear();
      await _reloadActiveMessages();
      _updateConversationPreview(peerId, text);
      await _loadConversations();
      if (mounted) setState(() => _sending = false);
    } catch (e) {
      setState(() {
        _sending = false;
        _hubReady = false;
        _error = 'Gửi tin nhắn thất bại. Kiểm tra kết nối chat hub.';
      });
      await _connectHub();
    }
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeOut,
        );
      }
    });
  }

  bool _peerIsOnline(ChatParticipant? peer) => peer?.isOnline ?? false;

  String _peerPresenceText(ChatParticipant? peer) {
    if (peer == null) return '';
    return presenceLabel(isOnline: peer.isOnline, lastSeenAt: peer.lastSeenAt);
  }

  @override
  Widget build(BuildContext context) {
    final auth = ref.watch(authControllerProvider);
    if (!auth.isLoggedIn) {
      return Center(
        child: FilledButton(
          onPressed: () => context.go('/login?returnUrl=/chat'),
          child: const Text('Đăng nhập để dùng tin nhắn'),
        ),
      );
    }

    final isWide = MediaQuery.sizeOf(context).width >= 720;

    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: Colors.orange.shade50),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.06),
              blurRadius: 24,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(24),
          child: isWide
              ? Row(
                  children: [
                    SizedBox(width: 300, child: _buildListColumn()),
                    Expanded(child: _buildThreadColumn(showBack: false)),
                  ],
                )
              : _mobileThreadOpen && _activeUserId != null
                  ? _buildThreadColumn(showBack: true)
                  : _buildListColumn(),
        ),
      ),
    );
  }

  Widget _buildListColumn() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
          child: Text(
            'Tin nhắn',
            style: TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 16,
              color: SacoColors.sacoBlue,
            ),
          ),
        ),
        const Divider(height: 1),
        Expanded(child: _buildConversationList()),
      ],
    );
  }

  Widget _buildThreadColumn({required bool showBack}) {
    if (_activeUserId == null) {
      return Center(
        child: Text(
          'Chọn một cuộc trò chuyện',
          style: TextStyle(color: Colors.grey.shade600),
        ),
      );
    }
    return Column(
      children: [
        _buildThreadHeader(showBack: showBack),
        if (_canShowSharedSpaceAction())
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 8, 12, 0),
            child: SizedBox(
              width: double.infinity,
              child: OutlinedButton(
                onPressed: _creatingSharedSpace ? null : _onSharedSpaceAction,
                style: OutlinedButton.styleFrom(
                  foregroundColor:
                      _hasExistingSharedSpace() ? Colors.green.shade700 : SacoColors.sacoOrange,
                  backgroundColor:
                      _hasExistingSharedSpace() ? Colors.green.shade50 : SacoColors.pageBackground,
                  side: BorderSide(
                    color: _hasExistingSharedSpace() ? Colors.green : SacoColors.sacoOrange,
                  ),
                ),
                child: Text(
                  _creatingSharedSpace
                      ? 'Đang xử lý…'
                      : _hasExistingSharedSpace()
                          ? 'Không gian chung'
                          : 'Tạo không gian chung',
                ),
              ),
            ),
          ),
        Expanded(child: _buildMessageList()),
        if (_error != null)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: Text(_error!, style: const TextStyle(color: Colors.red, fontSize: 12)),
          ),
        _buildInput(),
      ],
    );
  }

  Widget _buildConversationList() {
    if (_loadingList) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_conversations.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Text(
            _isLandlordShell
                ? 'Chưa có cuộc trò chuyện.\nMở từ Người xem tin hoặc khi người thuê nhắn cho bạn.'
                : 'Chưa có cuộc trò chuyện.\nMở chat từ Tìm bạn hoặc chi tiết phòng.',
            textAlign: TextAlign.center,
            style: TextStyle(color: Colors.grey.shade600, fontSize: 13),
          ),
        ),
      );
    }
    return ListView.builder(
      itemCount: _conversations.length,
      itemBuilder: (_, i) {
        final c = _conversations[i];
        final peer = _peers[c.otherUserId];
        final name = peer?.displayName ?? 'Người dùng';
        final avatar = peer?.avatarUrl ?? avatarFallbackUrl(name);
        final selected = _activeUserId == c.otherUserId;
        final badge = _roleBadgeColors(peer);
        final online = _peerIsOnline(peer);
        return Material(
          color: selected ? Colors.orange.shade50 : Colors.white,
          child: InkWell(
            onTap: () => _selectConversation(c.otherUserId),
            child: Container(
              decoration: BoxDecoration(
                border: selected
                    ? Border(right: BorderSide(color: SacoColors.sacoOrange, width: 2))
                    : null,
              ),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              child: Row(
                children: [
                  Stack(
                    children: [
                      CircleAvatar(
                        radius: 24,
                        backgroundImage: NetworkImage(avatar),
                      ),
                      Positioned(
                        right: 0,
                        bottom: 0,
                        child: Container(
                          width: 12,
                          height: 12,
                          decoration: BoxDecoration(
                            color: online ? Colors.green.shade500 : Colors.grey.shade400,
                            shape: BoxShape.circle,
                            border: Border.all(color: Colors.white, width: 2),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Flexible(
                              child: Text(
                                name,
                                style: const TextStyle(
                                  fontWeight: FontWeight.w600,
                                  color: SacoColors.sacoBlue,
                                ),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            const SizedBox(width: 6),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(
                                color: badge.bg,
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: Text(
                                _roleLabel(peer, landlordShell: _isLandlordShell),
                                style: TextStyle(
                                  fontSize: 10,
                                  fontWeight: FontWeight.bold,
                                  color: badge.text,
                                ),
                              ),
                            ),
                            if (c.lastMessageAt != null && c.lastMessageAt!.isNotEmpty) ...[
                              const SizedBox(width: 4),
                              Text(
                                _formatListTime(c.lastMessageAt),
                                style: TextStyle(fontSize: 11, color: Colors.grey.shade400),
                              ),
                            ],
                          ],
                        ),
                        const SizedBox(height: 4),
                        Text(
                          c.lastMessageText ?? '—',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(fontSize: 13, color: Colors.grey.shade600),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildThreadHeader({required bool showBack}) {
    final peer = _activeUserId != null ? _peers[_activeUserId!] : null;
    final badge = _roleBadgeColors(peer);
    final presence = _peerPresenceText(peer);
    return Material(
      color: Colors.white,
      child: Container(
        decoration: BoxDecoration(
          border: Border(bottom: BorderSide(color: Colors.grey.shade100)),
        ),
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        child: Row(
          children: [
            if (showBack)
              IconButton(
                icon: const Icon(Icons.arrow_back),
                onPressed: () => setState(() => _mobileThreadOpen = false),
              )
            else
              Padding(
                padding: const EdgeInsets.only(left: 8, right: 4),
                child: Stack(
                  children: [
                    CircleAvatar(
                      radius: 18,
                      backgroundImage: NetworkImage(
                        peer?.avatarUrl ?? avatarFallbackUrl(peer?.displayName ?? 'U'),
                      ),
                    ),
                    Positioned(
                      right: 0,
                      bottom: 0,
                      child: Container(
                        width: 10,
                        height: 10,
                        decoration: BoxDecoration(
                          color: _peerIsOnline(peer)
                              ? Colors.green.shade500
                              : Colors.grey.shade400,
                          shape: BoxShape.circle,
                          border: Border.all(color: Colors.white, width: 1.5),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Flexible(
                        child: Text(
                          peer?.displayName ?? 'Tin nhắn',
                          style: const TextStyle(fontWeight: FontWeight.w600),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      const SizedBox(width: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: badge.bg,
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Text(
                          _roleLabel(peer, landlordShell: _isLandlordShell),
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                            color: badge.text,
                          ),
                        ),
                      ),
                    ],
                  ),
                  Text(
                    presence.isNotEmpty
                        ? presence
                        : (_hubConnecting
                            ? 'Đang kết nối…'
                            : (_hubReady ? 'Đang hoạt động' : 'Offline')),
                    style: TextStyle(
                      fontSize: 12,
                      color: _peerIsOnline(peer) ? Colors.green.shade700 : Colors.grey.shade600,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMessageList() {
    if (_loadingMessages) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_messages.isEmpty) {
      return Center(
        child: Text(
          'Chưa có tin nhắn. Hãy gửi lời chào!',
          style: TextStyle(color: Colors.grey.shade600, fontSize: 13),
        ),
      );
    }
    return ListView.builder(
      controller: _scrollController,
      padding: const EdgeInsets.all(16),
      itemCount: _messages.length,
      itemBuilder: (_, i) {
        final m = _messages[i];
        return Align(
          alignment: m.isMine ? Alignment.centerRight : Alignment.centerLeft,
          child: Container(
            margin: const EdgeInsets.only(bottom: 8),
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            constraints: BoxConstraints(
              maxWidth: MediaQuery.sizeOf(context).width * 0.75,
            ),
            decoration: BoxDecoration(
              color: m.isMine ? SacoColors.sacoOrange : Colors.grey.shade100,
              borderRadius: BorderRadius.circular(16),
            ),
            child: Text(
              m.text,
              style: TextStyle(
                color: m.isMine ? Colors.white : Colors.black87,
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildInput() {
    return Material(
      color: Colors.white,
      child: Container(
        decoration: BoxDecoration(
          border: Border(top: BorderSide(color: Colors.grey.shade100)),
        ),
        child: SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _messageController,
                    decoration: InputDecoration(
                      hintText: 'Nhập tin nhắn…',
                      filled: true,
                      fillColor: Colors.grey.shade50,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(24),
                        borderSide: BorderSide.none,
                      ),
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 10,
                      ),
                    ),
                    onSubmitted: (_) => _sendMessage(),
                  ),
                ),
                const SizedBox(width: 8),
                IconButton.filled(
                  onPressed: _sending ? null : _sendMessage,
                  style: IconButton.styleFrom(
                    backgroundColor: SacoColors.sacoOrange,
                  ),
                  icon: _sending
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : const Icon(Icons.send, color: Colors.white, size: 20),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
