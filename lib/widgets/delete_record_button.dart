import 'package:flutter/material.dart';

import '../utils/app_colors.dart';
import '../utils/app_strings.dart';

/// Botón "Eliminar" de las hojas de edición de movimiento e ingreso
/// (#185, HU-06). Pide confirmación: Cancelar conserva el registro y
/// Eliminar llama a [onConfirmed], que borra, cierra la hoja y avisa.
class DeleteRecordButton extends StatelessWidget {
  /// Prefijo de las llaves: `<prefix>-delete`, `-delete-cancel` y
  /// `-delete-confirm` (por ejemplo `movement`).
  final String keyPrefix;
  final String label;
  final String title;

  /// Nombre del registro que se muestra en el diálogo.
  final String recordName;
  final bool enabled;
  final Future<void> Function() onConfirmed;

  const DeleteRecordButton({
    super.key,
    required this.keyPrefix,
    required this.label,
    required this.title,
    required this.recordName,
    required this.onConfirmed,
    this.enabled = true,
  });

  Future<void> _confirm(BuildContext context) async {
    final s = AppStrings.read(context);
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialog) => AlertDialog(
        title: Text(title),
        content: Text(AppStrings.fill(s.deleteRecordBody, [recordName])),
        actions: [
          TextButton(
            key: Key('$keyPrefix-delete-cancel'),
            onPressed: () => Navigator.of(dialog).pop(false),
            child: Text(s.cancel),
          ),
          TextButton(
            key: Key('$keyPrefix-delete-confirm'),
            onPressed: () => Navigator.of(dialog).pop(true),
            style: TextButton.styleFrom(foregroundColor: AppColors.red),
            child: Text(s.remove),
          ),
        ],
      ),
    );
    if (confirmed == true) await onConfirmed();
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 8),
      child: TextButton.icon(
        key: Key('$keyPrefix-delete'),
        onPressed: enabled ? () => _confirm(context) : null,
        style: TextButton.styleFrom(foregroundColor: AppColors.red),
        icon: const Icon(Icons.delete_outline_rounded, size: 18),
        label: Text(label),
      ),
    );
  }
}
