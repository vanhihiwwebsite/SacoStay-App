import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../config/theme.dart';
import '../../core/chat/chat_hub_service.dart';
import '../../core/utils/media_url.dart';
import '../../features/auth/auth_provider.dart';
import '../../models/chat.dart';
import '../../repositories/chat_repository.dart';

String _formatListTime(String? raw) {
  if (raw == null || raw.isEmpty) return '';
  final dt = DateTime.tryParse(raw);
  if (dt == null) return raw;
  return DateFormat('HH:mm').format(dt.toLocal());
}

String _roleLabel(ChatParticipant? peer) {
  if (peer?.isLandlord ?? false) return 'Chủ trọ';
  return 'Người tìm trọ';
}

({Color bg, Color text}) _roleBadgeColors(ChatParticipant? peer) {
  if (peer?.isLandlord ?? false) {
    return (bg: Colors.orange.shade100, text: Colors.orange.shade800);
  }
  return (bg: Colors.blue.shade100, text: Colors.blue.shade800);
}

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
  bool _loadingList = true;
  bool _loadingMessages = false;
  bool _hubReady = false;
  bool _sending = false;
  bool _mobileThreadOpen = false;
  String? _error;
  bool _bootstrapped = false;

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

    final token = await ref.read(tokenStorageProvider).read();
    if (token != null && token.isNotEmpty) {
      try {
        await _hub.connect(token);
        _hub.onIncomingMessage((senderId, text) {
          if (_activeUserId != null &&
              senderId.toLowerCase() == _activeUserId!.toLowerCase()) {
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
        });
        setState(() => _hubReady = true);
      } catch (_) {
        setState(() => _hubReady = false);
      }
    }

    await _loadConversations();

    if (!mounted) return;
    final params = GoRouterState.of(context).uri.queryParameters;
    final withId = params['with'];
    if (withId != null && withId.isNotEmpty) {
      await _selectConversation(withId);
    }
  }

  Future<void> _loadConversations() async {
    setState(() => _loadingList = true);
    final list = await ref.read(chatRepositoryProvider).getConversations();
    list.sort((a, b) {
      final at = a.lastMessageAt ?? '';
      final bt = b.lastMessageAt ?? '';
      return bt.compareTo(at);
    });
    setState(() {
      _conversations = list;
      _loadingList = false;
    });
    for (final c in list) {
      _loadPeer(c.otherUserId);
    }
  }

  Future<void> _loadPeer(String userId) async {
    if (_peers.containsKey(userId)) return;
    final peer = await ref.read(chatRepositoryProvider).fetchPeer(userId);
    setState(() => _peers[userId] = peer);
  }

  Future<void> _selectConversation(String userId) async {
    final me = ref.read(authControllerProvider).user?.id;
    if (me == null) return;

    setState(() {
      _activeUserId = userId;
      _mobileThreadOpen = true;
      _loadingMessages = true;
      _messages = [];
    });
    await _loadPeer(userId);
    final msgs = await ref.read(chatRepositoryProvider).getHistory(userId, me);
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
      setState(() => _error = 'Đang kết nối chat… thử lại sau.');
      return;
    }

    setState(() {
      _sending = true;
      _error = null;
    });

    try {
      await _hub.sendPrivateMessage(peerId, text);
      _messageController.clear();
      final me = ref.read(authControllerProvider).user?.id ?? '';
      setState(() {
        _messages = [
          ..._messages,
          ChatMessage(
            id: 'local-${DateTime.now().millisecondsSinceEpoch}',
            senderId: me,
            text: text,
            isMine: true,
          ),
        ];
        _sending = false;
      });
      _scrollToBottom();
      await _loadConversations();
    } catch (e) {
      setState(() {
        _sending = false;
        _error = e.toString();
      });
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
            'Chưa có cuộc trò chuyện.\nMở chat từ Tìm bạn hoặc chi tiết phòng.',
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
                            color: Colors.green.shade500,
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
                                _roleLabel(peer),
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
                child: CircleAvatar(
                  radius: 18,
                  backgroundImage: NetworkImage(
                    peer?.avatarUrl ?? avatarFallbackUrl(peer?.displayName ?? 'U'),
                  ),
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
                          _roleLabel(peer),
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
                    _hubReady ? 'Đang hoạt động' : 'Đang kết nối…',
                    style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
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
