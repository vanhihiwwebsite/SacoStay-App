import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../config/theme.dart';
import '../../core/api/api_exception.dart';
import '../../core/storage/guest_discovery_storage.dart';
import '../../core/utils/discovery_filters.dart';
import '../../core/utils/user_display.dart';
import '../../features/auth/auth_provider.dart';
import '../../shared/widgets/tenant_shell.dart';
import '../../core/utils/lifestyle_display.dart';
import '../../core/utils/media_url.dart';
import '../../models/lifestyle.dart';
import '../../repositories/lifestyle_repository.dart';
import 'widgets/discovery_filter_panel.dart';
import 'widgets/tenant_room_details_view.dart';

/// Chỉnh vị trí dọc của thẻ người dùng + 4 nút (Yêu thích / Bỏ qua / Thích / Hồ sơ).
/// Giảm → đẩy xuống dưới; tăng → đẩy lên trên (đơn vị: px).
const _kDiscoveryDeckBottomOffset = 40.0;

/// Thêm chiều cao thẻ người dùng (px).
const _kDiscoveryCardExtraHeight = 30.0;

/// Vị trí dọc nút lọc so với góc trên phải thẻ (âm = lên trên).
const _kDiscoveryFilterTopOffset = -55.0;

class DiscoveryScreen extends ConsumerStatefulWidget {
  const DiscoveryScreen({super.key});

  @override
  ConsumerState<DiscoveryScreen> createState() => _DiscoveryScreenState();
}

class _DiscoveryScreenState extends ConsumerState<DiscoveryScreen> {
  bool _loading = true;
  bool _needsQuiz = false;
  bool _isGuest = false;
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
    final auth = ref.read(authControllerProvider);

    if (!auth.isLoggedIn) {
      final guestStorage = await GuestDiscoveryStorage.create();
      if (!guestStorage.hasQuizCompleted) {
        setState(() {
          _needsQuiz = true;
          _isGuest = true;
          _loading = false;
        });
        return;
      }
      setState(() => _isGuest = true);
      await _loadDeck();
      return;
    }

    _isGuest = false;
    final uid = userIdFromUser(auth.user?.raw);
    final completed = uid != null
        ? await ref.read(lifestyleRepositoryProvider).ensureQuizCompleted(uid)
        : await ref.read(lifestyleRepositoryProvider).hasCompletedQuiz();
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
      List<SwipeDeckCard> deck;
      if (_isGuest) {
        final guestStorage = await GuestDiscoveryStorage.create();
        final optionIds = guestStorage.selectedOptionIds;
        deck = await repo.getGuestSwipeDeck(
          selectedOptionIds: optionIds,
          limit: 50,
          includeSwiped: true,
        );
      } else {
        deck = await repo.getSwipeDeck(limit: 50, includeSwiped: true);
      }

      List<WishlistItem> wishlist = [];
      SwipeQuota quota = const SwipeQuota(
        isPremium: false,
        weeklyLimit: 5,
        usedThisWeek: 0,
        remaining: 5,
        weekResetAt: '',
      );
      if (!_isGuest) {
        wishlist = await repo.getMyLikes();
        quota = await repo.getSwipeQuota();
      }
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
    } on ApiException catch (e) {
      setState(() {
        _loading = false;
        _deckEmpty = true;
      });
      if (e.statusCode == 403 && mounted) {
        context.go('/identity-verification?returnUrl=/discovery');
      }
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

  void _focusWishlistCard(String userId) {
    var idx = _deck.indexWhere((c) => c.userId == userId);
    if (idx == -1) {
      DiscoveryCard? card;
      for (final c in _allCards) {
        if (c.userId == userId) {
          card = c;
          break;
        }
      }
      if (card == null) return;
      setState(() {
        _deck = [
          ..._deck.take(_currentIndex),
          card!,
          ..._deck.skip(_currentIndex),
        ];
        idx = _currentIndex;
        _swipeAnimating = false;
        _dragX = 0;
        _currentIndex = idx;
        _photoIndex = 0;
        _showWishlist = false;
        _deckEmpty = false;
      });
      return;
    }
    setState(() {
      _swipeAnimating = false;
      _dragX = 0;
      _currentIndex = idx;
      _photoIndex = 0;
      _showWishlist = false;
    });
  }

  Color _scoreColor(int score) {
    if (score >= 80) return const Color(0xFF2ECC71);
    if (score >= 60) return const Color(0xFFF1C40F);
    return const Color(0xFFE74C3C);
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
    if (_needsQuiz) {
      return _QuizGate(
        isGuest: _isGuest,
        onStart: () {
          final guest = _isGuest ? '&guest=1' : '';
          context.go('/lifestyle-quiz?returnUrl=${Uri.encodeComponent('/discovery')}$guest');
        },
      );
    }
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
              child: LayoutBuilder(
                builder: (context, constraints) {
                  final bottomPad =
                      MediaQuery.paddingOf(context).bottom + _kDiscoveryDeckBottomOffset;
                  const actionBlockHeight = 88.0;
                  const stackGap = 14.0;
                  const filterPad = 12.0;
                  final maxCardHeight = (constraints.maxHeight -
                          bottomPad -
                          actionBlockHeight -
                          stackGap -
                          filterPad)
                      .clamp(240.0, 460.0);

                  return Padding(
                    padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.end,
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Stack(
                          clipBehavior: Clip.none,
                          alignment: Alignment.topRight,
                          children: [
                            Padding(
                              padding: const EdgeInsets.only(top: 12, right: 12),
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
                                  constraints: BoxConstraints(
                                    maxWidth: 400,
                                    maxHeight: maxCardHeight + _kDiscoveryCardExtraHeight,
                                  ),
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
                        Positioned(
                          top: _kDiscoveryFilterTopOffset,
                          right: 0,
                          child: Material(
                          elevation: 8,
                          shadowColor: SacoColors.sacoOrangeDark.withValues(alpha: 0.5),
                          color: SacoColors.sacoOrangeDark,
                          shape: const CircleBorder(),
                          child: InkWell(
                            customBorder: const CircleBorder(),
                            onTap: () => setState(() {
                              _showFilters = true;
                              _showWishlist = false;
                              _showProfile = false;
                            }),
                            child: const Padding(
                              padding: EdgeInsets.all(11),
                              child: Icon(
                                Icons.tune_rounded,
                                color: Colors.white,
                                size: 23,
                              ),
                            ),
                          ),
                        ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 14),
                    Padding(
                      padding: EdgeInsets.fromLTRB(4, 0, 4, bottomPad),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            child: Center(
                              child: _LabeledAction(
                                label: 'Yêu thích (${_wishlist.length})',
                                color: const Color(0xFFE53935),
                                icon: Icons.favorite_border,
                                size: 44,
                                compactLabel: true,
                                onTap: () => setState(() {
                                  _showWishlist = true;
                                  _showProfile = false;
                                }),
                              ),
                            ),
                          ),
                          Expanded(
                            child: Center(
                              child: _LabeledAction(
                                label: 'Bỏ qua',
                                color: const Color(0xFFFFBD59),
                                icon: Icons.close,
                                size: 50,
                                compactLabel: true,
                                onTap: () => _commitSwipe(false),
                              ),
                            ),
                          ),
                          SizedBox(width: TenantShell.fabClearanceWidth),
                          Expanded(
                            child: Center(
                              child: _LabeledAction(
                                label: 'Gửi lượt thích',
                                color: const Color(0xFF2ECC71),
                                icon: Icons.favorite,
                                size: 56,
                                filled: true,
                                compactLabel: true,
                                onTap: () => _commitSwipe(true),
                              ),
                            ),
                          ),
                          Expanded(
                            child: Center(
                              child: _LabeledAction(
                                label: 'Hồ sơ',
                                color: SacoColors.sacoOrange,
                                icon: Icons.person_outline,
                                size: 44,
                                compactLabel: true,
                                onTap: () {
                                  if (_current == null) return;
                                  setState(() {
                                    _showProfile = true;
                                    _showWishlist = false;
                                  });
                                },
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                      ],
                    ),
                  );
                },
              ),
            ),
          ],
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
            activeUserId: _current?.userId,
            scoreColor: _scoreColor,
            onClose: () => setState(() => _showWishlist = false),
            onSelect: _focusWishlistCard,
            onRemove: (id) async {
              await ref.read(lifestyleRepositoryProvider).removeLike(id);
              final list = await ref.read(lifestyleRepositoryProvider).getMyLikes();
              setState(() => _wishlist = list);
            },
          ),
        if (_showProfile && _current != null)
          _ProfileSheet(
            card: _current!,
            isPremium: _quota.isPremium,
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
  const _QuizGate({required this.onStart, this.isGuest = false});

  final VoidCallback onStart;
  final bool isGuest;

  @override
  Widget build(BuildContext context) {
    final bottomPad = TenantShell.bottomInset(context);
    return SingleChildScrollView(
      padding: EdgeInsets.fromLTRB(24, 24, 24, bottomPad),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const SizedBox(height: 24),
          Container(
            width: 80,
            height: 80,
            decoration: BoxDecoration(
              color: Colors.white,
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.08),
                  blurRadius: 12,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Icon(Icons.favorite, size: 40, color: SacoColors.sacoOrange),
          ),
          const SizedBox(height: 20),
          const Text(
            'Trắc nghiệm lối sống',
            style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 10),
          Text(
            isGuest
                ? 'Để tìm bạn ở ghép phù hợp, bạn cần hoàn thành trắc nghiệm lối sống trước nhé!'
                : 'Hoàn thành trắc nghiệm để tìm bạn ở ghép phù hợp gu của bạn.',
            textAlign: TextAlign.center,
            style: TextStyle(color: Colors.grey.shade600, height: 1.45),
          ),
          const SizedBox(height: 16),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.orange.shade100),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Quy trình matching trên SacoStay',
                  style: TextStyle(fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 8),
                _step('Trả lời trắc nghiệm về thói quen sinh hoạt và lối sống'),
                _step('Hệ thống tính % hòa hợp với từng người thuê trọ khác'),
                _step('Lướt thẻ — thích người bạn cảm thấy phù hợp, bỏ qua nếu chưa hợp'),
                _step('Khi cả hai thích nhau (match), mở Tin nhắn và tạo không gian chung'),
                if (isGuest)
                  _step('Đăng ký tài khoản để lưu kết quả, kết nối và tiếp tục tìm bạn'),
              ],
            ),
          ),
          const SizedBox(height: 24),
          FilledButton(
            onPressed: onStart,
            style: FilledButton.styleFrom(
              backgroundColor: SacoColors.sacoOrange,
              padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 14),
            ),
            child: const Text('Bắt đầu trắc nghiệm'),
          ),
        ],
      ),
    );
  }

  Widget _step(String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('• ', style: TextStyle(color: Colors.grey.shade700)),
          Expanded(
            child: Text(
              text,
              style: TextStyle(fontSize: 13, color: Colors.grey.shade700, height: 1.4),
            ),
          ),
        ],
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
    this.compactLabel = false,
  });

  final String label;
  final Color color;
  final IconData icon;
  final VoidCallback onTap;
  final double size;
  final bool filled;
  final bool compactLabel;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: SizedBox(
        width: compactLabel ? 72 : null,
        child: Column(
          children: [
            Material(
              elevation: 4,
              shape: const CircleBorder(),
              color: filled ? color : Colors.white,
              child: InkWell(
                onTap: onTap,
                customBorder: const CircleBorder(),
                child: SizedBox(
                  width: size,
                  height: size,
                  child: Icon(
                    icon,
                    color: filled ? Colors.white : color,
                    size: filled ? 28 : 24,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 4),
            Text(
              label,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: compactLabel ? 9.5 : 11,
                color: Colors.grey.shade600,
                fontWeight: filled ? FontWeight.bold : FontWeight.normal,
                height: 1.2,
              ),
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
    required this.isPremium,
    required this.onClose,
    required this.onChat,
  });

  final DiscoveryCard card;
  final bool isPremium;
  final VoidCallback onClose;
  final VoidCallback onChat;

  @override
  Widget build(BuildContext context) {
    final bottomPad = TenantShell.bottomInset(context);
    return Material(
      color: Colors.black54,
      child: Column(
        children: [
          const Spacer(flex: 3),
          Material(
            color: Colors.white,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
            clipBehavior: Clip.antiAlias,
            child: Padding(
              padding: EdgeInsets.fromLTRB(20, 20, 20, 20 + bottomPad),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                mainAxisSize: MainAxisSize.min,
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
                  if (isPremium)
                    OutlinedButton(
                      onPressed: () {
                        onClose();
                        context.push('/profile/${card.userId}');
                      },
                      child: const Text('Xem chi tiết hồ sơ'),
                    )
                  else
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
    required this.activeUserId,
    required this.scoreColor,
    required this.onClose,
    required this.onSelect,
    required this.onRemove,
  });

  final List<WishlistItem> items;
  final String? activeUserId;
  final Color Function(int score) scoreColor;
  final VoidCallback onClose;
  final ValueChanged<String> onSelect;
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
              height: MediaQuery.of(context).size.height * 0.62,
              child: Column(
                children: [
                  ListTile(
                    title: const Text(
                      'Danh sách yêu thích',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                    subtitle: Text('${items.length} người'),
                    trailing: IconButton(
                      onPressed: onClose,
                      icon: const Icon(Icons.close),
                    ),
                  ),
                  const Divider(height: 1),
                  Expanded(
                    child: items.isEmpty
                        ? const Center(
                            child: Padding(
                              padding: EdgeInsets.all(24),
                              child: Text(
                                'Hãy thả tim để thêm vào danh sách yêu thích!',
                                textAlign: TextAlign.center,
                                style: TextStyle(color: Colors.grey),
                              ),
                            ),
                          )
                        : GridView.builder(
                            padding: const EdgeInsets.all(16),
                            gridDelegate:
                                const SliverGridDelegateWithFixedCrossAxisCount(
                              crossAxisCount: 2,
                              crossAxisSpacing: 12,
                              mainAxisSpacing: 12,
                              childAspectRatio: 3 / 4,
                            ),
                            itemCount: items.length,
                            itemBuilder: (_, i) {
                              final u = items[i];
                              final active = activeUserId == u.userId;
                              final avatar = u.avatarUrl.isNotEmpty
                                  ? u.avatarUrl
                                  : avatarFallbackUrl(u.displayName);
                              return _WishlistCard(
                                item: u,
                                avatarUrl: avatar,
                                active: active,
                                scoreColor: scoreColor(u.matchingScore),
                                onTap: () => onSelect(u.userId),
                                onRemove: () => onRemove(u.userId),
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

class _WishlistCard extends StatelessWidget {
  const _WishlistCard({
    required this.item,
    required this.avatarUrl,
    required this.active,
    required this.scoreColor,
    required this.onTap,
    required this.onRemove,
  });

  final WishlistItem item;
  final String avatarUrl;
  final bool active;
  final Color scoreColor;
  final VoidCallback onTap;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.grey.shade100,
      borderRadius: BorderRadius.circular(16),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Stack(
          fit: StackFit.expand,
          children: [
            Image.network(
              avatarUrl,
              fit: BoxFit.cover,
              errorBuilder: (_, __, ___) => ColoredBox(
                color: SacoColors.sacoOrange,
                child: Center(
                  child: Text(
                    item.displayName.isNotEmpty
                        ? item.displayName.characters.first.toUpperCase()
                        : '?',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 28,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
            ),
            if (active)
              Positioned.fill(
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    border: Border.all(color: SacoColors.sacoOrange, width: 3),
                    borderRadius: BorderRadius.circular(16),
                  ),
                ),
              ),
            Positioned(
              top: 8,
              left: 8,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: scoreColor,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  '${item.matchingScore}%',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
            Positioned(
              top: 6,
              right: 6,
              child: Material(
                color: Colors.black54,
                shape: const CircleBorder(),
                clipBehavior: Clip.antiAlias,
                child: InkWell(
                  onTap: onRemove,
                  child: const SizedBox(
                    width: 28,
                    height: 28,
                    child: Icon(Icons.close, size: 16, color: Colors.white),
                  ),
                ),
              ),
            ),
            Positioned(
              left: 0,
              right: 0,
              bottom: 0,
              child: DecoratedBox(
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.bottomCenter,
                    end: Alignment.topCenter,
                    colors: [Colors.black87, Colors.transparent],
                  ),
                ),
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(10, 24, 10, 8),
                  child: Text(
                    item.displayName,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 12,
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
