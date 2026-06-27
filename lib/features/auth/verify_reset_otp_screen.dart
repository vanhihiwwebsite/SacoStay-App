import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../config/theme.dart';
import '../../core/api/api_exception.dart';
import '../../core/storage/user_prefs.dart';
import '../../features/auth/auth_provider.dart';

class VerifyResetOtpScreen extends ConsumerStatefulWidget {
  const VerifyResetOtpScreen({super.key});

  @override
  ConsumerState<VerifyResetOtpScreen> createState() => _VerifyResetOtpScreenState();
}

class _VerifyResetOtpScreenState extends ConsumerState<VerifyResetOtpScreen> {
  final _otp = TextEditingController();
  bool _loading = false;
  int _countdown = 60;
  String? _error;
  String? _email;
  bool _initialized = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_initialized) {
      _initialized = true;
      _email = ref.read(userPrefsProvider).resetEmail;
      _startCountdown();
    }
  }

  @override
  void dispose() {
    _otp.dispose();
    super.dispose();
  }

  void _startCountdown() {
    Future.doWhile(() async {
      await Future.delayed(const Duration(seconds: 1));
      if (!mounted) return false;
      if (_countdown <= 0) return false;
      setState(() => _countdown--);
      return _countdown > 0;
    });
  }

  Future<void> _submit() async {
    final email = _email;
    if (email == null || email.isEmpty) {
      context.go('/forgot-password');
      return;
    }
    final otp = _otp.text.trim();
    if (otp.length != 6) {
      setState(() => _error = 'OTP phải có 6 chữ số.');
      return;
    }
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      await ref.read(authRepositoryProvider).verifyResetOtp(email: email, otp: otp);
      if (mounted) context.go('/reset-password');
    } on ApiException catch (e) {
      setState(() {
        _loading = false;
        _error = e.message;
      });
    }
  }

  Future<void> _resend() async {
    final email = _email;
    if (email == null || _loading) return;
    setState(() => _loading = true);
    try {
      await ref.read(authRepositoryProvider).forgotPassword(email);
      setState(() {
        _loading = false;
        _countdown = 60;
      });
      _startCountdown();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('OTP mới đã được gửi!')),
      );
    } on ApiException catch (e) {
      setState(() {
        _loading = false;
        _error = e.message;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_email == null || _email!.isEmpty) {
      return Center(
        child: FilledButton(
          onPressed: () => context.go('/forgot-password'),
          child: const Text('Quay lại nhập email'),
        ),
      );
    }

    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 400),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text(
                'Xác minh OTP',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              Text(
                'Nhập mã OTP gửi tới $_email',
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.grey.shade600),
              ),
              const SizedBox(height: 24),
              TextField(
                controller: _otp,
                keyboardType: TextInputType.number,
                maxLength: 6,
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 24, letterSpacing: 8),
                decoration: const InputDecoration(
                  labelText: 'Mã OTP',
                  border: OutlineInputBorder(),
                ),
              ),
              if (_error != null)
                Text(_error!, style: const TextStyle(color: Colors.red)),
              const SizedBox(height: 16),
              FilledButton(
                onPressed: _loading ? null : _submit,
                style: FilledButton.styleFrom(
                  backgroundColor: SacoColors.sacoOrange,
                  minimumSize: const Size.fromHeight(48),
                ),
                child: Text(_loading ? 'Đang xác minh…' : 'Tiếp tục'),
              ),
              const SizedBox(height: 8),
              TextButton(
                onPressed: _countdown > 0 || _loading ? null : _resend,
                child: Text(
                  _countdown > 0 ? 'Gửi lại OTP (${_countdown}s)' : 'Gửi lại OTP',
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
