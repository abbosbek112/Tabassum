import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/localization.dart';
import '../../core/twa_service.dart';
import 'auth_controller.dart';

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
const _textTertiary = Color(0xFF94A3B8);

class AuthScreen extends ConsumerStatefulWidget {
  const AuthScreen({super.key});

  @override
  ConsumerState<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends ConsumerState<AuthScreen> {
  // Step 1 — Registration form
  final _nameCtrl    = TextEditingController();
  final _surnameCtrl = TextEditingController();
  final _ageCtrl     = TextEditingController();

  // Step 2 — OTP
  final _otpCtrl = TextEditingController();

  int _step = 1; // 1 = form, 2 = OTP
  String _telegramId = '';

  @override
  void initState() {
    super.initState();
    // Grab telegramId from TWA SDK
    WidgetsBinding.instance.addPostFrameCallback((_) {
      try {
        final twa = ref.read(twaServiceProvider);
        final id  = twa.telegramUserId?.toString();
        if (id != null) setState(() => _telegramId = id);
      } catch (_) {}
    });
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _surnameCtrl.dispose();
    _ageCtrl.dispose();
    _otpCtrl.dispose();
    super.dispose();
  }

  // ─── Submit step 1 ──────────────────────────────────────────────────────
  Future<void> _submitForm() async {
    final name = _nameCtrl.text.trim();
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
      _snack('Telegram ilovasi orqali oching. Bot dan bog\'laning!');
      return;
    }

    await ref.read(authControllerProvider.notifier).sendOtp(telegramId: _telegramId);

    final err = ref.read(authControllerProvider).error;
    if (err != null) {
      _snack(err.toString());
      return;
    }

    setState(() { _step = 2; _otpCtrl.clear(); });
  }

  // ─── Submit step 2 ──────────────────────────────────────────────────────
  Future<void> _submitOtp() async {
    final code    = _otpCtrl.text.trim();
    final name    = _nameCtrl.text.trim();
    final surname = _surnameCtrl.text.trim();
    final age     = int.tryParse(_ageCtrl.text.trim()) ?? 0;

    if (code.length != 6) {
      _snack('6 xonali kodni kiriting');
      return;
    }

    await ref.read(authControllerProvider.notifier).verifyOtp(
      telegramId: _telegramId,
      code: code,
      name: name,
      surname: surname,
      age: age,
    );

    final err = ref.read(authControllerProvider).error;
    if (err != null && mounted) _snack(_friendlyError(err));
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
    final isBusy = ref.watch(authControllerProvider).isLoading;
    final w      = MediaQuery.of(context).size.width;
    final hPad   = w > 500 ? (w - 420) / 2 : 24.0;
    final isCompact = w < 375;

    ref.listen(authControllerProvider, (_, next) {
      final err = next.error;
      if (err != null && mounted) _snack(_friendlyError(err));
    });

    return Scaffold(
      backgroundColor: _bgTop,
      body: Stack(
        children: [
          _buildBackground(w),
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
                    _step == 1
                        ? 'Tabassum Marketplacega xush kelibsiz!'
                        : 'Telegram botdan yuborilgan kodni kiriting',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: _textSecondary,
                      fontSize: isCompact ? 13 : 14,
                      fontWeight: FontWeight.w500,
                    ),
                  ).animate().fadeIn(duration: 400.ms),

                  SizedBox(height: isCompact ? 28 : 40),

                  // Card
                  AnimatedSwitcher(
                    duration: 350.ms,
                    transitionBuilder: (child, anim) => FadeTransition(
                      opacity: anim,
                      child: SlideTransition(
                        position: Tween<Offset>(
                          begin: const Offset(0.05, 0),
                          end: Offset.zero,
                        ).animate(anim),
                        child: child,
                      ),
                    ),
                    child: _step == 1
                        ? _buildFormCard(isBusy, isCompact)
                        : _buildOtpCard(isBusy, isCompact),
                  ),

                  SizedBox(height: isCompact ? 12 : 20),

                  // Footer
                  Text(
                    'Tabassum Marketplace © 2025',
                    style: TextStyle(
                      color: _textTertiary.withOpacity(0.5),
                      fontSize: 11,
                    ),
                  ).animate().fadeIn(delay: 800.ms),

                  const SizedBox(height: 24),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ─── Step 1: Registration Form ──────────────────────────────────────────
  Widget _buildFormCard(bool isBusy, bool isCompact) {
    return _Card(
      key: const ValueKey('form'),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _sectionTitle('Ro\'yxatdan o\'tish', Icons.person_add_alt_1_rounded),
          SizedBox(height: isCompact ? 20 : 26),

          _field(ctrl: _nameCtrl, label: 'Ism *', icon: Icons.badge_outlined, isBusy: isBusy),
          const SizedBox(height: 14),
          _field(ctrl: _surnameCtrl, label: 'Familya (ixtiyoriy)', icon: Icons.person_outline_rounded, isBusy: isBusy),
          const SizedBox(height: 14),
          _field(
            ctrl: _ageCtrl,
            label: 'Yoshingiz *',
            icon: Icons.cake_outlined,
            keyboardType: TextInputType.number,
            inputFormatters: [FilteringTextInputFormatter.digitsOnly],
            isBusy: isBusy,
          ),

          const SizedBox(height: 24),

          // Info banner
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: _accent.withOpacity(0.08),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: _accent.withOpacity(0.2)),
            ),
            child: Row(
              children: [
                Icon(Icons.send_rounded, color: _accent, size: 18),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'Tasdiqlash kodi Telegram botga yuboriladi',
                    style: TextStyle(
                      color: _accent,
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 20),

          _primaryButton(
            label: 'Davom etish',
            icon: Icons.arrow_forward_rounded,
            isBusy: isBusy,
            onTap: _submitForm,
          ),
        ],
      ),
    );
  }

  // ─── Step 2: OTP ────────────────────────────────────────────────────────
  Widget _buildOtpCard(bool isBusy, bool isCompact) {
    return _Card(
      key: const ValueKey('otp'),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          _sectionTitle('Tasdiqlash', Icons.lock_open_rounded),
          SizedBox(height: isCompact ? 16 : 22),

          // Big lock icon
          Container(
            width: 72,
            height: 72,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [_accent, _accent.withOpacity(0.7)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(20),
              boxShadow: [
                BoxShadow(
                  color: _accent.withOpacity(0.25),
                  blurRadius: 16,
                  offset: const Offset(0, 6),
                ),
              ],
            ),
            child: const Icon(Icons.message_outlined, color: Colors.white, size: 32),
          ).animate().scale(duration: 500.ms, curve: Curves.easeOutBack),

          const SizedBox(height: 16),

          Text(
            'Telegram botdan kelgan\n6 xonali kodni kiriting',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: _textSecondary,
              fontSize: 13,
              height: 1.5,
            ),
          ),

          const SizedBox(height: 24),

          // OTP Input
          TextField(
            controller: _otpCtrl,
            enabled: !isBusy,
            keyboardType: TextInputType.number,
            textAlign: TextAlign.center,
            maxLength: 6,
            inputFormatters: [FilteringTextInputFormatter.digitsOnly],
            style: const TextStyle(
              color: _textPrimary,
              fontWeight: FontWeight.w800,
              fontSize: 28,
              letterSpacing: 8,
            ),
            decoration: InputDecoration(
              counterText: '',
              filled: true,
              fillColor: _inputBg,
              hintText: '——————',
              hintStyle: const TextStyle(
                color: _textTertiary,
                letterSpacing: 8,
                fontSize: 22,
              ),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: const BorderSide(color: _inputBorder),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: const BorderSide(color: _inputBorder),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: const BorderSide(color: _inputFocus, width: 2),
              ),
            ),
          ).animate().fadeIn(delay: 100.ms),

          const SizedBox(height: 20),

          _primaryButton(
            label: 'Tasdiqlash',
            icon: Icons.check_circle_rounded,
            isBusy: isBusy,
            onTap: _submitOtp,
          ),

          const SizedBox(height: 12),

          // Back button
          TextButton.icon(
            onPressed: isBusy ? null : () => setState(() { _step = 1; }),
            icon: const Icon(Icons.arrow_back_rounded, size: 16),
            label: const Text('Orqaga qaytish'),
            style: TextButton.styleFrom(
              foregroundColor: _textSecondary,
              textStyle: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500),
            ),
          ),
        ],
      ),
    );
  }

  // ─── Helpers ────────────────────────────────────────────────────────────

  Widget _sectionTitle(String title, IconData icon) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: _primary.withOpacity(0.08),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(icon, color: _primary, size: 18),
        ),
        const SizedBox(width: 10),
        Text(
          title,
          style: const TextStyle(
            color: _textPrimary,
            fontWeight: FontWeight.w800,
            fontSize: 18,
          ),
        ),
      ],
    );
  }

  Widget _field({
    required TextEditingController ctrl,
    required String label,
    required IconData icon,
    bool isBusy = false,
    TextInputType keyboardType = TextInputType.text,
    List<TextInputFormatter>? inputFormatters,
  }) {
    return TextField(
      controller: ctrl,
      enabled: !isBusy,
      keyboardType: keyboardType,
      inputFormatters: inputFormatters,
      style: const TextStyle(color: _textPrimary, fontWeight: FontWeight.w500, fontSize: 15),
      cursorColor: _accent,
      decoration: InputDecoration(
        filled: true,
        fillColor: _inputBg,
        prefixIcon: Padding(
          padding: const EdgeInsets.only(left: 14, right: 8),
          child: Icon(icon, color: _textTertiary, size: 20),
        ),
        prefixIconConstraints: const BoxConstraints(minWidth: 0, minHeight: 0),
        labelText: label,
        labelStyle: const TextStyle(color: _textTertiary, fontSize: 14),
        floatingLabelStyle: const TextStyle(color: _inputFocus, fontSize: 13, fontWeight: FontWeight.w600),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: const BorderSide(color: _inputBorder)),
        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: const BorderSide(color: _inputBorder)),
        focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: const BorderSide(color: _inputFocus, width: 1.5)),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      ),
    );
  }

  Widget _primaryButton({
    required String label,
    required IconData icon,
    required bool isBusy,
    required VoidCallback onTap,
  }) {
    return SizedBox(
      width: double.infinity,
      height: 54,
      child: FilledButton.icon(
        style: FilledButton.styleFrom(
          backgroundColor: _primary,
          foregroundColor: Colors.white,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          elevation: 0,
        ),
        onPressed: isBusy ? null : onTap,
        icon: isBusy
            ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2.5))
            : Icon(icon, size: 20),
        label: isBusy ? const Text('Yuborilmoqda...') : Text(label, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15)),
      ),
    );
  }

  // ─── Background ─────────────────────────────────────────────────────────
  Widget _buildBackground(double w) {
    return Stack(
      children: [
        Positioned.fill(
          child: Container(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [_bgTop, _bgBot, Colors.white],
              ),
            ),
          ),
        ),
        _orb(top: -80, left: -80, size: 280, color: _accent.withOpacity(0.05), dur: 15),
        _orb(top: 120, right: -60, size: 220, color: const Color(0xFF8B5CF6).withOpacity(0.04), dur: 18),
        _orb(bottom: 60, right: 20, size: 160, color: const Color(0xFF06B6D4).withOpacity(0.03), dur: 12),
      ],
    );
  }

  Widget _orb({double? top, double? left, double? right, double? bottom, required double size, required Color color, required double dur}) {
    return Positioned(
      top: top, left: left, right: right, bottom: bottom,
      child: Container(
        width: size, height: size,
        decoration: BoxDecoration(shape: BoxShape.circle, gradient: RadialGradient(colors: [color, color.withOpacity(0)])),
      )
      .animate(onPlay: (c) => c.repeat(reverse: true))
      .move(begin: Offset.zero, end: const Offset(30, 40), duration: Duration(seconds: dur.toInt()), curve: Curves.easeInOutSine)
      .scale(begin: const Offset(1, 1), end: const Offset(1.15, 1.15), duration: Duration(seconds: dur.toInt()), curve: Curves.easeInOutSine),
    );
  }

  // ─── Branding ───────────────────────────────────────────────────────────
  Widget _buildBranding(bool isCompact) {
    return Column(
      children: [
        Container(
          padding: EdgeInsets.all(isCompact ? 14 : 18),
          decoration: BoxDecoration(
            gradient: const LinearGradient(colors: [_primary, Color(0xFF1E293B)], begin: Alignment.topLeft, end: Alignment.bottomRight),
            borderRadius: BorderRadius.circular(isCompact ? 18 : 22),
            boxShadow: [BoxShadow(color: _primary.withOpacity(0.15), blurRadius: 30, offset: const Offset(0, 10))],
          ),
          child: Icon(Icons.shopping_bag_rounded, size: isCompact ? 28.0 : 34.0, color: Colors.white),
        )
          .animate().scale(duration: 600.ms, curve: Curves.easeOutBack, delay: 100.ms)
          .then().shimmer(duration: 1200.ms, color: Colors.white.withOpacity(0.15)),

        SizedBox(height: isCompact ? 14 : 18),

        Text(
          'Tabassum',
          style: TextStyle(
            color: _textPrimary,
            fontWeight: FontWeight.w900,
            fontSize: isCompact ? 26.0 : 32.0,
            letterSpacing: -1.0,
          ),
        ).animate().fadeIn(delay: 200.ms, duration: 500.ms).slideY(begin: 0.2, end: 0),
      ],
    );
  }
}

// ─── Reusable Card widget ────────────────────────────────────────────────────
class _Card extends StatelessWidget {
  final Widget child;
  const _Card({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 28),
      decoration: BoxDecoration(
        color: _cardBg,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: const Color(0xFFF1F5F9)),
        boxShadow: [
          BoxShadow(color: _primary.withOpacity(0.04), blurRadius: 40, offset: const Offset(0, 12)),
          BoxShadow(color: _primary.withOpacity(0.02), blurRadius: 8, offset: const Offset(0, 2)),
        ],
      ),
      child: child,
    ).animate().fadeIn(duration: 500.ms, delay: 200.ms).moveY(begin: 20, end: 0, curve: Curves.easeOutCubic);
  }
}

String _friendlyError(Object err) => err.toString().replaceAll('Exception: ', '');
