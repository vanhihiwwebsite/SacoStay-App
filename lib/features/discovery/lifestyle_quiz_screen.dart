import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../config/theme.dart';
import '../../core/api/api_exception.dart';
import '../../models/lifestyle.dart';
import '../../repositories/lifestyle_repository.dart';

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
  int _index = 0;
  final _answers = <int, int>{};

  @override
  void initState() {
    super.initState();
    _loadQuestions();
  }

  Future<void> _loadQuestions() async {
    final list = await ref.read(lifestyleRepositoryProvider).getQuestions();
    setState(() {
      _questions = list;
      _loading = false;
      if (list.isEmpty) {
        _error = 'Chưa có câu hỏi trắc nghiệm trên server.';
      }
    });
  }

  LifestyleQuestion? get _current =>
      _index < _questions.length ? _questions[_index] : null;

  Future<void> _submit() async {
    if (_answers.length < _questions.length) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Vui lòng trả lời tất cả câu hỏi.')),
      );
      return;
    }
    setState(() => _submitting = true);
    try {
      final ids = _questions.map((q) => _answers[q.id]!).toList();
      await ref.read(lifestyleRepositoryProvider).submitAnswers(ids);
      if (!mounted) return;
      final returnUrl =
          GoRouterState.of(context).uri.queryParameters['returnUrl'] ?? '/discovery';
      context.go(returnUrl);
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
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_error != null && _questions.isEmpty) {
      return Center(child: Text(_error!));
    }

    final q = _current;
    if (q == null) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('Hoàn tất trắc nghiệm!'),
            const SizedBox(height: 16),
            FilledButton(
              onPressed: _submitting ? null : _submit,
              style: FilledButton.styleFrom(backgroundColor: SacoColors.sacoOrange),
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
      );
    }

    final selected = _answers[q.id];

    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'Câu ${_index + 1}/${_questions.length}',
            style: TextStyle(color: Colors.grey.shade600),
          ),
          const SizedBox(height: 8),
          Text(
            q.content,
            style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 24),
          ...q.options.map((opt) {
            final isSelected = selected == opt.id;
            return Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: Material(
                color: isSelected
                    ? SacoColors.sacoOrange.withValues(alpha: 0.12)
                    : Colors.white,
                borderRadius: BorderRadius.circular(12),
                child: InkWell(
                  onTap: () => setState(() => _answers[q.id] = opt.id),
                  borderRadius: BorderRadius.circular(12),
                  child: Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: isSelected
                            ? SacoColors.sacoOrange
                            : Colors.grey.shade300,
                      ),
                    ),
                    child: Text(opt.content),
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
                  onPressed: () => setState(() => _index -= 1),
                  child: const Text('Quay lại'),
                ),
              const Spacer(),
              FilledButton(
                onPressed: () {
                  if (selected == null) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Chọn một đáp án')),
                    );
                    return;
                  }
                  if (_index < _questions.length - 1) {
                    setState(() => _index += 1);
                  } else {
                    _submit();
                  }
                },
                style: FilledButton.styleFrom(backgroundColor: SacoColors.sacoOrange),
                child: Text(
                  _index < _questions.length - 1 ? 'Tiếp theo' : 'Hoàn tất',
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}