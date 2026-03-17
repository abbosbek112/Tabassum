import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../../core/localization.dart';
import '../../core/constants.dart';
import 'auth_controller.dart';

class AuthScreen extends ConsumerStatefulWidget {
  const AuthScreen({super.key});

  @override
  ConsumerState<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends ConsumerState<AuthScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabs;
  bool _isLogin = true;
  bool _obscureLoginPass = true;
  bool _obscureSignUpPass = true;

  final _loginEmailCtrl = TextEditingController();
  final _loginPassCtrl = TextEditingController();
  final _signUpEmailCtrl = TextEditingController();
  final _signUpPassCtrl = TextEditingController();

  @override
  void initState() {
    super.initState();
    _tabs = TabController(length: 2, vsync: this);
    _tabs.addListener(() {
      if (_tabs.indexIsChanging) return;
      setState(() => _isLogin = _tabs.index == 0);
    });
  }

  @override
  void dispose() {
    _tabs.dispose();
    _loginEmailCtrl.dispose();
    _loginPassCtrl.dispose();
    _signUpEmailCtrl.dispose();
    _signUpPassCtrl.dispose();
    super.dispose();
  }

  // ─── Design Tokens ──────────────────────────────────────
  static const _primary = Color(0xFF0F172A);
  static const _accent = Color(0xFF3B82F6);
  static const _accentLight = Color(0xFFDBEAFE);
  static const _bgGradientTop = Color(0xFFF0F4FF);
  static const _bgGradientBot = Color(0xFFFAFBFF);
  static const _cardBg = Colors.white;
  static const _inputBg = Color(0xFFF8FAFC);
  static const _inputBorder = Color(0xFFE2E8F0);
  static const _inputFocusBorder = Color(0xFF3B82F6);
  static const _textPrimary = Color(0xFF0F172A);
  static const _textSecondary = Color(0xFF64748B);
  static const _textTertiary = Color(0xFF94A3B8);
  static const _dividerColor = Color(0xFFE2E8F0);

  void _showResetPasswordDialog() {
    final emailCtrl = TextEditingController(text: _loginEmailCtrl.text);
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text(ctx.l('forgot_password'), style: const TextStyle(fontWeight: FontWeight.w700)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(ctx.l('enter_email_to_reset'), style: const TextStyle(color: _textSecondary)),
            const SizedBox(height: 16),
            TextField(
              controller: emailCtrl,
              decoration: InputDecoration(
                labelText: ctx.l('email'),
                prefixIcon: const Icon(Icons.alternate_email_rounded, size: 20),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(ctx.l('cancel'), style: const TextStyle(color: _textSecondary)),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: _primary,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            onPressed: () async {
              final email = emailCtrl.text.trim();
              if (email.isEmpty) return;
              await ref.read(authControllerProvider.notifier).sendPasswordResetEmail(email);
              if (ctx.mounted) {
                Navigator.pop(ctx);
                ScaffoldMessenger.of(ctx).showSnackBar(
                  SnackBar(
                    content: Text(ctx.l('reset_email_sent')),
                    behavior: SnackBarBehavior.floating,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                );
              }
            },
            child: Text(ctx.l('apply')),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final authAsync = ref.watch(authControllerProvider);
    final isBusy = authAsync.isLoading;
    final mq = MediaQuery.of(context);
    final w = mq.size.width;
    final isCompact = w < 375;

    ref.listen(authControllerProvider, (prev, next) {
      final err = next.error;
      if (err != null && context.mounted) {
        ScaffoldMessenger.of(context)
          ..clearSnackBars()
          ..showSnackBar(
            SnackBar(
              content: Row(
                children: [
                  const Icon(Icons.error_outline_rounded, color: Colors.white, size: 20),
                  const SizedBox(width: 10),
                  Expanded(child: Text(_friendlyError(err))),
                ],
              ),
              backgroundColor: const Color(0xFFEF4444),
              behavior: SnackBarBehavior.floating,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              margin: const EdgeInsets.all(16),
            ),
          );
      }
    });

    return Scaffold(
      backgroundColor: _bgGradientTop,
      body: Stack(
        children: [
          // Decorative background
          _buildDecoBackground(w),

          // Main content
          SafeArea(
            child: LayoutBuilder(
              builder: (context, constraints) {
                final hPad = isCompact ? 20.0 : (w > 500 ? (w - 420) / 2 : 28.0);

                return SingleChildScrollView(
                  padding: EdgeInsets.symmetric(horizontal: hPad),
                  physics: const BouncingScrollPhysics(),
                  child: ConstrainedBox(
                    constraints: BoxConstraints(minHeight: constraints.maxHeight),
                    child: IntrinsicHeight(
                      child: Column(
                        children: [
                          SizedBox(height: isCompact ? 28 : 44),

                          // Branding
                          _buildBranding(isCompact),

                          SizedBox(height: isCompact ? 6 : 10),

                          // Subtitle
                          Text(
                            context.l('auth_subtitle'),
                            style: TextStyle(
                              color: _textSecondary,
                              fontSize: isCompact ? 14 : 15,
                              fontWeight: FontWeight.w500,
                            ),
                          ).animate().fadeIn(delay: 350.ms, duration: 500.ms),

                          SizedBox(height: isCompact ? 24 : 36),

                          // Card
                          _buildCard(isBusy, isCompact),

                          SizedBox(height: isCompact ? 18 : 24),

                          // Social login
                          _buildSocial(isBusy, isCompact),

                          const Spacer(),

                          // Footer
                          _buildFooter(isCompact),

                          SizedBox(height: isCompact ? 12 : 20),
                        ],
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  // ─── Decorative BG ──────────────────────────────────────
  Widget _buildDecoBackground(double screenW) {
    return Stack(
      children: [
        // Base Gradient
        Positioned.fill(
          child: Container(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [_bgGradientTop, _bgGradientBot, Colors.white],
              ),
            ),
          ),
        ),
        
        // Floating Orb 1: Large soft blue top-left
        _buildFloatingOrb(
          top: -100,
          left: -100,
          size: 300,
          color: _accent.withOpacity(0.05),
          moveOffset: const Offset(40, 60),
          duration: 15.seconds,
        ),

        // Floating Orb 2: Medium purple top-right
        _buildFloatingOrb(
          top: 100,
          right: -80,
          size: 250,
          color: const Color(0xFF8B5CF6).withOpacity(0.04),
          moveOffset: const Offset(-50, 40),
          duration: 18.seconds,
        ),

        // Floating Orb 3: Small cyan bottom-right
        _buildFloatingOrb(
          bottom: 40,
          right: 20,
          size: 180,
          color: const Color(0xFF06B6D4).withOpacity(0.03),
          moveOffset: const Offset(-30, -50),
          duration: 12.seconds,
        ),

        // Floating Orb 4: Medium indigo bottom-left
        _buildFloatingOrb(
          bottom: -50,
          left: 40,
          size: 220,
          color: _primary.withOpacity(0.04),
          moveOffset: const Offset(50, -30),
          duration: 20.seconds,
        ),
      ],
    );
  }

  Widget _buildFloatingOrb({
    double? top,
    double? left,
    double? right,
    double? bottom,
    required double size,
    required Color color,
    required Offset moveOffset,
    required Duration duration,
  }) {
    return Positioned(
      top: top,
      left: left,
      right: right,
      bottom: bottom,
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          gradient: RadialGradient(
            colors: [color, color.withOpacity(0)],
          ),
        ),
      )
      .animate(onPlay: (c) => c.repeat(reverse: true))
      .move(begin: Offset.zero, end: moveOffset, duration: duration, curve: Curves.easeInOutSine)
      .scale(begin: const Offset(1, 1), end: const Offset(1.2, 1.2), duration: duration, curve: Curves.easeInOutSine),
    );
  }

  // ─── Branding ───────────────────────────────────────────
  Widget _buildBranding(bool isCompact) {
    final iconSize = isCompact ? 28.0 : 34.0;
    final titleSize = isCompact ? 26.0 : 32.0;

    return Column(
      children: [
        // Logo with gradient background
        Container(
          padding: EdgeInsets.all(isCompact ? 14 : 18),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [_primary, Color(0xFF1E293B)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(isCompact ? 18 : 22),
            boxShadow: [
              BoxShadow(
                color: _primary.withOpacity(0.15),
                blurRadius: 30,
                offset: const Offset(0, 10),
              ),
            ],
          ),
          child: Icon(Icons.shopping_bag_rounded, size: iconSize, color: Colors.white),
        )
          .animate().scale(duration: 600.ms, curve: Curves.easeOutBack, delay: 100.ms)
          .then().shimmer(duration: 1200.ms, color: Colors.white.withOpacity(0.15)),

        SizedBox(height: isCompact ? 16 : 22),

        // Title
        Text(
          'Tabassum',
          style: TextStyle(
            color: _textPrimary,
            fontWeight: FontWeight.w900,
            fontSize: titleSize,
            letterSpacing: -1.0,
            height: 1.1,
          ),
        ).animate().fadeIn(delay: 200.ms, duration: 500.ms).slideY(begin: 0.2, end: 0),
      ],
    );
  }

  // ─── Card ───────────────────────────────────────────────
  Widget _buildCard(bool isBusy, bool isCompact) {
    final padH = isCompact ? 18.0 : 26.0;
    final padV = isCompact ? 22.0 : 30.0;
    final radius = isCompact ? 22.0 : 26.0;
    final formH = isCompact ? 145.0 : 165.0;

    return Container(
      padding: EdgeInsets.symmetric(horizontal: padH, vertical: padV),
      decoration: BoxDecoration(
        color: _cardBg,
        borderRadius: BorderRadius.circular(radius),
        border: Border.all(color: const Color(0xFFF1F5F9), width: 1),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF0F172A).withOpacity(0.04),
            blurRadius: 40,
            offset: const Offset(0, 12),
            spreadRadius: 0,
          ),
          BoxShadow(
            color: const Color(0xFF0F172A).withOpacity(0.02),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Tab Switcher
          Container(
            height: isCompact ? 44 : 50,
            padding: const EdgeInsets.all(3),
            decoration: BoxDecoration(
              color: const Color(0xFFF1F5F9),
              borderRadius: BorderRadius.circular(isCompact ? 13 : 15),
            ),
            child: TabBar(
              controller: _tabs,
              indicatorSize: TabBarIndicatorSize.tab,
              dividerColor: Colors.transparent,
              indicator: BoxDecoration(
                borderRadius: BorderRadius.circular(isCompact ? 10 : 12),
                color: _primary,
                boxShadow: [
                  BoxShadow(
                    color: _primary.withOpacity(0.15),
                    blurRadius: 6,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              labelColor: Colors.white,
              unselectedLabelColor: _textSecondary,
              labelStyle: TextStyle(fontWeight: FontWeight.w700, fontSize: isCompact ? 13 : 14),
              unselectedLabelStyle: TextStyle(fontWeight: FontWeight.w500, fontSize: isCompact ? 13 : 14),
              splashFactory: NoSplash.splashFactory,
              overlayColor: WidgetStateProperty.all(Colors.transparent),
              tabs: [
                Tab(text: context.l('login')),
                Tab(text: context.l('sign_up')),
              ],
            ),
          ),

          SizedBox(height: isCompact ? 22 : 28),

          // Forms
          SizedBox(
            height: formH,
            child: TabBarView(
              controller: _tabs,
              children: [
                _buildLoginForm(isBusy, isCompact),
                _buildSignUpForm(isBusy, isCompact),
              ],
            ),
          ),

          SizedBox(height: isCompact ? 18 : 24),

          // Action Button
          SizedBox(
            width: double.infinity,
            height: isCompact ? 50 : 56,
            child: AnimatedContainer(
              duration: 200.ms,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(isCompact ? 14 : 16),
                boxShadow: isBusy ? [] : [
                  BoxShadow(
                    color: _primary.withOpacity(0.15),
                    blurRadius: 16,
                    offset: const Offset(0, 6),
                  ),
                ],
              ),
              child: FilledButton(
                style: FilledButton.styleFrom(
                  backgroundColor: _primary,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(isCompact ? 14 : 16),
                  ),
                  elevation: 0,
                ),
                onPressed: isBusy ? null : _submit,
                child: AnimatedSwitcher(
                  duration: 200.ms,
                  child: isBusy
                    ? const SizedBox(
                        key: ValueKey('loading'),
                        width: 22, height: 22,
                        child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2.5),
                      )
                    : Text(
                        key: ValueKey(_isLogin ? 'login' : 'signup'),
                        (_isLogin ? context.l('login') : context.l('create_account')).toUpperCase(),
                        style: TextStyle(
                          fontSize: isCompact ? 13 : 15,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 1.0,
                        ),
                      ),
                ),
              ),
            ),
          ),

          if (_isLogin) ...[
            SizedBox(height: isCompact ? 8 : 12),
            TextButton(
              onPressed: isBusy ? null : _showResetPasswordDialog,
              style: TextButton.styleFrom(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              ),
              child: Text(
                context.l('forgot_password'),
                style: TextStyle(
                  color: _accent,
                  fontSize: isCompact ? 12 : 13,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ],
      ),
    ).animate()
      .fadeIn(duration: 600.ms, delay: 300.ms)
      .moveY(begin: 24, end: 0, curve: Curves.easeOutCubic);
  }

  // ─── Forms ──────────────────────────────────────────────
  Widget _buildLoginForm(bool isBusy, bool isCompact) {
    return Column(
      children: [
        _buildField(
          controller: _loginEmailCtrl,
          label: context.l('email'),
          icon: Icons.alternate_email_rounded,
          keyboardType: TextInputType.emailAddress,
          isBusy: isBusy,
          isCompact: isCompact,
        ),
        SizedBox(height: isCompact ? 12 : 16),
        _buildField(
          controller: _loginPassCtrl,
          label: context.l('password'),
          icon: Icons.lock_outline_rounded,
          isPassword: true,
          obscure: _obscureLoginPass,
          onToggleObscure: () => setState(() => _obscureLoginPass = !_obscureLoginPass),
          isBusy: isBusy,
          isCompact: isCompact,
        ),
      ],
    );
  }

  Widget _buildSignUpForm(bool isBusy, bool isCompact) {
    return Column(
      children: [
        _buildField(
          controller: _signUpEmailCtrl,
          label: context.l('email'),
          icon: Icons.alternate_email_rounded,
          keyboardType: TextInputType.emailAddress,
          isBusy: isBusy,
          isCompact: isCompact,
        ),
        SizedBox(height: isCompact ? 12 : 16),
        _buildField(
          controller: _signUpPassCtrl,
          label: context.l('password'),
          icon: Icons.lock_outline_rounded,
          isPassword: true,
          obscure: _obscureSignUpPass,
          onToggleObscure: () => setState(() => _obscureSignUpPass = !_obscureSignUpPass),
          isBusy: isBusy,
          isCompact: isCompact,
        ),
      ],
    );
  }

  // ─── Text Field ─────────────────────────────────────────
  Widget _buildField({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    bool isPassword = false,
    bool obscure = false,
    VoidCallback? onToggleObscure,
    bool isBusy = false,
    bool isCompact = false,
    TextInputType keyboardType = TextInputType.text,
  }) {
    final borderR = isCompact ? 12.0 : 14.0;

    return TextField(
      controller: controller,
      obscureText: isPassword ? obscure : false,
      enabled: !isBusy,
      keyboardType: keyboardType,
      style: TextStyle(
        color: _textPrimary,
        fontWeight: FontWeight.w500,
        fontSize: isCompact ? 14 : 15,
      ),
      cursorColor: _accent,
      decoration: InputDecoration(
        filled: true,
        fillColor: _inputBg,
        prefixIcon: Padding(
          padding: const EdgeInsets.only(left: 14, right: 8),
          child: Icon(icon, color: _textTertiary, size: isCompact ? 18 : 20),
        ),
        prefixIconConstraints: const BoxConstraints(minWidth: 0, minHeight: 0),
        suffixIcon: isPassword
          ? IconButton(
              icon: Icon(
                obscure ? Icons.visibility_off_outlined : Icons.visibility_outlined,
                color: _textTertiary,
                size: isCompact ? 18 : 20,
              ),
              onPressed: onToggleObscure,
              splashRadius: 18,
            )
          : null,
        labelText: label,
        labelStyle: TextStyle(color: _textTertiary, fontSize: isCompact ? 13 : 14),
        floatingLabelStyle: TextStyle(
          color: _inputFocusBorder,
          fontSize: isCompact ? 12 : 13,
          fontWeight: FontWeight.w600,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(borderR),
          borderSide: const BorderSide(color: _inputBorder),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(borderR),
          borderSide: const BorderSide(color: _inputBorder),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(borderR),
          borderSide: const BorderSide(color: _inputFocusBorder, width: 1.5),
        ),
        contentPadding: EdgeInsets.symmetric(
          horizontal: isCompact ? 14 : 18,
          vertical: isCompact ? 14 : 16,
        ),
      ),
    );
  }

  // ─── Social Login ───────────────────────────────────────
  Widget _buildSocial(bool isBusy, bool isCompact) {
    return Column(
      children: [
        // Divider
        Row(
          children: [
            const Expanded(child: Divider(color: _dividerColor, thickness: 1)),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                decoration: BoxDecoration(
                  color: const Color(0xFFF8FAFC),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: _dividerColor),
                ),
                child: const Text(
                  'OR',
                  style: TextStyle(
                    color: _textTertiary,
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 1.5,
                  ),
                ),
              ),
            ),
            const Expanded(child: Divider(color: _dividerColor, thickness: 1)),
          ],
        ),

        SizedBox(height: isCompact ? 16 : 22),

        // Google Button
        SizedBox(
          width: double.infinity,
          height: isCompact ? 50 : 54,
          child: OutlinedButton(
            style: OutlinedButton.styleFrom(
              side: const BorderSide(color: _inputBorder, width: 1.5),
              backgroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(isCompact ? 14 : 16),
              ),
              elevation: 0,
            ),
            onPressed: isBusy ? null : () => ref.read(authControllerProvider.notifier).signInWithGoogle(),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              mainAxisSize: MainAxisSize.min,
              children: [
                Image.asset(
                  'images/google_logo.png',
                  height: isCompact ? 20 : 22,
                  errorBuilder: (_, __, ___) => Icon(
                    Icons.login_rounded,
                    color: _textSecondary,
                    size: isCompact ? 20 : 22,
                  ),
                ),
                SizedBox(width: isCompact ? 10 : 12),
                Flexible(
                  child: Text(
                    context.l('google_sign_in'),
                    style: TextStyle(
                      color: _textPrimary,
                      fontWeight: FontWeight.w600,
                      fontSize: isCompact ? 13 : 14,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    ).animate().fadeIn(delay: 500.ms, duration: 500.ms);
  }

  // ─── Footer ─────────────────────────────────────────────
  Widget _buildFooter(bool isCompact) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8),
      child: Text(
        'Tabassum Marketplace © 2024',
        textAlign: TextAlign.center,
        style: TextStyle(
          color: _textTertiary.withOpacity(0.6),
          fontSize: isCompact ? 11 : 12,
          fontWeight: FontWeight.w400,
        ),
      ),
    ).animate().fadeIn(delay: 800.ms);
  }

  // ─── Logic ──────────────────────────────────────────────
  Future<void> _submit() async {
    final email = _isLogin ? _loginEmailCtrl.text : _signUpEmailCtrl.text;
    final pass = _isLogin ? _loginPassCtrl.text : _signUpPassCtrl.text;

    if (!_validate(context, email, pass)) return;

    if (_isLogin) {
      await ref.read(authControllerProvider.notifier).signIn(email: email, password: pass);
    } else {
      await ref.read(authControllerProvider.notifier).signUp(
            email: email,
            password: pass,
            role: UserRole.customer,
          );
    }
  }

  bool _validate(BuildContext context, String email, String password) {
    final trimmedEmail = email.trim();
    final trimmedPass = password.trim();

    if (trimmedEmail.isEmpty || !trimmedEmail.contains('@')) {
      _showSnack(context.l('valid_email_required'));
      return false;
    }
    if (trimmedPass.length < 6) {
      _showSnack(context.l('password_min_length'));
      return false;
    }
    return true;
  }

  void _showSnack(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg),
        backgroundColor: const Color(0xFFEF4444),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        margin: const EdgeInsets.all(16),
      ),
    );
  }
}

String _friendlyError(Object err) {
  if (err is FirebaseAuthException) {
    switch (err.code) {
      case 'invalid-email': return 'Email manzil noto\'g\'ri formatda.';
      case 'user-not-found': return 'Bu email bilan foydalanuvchi topilmadi.';
      case 'wrong-password':
      case 'invalid-credential': return 'Email yoki parol noto\'g\'ri.';
      case 'email-already-in-use': return 'Bu email allaqachon ro\'yxatdan o\'tgan.';
      case 'weak-password': return 'Parol juda oddiy — kamida 6 ta belgi kiriting.';
      case 'too-many-requests': return 'Juda ko\'p urinish. Biroz kuting.';
      case 'network-request-failed': return 'Tarmoq xatosi. Internetni tekshiring.';
      default: return err.message ?? err.code;
    }
  }
  return err.toString();
}
