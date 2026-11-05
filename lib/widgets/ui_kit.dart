import 'package:flutter/material.dart';

import '../utils/app_colors.dart';

/// Piezas visuales compartidas por los formularios de KoPay.

/// Abre [child] como hoja inferior que se ajusta al teclado.
Future<T?> showKopaySheet<T>(BuildContext context, Widget child) {
  return showModalBottomSheet<T>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    builder: (_) => child,
  );
}

/// Contenedor de una hoja inferior: esquinas redondeadas, asa, título y
/// espacio para el teclado.
class KopaySheet extends StatelessWidget {
  final String title;
  final Widget child;

  const KopaySheet({super.key, required this.title, required this.child});

  @override
  Widget build(BuildContext context) {
    final keyboard = MediaQuery.of(context).viewInsets.bottom;
    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      ),
      padding: EdgeInsets.only(bottom: keyboard),
      child: SafeArea(
        top: false,
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 10, 20, 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Center(
                child: Container(
                  width: 36,
                  height: 4,
                  decoration: BoxDecoration(
                    color: AppColors.hair2,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 18),
              Text(
                title,
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w600,
                  color: AppColors.text,
                  letterSpacing: -0.4,
                ),
              ),
              const SizedBox(height: 18),
              child,
            ],
          ),
        ),
      ),
    );
  }
}

/// Etiqueta pequeña encima de un campo.
class FieldLabel extends StatelessWidget {
  final String text;

  const FieldLabel(this.text, {super.key});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6, left: 2, top: 14),
      child: Text(
        text.toUpperCase(),
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w500,
          color: AppColors.text3,
          letterSpacing: 1.1,
        ),
      ),
    );
  }
}

/// Campo que se toca para elegir un valor (categoría, fecha) y que
/// puede mostrar un error de validación debajo.
class PickerField extends StatelessWidget {
  final String? value;
  final String placeholder;
  final IconData icon;
  final VoidCallback onTap;
  final String? errorText;

  const PickerField({
    super.key,
    required this.value,
    required this.placeholder,
    required this.icon,
    required this.onTap,
    this.errorText,
  });

  @override
  Widget build(BuildContext context) {
    final hasError = errorText != null;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Material(
          color: AppColors.surfaceHi,
          borderRadius: BorderRadius.circular(12),
          child: InkWell(
            onTap: onTap,
            borderRadius: BorderRadius.circular(12),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(12),
                border: hasError
                    ? Border.all(color: AppColors.red, width: 1.2)
                    : null,
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      value ?? placeholder,
                      style: TextStyle(
                        fontSize: 15,
                        color: value == null ? AppColors.text3 : AppColors.text,
                      ),
                    ),
                  ),
                  Icon(icon, size: 20, color: AppColors.text2),
                ],
              ),
            ),
          ),
        ),
        if (hasError)
          Padding(
            padding: const EdgeInsets.only(top: 6, left: 16),
            child: Text(
              errorText!,
              style: TextStyle(fontSize: 12, color: AppColors.red),
            ),
          ),
      ],
    );
  }
}

/// Selector de dos opciones, por ejemplo Gasto / Entrada.
class TwoOptionToggle extends StatelessWidget {
  final String left;
  final String right;
  final bool leftSelected;
  final ValueChanged<bool> onChanged;
  final Color leftColor;
  final Color rightColor;

  const TwoOptionToggle({
    super.key,
    required this.left,
    required this.right,
    required this.leftSelected,
    required this.onChanged,
    required this.leftColor,
    required this.rightColor,
  });

  @override
  Widget build(BuildContext context) {
    Widget option(String label, bool selected, Color color, bool isLeft) {
      return Expanded(
        child: GestureDetector(
          key: Key('toggle-$label'),
          behavior: HitTestBehavior.opaque,
          onTap: () => onChanged(isLeft),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 150),
            padding: const EdgeInsets.symmetric(vertical: 10),
            decoration: BoxDecoration(
              color: selected ? color.withValues(alpha: 0.15) : null,
              borderRadius: BorderRadius.circular(10),
            ),
            alignment: Alignment.center,
            child: Text(
              label,
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: selected ? color : AppColors.text2,
              ),
            ),
          ),
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: AppColors.surfaceHi,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          option(left, leftSelected, leftColor, true),
          option(right, !leftSelected, rightColor, false),
        ],
      ),
    );
  }
}

/// Botón principal de guardar, con indicador mientras se guarda.
class SaveButton extends StatelessWidget {
  final String label;
  final bool saving;
  final VoidCallback onPressed;

  const SaveButton({
    super.key,
    required this.label,
    required this.saving,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 24),
      child: SizedBox(
        height: 50,
        child: FilledButton(
          onPressed: saving ? null : onPressed,
          child: saving
              ? const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : Text(label),
        ),
      ),
    );
  }
}

/// Abre el calendario y devuelve solo la fecha (sin hora).
Future<DateTime?> pickDate(BuildContext context, DateTime initial) async {
  final now = DateTime.now();
  final picked = await showDatePicker(
    context: context,
    initialDate: initial,
    firstDate: DateTime(2000),
    lastDate: DateTime(now.year + 1, 12, 31),
  );
  return picked == null
      ? null
      : DateTime(picked.year, picked.month, picked.day);
}
