class AppConstants {
  static const String appName = 'سوق سوريا الشامل';
  static const Color0xFF005B41 = 0xFF005B41;

  static const List<String> provinces = [
    'الكل',
    'دمشق',
    'ريف دمشق',
    'حلب',
    'حمص',
    'حماة',
    'اللاذقية',
    'طرطوس',
    'إدلب',
    'دير الزور',
    'الرقة',
    'الحسكة',
    'درعا',
    'السويداء',
    'القنيطرة',
  ];

  static const List<Map<String, dynamic>> categories = [
    {'title': 'سيارات', 'icon': 'directions_car', 'color': 0xFFFF9800},
    {'title': 'عقارات', 'icon': 'home', 'color': 0xFF2196F3},
    {'title': 'إلكترونيات', 'icon': 'smartphone', 'color': 0xFF3F51B5},
    {'title': 'أدوات منزلية', 'icon': 'chair', 'color': 0xFF9C27B0},
    {'title': 'طيور وحيوانات', 'icon': 'pets', 'color': 0xFFF57C00},
    {'title': 'إعلانات تجارية', 'icon': 'campaign', 'color': 0xFFE64A19},
    {'title': 'سوق المستعمل', 'icon': 'autorenew', 'color': 0xFF00897B},
    {'title': 'وظائف وعمال', 'icon': 'work', 'color': 0xFF607D8B},
  ];

  static const List<Map<String, dynamic>> subCategories = {
    'عقارات': [
      {'title': 'عقارات للإيجار', 'icon': 'home_work', 'color': 0xFF2196F3},
      {'title': 'عقارات للبيع والشراء', 'icon': 'vpn_key', 'color': 0xFF4CAF50},
    ],
    'إلكترونيات': [
      {'title': 'هواتف وموبايلات', 'icon': 'smartphone', 'color': 0xFF3F51B5},
      {'title': 'لابتوبات وكمبيوتر', 'icon': 'laptop', 'color': 0xFF00897B},
      {'title': 'إلكترونيات منوعة', 'icon': 'devices', 'color': 0xFFE64A19},
    ],
    'طيور وحيوانات': [
      {'title': 'طيور الكنار', 'icon': 'flutter_dash', 'color': 0xFFFFC107},
      {'title': 'طيور الحسون', 'icon': 'music_note', 'color': 0xFFFF9800},
      {'title': 'طيور الحمام', 'icon': 'bedroom_baby', 'color': 0xFF607D8B},
      {'title': 'الحيوانات الأليفة', 'icon': 'pets', 'color': 0xFF7B1FA2},
    ],
  };

  static const List<String> contactMethods = [
    'اتصال هاتف',
    'واتساب',
    'تليجرام',
  ];
}
