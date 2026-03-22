import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../../core/twa_service.dart';
import 'auth_controller.dart';
import 'auth_repository.dart';

// ─── Design Tokens ──────────────────────────────────────────────────────────
const _primary     = Color(0xFF0F172A);
const _accent      = Color(0xFF3B82F6);
const _bgTop       = Color(0xFFF0F4FF);
const _bgBot       = Color(0xFFFAFBFF);
const _cardBg      = Colors.white;
const _inputBg     = Color(0xFFF8FAFC);
const _inputBorder = Color(0xFFE2E8F0);
const _inputFocus  = Color(0xFF3B82F6);
const _textPrimary = Color(0xFF0F172A);
const _textSecondary = Color(0xFF64748B);

class AuthScreen extends ConsumerStatefulWidget {
  const AuthScreen({super.key});

  @override
  ConsumerState<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends ConsumerState<AuthScreen> {
  final _nameCtrl    = TextEditingController();
  final _surnameCtrl = TextEditingController();
  final _ageCtrl     = TextEditingController();

  String _telegramId = '';
  bool _isCheckingLogin = true;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _initAuthFlow();
    });
  }

  Future<void> _initAuthFlow() async {
    try {
      final twa = ref.read(twaServiceProvider);
      String? id = twa.telegramUserId?.toString();
      final initData = twa.initData;

      // Fallback: If TWA id is missing (desktop reload) but we are authenticated
      if (id == null || id.isEmpty) {
        final currentFirebaseUser = FirebaseAuth.instance.currentUser;
        if (currentFirebaseUser != null && currentFirebaseUser.uid.startsWith('tg_')) {
          id = currentFirebaseUser.uid.replaceFirst('tg_', '');
        }
      }
      
      if (id != null && id.isNotEmpty) {
        setState(() => _telegramId = id!);
        
        // If we don't have initData (e.g. session reload), we can't call telegramLogin (which validates)
        // But the router only sent us here if profile is missing. 
        // If we have an active session, but no profile, and No initData (can't validate),
        // we should just show the registration form.
        
        if (initData == null || initData.isEmpty) {
          // Already have firebase session? Let's check profile again.
          final profile = ref.read(authStateProvider).user; 
          if (profile == null) {
            // No profile + No way to validate initData = just show the form
            if (mounted) setState(() => _isCheckingLogin = false);
            return;
          }
        }

        // Attempt direct login / validation if we have initData
        if (initData != null && initData.isNotEmpty) {
          final needsRegistration = await ref.read(authControllerProvider.notifier).telegramLogin(
            telegramId: id,
            initData: initData,
          );
          
          if (needsRegistration) {
            if (mounted) setState(() => _isCheckingLogin = false);
          }
          // Else: Logged in! _RouterRefreshNotifier will redirect
        } else {
          // Fallback if authenticated but somehow arrived here
          if (mounted) setState(() => _isCheckingLogin = false);
        }
      } else {
        // No telegram ID found (e.g. testing in browser)
        if (mounted) {
          setState(() => _isCheckingLogin = false);
          _snack('Telegram bo\'limidan kiring!');
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isCheckingLogin = false;
          _errorMessage = e.toString().replaceAll('Exception: ', '');
        });
      }
    }
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _surnameCtrl.dispose();
    _ageCtrl.dispose();
    super.dispose();
  }

  Future<void> _submitForm() async {
    final name = _nameCtrl.text.trim();
    final surname = _surnameCtrl.text.trim();
    final age  = int.tryParse(_ageCtrl.text.trim());

    if (name.isEmpty) {
      _snack('Ismingizni kiriting');
      return;
    }
    if (age == null || age < 10 || age > 100) {
      _snack('Yoshingizni to\'g\'ri kiriting');
      return;
    }
    if (_telegramId.isEmpty) {
      _snack('Telegram orqali tizimga kiring!');
      return;
    }

    final twa = ref.read(twaServiceProvider);
    final initData = twa.initData;
    final telegramUsername = twa.telegramUser?.username ?? '';

    if (initData == null || initData.isEmpty) {
      _snack('Telegram initData topilmadi!');
      return;
    }

    await ref.read(authControllerProvider.notifier).telegramRegister(
      telegramId: _telegramId, 
      initData: initData,
      name: name, 
      surname: surname, 
      age: age,
    );

    // After successful registration, update the profile with telegramUsername
    final firebaseUser = FirebaseAuth.instance.currentUser;
    if (firebaseUser != null && telegramUsername.isNotEmpty) {
      await ref.read(authRepositoryProvider).updateProfile(
        uid: firebaseUser.uid,
        telegramUsername: telegramUsername,
      );
    }

    final err = ref.read(authControllerProvider).error;
    if (err != null && mounted) {
      _snack(err.toString());
    }
  }

  void _snack(String msg) {
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

  @override
  Widget build(BuildContext context) {
    final isBusy = ref.watch(authControllerProvider).isLoading || _isCheckingLogin;
    final w      = MediaQuery.of(context).size.width;
    final hPad   = w > 500 ? (w - 420) / 2 : 24.0;
    final isCompact = w < 375;

    return Scaffold(
      backgroundColor: _bgTop,
      body: Stack(
        children: [
          _buildBackground(w),
          
          if (_isCheckingLogin)
            Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const CircularProgressIndicator(color: _accent),
                  const SizedBox(height: 20),
                  Text(
                    'Tabassum ga ulanmoqda...',
                    style: TextStyle(color: _textSecondary, fontSize: 14),
                  ),
                ],
              ),
            )
          else if (_errorMessage != null)
            Center(
              child: Padding(
                padding: const EdgeInsets.all(32),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.wifi_off, size: 56, color: Color(0xFFEF4444)),
                    const SizedBox(height: 16),
                    Text(
                      _errorMessage!,
                      textAlign: TextAlign.center,
                      style: const TextStyle(color: _textSecondary, fontSize: 15),
                    ),
                    const SizedBox(height: 24),
                    FilledButton.icon(
                      onPressed: () {
                        setState(() {
                          _isCheckingLogin = true;
                          _errorMessage = null;
                        });
                        _initAuthFlow();
                      },
                      icon: const Icon(Icons.refresh),
                      label: const Text('Qayta urinish'),
                    ),
                  ],
                ),
              ),
            )
          else
            SafeArea(
              child: SingleChildScrollView(
                padding: EdgeInsets.symmetric(horizontal: hPad),
                physics: const BouncingScrollPhysics(),
                child: Column(
                  children: [
                    SizedBox(height: isCompact ? 32 : 52),
                    _buildBranding(isCompact),
                    SizedBox(height: isCompact ? 8 : 14),

                    // Subtitle
                    Text(
                      'Tabassum Marketplacega xush kelibsiz!',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: _textSecondary,
                        fontSize: isCompact ? 13 : 15,
                        fontWeight: FontWeight.w500,
                        letterSpacing: 0.2,
                        height: 1.4,
                      ),
                    ).animate().fade(delay: 150.ms).slideY(begin: 0.2),

                    SizedBox(height: isCompact ? 28 : 40),

                    // the unified card
                    Container(
                      decoration: BoxDecoration(
                        color: _cardBg,
                        borderRadius: BorderRadius.circular(32),
                        boxShadow: [
                          BoxShadow(
                            color: const Color(0xFF3B82F6).withOpacity(0.08),
                            blurRadius: 40,
                            offset: const Offset(0, 16),
                            spreadRadius: -8,
                          ),
                        ],
                        border: Border.all(color: Colors.white, width: 2),
                      ),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(32),
                        child: _buildRegisterForm(isBusy),
                      ),
                    ).animate().fade(delay: 200.ms).slideY(begin: 0.05),

                    SizedBox(height: isCompact ? 24 : 32),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }

  // ─── Content Steps ────────────────────────────────────────────────────────

  Widget _buildRegisterForm(bool isBusy) {
    return Padding(
      padding: const EdgeInsets.all(28.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'Ro\'yxatdan o\'tish',
            style: TextStyle(
              color: _textPrimary,
              fontSize: 22,
              fontWeight: FontWeight.w800,
              letterSpacing: -0.5,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'Barcha maydonlarni to\'ldiring',
            style: TextStyle(
              color: _textSecondary,
              fontSize: 13,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 24),

          _Field(
            ctrl: _nameCtrl,
            icon: Icons.person_rounded,
            label: 'Ism (* majburiy)',
            keyboardType: TextInputType.name,
            enabled: !isBusy,
          ),
          const SizedBox(height: 16),

          _Field(
            ctrl: _surnameCtrl,
            icon: Icons.badge_rounded,
            label: 'Familya (ixtiyoriy)',
            keyboardType: TextInputType.name,
            enabled: !isBusy,
          ),
          const SizedBox(height: 16),

          _Field(
            ctrl: _ageCtrl,
            icon: Icons.cake_rounded,
            label: 'Yosh (* majburiy)',
            keyboardType: TextInputType.number,
            formatters: [FilteringTextInputFormatter.digitsOnly],
            enabled: !isBusy,
          ),

          const SizedBox(height: 28),

          _PrimaryButton(
            text: 'Ro\'yxatdan o\'tish',
            icon: Icons.arrow_forward_rounded,
            isBusy: isBusy,
            onTap: _submitForm,
          ),
        ],
      ),
    );
  }

  // ─── Helpers ─────────────────────────────────────────────────────────────

  Widget _buildBackground(double w) {
    return Positioned.fill(
      child: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [_bgTop, _bgBot],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            stops: [0.0, 0.8],
          ),
        ),
        child: Stack(
          children: [
            Positioned(
              top: -w * 0.4, right: -w * 0.2,
              child: _Blob(color: _accent.withOpacity(0.08), size: w * 0.9),
            ).animate(onPlay: (c) => c.repeat(reverse: true)).move(
                duration: 8.seconds, begin: const Offset(0, 0), end: const Offset(-30, 20)),
            Positioned(
              bottom: -w * 0.3, left: -w * 0.2,
              child: _Blob(color: const Color(0xFF6366F1).withOpacity(0.06), size: w * 0.8),
            ).animate(onPlay: (c) => c.repeat(reverse: true)).move(
                duration: 10.seconds, begin: const Offset(0, 0), end: const Offset(40, -10)),
          ],
        ),
      ),
    );
  }

  Widget _buildBranding(bool compact) {
    return Center(
      child: Container(
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: Colors.white,
          shape: BoxShape.circle,
          boxShadow: [
            BoxShadow(
              color: _accent.withOpacity(0.12),
              blurRadius: 32,
              offset: const Offset(0, 12),
            ),
          ],
        ),
        child: Image.asset(
          'assets/launcher_icon.png',
          width: compact ? 60 : 72,
          height: compact ? 60 : 72,
        ),
      ).animate().scale(duration: 500.ms, curve: Curves.easeOutBack),
    );
  }
}

class _Field extends StatelessWidget {
  final TextEditingController ctrl;
  final IconData icon;
  final String label;
  final TextInputType keyboardType;
  final bool enabled;
  final List<TextInputFormatter>? formatters;
  final int? maxLength;
  final Widget? suffix;

  const _Field({
    required this.ctrl,
    required this.icon,
    required this.label,
    this.keyboardType = TextInputType.text,
    this.enabled = true,
    this.formatters,
    this.maxLength,
    this.suffix,
  });

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      controller: ctrl,
      keyboardType: keyboardType,
      inputFormatters: formatters,
      maxLength: maxLength,
      enabled: enabled,
      enableInteractiveSelection: true,
      style: const TextStyle(
        fontSize: 15,
        fontWeight: FontWeight.w600,
        color: _textPrimary,
        letterSpacing: 0.3,
      ),
      cursorColor: _inputFocus,
      decoration: InputDecoration(
        counterText: '',
        labelText: label,
        labelStyle: TextStyle(
          color: _textSecondary.withOpacity(0.8),
          fontSize: 14,
          fontWeight: FontWeight.w500,
        ),
        floatingLabelStyle: const TextStyle(
          color: _inputFocus,
          fontSize: 13,
          fontWeight: FontWeight.w700,
        ),
        prefixIcon: Icon(icon, color: _textSecondary.withOpacity(0.6), size: 22),
        suffixIcon: suffix,
        filled: true,
        fillColor: _inputBg,
        contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(20),
          borderSide: const BorderSide(color: _inputBorder, width: 1.5),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(20),
          borderSide: const BorderSide(color: _inputBorder, width: 1.5),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(20),
          borderSide: const BorderSide(color: _inputFocus, width: 2),
        ),
        disabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(20),
          borderSide: BorderSide(color: _inputBorder.withOpacity(0.5), width: 1),
        ),
      ),
    );
  }
}

class _PrimaryButton extends StatelessWidget {
  final String text;
  final IconData icon;
  final VoidCallback onTap;
  final bool isBusy;

  const _PrimaryButton({
    required this.text,
    required this.icon,
    required this.onTap,
    this.isBusy = false,
  });

  @override
  Widget build(BuildContext context) {
    return FilledButton(
      onPressed: isBusy ? null : (() {
        HapticFeedback.lightImpact();
        onTap();
      }),
      style: FilledButton.styleFrom(
        backgroundColor: _primary,
        foregroundColor: Colors.white,
        padding: const EdgeInsets.symmetric(vertical: 18),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        elevation: 0,
        disabledBackgroundColor: _primary.withOpacity(0.6),
      ),
      child: isBusy
          ? const SizedBox(
              height: 24, width: 24,
              child: CircularProgressIndicator(strokeWidth: 2.5, color: Colors.white),
            )
          : Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  text,
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 0.5,
                  ),
                ),
                const SizedBox(width: 8),
                Icon(icon, size: 20),
              ],
            ),
    );
  }
}

class _Blob extends StatelessWidget {
  final Color color;
  final double size;
  const _Blob({required this.color, required this.size});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.only(
          topLeft: Radius.circular(size * 0.4),
          topRight: Radius.circular(size * 0.6),
          bottomLeft: Radius.circular(size * 0.7),
          bottomRight: Radius.circular(size * 0.3),
        ),
      ),
    );
  }
}
