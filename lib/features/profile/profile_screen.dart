import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import '../../shared/widgets/loading_widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter/services.dart';

import '../../core/localization.dart';
import '../auth/auth_controller.dart';
import '../auth/models/user_model.dart';
import '../../core/constants.dart';
import '../../core/shared_providers.dart';
import '../../shared/models/shop_model.dart';
import '../marketplace/shop_repository.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../core/providers.dart';

class ProfileScreen extends ConsumerWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profileAsync = ref.watch(currentUserProfileProvider);

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        title: Padding(
          padding: const EdgeInsets.only(top: 8),
          child: Text(
            context.l('profile') ?? 'Profil',
            style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 24, letterSpacing: -1.0)
          ),
        ),
        backgroundColor: Theme.of(context).scaffoldBackgroundColor,
        elevation: 0,
        centerTitle: false,
        surfaceTintColor: Colors.transparent,
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Divider(height: 1, color: Theme.of(context).dividerColor.withOpacity(0.05)),
        ),
      ),
      body: profileAsync.when(
        data: (profile) {
          if (profile == null) return Center(child: Text(context.l('not_logged_in') ?? 'Sign in required'));
          return _ProfileBody(profile: profile);
        },
        error: (e, _) => Center(child: Text('${context.l("error") ?? "Error"}: $e')),
        loading: () => const AppOverlayLoading(),
      ),
    );
  }
}

class _ProfileBody extends ConsumerStatefulWidget {
  final UserModel profile;
  const _ProfileBody({required this.profile});

  @override
  ConsumerState<_ProfileBody> createState() => _ProfileBodyState();
}

class _ProfileBodyState extends ConsumerState<_ProfileBody> {
  final _nameCtrl = TextEditingController();
  final _phoneCtrl = TextEditingController();
  bool _isEditing = false;

  @override
  void initState() {
    super.initState();
    _resetFields();
  }

  void _resetFields() {
    _nameCtrl.text = widget.profile.displayName;
    _phoneCtrl.text = widget.profile.phoneNumber;
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _phoneCtrl.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    try {
      await ref.read(authControllerProvider.notifier).updateProfile(
            displayName: _nameCtrl.text.trim(),
            phoneNumber: _phoneCtrl.text.trim(),
          );
      if (mounted) {
        setState(() {
          _isEditing = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(context.l('profile_updated') ?? 'Profil yangilandi'), behavior: SnackBarBehavior.floating),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('${context.l("error") ?? "Error"}: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(authStateProvider);
    final busy = authState.isUpdatingProfile;

    return ListView(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
      physics: const BouncingScrollPhysics(),
      children: [
        // User Header Card
        Container(
          clipBehavior: Clip.antiAlias,
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.surface,
            borderRadius: BorderRadius.circular(32),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.06),
                blurRadius: 30,
                offset: const Offset(0, 15),
              ),
            ],
          ),
          child: Stack(
            children: [
              // Subtle background design element
              Positioned(
                top: -30, right: -20,
                child: Container(
                  width: 120, height: 120,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: RadialGradient(
                      colors: [
                        Theme.of(context).colorScheme.primary.withOpacity(0.08),
                        Theme.of(context).colorScheme.primary.withOpacity(0),
                      ],
                    ),
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(32),
                child: SizedBox(
                  width: double.infinity,
                  child: Column(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    // Premium Avatar
                    Hero(
                      tag: 'profile-avatar',
                      child: Container(
                        padding: const EdgeInsets.all(4),
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          gradient: LinearGradient(
                            colors: [
                              Theme.of(context).colorScheme.primary.withOpacity(0.2),
                              Theme.of(context).colorScheme.secondary.withOpacity(0.1),
                            ],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ),
                        ),
                        child: Container(
                          padding: const EdgeInsets.all(2),
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: Theme.of(context).colorScheme.surface,
                          ),
                          child: CircleAvatar(
                            radius: 46,
                            backgroundColor: Theme.of(context).colorScheme.primaryContainer.withOpacity(0.15),
                            child: Text(
                              (widget.profile.displayName.isNotEmpty
                                      ? widget.profile.displayName[0]
                                      : widget.profile.email[0])
                                  .toUpperCase(),
                              style: TextStyle(
                                fontSize: 38, 
                                fontWeight: FontWeight.w900, 
                                color: Theme.of(context).colorScheme.primary,
                                letterSpacing: -1.0,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 20),
                    Text(
                      widget.profile.displayName.isNotEmpty 
                        ? widget.profile.displayName 
                        : (context.l('user_role') ?? 'Foydalanuvchi'),
                      style: const TextStyle(
                        fontSize: 24, 
                        fontWeight: FontWeight.w900, 
                        letterSpacing: -0.8
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      widget.profile.email,
                      style: TextStyle(
                        fontSize: 14, 
                        color: Theme.of(context).colorScheme.onSurfaceVariant.withOpacity(0.6), 
                        fontWeight: FontWeight.w600
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 16),
                    // Refined Role Badge
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: widget.profile.role == UserRole.seller
                            ? [Theme.of(context).colorScheme.primary.withOpacity(0.1), Theme.of(context).colorScheme.primary.withOpacity(0.05)]
                            : [Theme.of(context).colorScheme.tertiary.withOpacity(0.1), Theme.of(context).colorScheme.tertiary.withOpacity(0.05)],
                        ),
                        borderRadius: BorderRadius.circular(100),
                        border: Border.all(
                          color: widget.profile.role == UserRole.seller
                            ? Theme.of(context).colorScheme.primary.withOpacity(0.15)
                            : Theme.of(context).colorScheme.tertiary.withOpacity(0.15),
                        ),
                      ),
                      child: Text(
                        widget.profile.role == UserRole.seller 
                          ? (context.l('seller') ?? 'SOTUVCHI').toUpperCase() 
                          : (context.l('customer') ?? 'MIJOZ').toUpperCase(),
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w900,
                          letterSpacing: 0.8,
                          color: widget.profile.role == UserRole.seller
                            ? Theme.of(context).colorScheme.primary
                            : Theme.of(context).colorScheme.tertiary,
                        ),
                      ),
                    ),
                  ],
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 32),

        // Settings Section (Theme)
        _buildSettingsSection(context, ref),
        const SizedBox(height: 32),

        // Subscription Section (for Sellers)
        if (widget.profile.role == UserRole.seller) ...[
          _buildSubscriptionSection(context, ref, widget.profile.uid),
          const SizedBox(height: 32),
        ],

        // Become Seller Card (only for Customers)
        if (widget.profile.role == UserRole.customer) ...[
          _BecomeSellerCard(),
          const SizedBox(height: 32),
        ],

        // My Shop Section (Only for Sellers and Admins)
        if (widget.profile.role == UserRole.seller || widget.profile.role == UserRole.admin) ...[
          _buildUltimateMyShopSection(context, ref, widget.profile.uid),
        ],

        // Personal Info Section
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                context.l('personal_info') ?? 'Shaxsiy ma\'lumotlar',
                style: TextStyle(
                  fontSize: 14, 
                  fontWeight: FontWeight.w800, 
                  letterSpacing: 0.5,
                  color: Theme.of(context).colorScheme.primary.withOpacity(0.8)
                )
              ),
              if (!_isEditing)
                TextButton.icon(
                  onPressed: () {
                    HapticFeedback.mediumImpact();
                    setState(() => _isEditing = true);
                  },
                  icon: const Icon(Icons.edit_note_rounded, size: 20),
                  label: Text(context.l('edit_profile') ?? 'Tahrirlash', style: const TextStyle(fontWeight: FontWeight.w800)),
                  style: TextButton.styleFrom(
                    visualDensity: VisualDensity.compact,
                    foregroundColor: Theme.of(context).colorScheme.primary,
                  ),
                )
              else
                Row(
                  children: [
                    TextButton(
                      onPressed: busy ? null : () {
                        HapticFeedback.lightImpact();
                        setState(() { _isEditing = false; _resetFields(); });
                      },
                      child: Text(context.l('cancel') ?? 'Bekor qilish', style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant, fontWeight: FontWeight.w700)),
                    ),
                    const SizedBox(width: 8),
                    FilledButton(
                      onPressed: busy ? null : () {
                        HapticFeedback.mediumImpact();
                        _save();
                      },
                      style: FilledButton.styleFrom(
                        backgroundColor: Theme.of(context).colorScheme.primary,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                        minimumSize: Size.zero,
                        visualDensity: VisualDensity.compact,
                      ),
                      child: Text(busy ? '${context.l("updating") ?? "SAVING"}...' : (context.l('save') ?? 'SAQLASH'), style: const TextStyle(fontWeight: FontWeight.w900, color: Colors.white, fontSize: 13)),
                    ),
                  ],
                ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        Container(
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.surface,
            borderRadius: BorderRadius.circular(28),
            border: Border.all(color: Theme.of(context).colorScheme.outlineVariant.withOpacity(0.5)),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.03),
                blurRadius: 20,
                offset: const Offset(0, 10),
              ),
            ],
          ),
          child: Column(
            children: [
              _buildField(
                label: context.l('full_name') ?? 'To\'liq ism',
                controller: _nameCtrl,
                enabled: _isEditing,
                icon: Icons.person_outline_rounded,
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: Divider(height: 1, color: Theme.of(context).dividerColor.withOpacity(0.05)),
              ),
              _buildField(
                label: context.l('phone_number') ?? 'Telefon raqami',
                controller: _phoneCtrl,
                enabled: _isEditing,
                keyboardType: TextInputType.phone,
                icon: Icons.phone_iphone_rounded,
              ),
            ],
          ),
        ),

        const SizedBox(height: 32),
        // Sign Out Button
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Material(
            color: const Color(0xFFF43F5E).withOpacity(0.08),
            borderRadius: BorderRadius.circular(24),
            child: InkWell(
              onTap: () {
                HapticFeedback.heavyImpact();
                ref.read(authControllerProvider.notifier).signOut();
              },
              borderRadius: BorderRadius.circular(24),
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 20),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(24),
                  border: Border.all(color: const Color(0xFFF43F5E).withOpacity(0.1)),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.logout_rounded, color: Color(0xFFF43F5E), size: 22),
                    const SizedBox(width: 12),
                    Text(
                      context.l('sign_out') ?? 'HISOBDAN CHIQISH', 
                      style: const TextStyle(
                        color: Color(0xFFF43F5E),
                        fontWeight: FontWeight.w900, 
                        letterSpacing: 1.2,
                        fontSize: 13,
                      )
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
        const SizedBox(height: 20),
        // Hidden admin entry — tap 5 times to open
        _AdminEntryPoint(),
        const SizedBox(height: 140),
      ],
    );
  }

  Widget _buildField({
    required String label,
    required TextEditingController controller,
    required IconData icon,
    bool enabled = false,
    int maxLines = 1,
    TextInputType? keyboardType,
  }) {
    final busy = ref.watch(authStateProvider).isUpdatingProfile;
    return Padding(
      padding: const EdgeInsets.all(20),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.primary.withOpacity(0.04),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: Theme.of(context).colorScheme.primary.withOpacity(0.6), size: 20),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label.toUpperCase(), 
                  style: TextStyle(
                    fontSize: 10, 
                    fontWeight: FontWeight.w900, 
                    letterSpacing: 0.8,
                    color: Theme.of(context).colorScheme.primary.withOpacity(0.4)
                  )
                ),
                const SizedBox(height: 2),
                TextField(
                  controller: controller,
                  readOnly: !enabled || busy,
                  maxLines: maxLines,
                  keyboardType: keyboardType,
                  style: TextStyle(
                    fontSize: 16, 
                    fontWeight: FontWeight.w800, 
                    color: (enabled && !busy) ? Theme.of(context).colorScheme.onSurface : Theme.of(context).colorScheme.onSurface.withOpacity(0.9),
                    letterSpacing: -0.2,
                  ),
                  decoration: const InputDecoration(
                    border: InputBorder.none,
                    isDense: true,
                    contentPadding: EdgeInsets.zero,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildUltimateMyShopSection(BuildContext context, WidgetRef ref, String uid) {
    final shopsAsync = ref.watch(myShopsProvider(uid));

    return shopsAsync.maybeWhen(
      data: (shops) {
        if (shops.isEmpty) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 4),
                child: Text(
                  context.l('my_shop') ?? 'Mening do\'konim',
                  style: TextStyle(
                    fontSize: 14, 
                    fontWeight: FontWeight.w800, 
                    letterSpacing: 0.5,
                    color: Theme.of(context).colorScheme.primary.withOpacity(0.8)
                  )
                ),
              ),
              const SizedBox(height: 12),
              Container(
                width: double.infinity,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(28),
                  color: Theme.of(context).colorScheme.primary.withOpacity(0.05),
                  border: Border.all(color: Theme.of(context).colorScheme.primary.withOpacity(0.1)),
                ),
                padding: const EdgeInsets.all(24),
                child: Column(
                  children: [
                    Icon(Icons.storefront_rounded, size: 48, color: Theme.of(context).colorScheme.primary.withOpacity(0.5)),
                    const SizedBox(height: 16),
                    Text(
                      context.l('no_shop_yet') ?? 'Hali do\'koningiz yo\'q',
                      style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      context.l('create_shop_desc') ?? 'Sotuvni boshlash uchun do\'kon yarating',
                      style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Theme.of(context).colorScheme.onSurfaceVariant.withOpacity(0.6)),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 20),
                    FilledButton.icon(
                      onPressed: () => _showEditShopSheet(context, ref, null),
                      icon: const Icon(Icons.add_rounded),
                      label: Text(context.l('create_shop') ?? 'DO\'KON YARATISH'),
                      style: FilledButton.styleFrom(
                        backgroundColor: Colors.black,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 32),
            ],
          );
        }
        final shop = shops.first;
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    context.l('my_shop') ?? 'Mening do\'konim',
                    style: TextStyle(
                      fontSize: 14, 
                      fontWeight: FontWeight.w800, 
                      letterSpacing: 0.5,
                      color: Theme.of(context).colorScheme.primary.withOpacity(0.8)
                    )
                  ),
                  TextButton.icon(
                    onPressed: () => _showEditShopSheet(context, ref, shop),
                    icon: const Icon(Icons.settings_outlined, size: 16),
                    label: Text(context.l('edit_shop') ?? 'Sozlash',
                        style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w800)),
                    style: TextButton.styleFrom(
                      foregroundColor: Theme.of(context).colorScheme.primary,
                      visualDensity: VisualDensity.compact,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            Container(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(28),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.04),
                    blurRadius: 20,
                    offset: const Offset(0, 10),
                  ),
                ],
              ),
              child: Material(
                color: Theme.of(context).colorScheme.surface,
                borderRadius: BorderRadius.circular(28),
                clipBehavior: Clip.antiAlias,
                child: InkWell(
                  onTap: () => context.go('/market/shop/${shop.id}'),
                  child: Container(
                    padding: const EdgeInsets.all(24),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(28),
                      border: Border.all(color: Theme.of(context).colorScheme.outlineVariant.withOpacity(0.5)),
                    ),
                    child: Row(
                      children: [
                        Container(
                          width: 64,
                          height: 64,
                          decoration: BoxDecoration(
                            color: Theme.of(context).colorScheme.surfaceContainerHighest,
                            borderRadius: BorderRadius.circular(20),
                            image: shop.image.isNotEmpty
                                ? DecorationImage(image: CachedNetworkImageProvider(shop.image), fit: BoxFit.cover)
                                : null,
                          ),
                          child: shop.image.isEmpty
                               ? Icon(Icons.storefront_rounded, color: Theme.of(context).colorScheme.primary.withOpacity(0.5), size: 32)
                               : null,
                        ),
                        const SizedBox(width: 20),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(shop.name,
                                  style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w900, letterSpacing: -0.5)),
                              const SizedBox(height: 4),
                              Text(
                                shop.about.isNotEmpty ? shop.about : (context.l('update_boutique_details') ?? 'Butik ma\'lumotlarini yangilang'),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Theme.of(context).colorScheme.onSurfaceVariant.withOpacity(0.6)),
                              ),
                            ],
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: Theme.of(context).colorScheme.primary.withOpacity(0.05),
                            shape: BoxShape.circle,
                          ),
                          child: Icon(Icons.arrow_forward_ios_rounded, color: Theme.of(context).colorScheme.primary, size: 14),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 32),
          ],
        );
      },
      orElse: () => const SizedBox.shrink(),
    );
  }

  void _showEditShopSheet(BuildContext context, WidgetRef ref, ShopModel? shop) {
    showModalBottomSheet(
      context: context,
      useRootNavigator: true,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => _EditShopSheet(shop: shop),
    );
  }

  Widget _buildSettingsSection(BuildContext context, WidgetRef ref) {
    final themeMode = ref.watch(themeModeProvider);
    final lang = ref.watch(localeProvider);
    final isDark = themeMode == ThemeMode.dark;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4),
          child: Text(
            context.l('account_settings') ?? 'Hisob sozlamalari',
            style: TextStyle(
              fontSize: 14, 
              fontWeight: FontWeight.w800, 
              letterSpacing: 0.5,
              color: Theme.of(context).colorScheme.primary.withOpacity(0.8)
            )
          ),
        ),
        const SizedBox(height: 12),
        Container(
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.surface,
            borderRadius: BorderRadius.circular(28),
            border: Border.all(color: Theme.of(context).colorScheme.outlineVariant.withOpacity(0.5)),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.03),
                blurRadius: 20,
                offset: const Offset(0, 10),
              ),
            ],
          ),
          child: Column(
            children: [
              // Dark mode toggle
              _buildSettingRow(
                context,
                icon: isDark ? Icons.dark_mode_rounded : Icons.light_mode_rounded,
                title: context.l('dark_mode') ?? 'Tungi rejim',
                trailing: Switch.adaptive(
                  value: isDark,
                  activeColor: Theme.of(context).colorScheme.primary,
                  onChanged: (val) {
                    HapticFeedback.lightImpact();
                    ref.read(themeModeProvider.notifier).state = val ? ThemeMode.dark : ThemeMode.light;
                  },
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: Divider(height: 1, color: Theme.of(context).dividerColor.withOpacity(0.05)),
              ),
              // Language toggle
              _buildSettingRow(
                context,
                icon: Icons.translate_rounded,
                title: context.l('language') ?? 'Til',
                trailing: Container(
                  padding: const EdgeInsets.all(4),
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.surfaceContainerHighest.withOpacity(0.5),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      _LangChip(label: 'UZ', value: 'uz', current: lang, ref: ref),
                      _LangChip(label: 'RU', value: 'ru', current: lang, ref: ref),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildSettingRow(BuildContext context, {required IconData icon, required String title, required Widget trailing}) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.primary.withOpacity(0.06),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Icon(icon, color: Theme.of(context).colorScheme.primary, size: 22),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Text(
              title,
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700, letterSpacing: -0.2),
            ),
          ),
          trailing,
        ],
      ),
    );
  }

  Widget _buildSubscriptionSection(BuildContext context, WidgetRef ref, String uid) {
    final shopsAsync = ref.watch(myShopsProvider(uid));

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4),
          child: Text(
            context.l('subscription') ?? 'Obuna',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w800,
              letterSpacing: 0.5,
              color: Theme.of(context).colorScheme.primary.withOpacity(0.8),
            ),
          ),
        ),
        const SizedBox(height: 12),
        shopsAsync.when(
          data: (shops) {
            if (shops.isEmpty) return const SizedBox.shrink();
            final shop = shops.first;
            final subAsync = ref.watch(shopSubscriptionProvider(shop.id));

            return subAsync.when(
              data: (s) {
                final isActive = s != null &&
                    s.status == 'active' &&
                    s.endDate.isAfter(DateTime.now());
                final daysLeft = isActive ? s.endDate.difference(DateTime.now()).inDays : 0;
                final totalDays = isActive ? s.endDate.difference(s.startDate).inDays : 30;
                final progress = isActive ? (totalDays - daysLeft) / totalDays : 0.0;

                return Material(
                  color: Colors.transparent,
                  child: InkWell(
                    borderRadius: BorderRadius.circular(24),
                    onTap: () => context.push('/seller/subscription'),
                    child: Container(
                      decoration: BoxDecoration(
                        color: isActive
                            ? const Color(0xFF10B981).withOpacity(0.08)
                            : Theme.of(context).colorScheme.surface,
                        borderRadius: BorderRadius.circular(24),
                        border: Border.all(
                          color: isActive
                              ? const Color(0xFF10B981).withOpacity(0.25)
                              : Theme.of(context).colorScheme.outlineVariant.withOpacity(0.5),
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.03),
                            blurRadius: 16,
                            offset: const Offset(0, 6),
                          ),
                        ],
                      ),
                      padding: const EdgeInsets.all(20),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              // Icon
                              Container(
                                padding: const EdgeInsets.all(10),
                                decoration: BoxDecoration(
                                  color: isActive
                                      ? const Color(0xFF10B981).withOpacity(0.15)
                                      : Theme.of(context).colorScheme.primary.withOpacity(0.08),
                                  shape: BoxShape.circle,
                                ),
                                child: Icon(
                                  isActive ? Icons.verified_rounded : Icons.stars_outlined,
                                  color: isActive
                                      ? const Color(0xFF10B981)
                                      : Theme.of(context).colorScheme.primary,
                                  size: 22,
                                ),
                              ),
                              const SizedBox(width: 14),
                              // Text
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      isActive ? 'Obuna faol' : 'Obuna faol emas',
                                      style: TextStyle(
                                        fontWeight: FontWeight.w800,
                                        fontSize: 16,
                                        color: isActive
                                            ? const Color(0xFF10B981)
                                            : Theme.of(context).colorScheme.onSurface,
                                      ),
                                    ),
                                    const SizedBox(height: 2),
                                    Text(
                                      isActive
                                          ? '$daysLeft kun qoldi'
                                          : 'Mahsulotlaringiz ko\'rinmaydi',
                                      style: TextStyle(
                                        fontSize: 13,
                                        fontWeight: FontWeight.w600,
                                        color: isActive
                                            ? const Color(0xFF10B981).withOpacity(0.8)
                                            : Theme.of(context).colorScheme.onSurface.withOpacity(0.5),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              // Arrow
                              Icon(
                                Icons.chevron_right_rounded,
                                color: Theme.of(context).colorScheme.onSurface.withOpacity(0.3),
                              ),
                            ],
                          ),

                          if (isActive) ...[
                            const SizedBox(height: 16),
                            // Progress bar
                            ClipRRect(
                              borderRadius: BorderRadius.circular(100),
                              child: LinearProgressIndicator(
                                value: progress.clamp(0.0, 1.0),
                                minHeight: 6,
                                backgroundColor: const Color(0xFF10B981).withOpacity(0.15),
                                valueColor: const AlwaysStoppedAnimation<Color>(Color(0xFF10B981)),
                              ),
                            ),
                            const SizedBox(height: 6),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(
                                  '${s.startDate.day}.${s.startDate.month.toString().padLeft(2, '0')}.${s.startDate.year}',
                                  style: TextStyle(
                                    fontSize: 11,
                                    color: Theme.of(context).colorScheme.onSurface.withOpacity(0.4),
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                                Text(
                                  '${s.endDate.day}.${s.endDate.month.toString().padLeft(2, '0')}.${s.endDate.year}',
                                  style: TextStyle(
                                    fontSize: 11,
                                    color: Theme.of(context).colorScheme.onSurface.withOpacity(0.4),
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ],
                            ),
                          ] else ...[
                            const SizedBox(height: 14),
                            SizedBox(
                              width: double.infinity,
                              child: FilledButton.icon(
                                onPressed: () => context.push('/seller/subscription'),
                                icon: const Icon(Icons.star_rounded, size: 18),
                                label: const Text(
                                  'Obuna sotib olish',
                                  style: TextStyle(fontWeight: FontWeight.w800),
                                ),
                                style: FilledButton.styleFrom(
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                                  padding: const EdgeInsets.symmetric(vertical: 12),
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ),
                );
              },
              error: (e, _) => const SizedBox.shrink(),
              loading: () => const AppLoadingIndicator(size: 20),
            );
          },
          error: (e, _) => const SizedBox.shrink(),
          loading: () => const SizedBox.shrink(),
        ),
      ],
    );
  }
}

class _LangChip extends ConsumerWidget {
  final String label;
  final String value;
  final String current;
  final WidgetRef ref;
  const _LangChip({required this.label, required this.value, required this.current, required this.ref});

  @override
  Widget build(BuildContext context, WidgetRef _) {
    final isSelected = current == value;
    return GestureDetector(
      onTap: () => ref.read(localeProvider.notifier).state = value,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xFF6366F1) : Colors.transparent,
          borderRadius: BorderRadius.circular(10),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontWeight: FontWeight.w700,
            fontSize: 13,
            color: isSelected ? Colors.white : Theme.of(context).textTheme.bodyMedium?.color,
          ),
        ),
      ),
    );
  }
}

class _EditShopSheet extends ConsumerStatefulWidget {
  final ShopModel? shop;
  const _EditShopSheet({this.shop});

  @override
  ConsumerState<_EditShopSheet> createState() => _EditShopSheetState();
}

class _EditShopSheetState extends ConsumerState<_EditShopSheet> {
  late final TextEditingController _nameCtrl;
  late final TextEditingController _aboutCtrl;
  late final TextEditingController _tgCtrl;
  late final TextEditingController _phoneCtrl;
  late ShopGenre _selectedGenre;
  XFile? _pickedImage;
  Uint8List? _pickedImageBytes;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    _nameCtrl = TextEditingController(text: widget.shop?.name ?? '');
    _aboutCtrl = TextEditingController(text: widget.shop?.about ?? '');
    _tgCtrl = TextEditingController(text: widget.shop?.telegram ?? '');
    _phoneCtrl = TextEditingController(text: widget.shop?.phone ?? '');
    _selectedGenre = widget.shop?.genre ?? ShopGenre.clothes;
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _aboutCtrl.dispose();
    _tgCtrl.dispose();
    _phoneCtrl.dispose();
    super.dispose();
  }

  Future<void> _pickShopImage() async {
    final picked = await ImagePicker().pickImage(
      source: ImageSource.gallery,
      imageQuality: 80,
      maxWidth: 800,
      maxHeight: 800,
    );
    if (picked != null) {
      final bytes = await picked.readAsBytes();
      setState(() {
        _pickedImage = picked;
        _pickedImageBytes = bytes;
      });
    }
  }

  Future<void> _save() async {
    if (_nameCtrl.text.trim().isEmpty) return;
    setState(() => _busy = true);
    try {
      final repo = ref.read(shopRepositoryProvider);
      final user = ref.read(authStateProvider).user;
      if (user == null) return;

      String imageUrl = widget.shop?.image ?? '';

      if (_pickedImage != null && _pickedImageBytes != null) {
        imageUrl = await repo.uploadShopImage(
          shopId: widget.shop?.id ?? 'temp_${user.uid}',
          bytes: _pickedImageBytes!,
          fileName: 'shop_${DateTime.now().millisecondsSinceEpoch}.jpg',
        );
      }

      final shopData = widget.shop?.toMap() ?? {};
      shopData['name'] = _nameCtrl.text.trim();
      shopData['about'] = _aboutCtrl.text.trim();
      shopData['telegram'] = _tgCtrl.text.trim();
      shopData['phone'] = _phoneCtrl.text.trim();
      shopData['genre'] = _selectedGenre.asString;
      shopData['image'] = imageUrl;
      shopData['ownerId'] = user.uid;

      if (widget.shop == null) {
        await repo.createShop(ShopModel.fromMap('', shopData));
      } else {
        await repo.updateShop(ShopModel.fromMap(widget.shop!.id, shopData));
      }

      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(widget.shop == null 
              ? (context.l('shop_created') ?? 'Do\'kon yaratildi')
              : (context.l('shop_updated') ?? 'Do\'kon yangilandi')), 
            behavior: SnackBarBehavior.floating
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('${context.l("error") ?? "Xato"}: $e'), backgroundColor: Colors.red),
        );
        setState(() => _busy = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Theme.of(context).scaffoldBackgroundColor,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(32)),
      ),
      padding: EdgeInsets.only(
        top: 32,
        left: 24,
        right: 24,
        bottom: 32 + MediaQuery.of(context).viewInsets.bottom,
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  widget.shop == null 
                    ? (context.l('create_shop') ?? 'Do\'kon yaratish')
                    : (context.l('edit_shop') ?? 'Do\'konni tahrirlash'),
                    style: TextStyle(fontSize: 24, fontWeight: FontWeight.w800, letterSpacing: -0.5, color: Theme.of(context).textTheme.titleLarge?.color)),
                if (_busy) const SizedBox(width: 24, height: 24, child: CircularProgressIndicator(strokeWidth: 2)),
              ],
            ),
            const SizedBox(height: 24),
            // Shop photo picker
            Center(
              child: GestureDetector(
                onTap: _busy ? null : _pickShopImage,
                child: Stack(
                  children: [
                    Container(
                      width: 100,
                      height: 100,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: Theme.of(context).dividerColor.withOpacity(0.1),
                        border: Border.all(color: Theme.of(context).dividerColor.withOpacity(0.3), width: 2),
                        image: _pickedImageBytes != null
                            ? DecorationImage(image: MemoryImage(_pickedImageBytes!), fit: BoxFit.cover)
                            : (widget.shop?.image.isNotEmpty == true
                                ? DecorationImage(image: CachedNetworkImageProvider(widget.shop!.image), fit: BoxFit.cover)
                                : null),
                      ),
                      child: (_pickedImage == null && (widget.shop?.image.isEmpty ?? true))
                          ? Icon(Icons.storefront_outlined, color: Theme.of(context).textTheme.bodySmall?.color, size: 40)
                          : null,
                    ),
                    Positioned(
                      bottom: 0, right: 0,
                      child: Container(
                        width: 32, height: 32,
                        decoration: BoxDecoration(
                          color: Colors.black,
                          shape: BoxShape.circle,
                          border: Border.all(color: Theme.of(context).scaffoldBackgroundColor, width: 2),
                        ),
                        child: const Icon(Icons.camera_alt_rounded, color: Colors.white, size: 16),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 24),
            _buildInput(context.l('shop_name') ?? 'Do\'kon nomi', _nameCtrl, Icons.storefront),
            const SizedBox(height: 16),
            _buildInput(context.l('shop_about') ?? 'Do\'kon haqida', _aboutCtrl, Icons.info_outline, maxLines: 3),
            const SizedBox(height: 16),
            _buildInput(context.l('telegram_username') ?? 'Telegram User', _tgCtrl, Icons.telegram),
            const SizedBox(height: 16),
            _buildInput(context.l('phone') ?? 'Telefon', _phoneCtrl, Icons.phone_outlined),
            const SizedBox(height: 24),
            Text(
              context.l('shop_genre') ?? 'Do\'kon yo\'nalishi',
              style: TextStyle(fontSize: 14, fontWeight: FontWeight.w800, color: Theme.of(context).textTheme.titleMedium?.color),
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: ShopGenre.values.map((genre) {
                final isSelected = _selectedGenre == genre;
                return ChoiceChip(
                  label: Text(context.l(genre.name)),
                  selected: isSelected,
                  onSelected: _busy ? null : (selected) {
                    if (selected) setState(() => _selectedGenre = genre);
                  },
                  labelStyle: TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 13,
                    color: isSelected ? Colors.white : Theme.of(context).textTheme.bodyMedium?.color,
                  ),
                  selectedColor: Colors.black,
                  backgroundColor: Theme.of(context).dividerColor.withOpacity(0.05),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  showCheckmark: false,
                );
              }).toList(),
            ),
            const SizedBox(height: 32),
            FilledButton(
              onPressed: _busy ? null : _save,
              style: FilledButton.styleFrom(
                backgroundColor: Colors.black,
                padding: const EdgeInsets.symmetric(vertical: 18),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              ),
              child: Text(
                widget.shop == null 
                  ? (context.l('create') ?? 'YARATISH')
                  : (context.l('save_changes') ?? 'SAQLASH'),
                  style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16)),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInput(String label, TextEditingController ctrl, IconData icon, {int maxLines = 1, TextInputType? keyboardType}) {
    return Container(
      decoration: BoxDecoration(
        color: Theme.of(context).dividerColor.withOpacity(0.08),
        borderRadius: BorderRadius.circular(16),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: TextField(
        controller: ctrl,
        maxLines: maxLines,
        keyboardType: keyboardType,
        enableInteractiveSelection: true,
        decoration: InputDecoration(
          icon: Icon(icon, color: Theme.of(context).textTheme.bodySmall?.color, size: 20),
          labelText: label,
          labelStyle: TextStyle(color: Theme.of(context).textTheme.bodySmall?.color, fontSize: 12, fontWeight: FontWeight.w600),
          border: InputBorder.none,
          floatingLabelBehavior: FloatingLabelBehavior.always,
        ),
        style: TextStyle(fontWeight: FontWeight.w700, fontSize: 15, color: Theme.of(context).textTheme.bodyLarge?.color),
      ),
    );
  }
}

class _BecomeSellerCard extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [cs.primary, cs.primary.withOpacity(0.8)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(28),
        boxShadow: [
          BoxShadow(
            color: cs.primary.withOpacity(0.3),
            blurRadius: 20,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.2),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.storefront_rounded, color: Colors.white, size: 28),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      context.l('become_seller_title') ?? 'Sotuvchi bo\'lmoqchimisiz?',
                      style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w900, letterSpacing: -0.5),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      context.l('become_seller_desc') ?? 'O\'z mahsulotlaringizni soting',
                      style: TextStyle(color: Colors.white.withOpacity(0.8), fontSize: 13, fontWeight: FontWeight.w600),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.1),
              borderRadius: BorderRadius.circular(20),
            ),
            child: const Column(
              children: [
                _ContactRow(icon: Icons.telegram, label: 'Telegram', value: '@abboc19'),
                Padding(
                  padding: EdgeInsets.symmetric(vertical: 12),
                  child: Divider(color: Colors.white12, height: 1),
                ),
                _ContactRow(icon: Icons.phone_rounded, label: 'Telefon', value: '+998 94 227 34 07'),
              ],
            ),
          ),
          const SizedBox(height: 20),
          Text(
            context.l('become_seller_contact') ?? 'Sotuvchi bo\'lish uchun administrator bilan bog\'laning. Tasdiqlanganingizdan so\'ng siz do\'kon ochishingiz mumkin.',
            style: TextStyle(color: Colors.white.withOpacity(0.7), fontSize: 12, fontWeight: FontWeight.w500, height: 1.4),
          ),
        ],
      ),
    );
  }
}

class _ContactRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;

  const _ContactRow({required this.icon, required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, color: Colors.white70, size: 20),
        const SizedBox(width: 12),
        Expanded(
          child: Text(label, style: const TextStyle(color: Colors.white60, fontSize: 13, fontWeight: FontWeight.w600)),
        ),
        Text(value, style: const TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w800)),
      ],
    );
  }
}

class _AdminEntryPoint extends ConsumerStatefulWidget {
  @override
  ConsumerState<_AdminEntryPoint> createState() => _AdminEntryPointState();
}

class _AdminEntryPointState extends ConsumerState<_AdminEntryPoint> {
  int _tapCount = 0;

  @override
  Widget build(BuildContext context) {
    final user = ref.watch(authStateProvider).user;
    final isAdmin = user?.role == UserRole.admin;
    final cs = Theme.of(context).colorScheme;

    if (isAdmin) {
      return Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        child: FilledButton.icon(
          onPressed: () => context.push('/admin'),
          icon: const Icon(Icons.admin_panel_settings_rounded),
          label: Text(context.l('admin_panel_entry') ?? 'ADMIN PANELGA KIRISH', style: TextStyle(fontWeight: FontWeight.w900)),
          style: FilledButton.styleFrom(
            backgroundColor: Colors.purple,
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(vertical: 16),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          ),
        ),
      );
    }

    return GestureDetector(
      onTap: () {
        _tapCount++;
        if (_tapCount >= 5) {
          _tapCount = 0;
          context.push('/admin');
        }
      },
      behavior: HitTestBehavior.opaque,
      child: Center(
        child: Text(
          'v2.0',
          style: TextStyle(
            fontSize: 11,
            color: Theme.of(context).colorScheme.onSurface.withOpacity(0.12),
            fontWeight: FontWeight.w500,
          ),
        ),
      ),
    );
  }
}
