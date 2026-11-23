import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../providers/category_provider.dart';
import '../utils/app_colors.dart';
import '../utils/validators.dart';
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

/// Iconos por palabra clave, en minúsculas. Incluye `ingreso`, que usa
/// el historial para los ingresos.
const Map<String, String> _emojiByKeyword = {
  'comida': '🛒',
  'transporte': '🚌',
  'servicios': '💡',
  'vivienda': '🏠',
  'entretenimiento': '🎬',
  'salud': '💊',
  'otros': '📦',
  'ingreso': '💼',
};

/// Icono de una categoría. Ignora espacios a los lados y mayúsculas, y
/// reconoce la palabra clave dentro del texto (`Compra de comida` → 🛒).
/// Las categorías sin coincidencia usan un icono genérico.
String categoryEmoji(String category) {
  final normalized = category.trim().toLowerCase();
  for (final entry in _emojiByKeyword.entries) {
    if (normalized.contains(entry.key)) return entry.value;
  }
  return '🏷️';
}

/// Abre el selector de categorías y devuelve la elegida, o `null` si se
/// cierra sin elegir.
///
/// Si hay un [CategoryProvider] en el árbol, el selector permite buscar,
/// crear, renombrar y eliminar categorías. Si no lo hay, muestra
/// [categories] (o las iniciales) solo para elegir.
Future<String?> showCategoryPicker(
  BuildContext context, {
  String? selected,
  List<String>? categories,
}) {
  return showKopaySheet<String>(
    context,
    CategoryPickerSheet(selected: selected, categories: categories),
  );
}

class CategoryPickerSheet extends StatefulWidget {
  final String? selected;

  /// Lista fija para cuando no hay [CategoryProvider].
  final List<String>? categories;

  const CategoryPickerSheet({super.key, this.selected, this.categories});

  @override
  State<CategoryPickerSheet> createState() => _CategoryPickerSheetState();
}

class _CategoryPickerSheetState extends State<CategoryPickerSheet> {
  final _search = TextEditingController();
  final _name = TextEditingController();

  String _query = '';

  /// Categoría que se está renombrando.
  String? _editing;

  /// `true` mientras se escribe una categoría nueva.
  bool _adding = false;

  String? _error;

  @override
  void dispose() {
    _search.dispose();
    _name.dispose();
    super.dispose();
  }

  void _startAdd() {
    _name.text = _query.trim();
    setState(() {
      _adding = true;
      _editing = null;
      _error = null;
    });
  }

  void _startEdit(String category) {
    _name.text = category;
    setState(() {
      _editing = category;
      _adding = false;
      _error = null;
    });
  }

  void _cancelEdit() {
    setState(() {
      _editing = null;
      _adding = false;
      _error = null;
    });
  }

  Future<void> _saveNew(CategoryProvider provider) async {
    try {
      final name = await provider.add(_name.text);
      if (mounted) Navigator.of(context).pop(name);
    } on ValidationException catch (e) {
      setState(() => _error = e.message);
    }
  }

  Future<void> _saveRename(CategoryProvider provider) async {
    final old = _editing;
    if (old == null) return;
    try {
      await provider.rename(old, _name.text);
      _cancelEdit();
    } on ValidationException catch (e) {
      setState(() => _error = e.message);
    }
  }

  Future<void> _confirmDelete(
    CategoryProvider provider,
    String category,
  ) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.surface,
        title: Text(
          '¿Eliminar "$category"?',
          style: TextStyle(color: AppColors.text, fontSize: 17),
        ),
        content: Text(
          'Dejará de aparecer en el selector. Los gastos que ya la usan '
          'conservan su categoría.',
          style: TextStyle(color: AppColors.text2, fontSize: 14),
        ),
        actions: [
          TextButton(
            key: const Key('category-delete-cancel'),
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Cancelar'),
          ),
          TextButton(
            key: const Key('category-delete-confirm'),
            onPressed: () => Navigator.of(ctx).pop(true),
            style: TextButton.styleFrom(foregroundColor: AppColors.red),
            child: const Text('Eliminar'),
          ),
        ],
      ),
    );
    if (ok == true) await provider.remove(category);
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<CategoryProvider?>();
    final canManage = provider != null;
    final all =
        provider?.categories ??
        widget.categories ??
        defaultCategoryEmojis.keys.toList();
    final visible = provider != null
        ? provider.search(_query)
        : all
              .where((c) => c.toLowerCase().contains(_query.toLowerCase()))
              .toList();

    return KopaySheet(
      title: 'Categoría',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          TextField(
            key: const Key('category-search'),
            controller: _search,
            onChanged: (v) => setState(() => _query = v),
            textInputAction: TextInputAction.search,
            decoration: InputDecoration(
              hintText: 'Buscar categoría',
              prefixIcon: Icon(
                Icons.search_rounded,
                color: AppColors.text3,
                size: 20,
              ),
            ),
          ),
          const SizedBox(height: 8),
          if (provider != null)
            _adding
                ? _NameEditor(
                    key: const Key('category-new-editor'),
                    controller: _name,
                    hint: 'Nombre de la categoría',
                    error: _error,
                    onSave: () => _saveNew(provider),
                    onCancel: _cancelEdit,
                  )
                : _ActionRow(
                    key: const Key('category-add'),
                    icon: Icons.add_rounded,
                    label: 'Nueva categoría',
                    onTap: _startAdd,
                  ),
          for (final category in visible)
            if (category == _editing && provider != null)
              _NameEditor(
                key: Key('category-edit-editor-$category'),
                controller: _name,
                hint: 'Nuevo nombre',
                error: _error,
                onSave: () => _saveRename(provider),
                onCancel: _cancelEdit,
              )
            else
              _CategoryRow(
                category: category,
                isSelected: category == widget.selected,
                onTap: () => Navigator.of(context).pop(category),
                onEdit: canManage ? () => _startEdit(category) : null,
                onDelete: provider != null
                    ? () => _confirmDelete(provider, category)
                    : null,
              ),
          if (visible.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 16),
              child: Text(
                _query.trim().isEmpty
                    ? 'No hay categorías. Crea una nueva.'
                    : 'Sin resultados para "${_query.trim()}"',
                key: const Key('category-empty'),
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 13, color: AppColors.text3),
              ),
            ),
        ],
      ),
    );
  }
}

class _CategoryRow extends StatelessWidget {
  final String category;
  final bool isSelected;
  final VoidCallback onTap;
  final VoidCallback? onEdit;
  final VoidCallback? onDelete;

  const _CategoryRow({
    required this.category,
    required this.isSelected,
    required this.onTap,
    this.onEdit,
    this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        key: Key('category-$category'),
        borderRadius: BorderRadius.circular(12),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 6),
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
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 15,
                    color: isSelected ? AppColors.green : AppColors.text,
                  ),
                ),
              ),
              if (isSelected)
                Padding(
                  padding: const EdgeInsets.only(left: 4),
                  child: Icon(
                    Icons.check_rounded,
                    color: AppColors.green,
                    size: 20,
                  ),
                ),
              if (onEdit != null)
                IconButton(
                  key: Key('category-edit-$category'),
                  tooltip: 'Renombrar',
                  onPressed: onEdit,
                  icon: Icon(
                    Icons.edit_outlined,
                    color: AppColors.text3,
                    size: 19,
                  ),
                ),
              if (onDelete != null)
                IconButton(
                  key: Key('category-delete-$category'),
                  tooltip: 'Eliminar',
                  onPressed: onDelete,
                  icon: Icon(
                    Icons.delete_outline_rounded,
                    color: AppColors.text3,
                    size: 19,
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ActionRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  const _ActionRow({
    super.key,
    required this.icon,
    required this.label,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 12),
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
                child: Icon(icon, color: AppColors.green, size: 20),
              ),
              Text(
                label,
                style: TextStyle(
                  fontSize: 15,
                  color: AppColors.green,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Campo para escribir el nombre de una categoría nueva o renombrada.
class _NameEditor extends StatelessWidget {
  final TextEditingController controller;
  final String hint;
  final String? error;
  final VoidCallback onSave;
  final VoidCallback onCancel;

  const _NameEditor({
    super.key,
    required this.controller,
    required this.hint,
    required this.onSave,
    required this.onCancel,
    this.error,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: TextField(
              key: const Key('category-name-field'),
              controller: controller,
              autofocus: true,
              maxLength: CategoryProvider.maxLength,
              textCapitalization: TextCapitalization.sentences,
              textInputAction: TextInputAction.done,
              onSubmitted: (_) => onSave(),
              decoration: InputDecoration(
                hintText: hint,
                errorText: error,
                counterText: '',
              ),
            ),
          ),
          IconButton(
            key: const Key('category-save'),
            tooltip: 'Guardar',
            onPressed: onSave,
            icon: Icon(Icons.check_rounded, color: AppColors.green),
          ),
          IconButton(
            key: const Key('category-cancel'),
            tooltip: 'Cancelar',
            onPressed: onCancel,
            icon: Icon(Icons.close_rounded, color: AppColors.text3),
          ),
        ],
      ),
    );
  }
}
