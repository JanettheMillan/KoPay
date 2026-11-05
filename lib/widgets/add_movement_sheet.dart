import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/movement_model.dart';
import '../providers/movement_provider.dart';
import '../utils/app_colors.dart';
import '../utils/format_utils.dart';
import '../utils/validators.dart';
import 'category_picker_sheet.dart';
import 'ui_kit.dart';

/// Abre el formulario de gasto o movimiento. Con [initial] edita ese
/// registro. Devuelve el movimiento guardado, o `null` si se cancela.
Future<Movement?> showAddMovementSheet(
  BuildContext context, {
  Movement? initial,
}) {
  return showKopaySheet<Movement>(context, AddMovementSheet(initial: initial));
}

/// Formulario con monto, tipo (gasto o entrada), descripción, categoría,
/// fecha y nota. Valida con [Validators] y guarda con [MovementProvider].
class AddMovementSheet extends StatefulWidget {
  final Movement? initial;

  const AddMovementSheet({super.key, this.initial});

  @override
  State<AddMovementSheet> createState() => _AddMovementSheetState();
}

class _AddMovementSheetState extends State<AddMovementSheet> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _amount;
  late final TextEditingController _description;
  late final TextEditingController _note;

  late bool _isExpense;
  String? _category;
  late DateTime _date;

  bool _submitted = false;
  bool _saving = false;

  bool get _isEditing => widget.initial?.id != null;

  @override
  void initState() {
    super.initState();
    final m = widget.initial;
    _amount = TextEditingController(
      text: m == null ? '' : m.absAmount.toStringAsFixed(2),
    );
    _description = TextEditingController(text: m?.description ?? '');
    _note = TextEditingController(text: m?.note ?? '');
    _isExpense = m?.isExpense ?? true;
    _category = m?.category;
    final now = DateTime.now();
    _date = m?.date ?? DateTime(now.year, now.month, now.day);
  }

  @override
  void dispose() {
    _amount.dispose();
    _description.dispose();
    _note.dispose();
    super.dispose();
  }

  String? get _categoryError =>
      _submitted ? Validators.category(_category) : null;

  Future<void> _chooseCategory() async {
    final picked = await showCategoryPicker(context, selected: _category);
    if (picked != null) setState(() => _category = picked);
  }

  Future<void> _chooseDate() async {
    final picked = await pickDate(context, _date);
    if (picked != null) setState(() => _date = picked);
  }

  Future<void> _save() async {
    setState(() => _submitted = true);
    final fieldsOk = _formKey.currentState!.validate();
    if (!fieldsOk || _categoryError != null) return;

    final note = _note.text.trim();
    final movement = Movement(
      id: widget.initial?.id,
      amount: Validators.signedAmount(
        Validators.parseAmount(_amount.text)!,
        isExpense: _isExpense,
      ),
      description: _description.text.trim(),
      category: _category!,
      date: _date,
      note: note.isEmpty ? null : note,
    );

    setState(() => _saving = true);
    final provider = context.read<MovementProvider>();
    final navigator = Navigator.of(context);
    final messenger = ScaffoldMessenger.of(context);
    try {
      if (_isEditing) {
        await provider.update(movement);
        navigator.pop(movement);
      } else {
        navigator.pop(await provider.add(movement));
      }
    } on ValidationException catch (e) {
      setState(() => _saving = false);
      messenger.showSnackBar(SnackBar(content: Text(e.message)));
    } catch (_) {
      setState(() => _saving = false);
      messenger.showSnackBar(
        const SnackBar(content: Text('No se pudo guardar. Intenta de nuevo.')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final title = _isEditing
        ? 'Editar movimiento'
        : (_isExpense ? 'Nuevo gasto' : 'Nueva entrada');

    return KopaySheet(
      title: title,
      child: Form(
        key: _formKey,
        autovalidateMode: _submitted
            ? AutovalidateMode.onUserInteraction
            : AutovalidateMode.disabled,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            TwoOptionToggle(
              key: const Key('movement-type'),
              left: 'Gasto',
              right: 'Entrada',
              leftSelected: _isExpense,
              leftColor: AppColors.red,
              rightColor: AppColors.green,
              onChanged: (expense) => setState(() => _isExpense = expense),
            ),
            const FieldLabel('Monto'),
            TextFormField(
              key: const Key('movement-amount'),
              controller: _amount,
              autofocus: !_isEditing,
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
              textInputAction: TextInputAction.next,
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.w600,
                color: _isExpense ? AppColors.text : AppColors.green,
              ),
              decoration: InputDecoration(
                hintText: '0.00',
                prefixText: _isExpense ? r'− $ ' : r'+ $ ',
              ),
              validator: Validators.amount,
            ),
            const FieldLabel('Descripción'),
            TextFormField(
              key: const Key('movement-description'),
              controller: _description,
              textCapitalization: TextCapitalization.sentences,
              textInputAction: TextInputAction.next,
              maxLength: 60,
              decoration: const InputDecoration(
                hintText: 'Ej. Súper, gasolina, cine',
                counterText: '',
              ),
              validator: Validators.description,
            ),
            const FieldLabel('Categoría'),
            PickerField(
              key: const Key('movement-category'),
              value: _category == null
                  ? null
                  : '${categoryEmoji(_category!)}  $_category',
              placeholder: 'Seleccionar',
              icon: Icons.expand_more_rounded,
              errorText: _categoryError,
              onTap: _chooseCategory,
            ),
            const FieldLabel('Fecha'),
            PickerField(
              key: const Key('movement-date'),
              value: FormatUtils.fullDate(_date),
              placeholder: '',
              icon: Icons.calendar_today_rounded,
              onTap: _chooseDate,
            ),
            const FieldLabel('Nota (opcional)'),
            TextFormField(
              key: const Key('movement-note'),
              controller: _note,
              maxLines: 2,
              maxLength: 140,
              decoration: const InputDecoration(
                hintText: 'Algo que quieras recordar',
                counterText: '',
              ),
            ),
            SaveButton(
              key: const Key('movement-save'),
              label: _isEditing ? 'Guardar cambios' : 'Guardar',
              saving: _saving,
              onPressed: _save,
            ),
          ],
        ),
      ),
    );
  }
}
