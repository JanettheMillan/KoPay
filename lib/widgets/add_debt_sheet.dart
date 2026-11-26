import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/debt_model.dart';
import '../providers/debt_provider.dart';
import '../utils/app_strings.dart';
import '../utils/format_utils.dart';
import '../utils/validators.dart';
import 'ui_kit.dart';

/// Abre el formulario de deuda. Con [initial] edita esa deuda.
/// Devuelve la deuda guardada, o `null` si se cancela.
Future<DebtModel?> showAddDebtSheet(
  BuildContext context, {
  DebtModel? initial,
}) {
  return showKopaySheet<DebtModel>(context, AddDebtSheet(initial: initial));
}

/// Formulario de deuda (HU-19): nombre, mensualidad, saldo restante y
/// próximo vencimiento. Guarda con [DebtProvider], que pone el estado
/// según el saldo. No se cierra si falta algún dato.
class AddDebtSheet extends StatefulWidget {
  final DebtModel? initial;

  const AddDebtSheet({super.key, this.initial});

  @override
  State<AddDebtSheet> createState() => _AddDebtSheetState();
}

class _AddDebtSheetState extends State<AddDebtSheet> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _name;
  late final TextEditingController _monthly;
  late final TextEditingController _remaining;
  late DateTime _dueDate;

  bool _submitted = false;
  bool _saving = false;

  bool get _isEditing => widget.initial?.id != null;

  @override
  void initState() {
    super.initState();
    final d = widget.initial;
    String money(double? v) => v == null ? '' : v.toStringAsFixed(2);
    _name = TextEditingController(text: d?.name ?? '');
    _monthly = TextEditingController(text: money(d?.monthlyPayment));
    _remaining = TextEditingController(text: money(d?.remainingBalance));
    final now = DateTime.now();
    _dueDate = d?.dueDate ?? DateTime(now.year, now.month + 1, now.day);
  }

  @override
  void dispose() {
    _name.dispose();
    _monthly.dispose();
    _remaining.dispose();
    super.dispose();
  }

  /// Importe que puede ser cero (una deuda ya liquidada), pero no vacío.
  static String? _amountOrZero(String? text) {
    if (text != null && double.tryParse(text.trim()) == 0) return null;
    return Validators.amount(text);
  }

  static double _parse(String text) =>
      double.tryParse(text.trim()) == 0 ? 0 : Validators.parseAmount(text)!;

  Future<void> _chooseDate() async {
    final picked = await pickDate(context, _dueDate);
    if (picked != null) setState(() => _dueDate = picked);
  }

  Future<void> _save() async {
    setState(() => _submitted = true);
    if (!_formKey.currentState!.validate()) return;

    final s = AppStrings.read(context);
    final debt = DebtModel(
      id: widget.initial?.id,
      name: _name.text.trim(),
      monthlyPayment: _parse(_monthly.text),
      remainingBalance: _parse(_remaining.text),
      dueDate: _dueDate,
    );

    setState(() => _saving = true);
    final provider = context.read<DebtProvider>();
    final navigator = Navigator.of(context);
    final messenger = ScaffoldMessenger.of(context);
    try {
      if (_isEditing) {
        await provider.update(debt);
        navigator.pop(provider.byId(debt.id!) ?? debt);
      } else {
        navigator.pop(await provider.add(debt));
      }
    } on ValidationException catch (e) {
      setState(() => _saving = false);
      messenger.showSnackBar(SnackBar(content: Text(e.message)));
    } catch (_) {
      setState(() => _saving = false);
      messenger.showSnackBar(SnackBar(content: Text(s.saveError)));
    }
  }

  Widget _amountField(String key, TextEditingController controller) {
    return TextFormField(
      key: Key(key),
      controller: controller,
      keyboardType: const TextInputType.numberWithOptions(decimal: true),
      textInputAction: TextInputAction.next,
      decoration: const InputDecoration(hintText: '0.00', prefixText: r'$ '),
      validator: _amountOrZero,
    );
  }

  @override
  Widget build(BuildContext context) {
    final s = AppStrings.of(context);
    return KopaySheet(
      title: _isEditing ? s.editDebt : s.newDebt,
      child: Form(
        key: _formKey,
        autovalidateMode: _submitted
            ? AutovalidateMode.onUserInteraction
            : AutovalidateMode.disabled,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            FieldLabel(s.debtName),
            TextFormField(
              key: const Key('debt-name'),
              controller: _name,
              autofocus: !_isEditing,
              textCapitalization: TextCapitalization.sentences,
              textInputAction: TextInputAction.next,
              maxLength: 40,
              decoration: InputDecoration(
                hintText: s.debtNameHint,
                counterText: '',
              ),
              validator: (t) => t == null || t.trim().isEmpty
                  ? Validators.emptyDebtName
                  : null,
            ),
            FieldLabel(s.debtMonthly),
            _amountField('debt-monthly', _monthly),
            FieldLabel(s.debtRemaining),
            _amountField('debt-remaining', _remaining),
            FieldLabel(s.debtDueDate),
            PickerField(
              key: const Key('debt-due-date'),
              value: FormatUtils.fullDate(_dueDate),
              placeholder: '',
              icon: Icons.calendar_today_rounded,
              onTap: _chooseDate,
            ),
            SaveButton(
              key: const Key('debt-save'),
              label: _isEditing ? s.saveChanges : s.save,
              saving: _saving,
              onPressed: _save,
            ),
          ],
        ),
      ),
    );
  }
}
