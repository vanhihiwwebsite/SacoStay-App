import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../config/theme.dart';
import '../../core/api/api_exception.dart';
import '../../core/utils/auth_navigation.dart';
import '../../shared/widgets/saco_logo.dart';
import '../../shared/widgets/saco_buttons.dart';
import 'auth_provider.dart';

class OtpVerificationScreen extends ConsumerStatefulWidget {
  const OtpVerificationScreen({super.key});

  @override
  ConsumerState<OtpVerificationScreen> createState() => _OtpVerificationScreenState();
}

class _OtpVerificationScreenState extends ConsumerState<OtpVerificationScreen> {
  final _otpController = TextEditingController();
  int _countdown = 60;

  @override
  void initState() {
    super.initState();
    _startCountdown();
  }

  @override
  void dispose() {
    _otpController.dispose();
    super.dispose();
  }

  void _startCountdown() {
    Future.doWhile(() async {
      await Future<void>.delayed(const Duration(seconds: 1));
      if (!mounted) return false;
      if (_countdown > 0) {
        setState(() => _countdown--);
        return true;
      }
      return false;
    });
  }

  Future<void> _verify() async {
    final otp = _otpController.text.replaceAll(RegExp(r'\D'), '');
    if (otp.length != 6) {
      _snack('Vui lòng nhập đủ 6 chữ số.', isError: true);
      return;
    }

    try {
      await ref.read(authControllerProvider.notifier).verifyOtpAndLogin(otp);
      final prefs = ref.read(userPrefsProvider);
      final role = prefs.pendingRole ?? 'tenant';
      final storedReturn = sanitizeReturnUrl(prefs.authReturnUrl);
      String returnUrl = storedReturn ?? '/profile-setup';
      if (storedReturn == null) {
        if (role == 'landlord') {
          returnUrl = '/profile/me';
        }
      }
      _snack('Xác thực thành công!');
      await ref.read(userPrefsProvider).clearAuthReturnUrl();
      if (!mounted) return;
      context.go(returnUrl);
    } on ApiException catch (e) {
      _snack(e.message, isError: true);
    } catch (e) {
      _snack('Xác thực thất bại.', isError: true);
    }
  }

  void _snack(String msg, {bool isError = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg),
        backgroundColor: isError ? Colors.red.shade700 : SacoColors.sacoOrange,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final prefs = ref.watch(userPrefsProvider);
    final email = prefs.tempEmail ?? 'email@example.com';
    final loading = ref.watch(authControllerProvider).isLoading;

    return Scaffold(
      backgroundColor: SacoColors.pageBackground,
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.go('/register'),
        ),
        title: SacoLogo(height: 32, onTap: () => context.go('/')),
        centerTitle: true,
      ),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text(
              'Xác thực email',
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.w800,
                color: SacoColors.sacoBlue,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Nhập mã OTP 6 số đã gửi đến $email',
              style: const TextStyle(color: SacoColors.sacoGray),
            ),
            const SizedBox(height: 24),
            TextField(
              controller: _otpController,
              keyboardType: TextInputType.number,
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 28, fontWeight: FontWeight.bold),
              inputFormatters: [
                FilteringTextInputFormatter.digitsOnly,
                LengthLimitingTextInputFormatter(6),
              ],
              decoration: const InputDecoration(
                hintText: '000000',
                counterText: '',
              ),
              onChanged: (v) {
                final clean = v.replaceAll(RegExp(r'\D'), '');
                if (clean != v) {
                  _otpController.value = TextEditingValue(
                    text: clean,
                    selection: TextSelection.collapsed(offset: clean.length),
                  );
                }
              },
            ),
            const SizedBox(height: 24),
            SacoPrimaryButton(
              label: 'Xác thực',
              loading: loading,
              onPressed: _verify,
            ),
            const SizedBox(height: 16),
            TextButton(
              onPressed: _countdown == 0
                  ? () {
                      setState(() => _countdown = 60);
                      _startCountdown();
                      _snack('Đã gửi lại mã (mock).');
                    }
                  : null,
              child: Text(
                _countdown > 0
                    ? 'Gửi lại mã sau ${_countdown}s'
                    : 'Gửi lại mã OTP',
              ),
            ),
          ],
        ),
      ),
    );
  }
}
