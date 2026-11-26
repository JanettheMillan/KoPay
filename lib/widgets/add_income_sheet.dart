import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/income_model.dart';
import '../providers/income_provider.dart';
import '../services/auth_api.dart';
import '../utils/app_colors.dart';
import '../utils/app_strings.dart';
import '../utils/format_utils.dart';
import '../utils/validators.dart';
import 'delete_record_button.dart';
import 'ui_kit.dart';

/// Abre el formulario de ingreso. Con [initial] edita ese registro.
/// Devuelve el ingreso guardado, o `null` si se cancela.
Future<Income?> showAddIncomeSheet(BuildContext context, {Income? initial}) {
  return showKopaySheet<Income>(context, AddIncomeSheet(initial: initial));
}

/// Formulario con nombre, monto, fecha y nota. Valida con [Validators]
/// y guarda con [IncomeProvider]; no se cierra si falta algún dato.
class AddIncomeSheet extends StatefulWidget {
  final Income? initial;

  const AddIncomeSheet({super.key, this.initial});

  @override
  State<AddIncomeSheet> createState() => _AddIncomeSheetState();
}

class _AddIncomeSheetState extends State<AddIncomeSheet> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _name;
  late final TextEditingController _amount;
  late final TextEditingController _note;
  late DateTime _date;

  bool _submitted = false;
  bool _saving = false;

  bool get _isEditing => widget.initial?.id != null;

  @override
  void initState() {
    super.initState();
    final i = widget.initial;
    _name = TextEditingController(text: i?.name ?? '');
    _amount = TextEditingController(
      text: i == null ? '' : i.amount.toStringAsFixed(2),
    );
    _note = TextEditingController(text: i?.note ?? '');
    final now = DateTime.now();
    _date = i?.date ?? DateTime(now.year, now.month, now.day);
  }

  @override
  void dispose() {
    _name.dispose();
    _amount.dispose();
    _note.dispose();
    super.dispose();
  }

  Future<void> _chooseDate() async {
    final picked = await pickDate(context, _date);
    if (picked != null) setState(() => _date = picked);
  }

  /// Borra el ingreso en edición (#185, HU-06), cierra la hoja y avisa.
  Future<void> _delete() async {
    final s = AppStrings.read(context);
    final provider = context.read<IncomeProvider>();
    final navigator = Navigator.of(context);
    final messenger = ScaffoldMessenger.of(context);
    setState(() => _saving = true);
    try {
      await provider.delete(widget.initial!.id!);
      navigator.pop();
      messenger.showSnackBar(SnackBar(content: Text(s.incomeDeleted)));
    } on ApiException catch (e) {
      setState(() => _saving = false);
      messenger.showSnackBar(SnackBar(content: Text(e.displayMessage)));
    } on NetworkException {
      setState(() => _saving = false);
      messenger.showSnackBar(
        const SnackBar(content: Text(NetworkException.message)),
      );
    } catch (_) {
      setState(() => _saving = false);
      messenger.showSnackBar(SnackBar(content: Text(s.removeError)));
    }
  }

  Future<void> _save() async {
    setState(() => _submitted = true);
    if (!_formKey.currentState!.validate()) return;

    final note = _note.text.trim();
    final income = Income(
      id: widget.initial?.id,
      name: _name.text.trim(),
      amount: Validators.parseAmount(_amount.text)!,
      date: _date,
      note: note.isEmpty ? null : note,
    );

    setState(() => _saving = true);
    final provider = context.read<IncomeProvider>();
    final navigator = Navigator.of(context);
    final messenger = ScaffoldMessenger.of(context);
    try {
      if (_isEditing) {
        await provider.update(income);
        navigator.pop(income);
      } else {
        navigator.pop(await provider.add(income));
      }
    } on ValidationException catch (e) {
      setState(() => _saving = false);
      messenger.showSnackBar(SnackBar(content: Text(e.message)));
    } on ApiException catch (e) {
      // S5-08: mensaje de la API, por ejemplo el de un campo o el de
      // 409 VERSION_CONFLICT (la lista ya se recargó).
      setState(() => _saving = false);
      messenger.showSnackBar(SnackBar(content: Text(e.displayMessage)));
    } on NetworkException {
      setState(() => _saving = false);
      messenger.showSnackBar(
        const SnackBar(content: Text(NetworkException.message)),
      );
    } catch (_) {
      setState(() => _saving = false);
      messenger.showSnackBar(
        const SnackBar(content: Text('No se pudo guardar. Intenta de nuevo.')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return KopaySheet(
      title: _isEditing ? 'Editar ingreso' : 'Nuevo ingreso',
      child: Form(
        key: _formKey,
        autovalidateMode: _submitted
            ? AutovalidateMode.onUserInteraction
            : AutovalidateMode.disabled,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const FieldLabel('Nombre'),
            TextFormField(
              key: const Key('income-name'),
              controller: _name,
              autofocus: !_isEditing,
              textCapitalization: TextCapitalization.sentences,
              textInputAction: TextInputAction.next,
              maxLength: 60,
              decoration: const InputDecoration(
                hintText: 'Ej. Salario, bono, venta',
                counterText: '',
              ),
              validator: Validators.incomeName,
            ),
            const FieldLabel('Monto'),
            TextFormField(
              key: const Key('income-amount'),
              controller: _amount,
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
              textInputAction: TextInputAction.next,
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.w600,
                color: AppColors.green,
              ),
              decoration: const InputDecoration(
                hintText: '0.00',
                prefixText: r'+ $ ',
              ),
              validator: Validators.amount,
            ),
            const FieldLabel('Fecha'),
            PickerField(
              key: const Key('income-date'),
              value: FormatUtils.fullDate(_date),
              placeholder: '',
              icon: Icons.calendar_today_rounded,
              onTap: _chooseDate,
            ),
            const FieldLabel('Nota (opcional)'),
            TextFormField(
              key: const Key('income-note'),
              controller: _note,
              maxLines: 2,
              maxLength: 140,
              decoration: const InputDecoration(
                hintText: 'Algo que quieras recordar',
                counterText: '',
              ),
            ),
            SaveButton(
              key: const Key('income-save'),
              label: _isEditing ? 'Guardar cambios' : 'Guardar',
              saving: _saving,
              onPressed: _save,
            ),
            if (_isEditing)
              DeleteRecordButton(
                keyPrefix: 'income',
                label: AppStrings.of(context).deleteIncome,
                title: AppStrings.of(context).deleteIncomeTitle,
                recordName: widget.initial!.name,
                enabled: !_saving,
                onConfirmed: _delete,
              ),
          ],
        ),
      ),
    );
  }
}
