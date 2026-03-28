import 'package:flutter/material.dart';
import '../models/transaction_model.dart';
import '../theme/app_theme.dart';

class CategoryIcon extends StatelessWidget {
  final TransactionCategory category;
  final double size;
  final double iconSize;

  const CategoryIcon({
    super.key,
    required this.category,
    this.size = 44,
    this.iconSize = 20,
  });

  @override
  Widget build(BuildContext context) {
    final info = categoryInfoMap[category]!;
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: info.color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(size * 0.28),
        border: Border.all(color: info.color.withValues(alpha: 0.35), width: 1),
      ),
      child: Icon(info.icon, color: info.color, size: iconSize),
    );
  }
}