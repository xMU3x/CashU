class Cat {
  final String id, label, emoji;
  final bool income;
  const Cat(this.id, this.label, this.emoji, {this.income = false});
}

const categories = <Cat>[
  Cat('food', 'طعام', '🍔'),
  Cat('transport', 'مواصلات', '🚗'),
  Cat('bills', 'فواتير', '🧾'),
  Cat('shopping', 'تسوق', '🛍️'),
  Cat('health', 'صحة', '💊'),
  Cat('fun', 'ترفيه', '🎬'),
  Cat('edu', 'تعليم', '📚'),
  Cat('home', 'بيت', '🏠'),
  Cat('other', 'أخرى', '📦'),
  Cat('salary', 'مرتب', '💰', income: true),
  Cat('freelance', 'عمل حر', '💼', income: true),
  Cat('gift', 'هدية', '🎁', income: true),
  Cat('other_in', 'أخرى', '📦', income: true),
];

Cat? catById(String? id) {
  for (final c in categories) {
    if (c.id == id) return c;
  }
  return null;
}
