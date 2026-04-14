import 'package:flutter/material.dart';

enum CustomCategoryType { expense, income }

class CustomCategory {
  final String id;
  final String name;
  final int colorValue;
  final int iconCodePoint;
  final String iconFontFamily;
  final bool deleted;
  final DateTime createdAt;
  final CustomCategoryType categoryType;

  const CustomCategory({
    required this.id,
    required this.name,
    required this.colorValue,
    required this.iconCodePoint,
    this.iconFontFamily = 'MaterialIcons',
    this.deleted = false,
    required this.createdAt,
    this.categoryType = CustomCategoryType.expense,
  });

  Color get color => Color(colorValue);

  IconData get icon => IconData(
        iconCodePoint,
        fontFamily: iconFontFamily,
      );

  Map<String, dynamic> toMap() => {
        'id': id,
        'name': name,
        'color_value': colorValue,
        'icon_code_point': iconCodePoint,
        'icon_font_family': iconFontFamily,
        'deleted': deleted ? 1 : 0,
        'created_at': createdAt.millisecondsSinceEpoch,
        'category_type': categoryType.index,
      };
 
  factory CustomCategory.fromMap(Map<String, dynamic> map) => CustomCategory(
        id: map['id'] as String,
        name: map['name'] as String,
        colorValue: map['color_value'] as int,
        iconCodePoint: map['icon_code_point'] as int,
        iconFontFamily:
            map['icon_font_family'] as String? ?? 'MaterialIcons',
        deleted: (map['deleted'] as int? ?? 0) == 1,
        createdAt: DateTime.fromMillisecondsSinceEpoch(
            map['created_at'] as int),
        categoryType: CustomCategoryType
            .values[map['category_type'] as int? ?? 0],
      );

  CustomCategory copyWith({
    String? id,
    String? name,
    int? colorValue,
    int? iconCodePoint,
    String? iconFontFamily,
    bool? deleted,
    DateTime? createdAt,
    CustomCategoryType? categoryType,
  }) =>
      CustomCategory(
        id: id ?? this.id,
        name: name ?? this.name,
        colorValue: colorValue ?? this.colorValue,
        iconCodePoint: iconCodePoint ?? this.iconCodePoint,
        iconFontFamily: iconFontFamily ?? this.iconFontFamily,
        deleted: deleted ?? this.deleted,
        createdAt: createdAt ?? this.createdAt,
        categoryType: categoryType ?? this.categoryType,
      );
}

// ─── Palette & icon options shown in the picker ──────────────────────────────

/// Preset icons available in the custom-category picker.
const List<_IconOption> kCategoryIconOptions = [
  _IconOption(Icons.restaurant_rounded, 'Food'),
  _IconOption(Icons.local_cafe_rounded, 'Café'),
  _IconOption(Icons.local_bar_rounded, 'Bar'),
  _IconOption(Icons.flight_rounded, 'Travel'),
  _IconOption(Icons.directions_car_rounded, 'Car'),
  _IconOption(Icons.directions_bus_rounded, 'Transit'),
  _IconOption(Icons.local_gas_station_rounded, 'Fuel'),
  _IconOption(Icons.shopping_bag_rounded, 'Shopping'),
  _IconOption(Icons.storefront_rounded, 'Store'),
  _IconOption(Icons.home_rounded, 'Home'),
  _IconOption(Icons.electrical_services_rounded, 'Utilities'),
  _IconOption(Icons.wifi_rounded, 'Internet'),
  _IconOption(Icons.phone_android_rounded, 'Phone'),
  _IconOption(Icons.fitness_center_rounded, 'Gym'),
  _IconOption(Icons.favorite_rounded, 'Health'),
  _IconOption(Icons.local_hospital_rounded, 'Medical'),
  _IconOption(Icons.school_rounded, 'Education'),
  _IconOption(Icons.work_rounded, 'Work'),
  _IconOption(Icons.computer_rounded, 'Tech'),
  _IconOption(Icons.movie_rounded, 'Entertainment'),
  _IconOption(Icons.music_note_rounded, 'Music'),
  _IconOption(Icons.sports_esports_rounded, 'Gaming'),
  _IconOption(Icons.card_giftcard_rounded, 'Gifts'),
  _IconOption(Icons.child_care_rounded, 'Kids'),
  _IconOption(Icons.pets_rounded, 'Pets'),
  _IconOption(Icons.account_balance_wallet_rounded, 'Finance'),
  _IconOption(Icons.savings_rounded, 'Savings'),
  _IconOption(Icons.currency_exchange_rounded, 'Cashback'),
  _IconOption(Icons.handshake_rounded, 'Borrow/Lend'),
  _IconOption(Icons.category_rounded, 'Other'),
];

class _IconOption {
  final IconData icon;
  final String label;
  const _IconOption(this.icon, this.label);
}