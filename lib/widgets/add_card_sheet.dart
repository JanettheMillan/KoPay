import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../models/card_model.dart';
import '../providers/card_provider.dart';
import '../utils/validators.dart';
import 'ui_kit.dart';

/// Abre el formulario de tarjeta. Con [initial] edita esa tarjeta.
/// Devuelve la tarjeta guardada, o `null` si se cancela.
Future<CardModel?> showAddCardSheet(
  BuildContext context, {
  CardModel? initial,
}) {
  return showKopaySheet<CardModel>(context, AddCardSheet(initial: initial));
}

/// Formulario de tarjeta (HU-13, HU-14): nombre, banco, límite, saldo
/// usado, días de corte y de pago, y pago mínimo. Guarda con
/// [CardProvider]; no se cierra si falta algún dato.
class AddCardSheet extends StatefulWidget {
  final CardModel? initial;

  const AddCardSheet({super.key, this.initial});

  @override
  State<AddCardSheet> createState() => _AddCardSheetState();
}

class _AddCardSheetState extends State<AddCardSheet> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _name;
  late final TextEditingController _bank;
  late final TextEditingController _limit;
  late final TextEditingController _used;
  late final TextEditingController _cutDay;
  late final TextEditingController _paymentDay;
  late final TextEditingController _minimum;

  bool _submitted = false;
  bool _saving = false;

  bool get _isEditing => widget.initial?.id != null;

  @override
  void initState() {
    super.initState();
    final c = widget.initial;
    String money(double? v) => v == null ? '' : v.toStringAsFixed(2);
    _name = TextEditingController(text: c?.name ?? '');
    _bank = TextEditingController(text: c?.bank ?? '');
    _limit = TextEditingController(text: money(c?.creditLimit));
    _used = TextEditingController(text: money(c?.usedBalance));
    _cutDay = TextEditingController(text: c?.cutDay.toString() ?? '');
    _paymentDay = TextEditingController(text: c?.paymentDay.toString() ?? '');
    _minimum = TextEditingController(text: money(c?.minimumPayment));
  }

  @override
  void dispose() {
    for (final c in [
      _name,
      _bank,
      _limit,
      _used,
      _cutDay,
      _paymentDay,
      _minimum,
    ]) {
      c.dispose();
    }
    super.dispose();
  }

  static String? _requiredText(String? text, String message) =>
      text == null || text.trim().isEmpty ? message : null;

  /// Importe opcional: vacío o cero valen como cero.
  static String? _optionalAmount(String? text) {
    if (text == null || text.trim().isEmpty) return null;
    if (double.tryParse(text.trim()) == 0) return null;
    return Validators.amount(text);
  }

  static double _parseOptional(String text) =>
      text.trim().isEmpty ? 0 : (Validators.parseAmount(text) ?? 0);

  static String? _day(String? text) {
    final day = int.tryParse(text?.trim() ?? '');
    return day == null || day < 1 || day > 31 ? Validators.invalidDay : null;
  }

  Future<void> _save() async {
    setState(() => _submitted = true);
    if (!_formKey.currentState!.validate()) return;

    final card = CardModel(
      id: widget.initial?.id,
      name: _name.text.trim(),
      bank: _bank.text.trim(),
      creditLimit: Validators.parseAmount(_limit.text)!,
      usedBalance: _parseOptional(_used.text),
      cutDay: int.parse(_cutDay.text.trim()),
      paymentDay: int.parse(_paymentDay.text.trim()),
      minimumPayment: _parseOptional(_minimum.text),
    );

    setState(() => _saving = true);
    final provider = context.read<CardProvider>();
    final navigator = Navigator.of(context);
    final messenger = ScaffoldMessenger.of(context);
    try {
      if (_isEditing) {
        await provider.update(card);
        navigator.pop(card);
      } else {
        navigator.pop(await provider.add(card));
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

  Widget _amountField(
    String key,
    TextEditingController controller,
    String? Function(String?) validator,
  ) {
    return TextFormField(
      key: Key(key),
      controller: controller,
      keyboardType: const TextInputType.numberWithOptions(decimal: true),
      textInputAction: TextInputAction.next,
      decoration: const InputDecoration(hintText: '0.00', prefixText: r'$ '),
      validator: validator,
    );
  }

  Widget _dayField(String key, TextEditingController controller) {
    return TextFormField(
      key: Key(key),
      controller: controller,
      keyboardType: TextInputType.number,
      textInputAction: TextInputAction.next,
      inputFormatters: [
        FilteringTextInputFormatter.digitsOnly,
        LengthLimitingTextInputFormatter(2),
      ],
      decoration: const InputDecoration(hintText: '1 a 31'),
      validator: _day,
    );
  }

  @override
  Widget build(BuildContext context) {
    return KopaySheet(
      title: _isEditing ? 'Editar tarjeta' : 'Nueva tarjeta',
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
              key: const Key('card-name'),
              controller: _name,
              autofocus: !_isEditing,
              textCapitalization: TextCapitalization.sentences,
              textInputAction: TextInputAction.next,
              maxLength: 40,
              decoration: const InputDecoration(
                hintText: 'Ej. Oro, Clásica',
                counterText: '',
              ),
              validator: (t) => _requiredText(t, Validators.emptyCardName),
            ),
            const FieldLabel('Banco'),
            TextFormField(
              key: const Key('card-bank'),
              controller: _bank,
              textCapitalization: TextCapitalization.words,
              textInputAction: TextInputAction.next,
              maxLength: 40,
              decoration: const InputDecoration(
                hintText: 'Ej. BBVA',
                counterText: '',
              ),
              validator: (t) => _requiredText(t, Validators.emptyBank),
            ),
            const FieldLabel('Límite de crédito'),
            _amountField('card-limit', _limit, Validators.amount),
            const FieldLabel('Saldo usado'),
            _amountField('card-used', _used, _optionalAmount),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      const FieldLabel('Día de corte'),
                      _dayField('card-cut-day', _cutDay),
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      const FieldLabel('Día de pago'),
                      _dayField('card-payment-day', _paymentDay),
                    ],
                  ),
                ),
              ],
            ),
            const FieldLabel('Pago mínimo (opcional)'),
            _amountField('card-minimum', _minimum, _optionalAmount),
            SaveButton(
              key: const Key('card-save'),
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
