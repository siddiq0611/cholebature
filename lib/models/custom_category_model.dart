import 'package:flutter/material.dart';

/// A user-defined category that supplements the built-in [TransactionCategory] enum.
///
/// Soft-delete pattern: when [deleted] is true the category is hidden from
/// creation pickers but existing transactions still resolve it for display.
class CustomCategory {
  final String id;
  final String name;
  final int colorValue; // Color.value (ARGB int)
  final int iconCodePoint; // IconData.codePoint
  final String iconFontFamily; // e.g. 'MaterialIcons'
  final bool deleted;
  final DateTime createdAt;

  const CustomCategory({
    required this.id,
    required this.name,
    required this.colorValue,
    required this.iconCodePoint,
    this.iconFontFamily = 'MaterialIcons',
    this.deleted = false,
    required this.createdAt,
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
      );

  CustomCategory copyWith({
    String? id,
    String? name,
    int? colorValue,
    int? iconCodePoint,
    String? iconFontFamily,
    bool? deleted,
    DateTime? createdAt,
  }) =>
      CustomCategory(
        id: id ?? this.id,
        name: name ?? this.name,
        colorValue: colorValue ?? this.colorValue,
        iconCodePoint: iconCodePoint ?? this.iconCodePoint,
        iconFontFamily: iconFontFamily ?? this.iconFontFamily,
        deleted: deleted ?? this.deleted,
        createdAt: createdAt ?? this.createdAt,
      );
}

// ─── Palette & icon options shown in the picker ──────────────────────────────

/// Preset colours the user can pick from.
const List<Color> kCategoryColorPalette = [
  Color(0xFFEF5350), // red
  Color(0xFFEC407A), // pink
  Color(0xFFAB47BC), // purple
  Color(0xFF7E57C2), // deep purple
  Color(0xFF42A5F5), // blue
  Color(0xFF26C6DA), // cyan
  Color(0xFF26A69A), // teal
  Color(0xFF66BB6A), // green
  Color(0xFFD4E157), // lime
  Color(0xFFFFCA28), // amber
  Color(0xFFFFA726), // orange
  Color(0xFFFF7043), // deep orange
  Color(0xFF8D6E63), // brown
  Color(0xFF78909C), // blue-grey
  Color(0xFF9E9E9E), // grey
];

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