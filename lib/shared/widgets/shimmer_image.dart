import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:shimmer/shimmer.dart';

/// Universal rasm yuklovchi widget.
/// Rasm yuklanayotganda yaltirab turuvchi (shimmer) skelet animatsiyasi ko'rsatadi.
class ShimmerImage extends StatelessWidget {
  final String? url;
  final double? width;
  final double? height;
  final BoxFit fit;
  final BorderRadius? borderRadius;
  final Widget? placeholder;

  const ShimmerImage({
    super.key,
    required this.url,
    this.width,
    this.height,
    this.fit = BoxFit.cover,
    this.borderRadius,
    this.placeholder,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final shimmerBase = isDark ? const Color(0xFF2A2A2E) : const Color(0xFFEEEEEE);
    final shimmerHighlight = isDark ? const Color(0xFF3A3A40) : const Color(0xFFF5F5F5);

    Widget shimmerBox = Shimmer.fromColors(
      baseColor: shimmerBase,
      highlightColor: shimmerHighlight,
      child: Container(
        width: width,
        height: height,
        decoration: BoxDecoration(
          color: shimmerBase,
          borderRadius: borderRadius,
        ),
      ),
    );

    if (url == null || url!.isEmpty) {
      return ClipRRect(
        borderRadius: borderRadius ?? BorderRadius.zero,
        child: placeholder ??
            Container(
              width: width,
              height: height,
              color: isDark ? const Color(0xFF2A2A2E) : const Color(0xFFF0F0F5),
              child: Icon(
                Icons.image_outlined,
                color: isDark ? Colors.white24 : Colors.black12,
                size: (width ?? 48) * 0.4,
              ),
            ),
      );
    }

    return ClipRRect(
      borderRadius: borderRadius ?? BorderRadius.zero,
      child: CachedNetworkImage(
        imageUrl: url!,
        width: width,
        height: height,
        fit: fit,
        placeholder: (_, __) => shimmerBox,
        errorWidget: (_, __, ___) => Container(
          width: width,
          height: height,
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF2A2A2E) : const Color(0xFFF0F0F5),
            borderRadius: borderRadius,
          ),
          child: Icon(
            Icons.broken_image_outlined,
            color: isDark ? Colors.white24 : Colors.black12,
            size: (width ?? 48) * 0.35,
          ),
        ),
      ),
    );
  }
}

/// Mahsulotlar ro'yxati yuklanayotganda ko'rsatiladigan skelet karta.
class ShimmerProductCard extends StatelessWidget {
  const ShimmerProductCard({super.key});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final base = isDark ? const Color(0xFF2A2A2E) : const Color(0xFFEEEEEE);
    final highlight = isDark ? const Color(0xFF3A3A40) : const Color(0xFFF5F5F5);

    return Shimmer.fromColors(
      baseColor: base,
      highlightColor: highlight,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Rasm joyi
          Container(
            height: 160,
            decoration: BoxDecoration(
              color: base,
              borderRadius: BorderRadius.circular(16),
            ),
          ),
          const SizedBox(height: 10),
          // Nom
          Container(
            height: 14,
            width: double.infinity,
            decoration: BoxDecoration(
              color: base,
              borderRadius: BorderRadius.circular(7),
            ),
          ),
          const SizedBox(height: 6),
          // Narx
          Container(
            height: 12,
            width: 80,
            decoration: BoxDecoration(
              color: base,
              borderRadius: BorderRadius.circular(6),
            ),
          ),
        ],
      ),
    );
  }
}

/// Do'konlar ro'yxati yuklanayotganda ko'rsatiladigan skelet karta.
class ShimmerShopCard extends StatelessWidget {
  const ShimmerShopCard({super.key});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final base = isDark ? const Color(0xFF2A2A2E) : const Color(0xFFEEEEEE);
    final highlight = isDark ? const Color(0xFF3A3A40) : const Color(0xFFF5F5F5);

    return Shimmer.fromColors(
      baseColor: base,
      highlightColor: highlight,
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: base,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Row(
          children: [
            Container(
              width: 56,
              height: 56,
              decoration: BoxDecoration(
                color: highlight,
                borderRadius: BorderRadius.circular(16),
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    height: 14,
                    width: double.infinity,
                    decoration: BoxDecoration(
                      color: highlight,
                      borderRadius: BorderRadius.circular(7),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Container(
                    height: 11,
                    width: 120,
                    decoration: BoxDecoration(
                      color: highlight,
                      borderRadius: BorderRadius.circular(5),
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
