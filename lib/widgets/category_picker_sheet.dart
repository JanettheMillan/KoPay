import 'package:flutter/material.dart';

import '../utils/app_colors.dart';
import 'ui_kit.dart';

/// Categorías iniciales con su icono. Son las mismas que
/// `DatabaseHelper.defaultCategories` guarda en `settings`.
const Map<String, String> defaultCategoryEmojis = {
  'Comida': '🛒',
  'Transporte': '🚌',
  'Servicios': '💡',
  'Vivienda': '🏠',
  'Entretenimiento': '🎬',
  'Salud': '💊',
  'Otros': '📦',
};

/// Icono de una categoría; las que no están en la lista usan uno genérico.
String categoryEmoji(String category) =>
    defaultCategoryEmojis[category] ?? '🏷️';

/// Abre la lista de categorías y devuelve la elegida, o `null` si se
/// cierra sin elegir.
Future<String?> showCategoryPicker(
  BuildContext context, {
  String? selected,
  List<String>? categories,
}) {
  return showKopaySheet<String>(
    context,
    CategoryPickerSheet(
      selected: selected,
      categories: categories ?? defaultCategoryEmojis.keys.toList(),
    ),
  );
}

class CategoryPickerSheet extends StatelessWidget {
  final String? selected;
  final List<String> categories;

  const CategoryPickerSheet({
    super.key,
    required this.categories,
    this.selected,
  });

  @override
  Widget build(BuildContext context) {
    return KopaySheet(
      title: 'Categoría',
      child: Column(
        children: [
          for (final category in categories)
            Material(
              color: Colors.transparent,
              child: InkWell(
                key: Key('category-$category'),
                borderRadius: BorderRadius.circular(12),
                onTap: () => Navigator.of(context).pop(category),
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 4,
                    vertical: 10,
                  ),
                  child: Row(
                    children: [
                      Container(
                        width: 36,
                        height: 36,
                        margin: const EdgeInsets.only(right: 14),
                        decoration: BoxDecoration(
                          color: AppColors.surfaceHi,
                          borderRadius: BorderRadius.circular(10),
                        ),
                        alignment: Alignment.center,
                        child: Text(
                          categoryEmoji(category),
                          style: const TextStyle(fontSize: 18),
                        ),
                      ),
                      Expanded(
                        child: Text(
                          category,
                          style: TextStyle(fontSize: 15, color: AppColors.text),
                        ),
                      ),
                      if (category == selected)
                        Icon(
                          Icons.check_rounded,
                          color: AppColors.green,
                          size: 20,
                        ),
                    ],
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
