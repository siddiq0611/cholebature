import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/transaction_model.dart';
import '../models/custom_category_model.dart';
import '../providers/custom_category_provider.dart';
import '../theme/app_theme.dart';

/// Renders the icon for either a built-in [TransactionCategory] or a
/// [CustomCategory] identified by [customCategoryId].
///
/// Usage — built-in:
///   CategoryIcon(category: tx.category)
///
/// Usage — custom:
///   CategoryIcon(category: tx.category, customCategoryId: tx.customCategoryId)
class CategoryIcon extends ConsumerWidget {
  final TransactionCategory category;
  final String? customCategoryId;
  final double size;
  final double iconSize;

  const CategoryIcon({
    super.key,
    required this.category,
    this.customCategoryId,
    this.size = 44,
    this.iconSize = 20,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // ── Custom category ───────────────────────────────────────────────────
    if (customCategoryId != null) {
      final cat = ref.watch(customCategoryProvider).when(
            data: (list) {
              try {
                return list.firstWhere((c) => c.id == customCategoryId);
              } catch (_) {
                return null;
              }
            },
            loading: () => null,
            error: (_, __) => null,
          );

      if (cat != null) {
        final color = cat.deleted ? context.appTextMuted : cat.color;
        return _IconContainer(
          size: size,
          iconSize: iconSize,
          color: color,
          icon: cat.icon,
          opacity: cat.deleted ? 0.5 : 1.0,
        );
      }

      // Category was hard-deleted — show a generic fallback
      return _IconContainer(
        size: size,
        iconSize: iconSize,
        color: context.appTextMuted,
        icon: Icons.help_outline_rounded,
      );
    }

    // ── Built-in category ─────────────────────────────────────────────────
    final info = categoryInfoMap[category]!;
    return _IconContainer(
      size: size,
      iconSize: iconSize,
      color: info.color,
      icon: info.icon,
    );
  }
}

class _IconContainer extends StatelessWidget {
  final double size;
  final double iconSize;
  final Color color;
  final IconData icon;
  final double opacity;

  const _IconContainer({
    required this.size,
    required this.iconSize,
    required this.color,
    required this.icon,
    this.opacity = 1.0,
  });

  @override
  Widget build(BuildContext context) {
    return Opacity(
      opacity: opacity,
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.15),
          borderRadius: BorderRadius.circular(size * 0.28),
          border:
              Border.all(color: color.withValues(alpha: 0.35), width: 1),
        ),
        child: Icon(icon, color: color, size: iconSize),
      ),
    );
  }
}