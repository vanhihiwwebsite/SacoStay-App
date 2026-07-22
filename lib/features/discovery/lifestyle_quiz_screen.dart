import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../config/theme.dart';
import '../../core/api/api_exception.dart';
import '../../core/storage/guest_discovery_storage.dart';
import '../../core/storage/lifestyle_storage.dart';
import '../../core/utils/auth_navigation.dart';
import '../../core/utils/lifestyle_display.dart';
import '../../core/utils/user_display.dart';
import '../../features/auth/auth_provider.dart';
import '../../models/lifestyle.dart';
import '../../repositories/lifestyle_repository.dart';
import '../../shared/widgets/tenant_sub_page_scaffold.dart';

class LifestyleQuizScreen extends ConsumerStatefulWidget {
  const LifestyleQuizScreen({super.key});

  @override
  ConsumerState<LifestyleQuizScreen> createState() => _LifestyleQuizScreenState();
}

class _LifestyleQuizScreenState extends ConsumerState<LifestyleQuizScreen> {
  bool _loading = true;
  bool _submitting = false;
  String? _error;
  List<LifestyleQuestion> _questions = [];
  List<LifestyleQuestion> _activeQuestions = [];
  int _index = 0;
  final _answers = <int, int>{};
  bool _guestMode = false;
  bool _retakeMode = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _bootstrap());
  }

  Future<void> _bootstrap() async {
    if (!mounted) return;
    final params = GoRouterState.of(context).uri.queryParameters;
    _retakeMode = params['retake'] == '1';
    final auth = ref.read(authControllerProvider);
    _guestMode = params['guest'] == '1' || !auth.isLoggedIn;

    if (!_guestMode && !_retakeMode && auth.isLoggedIn) {
      final returnUrl = sanitizeReturnUrl(params['returnUrl']);
      final fromProfile = returnUrl == '/profile/me';
      if (!fromProfile) {
        final uid = userIdFromUser(auth.user?.raw);
        if (uid != null) {
          final completed = await ref.read(lifestyleRepositoryProvider).ensureQuizCompleted(uid);
          if (!mounted) return;
          if (completed) {
            context.go(returnUrl ?? '/discovery');
            return;
          }
        }
      }
    }

    await _loadQuestions();
  }

  Future<void> _loadQuestions() async {
    if (!mounted) return;
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final list = await ref.read(lifestyleRepositoryProvider).getQuestions();
      if (_retakeMode && !_guestMode) {
        final existing = await ref.read(lifestyleRepositoryProvider).getMyAnswers();
        for (final answer in existing) {
          _answers[answer.questionId] = answer.optionId;
        }
      }
      if (!mounted) return;
      setState(() {
        _questions = list;
        _rebuildActiveQuestions();
        _loading = false;
      });
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = e.message;
        _questions = [];
        _activeQuestions = [];
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = e.toString();
        _questions = [];
        _activeQuestions = [];
      });
    }
  }

  void _rebuildActiveQuestions() {
    final pair = resolveRoomQuestionPair(_questions);
    final flow = <LifestyleQuestion>[...pair.lifestyle];
    if (pair.roomStatus != null) flow.add(pair.roomStatus!);
    _activeQuestions = flow;
    if (_index > flow.length) _index = flow.length;
  }

  List<int> _collectSubmitOptionIds() {
    final pair = resolveRoomQuestionPair(_questions);
    final required = <LifestyleQuestion>[...pair.lifestyle];
    if (pair.roomStatus != null) required.add(pair.roomStatus!);
    final ids = <int>[];
    for (final q in required) {
      final optId = _answers[q.id];
      if (optId == null) return [];
      ids.add(optId);
    }
    return ids;
  }

  LifestyleQuestion? get _current =>
      _index < _activeQuestions.length ? _activeQuestions[_index] : null;

  Future<void> _submit() async {
    _rebuildActiveQuestions();
    final ids = _collectSubmitOptionIds();
    final expected = resolveRoomQuestionPair(_questions).expectedAnswerCount;
    if (ids.isEmpty || ids.length < expected) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Vui lòng trả lời đủ tất cả câu hỏi.')),
      );
      return;
    }

    setState(() {
      _submitting = true;
      _error = null;
    });

    try {
      if (_guestMode) {
        final guestStorage = await GuestDiscoveryStorage.create();
        await guestStorage.saveQuizResult(
          questions: _questions,
          answers: _answers,
          selectedOptionIds: ids,
        );
      } else {
        final message = await ref.read(lifestyleRepositoryProvider).submitAnswers(ids);
        final uid = userIdFromUser(ref.read(authControllerProvider).user?.raw);
        if (uid != null) {
          final storage = await LifestyleStorage.create();
          await storage.setQuizCompleted(uid);
        }
        await ref.read(authControllerProvider.notifier).refreshProfile();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(message), backgroundColor: SacoColors.sacoOrange),
          );
        }
      }

      if (!mounted) return;
      final params = GoRouterState.of(context).uri.queryParameters;
      final fallback = _guestMode ? '/discovery' : '/profile/me';
      final returnUrl = sanitizeReturnUrl(params['returnUrl']) ?? fallback;
      if (context.canPop()) {
        context.pop(true);
      } else {
        context.go(returnUrl);
      }
    } on ApiException catch (e) {
      setState(() {
        _submitting = false;
        _error = e.message;
      });
    } catch (e) {
      setState(() {
        _submitting = false;
        _error = e.toString();
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final isMobile = MediaQuery.sizeOf(context).width < 640;
    final params = GoRouterState.of(context).uri.queryParameters;
    final isRetake = params['retake'] == '1' || _retakeMode;
    final pageTitle = isRetake ? 'Thay đổi lối sống' : 'Trắc nghiệm lối sống';

    Widget content;
    if (_loading) {
      content = const Center(child: CircularProgressIndicator());
    } else if (_error != null && _activeQuestions.isEmpty) {
      content = Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.error_outline, size: 48, color: Colors.red.shade300),
              const SizedBox(height: 12),
              Text(_error!, textAlign: TextAlign.center),
              const SizedBox(height: 16),
              FilledButton(
                onPressed: _loadQuestions,
                style: FilledButton.styleFrom(minimumSize: const Size(0, 48)),
                child: const Text('Thử lại'),
              ),
            ],
          ),
        ),
      );
    } else {
      content = _buildQuizBody(context);
    }

    if (isMobile) {
      return TenantSubPageScaffold(title: pageTitle, body: content);
    }
    return content;
  }

  Widget _buildQuizBody(BuildContext context) {
    final q = _current;
    if (q == null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.check_circle_outline, size: 56, color: SacoColors.sacoOrange),
              const SizedBox(height: 12),
              const Text(
                'Hoàn tất trắc nghiệm!',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              Text(
                'Bấm gửi kết quả để lưu câu trả lời của bạn.',
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.grey.shade600),
              ),
              if (_error != null) ...[
                const SizedBox(height: 12),
                Text(_error!, style: const TextStyle(color: Colors.red, fontSize: 13)),
              ],
              const SizedBox(height: 20),
              FilledButton(
                onPressed: _submitting ? null : _submit,
                style: FilledButton.styleFrom(
                  backgroundColor: SacoColors.sacoOrange,
                  minimumSize: const Size(120, 48),
                ),
                child: _submitting
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                      )
                    : const Text('Gửi kết quả'),
              ),
            ],
          ),
        ),
      );
    }

    final selected = _answers[q.id];
    final progress = (_index + 1) / _activeQuestions.length;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: LinearProgressIndicator(
              value: progress,
              minHeight: 8,
              backgroundColor: Colors.grey.shade200,
              color: SacoColors.sacoOrange,
            ),
          ),
          const SizedBox(height: 12),
          Text(
            'Câu ${_index + 1}/${_activeQuestions.length}',
            style: TextStyle(color: Colors.grey.shade600, fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 8),
          Text(
            q.content,
            style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, height: 1.35),
          ),
          if (_error != null) ...[
            const SizedBox(height: 12),
            Text(_error!, style: const TextStyle(color: Colors.red, fontSize: 13)),
          ],
          const SizedBox(height: 20),
          ...q.options.map((opt) {
            final isSelected = selected == opt.id;
            return Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: Material(
                color: isSelected
                    ? SacoColors.sacoOrange.withValues(alpha: 0.12)
                    : Colors.white,
                borderRadius: BorderRadius.circular(12),
                elevation: isSelected ? 0 : 1,
                shadowColor: Colors.black.withValues(alpha: 0.04),
                child: InkWell(
                  onTap: () => setState(() => _answers[q.id] = opt.id),
                  borderRadius: BorderRadius.circular(12),
                  child: Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: isSelected ? SacoColors.sacoOrange : Colors.grey.shade200,
                        width: isSelected ? 2 : 1,
                      ),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          isSelected
                              ? Icons.radio_button_checked
                              : Icons.radio_button_off,
                          color: isSelected ? SacoColors.sacoOrange : Colors.grey.shade400,
                          size: 20,
                        ),
                        const SizedBox(width: 12),
                        Expanded(child: Text(opt.content)),
                      ],
                    ),
                  ),
                ),
              ),
            );
          }),
          const SizedBox(height: 24),
          Row(
            children: [
              if (_index > 0)
                OutlinedButton(
                  onPressed: _submitting ? null : () => setState(() => _index -= 1),
                  child: const Text('Quay lại'),
                ),
              const Spacer(),
              FilledButton(
                onPressed: _submitting
                    ? null
                    : () {
                        if (selected == null) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('Chọn một đáp án')),
                          );
                          return;
                        }
                        if (_index < _activeQuestions.length - 1) {
                          setState(() => _index += 1);
                        } else {
                          setState(() => _index = _activeQuestions.length);
                        }
                      },
                style: FilledButton.styleFrom(
                  backgroundColor: SacoColors.sacoOrange,
                  minimumSize: const Size(0, 48),
                ),
                child: Text(
                  _index < _activeQuestions.length - 1 ? 'Tiếp theo' : 'Hoàn tất',
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
