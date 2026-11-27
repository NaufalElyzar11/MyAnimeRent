import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

import '../config/theme.dart';
import '../models/costume.dart';
import 'costume_card.dart';
import 'sakuga.dart';

/// Komponen kecil yang dipakai bersama layar penyewa agar tampilannya seragam.

/// Judul bagian + tautan "Lihat semua".
class SectionHeader extends StatelessWidget {
  const SectionHeader({super.key, required this.title, this.subtitle, this.actionLabel, this.onAction});
  final String title;
  final String? subtitle;
  final String? actionLabel;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700)),
                if (subtitle != null)
                  Text(subtitle!,
                      style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant)),
              ],
            ),
          ),
          if (actionLabel != null && onAction != null)
            TextButton(
              onPressed: onAction,
              style: TextButton.styleFrom(minimumSize: const Size(48, 36), padding: const EdgeInsets.symmetric(horizontal: 8)),
              child: Text(actionLabel!),
            ),
        ],
      ),
    );
  }
}

/// Keadaan kosong yang ramah: ikon, judul, penjelasan, dan satu tindakan.
class EmptyState extends StatelessWidget {
  const EmptyState({
    super.key,
    required this.icon,
    required this.title,
    this.message,
    this.actionLabel,
    this.onAction,
  });
  final IconData icon;
  final String title;
  final String? message;
  final String? actionLabel;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 40),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          SpeedLines(
            size: 150,
            opacity: 0.08,
            child: Container(
              width: 84,
              height: 84,
              decoration: const BoxDecoration(gradient: AppColors.softGradient, shape: BoxShape.circle),
              child: Icon(icon, size: 40, color: theme.colorScheme.primary),
            ),
          ),
          const SizedBox(height: 4),
          Text(title, textAlign: TextAlign.center, style: theme.textTheme.titleMedium),
          if (message != null) ...[
            const SizedBox(height: 6),
            Text(
              message!,
              textAlign: TextAlign.center,
              style: theme.textTheme.bodyMedium?.copyWith(color: theme.colorScheme.onSurfaceVariant, height: 1.4),
            ),
          ],
          if (actionLabel != null && onAction != null) ...[
            const SizedBox(height: 20),
            FilledButton(onPressed: onAction, child: Text(actionLabel!)),
          ],
        ],
      ),
    );
  }
}

/// Kotak info berwarna lembut (penjelasan, peringatan ringan).
class InfoBanner extends StatelessWidget {
  const InfoBanner({super.key, required this.icon, required this.text, this.color, this.child});
  final IconData icon;
  final String text;
  final Color? color;
  final Widget? child;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final c = color ?? theme.colorScheme.secondary;
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: c.withValues(alpha: theme.brightness == Brightness.dark ? 0.18 : 0.08),
        borderRadius: BorderRadius.circular(AppSpacing.radiusSmall),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 20, color: c),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(text, style: theme.textTheme.bodySmall?.copyWith(height: 1.4)),
                ?child,
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Kolom pencarian palsu yang membuka layar Cari (beranda).
class SearchBarButton extends StatelessWidget {
  const SearchBarButton({super.key, required this.onTap, this.hint = 'Cari karakter, anime, atau kostum…'});
  final VoidCallback onTap;
  final String hint;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Material(
      color: theme.inputDecorationTheme.fillColor,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          child: Row(
            children: [
              Icon(Icons.search, color: theme.colorScheme.onSurfaceVariant),
              const SizedBox(width: 12),
              Expanded(
                child: Text(hint,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.bodyMedium?.copyWith(color: theme.colorScheme.onSurfaceVariant)),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Kotak abu-abu berdenyut sebagai pengganti konten yang sedang dimuat.
class SkeletonBox extends StatefulWidget {
  const SkeletonBox({super.key, this.width, this.height, this.radius = 12});
  final double? width;
  final double? height;
  final double radius;

  @override
  State<SkeletonBox> createState() => _SkeletonBoxState();
}

class _SkeletonBoxState extends State<SkeletonBox> with SingleTickerProviderStateMixin {
  late final AnimationController _c =
      AnimationController(vsync: this, duration: const Duration(milliseconds: 900))..repeat(reverse: true);

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final base = Theme.of(context).colorScheme.onSurface;
    return FadeTransition(
      opacity: Tween(begin: 0.05, end: 0.12).animate(_c),
      child: Container(
        width: widget.width,
        height: widget.height,
        decoration: BoxDecoration(color: base, borderRadius: BorderRadius.circular(widget.radius)),
      ),
    );
  }
}

/// Perkiraan tinggi bagian teks kartu kostum (mengikuti ukuran huruf pengguna).
double costumeCardTextHeight(BuildContext context) =>
    100 * MediaQuery.textScalerOf(context).scale(14).clamp(14.0, 22.0) / 14;

/// Grid kartu kostum: tinggi sel dihitung dari lebar sel (foto persegi) + teks,
/// sehingga tidak terpotong di HP kecil maupun saat huruf diperbesar.
class CostumeGridView extends StatelessWidget {
  const CostumeGridView({
    super.key,
    required this.costumes,
    required this.onTap,
    this.shrinkWrap = false,
    this.padding = const EdgeInsets.all(AppSpacing.page),
    this.physics,
    this.controller,
  });

  final List<Costume> costumes;
  final void Function(Costume) onTap;
  final bool shrinkWrap;
  final EdgeInsetsGeometry padding;
  final ScrollPhysics? physics;
  final ScrollController? controller;

  static const _spacing = 12.0;
  static const _maxExtent = 210.0;

  @override
  Widget build(BuildContext context) {
    final textHeight = costumeCardTextHeight(context);
    return LayoutBuilder(builder: (context, constraints) {
      final inner = constraints.maxWidth - padding.horizontal;
      final columns = (inner / _maxExtent).ceil().clamp(2, 6);
      final cell = (inner - _spacing * (columns - 1)) / columns;
      return GridView.builder(
        controller: controller,
        shrinkWrap: shrinkWrap,
        physics: physics,
        padding: padding,
        gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: columns,
          crossAxisSpacing: _spacing,
          mainAxisSpacing: _spacing,
          mainAxisExtent: cell + textHeight,
        ),
        itemCount: costumes.length,
        itemBuilder: (_, i) => CostumeCard(costume: costumes[i], onTap: () => onTap(costumes[i])),
      );
    });
  }
}

/// Kerangka grid saat katalog dimuat.
class CostumeGridSkeleton extends StatelessWidget {
  const CostumeGridSkeleton({super.key, this.count = 4});
  final int count;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 12,
      runSpacing: 16,
      children: [
        for (var i = 0; i < count; i++)
          SizedBox(
            width: 156,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: const [
                SkeletonBox(height: 156, radius: 16),
                SizedBox(height: 10),
                SkeletonBox(width: 120, height: 14, radius: 6),
                SizedBox(height: 6),
                SkeletonBox(width: 90, height: 12, radius: 6),
                SizedBox(height: 8),
                SkeletonBox(width: 70, height: 14, radius: 6),
              ],
            ),
          ),
      ],
    );
  }
}

/// Avatar toko: foto sampul bila ada, kalau tidak inisial di atas gradasi brand.
class StoreAvatar extends StatelessWidget {
  const StoreAvatar({super.key, required this.name, this.imageUrl = '', this.size = 48});
  final String name;
  final String imageUrl;
  final double size;

  @override
  Widget build(BuildContext context) {
    final initials = name
        .trim()
        .split(RegExp(r'\s+'))
        .where((p) => p.isNotEmpty)
        .take(2)
        .map((p) => p[0].toUpperCase())
        .join();
    final fallback = Container(
      width: size,
      height: size,
      alignment: Alignment.center,
      decoration: const BoxDecoration(gradient: AppColors.primaryGradient),
      child: Text(initials.isEmpty ? '?' : initials,
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: size * 0.36)),
    );
    return ClipRRect(
      borderRadius: BorderRadius.circular(size * 0.3),
      child: imageUrl.isEmpty
          ? fallback
          : CachedNetworkImage(
              imageUrl: imageUrl,
              width: size,
              height: size,
              fit: BoxFit.cover,
              errorWidget: (_, _, _) => fallback,
            ),
    );
  }
}
