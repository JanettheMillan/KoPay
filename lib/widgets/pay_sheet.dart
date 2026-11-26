import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/movement_model.dart';
import '../providers/movement_provider.dart';
import '../utils/app_colors.dart';
import '../utils/app_strings.dart';
import '../utils/format_utils.dart';
import '../utils/validators.dart';
import 'ui_kit.dart';

/// Guarda el pago y devuelve el movimiento creado. Lo arma quien abre la
/// hoja con `CardProvider.pay` o `DebtProvider.pay`.
typedef PayAction =
    Future<Movement> Function(double amount, DateTime date, String? note);

/// Abre el formulario de pago (S2-15). Devuelve el movimiento guardado o
/// `null` si se cancela.
///
/// [balance] es el máximo que se puede pagar (saldo usado de la tarjeta o
/// saldo restante de la deuda) y [check] lo valida igual que el provider.
/// Al guardar, recarga [MovementProvider] para que el pago aparezca en
/// Movimientos e Inicio (HU-16, HU-20).
Future<Movement?> showPaySheet(
  BuildContext context, {
  required String title,
  required String balanceLabel,
  required double balance,
  required String? Function(double amount, double balance) check,
  required PayAction onPay,
}) {
  return showKopaySheet<Movement>(
    context,
    PaySheet(
      title: title,
      balanceLabel: balanceLabel,
      balance: balance,
      check: check,
      onPay: onPay,
    ),
  );
}

/// Formulario de pago: monto (con "Pagar todo"), fecha y nota. Un monto
/// vacío, cero, no numérico o mayor que [balance] no se guarda (HU-17,
/// HU-22).
class PaySheet extends StatefulWidget {
  final String title;
  final String balanceLabel;
  final double balance;
  final String? Function(double amount, double balance) check;
  final PayAction onPay;

  const PaySheet({
    super.key,
    required this.title,
    required this.balanceLabel,
    required this.balance,
    required this.check,
    required this.onPay,
  });

  @override
  State<PaySheet> createState() => _PaySheetState();
}

class _PaySheetState extends State<PaySheet> {
  final _formKey = GlobalKey<FormState>();
  final _amount = TextEditingController();
  final _note = TextEditingController();
  late DateTime _date;
  bool _submitted = false;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    _date = DateTime(now.year, now.month, now.day);
  }

  @override
  void dispose() {
    _amount.dispose();
    _note.dispose();
    super.dispose();
  }

  String? _validateAmount(String? text) {
    final format = Validators.amount(text);
    if (format != null) return format;
    return widget.check(Validators.parseAmount(text)!, widget.balance);
  }

  Future<void> _chooseDate() async {
    final picked = await pickDate(context, _date);
    if (picked != null) setState(() => _date = picked);
  }

  Future<void> _save() async {
    setState(() => _submitted = true);
    if (!_formKey.currentState!.validate()) return;

    final s = AppStrings.read(context);
    final movements = context.read<MovementProvider?>();
    final navigator = Navigator.of(context);
    final messenger = ScaffoldMessenger.of(context);
    setState(() => _saving = true);
    try {
      final note = _note.text.trim();
      final payment = await widget.onPay(
        Validators.parseAmount(_amount.text)!,
        _date,
        note.isEmpty ? null : note,
      );
      await movements?.load();
      navigator.pop(payment);
    } on ValidationException catch (e) {
      setState(() => _saving = false);
      messenger.showSnackBar(SnackBar(content: Text(e.message)));
    } catch (_) {
      setState(() => _saving = false);
      messenger.showSnackBar(SnackBar(content: Text(s.saveError)));
    }
  }

  @override
  Widget build(BuildContext context) {
    final s = AppStrings.of(context);
    return KopaySheet(
      title: widget.title,
      child: Form(
        key: _formKey,
        autovalidateMode: _submitted
            ? AutovalidateMode.onUserInteraction
            : AutovalidateMode.disabled,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                color: AppColors.surfaceHi,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      widget.balanceLabel,
                      style: TextStyle(fontSize: 14, color: AppColors.text2),
                    ),
                  ),
                  Text(
                    FormatUtils.money(widget.balance),
                    key: const Key('pay-balance'),
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                      color: AppColors.text,
                    ),
                  ),
                ],
              ),
            ),
            Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Expanded(child: FieldLabel(s.payAmount)),
                TextButton(
                  key: const Key('pay-all'),
                  onPressed: _saving
                      ? null
                      : () => setState(
                          () =>
                              _amount.text = widget.balance.toStringAsFixed(2),
                        ),
                  child: Text(s.payAll),
                ),
              ],
            ),
            TextFormField(
              key: const Key('pay-amount'),
              controller: _amount,
              autofocus: true,
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
              decoration: const InputDecoration(
                hintText: '0.00',
                prefixText: r'$ ',
              ),
              validator: _validateAmount,
            ),
            FieldLabel(s.payDate),
            PickerField(
              key: const Key('pay-date'),
              value: FormatUtils.fullDate(_date),
              placeholder: '',
              icon: Icons.calendar_today_rounded,
              onTap: _chooseDate,
            ),
            FieldLabel(s.payNote),
            TextFormField(
              key: const Key('pay-note'),
              controller: _note,
              maxLength: 140,
              decoration: const InputDecoration(counterText: ''),
            ),
            SaveButton(
              key: const Key('pay-save'),
              label: s.recordPayment,
              saving: _saving,
              onPressed: _save,
            ),
          ],
        ),
      ),
    );
  }
}

/// Pide confirmación para anular un pago (D-10). Devuelve `true` si se
/// confirma; cancelar no cambia nada.
Future<bool> confirmCancelPayment(BuildContext context) async {
  final s = AppStrings.read(context);
  final confirmed = await showDialog<bool>(
    context: context,
    builder: (dialog) => AlertDialog(
      title: Text(s.cancelPaymentTitle),
      content: Text(s.cancelPaymentBody),
      actions: [
        TextButton(
          key: const Key('cancel-payment-dismiss'),
          onPressed: () => Navigator.of(dialog).pop(false),
          child: Text(s.cancel),
        ),
        TextButton(
          key: const Key('cancel-payment-confirm'),
          onPressed: () => Navigator.of(dialog).pop(true),
          style: TextButton.styleFrom(foregroundColor: AppColors.red),
          child: Text(s.cancelPayment),
        ),
      ],
    ),
  );
  return confirmed == true;
}

/// Pide confirmación y anula el pago [payment] (D-10, HU-16, HU-06).
///
/// [onCancel] borra el pago y recarga su tarjeta o deuda; después se
/// recarga [MovementProvider] para que el pago desaparezca de Movimientos
/// e Inicio. Cancelar la confirmación no cambia nada.
Future<void> cancelPayment(
  BuildContext context, {
  required Movement payment,
  required Future<void> Function(int paymentId) onCancel,
}) async {
  final movements = context.read<MovementProvider?>();
  final messenger = ScaffoldMessenger.of(context);
  final s = AppStrings.read(context);
  if (!await confirmCancelPayment(context)) return;
  try {
    await onCancel(payment.id!);
    await movements?.load();
    messenger.showSnackBar(SnackBar(content: Text(s.paymentCanceled)));
  } catch (_) {
    messenger.showSnackBar(SnackBar(content: Text(s.cancelPaymentError)));
  }
}

/// Pagos registrados a una tarjeta o deuda, del más reciente al más
/// antiguo. [refreshKey] cambia cuando cambia el saldo, para volver a
/// leerlos después de un pago o de anularlo.
///
/// Con [onCancel] cada pago muestra **Anular pago** (D-10).
class PaymentsList extends StatelessWidget {
  final Future<List<Movement>> Function() load;
  final Object refreshKey;
  final Future<void> Function(Movement payment)? onCancel;

  const PaymentsList({
    super.key,
    required this.load,
    required this.refreshKey,
    this.onCancel,
  });

  @override
  Widget build(BuildContext context) {
    final s = AppStrings.of(context);
    return FutureBuilder<List<Movement>>(
      key: ValueKey(refreshKey),
      future: load(),
      builder: (context, snapshot) {
        final payments = snapshot.data ?? const <Movement>[];
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.only(top: 24, bottom: 4),
              child: Text(
                s.paymentsHeader,
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: AppColors.text3,
                  letterSpacing: 1.2,
                ),
              ),
            ),
            if (snapshot.connectionState == ConnectionState.done &&
                payments.isEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 8),
                child: Text(
                  s.noPayments,
                  key: const Key('payments-empty'),
                  style: TextStyle(fontSize: 13, color: AppColors.text3),
                ),
              ),
            for (var i = 0; i < payments.length; i++)
              Container(
                key: Key('payment-row-$i'),
                padding: const EdgeInsets.symmetric(vertical: 12),
                decoration: BoxDecoration(
                  border: i == payments.length - 1
                      ? null
                      : Border(
                          bottom: BorderSide(color: AppColors.hair, width: 1),
                        ),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        payments[i].note == null
                            ? FormatUtils.fullDate(payments[i].date)
                            : '${FormatUtils.fullDate(payments[i].date)} · '
                                  '${payments[i].note}',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(fontSize: 13, color: AppColors.text2),
                      ),
                    ),
                    Text(
                      FormatUtils.money(payments[i].absAmount),
                      style: TextStyle(fontSize: 14, color: AppColors.text),
                    ),
                    if (onCancel != null)
                      IconButton(
                        key: Key('payment-cancel-$i'),
                        tooltip: s.cancelPayment,
                        visualDensity: VisualDensity.compact,
                        icon: Icon(
                          Icons.undo_rounded,
                          size: 18,
                          color: AppColors.text3,
                        ),
                        onPressed: () => onCancel!(payments[i]),
                      ),
                  ],
                ),
              ),
          ],
        );
      },
    );
  }
}
