import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../config/theme.dart';
import '../../core/utils/discovery_filters.dart';
import '../../core/utils/lifestyle_display.dart';
import '../../core/utils/media_url.dart';
import '../../models/lifestyle.dart';
import '../../repositories/lifestyle_repository.dart';
import 'widgets/discovery_filter_panel.dart';
import 'widgets/tenant_room_details_view.dart';

class DiscoveryScreen extends ConsumerStatefulWidget {
  const DiscoveryScreen({super.key});

  @override
  ConsumerState<DiscoveryScreen> createState() => _DiscoveryScreenState();
}

class _DiscoveryScreenState extends ConsumerState<DiscoveryScreen> {
  bool _loading = true;
  bool _needsQuiz = false;
  bool _deckEmpty = false;
  List<DiscoveryCard> _deck = [];
  List<DiscoveryCard> _allCards = [];
  DiscoveryFilters _activeFilters = defaultDiscoveryFilters;
  bool _showFilters = false;
  DiscoveryCard? _tenantRoomCard;
  List<WishlistItem> _wishlist = [];
  SwipeQuota _quota = const SwipeQuota(
    isPremium: false,
    weeklyLimit: 5,
    usedThisWeek: 0,
    remaining: 5,
    weekResetAt: '',
  );
  int _currentIndex = 0;
  double _dragX = 0;
  bool _swipeAnimating = false;
  bool _showWishlist = false;
  bool _showProfile = false;
  int _photoIndex = 0;

  @override
  void initState() {
    super.initState();
    _bootstrap();
  }

  Future<void> _bootstrap() async {
    setState(() => _loading = true);
    final repo = ref.read(lifestyleRepositoryProvider);
    final completed = await repo.hasCompletedQuiz();
    if (!completed) {
      setState(() {
        _needsQuiz = true;
        _loading = false;
      });
      return;
    }
    await _loadDeck();
  }

  Future<void> _loadDeck() async {
    final repo = ref.read(lifestyleRepositoryProvider);
    setState(() => _loading = true);
    try {
      final deck = await repo.getSwipeDeck(limit: 50, includeSwiped: true);
      final wishlist = await repo.getMyLikes();
      final quota = await repo.getSwipeQuota();
      final enriched = await Future.wait(deck.map(repo.enrichCard));
      enriched.sort((a, b) => b.matchingScore.compareTo(a.matchingScore));
      setState(() {
        _allCards = enriched;
        _deck = _applyFilters(enriched, _activeFilters);
        _wishlist = wishlist;
        _quota = quota;
        _currentIndex = 0;
        _deckEmpty = _deck.isEmpty;
        _needsQuiz = false;
        _loading = false;
      });
    } catch (_) {
      setState(() {
        _loading = false;
        _deckEmpty = true;
      });
    }
  }

  List<DiscoveryCard> _applyFilters(
    List<DiscoveryCard> cards,
    DiscoveryFilters filters,
  ) {
    return cards.where((c) => matchesDiscoveryFilters(c, filters)).toList();
  }

  void _onApplyFilters(DiscoveryFilters filters) {
    setState(() {
      _activeFilters = filters;
      _deck = _applyFilters(_allCards, filters);
      _currentIndex = 0;
      _deckEmpty = _deck.isEmpty;
      _showFilters = false;
      _photoIndex = 0;
    });
  }

  DiscoveryCard? get _current => _deck.isNotEmpty && _currentIndex < _deck.length
      ? _deck[_currentIndex]
      : null;

  int get _remainingSwipes {
    if (_quota.isPremium) return 999;
    return _quota.remaining ?? 0;
  }

  Future<void> _commitSwipe(bool isLike) async {
    if (!_quota.isPremium && _remainingSwipes <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Bạn đã hết lượt swipe tuần này.')),
      );
      return;
    }
    final card = _current;
    if (card == null || _swipeAnimating) return;

    setState(() {
      _swipeAnimating = true;
      _dragX = isLike ? 400 : -400;
    });

    final repo = ref.read(lifestyleRepositoryProvider);
    await repo.swipeUser(card.userId, isLike);
    if (isLike) {
      final wishlist = await repo.getMyLikes();
      setState(() => _wishlist = wishlist);
    }
    final quota = await repo.getSwipeQuota();
    await Future.delayed(const Duration(milliseconds: 280));

    setState(() {
      _quota = quota;
      _currentIndex += 1;
      _dragX = 0;
      _swipeAnimating = false;
      _photoIndex = 0;
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_needsQuiz) return _QuizGate(onStart: () => context.go('/lifestyle-quiz?returnUrl=/discovery'));
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_deckEmpty || _current == null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                'Chưa có người để gợi ý',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              Text(
                'Thử tải lại hoặc hoàn thành trắc nghiệm lối sống.',
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.grey.shade600),
              ),
              const SizedBox(height: 16),
              FilledButton(
                onPressed: _loadDeck,
                style: FilledButton.styleFrom(backgroundColor: SacoColors.sacoOrange),
                child: const Text('Tải lại'),
              ),
            ],
          ),
        ),
      );
    }

    final card = _current!;
    final likeOpacity = (_dragX / 100).clamp(0.0, 1.0);
    final passOpacity = (-_dragX / 100).clamp(0.0, 1.0);
    final cardImage = card.imageAt(_photoIndex);
    final titleLine = cardTitleLine(card);
    final metaLine = cardMetaLine(card);

    return Stack(
      children: [
        Column(
          children: [
            if (!_quota.isPremium)
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 6, 16, 0),
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.orange.shade200, width: 2),
                  ),
                  child: Text(
                    '⚡ Còn ${_quota.isPremium ? "∞" : _remainingSwipes} lượt swipe tuần này',
                    textAlign: TextAlign.center,
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
                  ),
                ),
              ),
            Expanded(
              child: Center(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
                  child: GestureDetector(
                    onTap: () {
                      if (card.profileImageUrls.length > 1) {
                        setState(() {
                          _photoIndex =
                              (_photoIndex + 1) % card.profileImageUrls.length;
                        });
                      }
                    },
                    onHorizontalDragUpdate: (d) {
                      if (_swipeAnimating) return;
                      setState(() => _dragX += d.delta.dx);
                    },
                    onHorizontalDragEnd: (d) {
                      if (_swipeAnimating) return;
                      if (_dragX > 80) {
                        _commitSwipe(true);
                      } else if (_dragX < -80) {
                        _commitSwipe(false);
                      } else {
                        setState(() => _dragX = 0);
                      }
                    },
                    child: Transform.translate(
                      offset: Offset(_dragX, 0),
                      child: Transform.rotate(
                        angle: (_dragX * 0.001).clamp(-0.2, 0.2),
                        child: ConstrainedBox(
                          constraints: const BoxConstraints(maxWidth: 400, maxHeight: 540),
                          child: AspectRatio(
                            aspectRatio: 0.75,
                            child: Stack(
                              fit: StackFit.expand,
                              children: [
                                ClipRRect(
                                  borderRadius: BorderRadius.circular(24),
                                  child: Image.network(
                                    cardImage,
                                    fit: BoxFit.cover,
                                    errorBuilder: (_, __, ___) => Container(
                                      color: SacoColors.sacoOrange.withValues(alpha: 0.2),
                                      alignment: Alignment.center,
                                      child: Text(
                                        card.displayName.isNotEmpty
                                            ? card.displayName[0]
                                            : '?',
                                        style: const TextStyle(
                                          fontSize: 64,
                                          fontWeight: FontWeight.bold,
                                          color: SacoColors.sacoOrange,
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                                if (card.profileImageUrls.length > 1)
                                  Positioned(
                                    top: 12,
                                    left: 12,
                                    right: 12,
                                    child: Row(
                                      children: List.generate(
                                        card.profileImageUrls.length,
                                        (i) => Expanded(
                                          child: Container(
                                            height: 3,
                                            margin: const EdgeInsets.symmetric(horizontal: 2),
                                            decoration: BoxDecoration(
                                              color: i == _photoIndex
                                                  ? Colors.white
                                                  : Colors.white.withValues(alpha: 0.35),
                                              borderRadius: BorderRadius.circular(2),
                                            ),
                                          ),
                                        ),
                                      ),
                                    ),
                                  ),
                                Container(
                                  decoration: BoxDecoration(
                                    borderRadius: BorderRadius.circular(24),
                                    gradient: LinearGradient(
                                      begin: Alignment.topCenter,
                                      end: Alignment.bottomCenter,
                                      colors: [
                                        Colors.transparent,
                                        Colors.black.withValues(alpha: 0.9),
                                      ],
                                      stops: const [0.5, 1.0],
                                    ),
                                  ),
                                ),
                                if (likeOpacity > 0)
                                  Positioned(
                                    top: 40,
                                    right: 24,
                                    child: Opacity(
                                      opacity: likeOpacity,
                                      child: Container(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 12,
                                          vertical: 6,
                                        ),
                                        decoration: BoxDecoration(
                                          border: Border.all(color: Colors.green, width: 3),
                                          borderRadius: BorderRadius.circular(8),
                                        ),
                                        child: const Text(
                                          'Phù hợp ✨',
                                          style: TextStyle(
                                            color: Colors.green,
                                            fontWeight: FontWeight.w900,
                                            fontSize: 18,
                                          ),
                                        ),
                                      ),
                                    ),
                                  ),
                                if (passOpacity > 0)
                                  Positioned(
                                    top: 40,
                                    left: 24,
                                    child: Opacity(
                                      opacity: passOpacity,
                                      child: Container(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 12,
                                          vertical: 6,
                                        ),
                                        decoration: BoxDecoration(
                                          border: Border.all(
                                            color: const Color(0xFFFFBD59),
                                            width: 3,
                                          ),
                                          borderRadius: BorderRadius.circular(8),
                                        ),
                                        child: const Text(
                                          'Lượt sau 👋',
                                          style: TextStyle(
                                            color: Color(0xFFFFBD59),
                                            fontWeight: FontWeight.w900,
                                            fontSize: 18,
                                          ),
                                        ),
                                      ),
                                    ),
                                  ),
                                Positioned(
                                  left: 20,
                                  right: 20,
                                  bottom: 20,
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Row(
                                        crossAxisAlignment: CrossAxisAlignment.end,
                                        children: [
                                          Expanded(
                                            child: Text(
                                              titleLine,
                                              style: const TextStyle(
                                                color: Colors.white,
                                                fontSize: 24,
                                                fontWeight: FontWeight.w900,
                                              ),
                                            ),
                                          ),
                                          _ScoreBadge(score: card.matchingScore),
                                        ],
                                      ),
                                      if (metaLine.isNotEmpty) ...[
                                        const SizedBox(height: 6),
                                        Text(
                                          '📍 $metaLine',
                                          style: const TextStyle(
                                            color: Color(0xFFE5E7EB),
                                            fontSize: 13,
                                          ),
                                        ),
                                      ],
                                      const SizedBox(height: 10),
                                      Row(
                                        children: [
                                          Container(
                                            padding: const EdgeInsets.symmetric(
                                              horizontal: 12,
                                              vertical: 6,
                                            ),
                                            decoration: BoxDecoration(
                                              color: SacoColors.sacoOrange,
                                              borderRadius: BorderRadius.circular(20),
                                            ),
                                            child: Text(
                                              '🏠 ${card.roomStatusLabel}',
                                              style: const TextStyle(
                                                color: Colors.white,
                                                fontSize: 12,
                                                fontWeight: FontWeight.w600,
                                              ),
                                            ),
                                          ),
                                          if (card.canOpenTenantRoomDetails) ...[
                                            const SizedBox(width: 8),
                                            Material(
                                              color: Colors.white,
                                              shape: const CircleBorder(),
                                              elevation: 2,
                                              child: InkWell(
                                                customBorder: const CircleBorder(),
                                                onTap: () =>
                                                    setState(() => _tenantRoomCard = card),
                                                child: const Padding(
                                                  padding: EdgeInsets.all(8),
                                                  child: Icon(
                                                    Icons.home_rounded,
                                                    color: SacoColors.sacoOrange,
                                                    size: 20,
                                                  ),
                                                ),
                                              ),
                                            ),
                                          ],
                                        ],
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 4, 24, 8),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  _LabeledAction(
                    label: 'Bỏ qua',
                    color: const Color(0xFFFFBD59),
                    icon: Icons.close,
                    size: 52,
                    onTap: () => _commitSwipe(false),
                  ),
                  const SizedBox(width: 32),
                  _LabeledAction(
                    label: 'Gửi lượt thích',
                    color: const Color(0xFF2ECC71),
                    icon: Icons.favorite,
                    size: 60,
                    filled: true,
                    onTap: () => _commitSwipe(true),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 56),
          ],
        ),
        Positioned(
          left: 0,
          right: 0,
          bottom: 0,
          child: Material(
            elevation: 8,
            color: Colors.white.withValues(alpha: 0.96),
            child: SafeArea(
              top: false,
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 6),
                child: Row(
                  children: [
                    Expanded(
                      child: _BottomNavButton(
                        label: 'Yêu thích (${_wishlist.length})',
                        icon: Icons.favorite_border,
                        onTap: () => setState(() {
                          _showWishlist = true;
                          _showProfile = false;
                        }),
                      ),
                    ),
                    Expanded(
                      child: _BottomNavButton(
                        label: 'Bộ lọc',
                        icon: Icons.tune,
                        onTap: () => setState(() {
                          _showFilters = true;
                          _showWishlist = false;
                          _showProfile = false;
                        }),
                      ),
                    ),
                    Expanded(
                      child: _BottomNavButton(
                        label: 'Hồ sơ',
                        icon: Icons.person_outline,
                        onTap: () => setState(() {
                          _showProfile = true;
                          _showWishlist = false;
                        }),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
        if (_tenantRoomCard != null)
          _TenantRoomPopup(
            card: _tenantRoomCard!,
            onClose: () => setState(() => _tenantRoomCard = null),
          ),
        if (_showFilters)
          Positioned.fill(
            child: GestureDetector(
              onTap: () => setState(() => _showFilters = false),
              child: Container(
                color: Colors.black38,
                alignment: Alignment.center,
                child: GestureDetector(
                  onTap: () {},
                  child: DiscoveryFilterPanel(
                    filters: _activeFilters,
                    onApply: _onApplyFilters,
                    onClose: () => setState(() => _showFilters = false),
                  ),
                ),
              ),
            ),
          ),
        if (_showWishlist)
          _WishlistSheet(
            items: _wishlist,
            onClose: () => setState(() => _showWishlist = false),
            onRemove: (id) async {
              await ref.read(lifestyleRepositoryProvider).removeLike(id);
              final list = await ref.read(lifestyleRepositoryProvider).getMyLikes();
              setState(() => _wishlist = list);
            },
          ),
        if (_showProfile && _current != null)
          _ProfileSheet(
            card: _current!,
            onClose: () => setState(() => _showProfile = false),
            onChat: () {
              final c = _current!;
              setState(() => _showProfile = false);
              context.go(
                Uri(
                  path: '/chat',
                  queryParameters: {
                    'with': c.userId,
                    'name': c.displayName,
                    'avatar': c.fallbackAvatarUrl ?? c.avatarUrl,
                    'role': 'tenant',
                  },
                ).toString(),
              );
            },
          ),
      ],
    );
  }
}

class _QuizGate extends StatelessWidget {
  const _QuizGate({required this.onStart});

  final VoidCallback onStart;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.favorite, size: 48, color: SacoColors.sacoOrange),
            const SizedBox(height: 16),
            const Text(
              'Trắc nghiệm lối sống',
              style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Text(
              'Hoàn thành trắc nghiệm để tìm bạn ở ghép phù hợp gu của bạn.',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.grey.shade600),
            ),
            const SizedBox(height: 24),
            FilledButton(
              onPressed: onStart,
              style: FilledButton.styleFrom(
                backgroundColor: SacoColors.sacoOrange,
                padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 14),
              ),
              child: const Text('Bắt đầu trắc nghiệm'),
            ),
          ],
        ),
      ),
    );
  }
}

class _ScoreBadge extends StatelessWidget {
  const _ScoreBadge({required this.score});

  final int score;

  Color get _color {
    if (score >= 80) return const Color(0xFF2ECC71);
    if (score >= 60) return const Color(0xFFF1C40F);
    return const Color(0xFFE74C3C);
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 48,
      height: 48,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(color: _color, width: 3),
        color: Colors.white.withValues(alpha: 0.15),
      ),
      alignment: Alignment.center,
      child: Text(
        '$score%',
        style: TextStyle(
          color: _color,
          fontWeight: FontWeight.bold,
          fontSize: 12,
        ),
      ),
    );
  }
}

class _LabeledAction extends StatelessWidget {
  const _LabeledAction({
    required this.label,
    required this.color,
    required this.icon,
    required this.onTap,
    this.size = 56,
    this.filled = false,
  });

  final String label;
  final Color color;
  final IconData icon;
  final VoidCallback onTap;
  final double size;
  final bool filled;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        children: [
          Material(
            elevation: 4,
            shape: const CircleBorder(),
            color: Colors.white,
            child: InkWell(
              onTap: onTap,
              customBorder: const CircleBorder(),
              child: SizedBox(
                width: size,
                height: size,
                child: Icon(
                  icon,
                  color: color,
                  size: filled ? 32 : 26,
                ),
              ),
            ),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: TextStyle(
              fontSize: 11,
              color: Colors.grey.shade600,
              fontWeight: filled ? FontWeight.bold : FontWeight.normal,
            ),
          ),
        ],
      ),
    );
  }
}

class _BottomNavButton extends StatelessWidget {
  const _BottomNavButton({
    required this.label,
    required this.icon,
    required this.onTap,
  });

  final String label;
  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 6),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 20, color: Colors.grey.shade700),
            const SizedBox(height: 2),
            Text(
              label,
              style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: Colors.grey.shade700),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}

class _ProfileSheet extends StatelessWidget {
  const _ProfileSheet({
    required this.card,
    required this.onClose,
    required this.onChat,
  });

  final DiscoveryCard card;
  final VoidCallback onClose;
  final VoidCallback onChat;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.black54,
      child: Column(
        children: [
          const Spacer(),
          Material(
            color: Colors.white,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
            clipBehavior: Clip.antiAlias,
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    children: [
                      const Expanded(
                        child: Text(
                          'Chi tiết hồ sơ',
                          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
                        ),
                      ),
                      IconButton(onPressed: onClose, icon: const Icon(Icons.close)),
                    ],
                  ),
                  CircleAvatar(
                    radius: 40,
                    backgroundImage: NetworkImage(
                      card.fallbackAvatarUrl ?? card.avatarUrl,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    cardTitleLine(card),
                    textAlign: TextAlign.center,
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
                  ),
                  if (card.jobLabel != null)
                    Text(card.jobLabel!, textAlign: TextAlign.center),
                  const SizedBox(height: 8),
                  Text(
                    '${card.matchingScore}% phù hợp',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: SacoColors.sacoOrange,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  if (card.bio != null && card.bio!.isNotEmpty) ...[
                    const SizedBox(height: 12),
                    Text(card.bio!, style: TextStyle(color: Colors.grey.shade700)),
                  ],
                  const SizedBox(height: 16),
                  OutlinedButton(
                    onPressed: () => context.go('/tenant-pricing'),
                    child: const Text('Nâng cấp Premium'),
                  ),
                  const SizedBox(height: 8),
                  FilledButton(
                    onPressed: onChat,
                    style: FilledButton.styleFrom(backgroundColor: SacoColors.sacoOrange),
                    child: const Text('Nhắn tin'),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _TenantRoomPopup extends StatelessWidget {
  const _TenantRoomPopup({required this.card, required this.onClose});

  final DiscoveryCard card;
  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) {
    final profile = card.tenantRoomProfile;
    return Material(
      color: Colors.black54,
      child: Center(
        child: Container(
          margin: const EdgeInsets.all(20),
          constraints: const BoxConstraints(maxWidth: 420),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
          ),
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        'Phòng trọ của ${card.displayName}',
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 17),
                      ),
                    ),
                    IconButton(onPressed: onClose, icon: const Icon(Icons.close)),
                  ],
                ),
                if (card.roomPriceLabel.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: Text(
                      card.roomPriceLabel,
                      style: TextStyle(
                        color: SacoColors.sacoOrange,
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                  ),
                if (profile != null)
                  TenantRoomDetailsView(
                    profile: profile,
                    priceLabel: card.roomPriceLabel,
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _WishlistSheet extends StatelessWidget {
  const _WishlistSheet({
    required this.items,
    required this.onClose,
    required this.onRemove,
  });

  final List<WishlistItem> items;
  final VoidCallback onClose;
  final ValueChanged<String> onRemove;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.black54,
      child: Column(
        children: [
          const Spacer(),
          Material(
            color: Colors.white,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
            clipBehavior: Clip.antiAlias,
            child: SizedBox(
              height: MediaQuery.of(context).size.height * 0.55,
              child: Column(
                children: [
                  ListTile(
                    title: const Text('Danh sách yêu thích',
                        style: TextStyle(fontWeight: FontWeight.bold)),
                    subtitle: Text('${items.length} người'),
                    trailing: IconButton(
                      onPressed: onClose,
                      icon: const Icon(Icons.close),
                    ),
                  ),
                  const Divider(height: 1),
                  Expanded(
                    child: items.isEmpty
                        ? const Center(child: Text('Chưa có ai trong danh sách'))
                        : ListView.builder(
                            itemCount: items.length,
                            itemBuilder: (_, i) {
                              final u = items[i];
                              return ListTile(
                                leading: CircleAvatar(
                                  backgroundImage: NetworkImage(u.avatarUrl),
                                ),
                                title: Text(u.displayName),
                                subtitle: Text('${u.matchingScore}% hòa hợp'),
                                trailing: IconButton(
                                  icon: const Icon(Icons.delete_outline),
                                  onPressed: () => onRemove(u.userId),
                                ),
                              );
                            },
                          ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
