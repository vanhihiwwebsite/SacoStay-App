import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../config/theme.dart';
import '../../shared/widgets/saco_logo.dart';
import '../../core/api/api_exception.dart';
import '../../core/utils/auth_navigation.dart';
import '../../core/utils/user_display.dart';
import '../../models/user_profile.dart';
import '../../shared/widgets/saco_buttons.dart';
import 'auth_provider.dart';

enum AuthMode { login, register }

class AuthScreen extends ConsumerStatefulWidget {
  const AuthScreen({super.key, this.initialMode = AuthMode.login});

  final AuthMode initialMode;

  @override
  ConsumerState<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends ConsumerState<AuthScreen> {
  late AuthMode _mode = widget.initialMode;
  String? _loginError;
  bool _loginBanned = false;
  String? _registerError;

  final _loginIdentifier = TextEditingController();
  final _loginPassword = TextEditingController();
  final _firstName = TextEditingController();
  final _lastName = TextEditingController();
  final _username = TextEditingController();
  final _phone = TextEditingController();
  final _email = TextEditingController();
  final _password = TextEditingController();
  final _confirmPassword = TextEditingController();

  bool _showLoginPassword = false;
  bool _showRegisterPassword = false;
  bool _showConfirmPassword = false;
  String _selectedRole = 'tenant';
  String? _returnUrl;
  String? _roleQuery;
  bool _routeParamsSynced = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_routeParamsSynced) return;
    _routeParamsSynced = true;
    final params = GoRouterState.of(context).uri.queryParameters;
    _returnUrl = params['returnUrl'];
    _roleQuery = params['role'];
    if (_roleQuery == 'landlord') {
      _selectedRole = 'landlord';
    }
  }

  @override
  void dispose() {
    _loginIdentifier.dispose();
    _loginPassword.dispose();
    _firstName.dispose();
    _lastName.dispose();
    _username.dispose();
    _phone.dispose();
    _email.dispose();
    _password.dispose();
    _confirmPassword.dispose();
    super.dispose();
  }

  bool get _requiresLandlordAuth => _roleQuery == 'landlord';

  Future<void> _submitLogin() async {
    final identifier = _loginIdentifier.text.trim();
    final password = _loginPassword.text;
    if (identifier.length < 3 || password.isEmpty) {
      _loginError = 'Vui lòng nhập đủ thông tin đăng nhập.';
      setState(() {});
      return;
    }

    _loginError = null;
    _loginBanned = false;
    setState(() {});

    try {
      await ref.read(authControllerProvider.notifier).login(
            identifier: identifier,
            password: password,
          );
      await ref.read(authControllerProvider.notifier).refreshUser();
      _navigateAfterAuth();
    } on ApiException catch (e) {
      _loginError = e.message;
      _loginBanned = e.isBanned;
      setState(() {});
      if (!e.isBanned) _showSnack(e.message, isError: true);
    } catch (e) {
      _loginError = e.toString();
      setState(() {});
      _showSnack('Đăng nhập thất bại.', isError: true);
    }
  }

  Future<void> _submitRegister() async {
    final fn = _firstName.text.trim();
    final ln = _lastName.text.trim();
    final un = _username.text.trim();
    final phone = _phone.text.trim();
    final email = _email.text.trim();
    final pw = _password.text;
    final cpw = _confirmPassword.text;

    if (fn.isEmpty || ln.isEmpty || un.isEmpty || phone.isEmpty || email.isEmpty) {
      _registerError = 'Vui lòng điền đầy đủ thông tin.';
      setState(() {});
      return;
    }
    if (pw.length < 6) {
      _registerError = 'Mật khẩu phải có ít nhất 6 ký tự.';
      setState(() {});
      return;
    }
    if (pw != cpw) {
      _registerError = 'Mật khẩu xác nhận không khớp.';
      setState(() {});
      return;
    }
    if (!RegExp(r'^[0-9]{10,11}$').hasMatch(phone)) {
      _registerError = 'Số điện thoại không hợp lệ.';
      setState(() {});
      return;
    }

    _registerError = null;
    setState(() {});

    try {
      final request = RegisterRequest(
        userName: un,
        email: email,
        password: pw,
        confirmPassword: cpw,
        role: _selectedRole,
        firstName: fn,
        lastName: ln,
        phoneNumber: phone,
      );
      await ref.read(authControllerProvider.notifier).register(request);

      final prefs = ref.read(userPrefsProvider);
      final safeReturn = sanitizeReturnUrl(_returnUrl);
      if (safeReturn != null) {
        await prefs.setAuthReturnUrl(safeReturn);
      }

      _showSnack('Đăng ký thành công! Vui lòng xác thực OTP.');
      context.go('/otp-verification');
    } on ApiException catch (e) {
      _registerError = e.message;
      setState(() {});
      _showSnack(e.message, isError: true);
    } catch (e) {
      _registerError = e.toString();
      setState(() {});
      _showSnack('Đăng ký thất bại.', isError: true);
    }
  }

  void _navigateAfterAuth() {
    final auth = ref.read(authControllerProvider);
    if (isAdminUser(auth.user?.raw)) {
      context.go('/admin');
      return;
    }
    final returnUrl = _returnUrl;
    final target = resolvePostLoginUrl(returnUrl);
    if (isCreateListingReturnUrl(target) && !isLandlordUser(auth.user?.raw)) {
      _showSnack('Chỉ có thể đăng tin với vai trò chủ trọ.', isError: true);
      context.go('/');
      return;
    }
    ref.read(userPrefsProvider).clearAuthReturnUrl();
    _showSnack('Đăng nhập thành công');
    context.go(target);
  }

  void _showSnack(String message, {bool isError = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: isError ? Colors.red.shade700 : SacoColors.sacoOrange,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final loading = ref.watch(authControllerProvider).isLoading;

    return Scaffold(
      backgroundColor: SacoColors.pageBackground,
      body: SafeArea(
        child: Stack(
          children: [
            Positioned(
              top: -80,
              left: -80,
              child: Container(
                width: 200,
                height: 200,
                decoration: BoxDecoration(
                  color: SacoColors.sacoOrange.withValues(alpha: 0.1),
                  shape: BoxShape.circle,
                ),
              ),
            ),
            Positioned(
              bottom: -80,
              right: -80,
              child: Container(
                width: 200,
                height: 200,
                decoration: BoxDecoration(
                  color: const Color(0xFF4A9FD9).withValues(alpha: 0.1),
                  shape: BoxShape.circle,
                ),
              ),
            ),
            SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              child: Column(
                children: [
                  Align(
                    alignment: Alignment.centerLeft,
                    child: SacoLogo(
                      height: 40,
                      onTap: () => context.go('/'),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Container(
                    width: double.infinity,
                    constraints: const BoxConstraints(maxWidth: 480),
                    padding: const EdgeInsets.all(24),
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
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Text(
                          _mode == AuthMode.login
                              ? 'Chào mừng trở lại!'
                              : 'Tạo tài khoản mới',
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.w800,
                            color: SacoColors.sacoBlue,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          _mode == AuthMode.login
                              ? 'Đăng nhập để tiếp tục tìm kiếm bạn ở ghép'
                              : 'Tham gia cộng đồng SacoStay ngay hôm nay',
                          textAlign: TextAlign.center,
                          style: const TextStyle(color: SacoColors.sacoGray),
                        ),
                        const SizedBox(height: 24),
                        if (_mode == AuthMode.login) ...[
                          if (_requiresLandlordAuth)
                            Container(
                              padding: const EdgeInsets.all(12),
                              margin: const EdgeInsets.only(bottom: 16),
                              decoration: BoxDecoration(
                                color: Colors.amber.shade50,
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(color: Colors.amber.shade200),
                              ),
                              child: Text(
                                'Để đăng tin phòng, vui lòng đăng nhập bằng tài khoản chủ trọ hoặc đăng ký mới với vai trò chủ trọ.',
                                style: TextStyle(color: Colors.amber.shade900, fontSize: 13),
                              ),
                            ),
                          SacoTextField(
                            controller: _loginIdentifier,
                            label: 'Email hoặc tên đăng nhập',
                            hint: 'email@example.com hoặc username',
                            prefixIcon: const Icon(Icons.person_outline),
                          ),
                          const SizedBox(height: 12),
                          SacoTextField(
                            controller: _loginPassword,
                            label: 'Mật khẩu',
                            obscureText: !_showLoginPassword,
                            prefixIcon: const Icon(Icons.lock_outline),
                            suffixIcon: IconButton(
                              onPressed: () =>
                                  setState(() => _showLoginPassword = !_showLoginPassword),
                              icon: Icon(
                                _showLoginPassword ? Icons.visibility_off : Icons.visibility,
                              ),
                            ),
                          ),
                          Align(
                            alignment: Alignment.centerRight,
                            child: TextButton(
                              onPressed: () => context.go('/forgot-password'),
                              child: const Text('Quên mật khẩu?'),
                            ),
                          ),
                          if (_loginBanned)
                            Container(
                              padding: const EdgeInsets.all(12),
                              margin: const EdgeInsets.only(bottom: 12),
                              decoration: BoxDecoration(
                                color: Colors.amber.shade50,
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(color: Colors.amber.shade300),
                              ),
                              child: Text(
                                _loginError ?? '',
                                style: TextStyle(color: Colors.amber.shade900, fontSize: 13),
                              ),
                            ),
                          if (_loginError != null && !_loginBanned)
                            Padding(
                              padding: const EdgeInsets.only(bottom: 12),
                              child: Text(
                                _loginError!,
                                textAlign: TextAlign.center,
                                style: const TextStyle(color: Colors.red),
                              ),
                            ),
                          SacoPrimaryButton(
                            label: 'Đăng nhập',
                            loading: loading,
                            onPressed: _submitLogin,
                          ),
                          const SizedBox(height: 16),
                          Center(
                            child: TextButton(
                              onPressed: () => context.go(
                                Uri(
                                  path: '/register',
                                  queryParameters: GoRouterState.of(context).uri.queryParameters,
                                ).toString(),
                              ),
                              child: const Text('Chưa có tài khoản? Đăng ký ngay'),
                            ),
                          ),
                        ] else ...[
                          const Text(
                            'Bạn là ai?',
                            style: TextStyle(fontWeight: FontWeight.w600),
                          ),
                          const SizedBox(height: 8),
                          Row(
                            children: [
                              Expanded(
                                child: _RoleChip(
                                  label: 'Người thuê trọ',
                                  subtitle: 'Tìm phòng & bạn ở ghép',
                                  selected: _selectedRole == 'tenant',
                                  onTap: () => setState(() => _selectedRole = 'tenant'),
                                ),
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: _RoleChip(
                                  label: 'Chủ trọ',
                                  subtitle: 'Đăng tin cho thuê',
                                  selected: _selectedRole == 'landlord',
                                  onTap: () => setState(() => _selectedRole = 'landlord'),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 16),
                          Row(
                            children: [
                              Expanded(
                                child: SacoTextField(
                                  controller: _firstName,
                                  label: 'Họ',
                                  hint: 'Nguyễn',
                                ),
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: SacoTextField(
                                  controller: _lastName,
                                  label: 'Tên',
                                  hint: 'Văn A',
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          SacoTextField(
                            controller: _username,
                            label: 'Tên đăng nhập',
                            hint: 'username123',
                            prefixIcon: const Icon(Icons.badge_outlined),
                          ),
                          const SizedBox(height: 12),
                          SacoTextField(
                            controller: _phone,
                            label: 'Số điện thoại',
                            hint: '0912345678',
                            keyboardType: TextInputType.phone,
                            prefixIcon: const Icon(Icons.phone_outlined),
                          ),
                          const SizedBox(height: 12),
                          SacoTextField(
                            controller: _email,
                            label: 'Email',
                            hint: 'name@example.com',
                            keyboardType: TextInputType.emailAddress,
                            autocorrect: false,
                            prefixIcon: const Icon(Icons.email_outlined),
                          ),
                          const SizedBox(height: 12),
                          SacoTextField(
                            controller: _password,
                            label: 'Mật khẩu',
                            obscureText: !_showRegisterPassword,
                            prefixIcon: const Icon(Icons.lock_outline),
                            suffixIcon: IconButton(
                              onPressed: () =>
                                  setState(() => _showRegisterPassword = !_showRegisterPassword),
                              icon: Icon(
                                _showRegisterPassword ? Icons.visibility_off : Icons.visibility,
                              ),
                            ),
                          ),
                          const SizedBox(height: 12),
                          SacoTextField(
                            controller: _confirmPassword,
                            label: 'Xác nhận mật khẩu',
                            obscureText: !_showConfirmPassword,
                            prefixIcon: const Icon(Icons.lock_outline),
                            suffixIcon: IconButton(
                              onPressed: () =>
                                  setState(() => _showConfirmPassword = !_showConfirmPassword),
                              icon: Icon(
                                _showConfirmPassword ? Icons.visibility_off : Icons.visibility,
                              ),
                            ),
                          ),
                          if (_registerError != null) ...[
                            const SizedBox(height: 12),
                            Text(
                              _registerError!,
                              textAlign: TextAlign.center,
                              style: const TextStyle(color: Colors.red),
                            ),
                          ],
                          const SizedBox(height: 16),
                          SacoPrimaryButton(
                            label: 'Đăng ký',
                            loading: loading,
                            onPressed: _submitRegister,
                          ),
                          const SizedBox(height: 16),
                          Center(
                            child: TextButton(
                              onPressed: () => context.go(
                                Uri(
                                  path: '/login',
                                  queryParameters:
                                      GoRouterState.of(context).uri.queryParameters,
                                ).toString(),
                              ),
                              child: const Text('Đã có tài khoản? Đăng nhập ngay'),
                            ),
                          ),
                        ],
                        const SizedBox(height: 16),
                        const Text(
                          'Bằng việc tiếp tục, bạn đồng ý với Điều khoản sử dụng và Chính sách của SacoStay.',
                          textAlign: TextAlign.center,
                          style: TextStyle(fontSize: 11, color: SacoColors.sacoGray),
                        ),
                      ],
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
}

class _RoleChip extends StatelessWidget {
  const _RoleChip({
    required this.label,
    required this.subtitle,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final String subtitle;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: selected ? SacoColors.sacoOrange.withValues(alpha: 0.08) : Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: selected ? SacoColors.sacoOrange : Colors.grey.shade200,
            width: selected ? 2 : 1,
          ),
        ),
        child: Column(
          children: [
            Icon(
              label.contains('Chủ') ? Icons.home_outlined : Icons.people_outline,
              color: selected ? SacoColors.sacoOrange : SacoColors.sacoGray,
            ),
            const SizedBox(height: 6),
            Text(
              label,
              style: TextStyle(
                fontWeight: FontWeight.w700,
                color: selected ? SacoColors.sacoOrange : SacoColors.sacoBlue,
                fontSize: 12,
              ),
            ),
            Text(
              subtitle,
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 10, color: SacoColors.sacoGray),
            ),
          ],
        ),
      ),
    );
  }
}
