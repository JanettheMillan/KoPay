import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/debt_model.dart';
import '../providers/debt_provider.dart';
import '../utils/app_colors.dart';
import '../utils/app_strings.dart';
import '../utils/format_utils.dart';
import '../utils/validators.dart';
import '../widgets/add_debt_sheet.dart';
import '../widgets/debts_section.dart';
import '../widgets/pay_sheet.dart';

/// Abre el detalle de la deuda con ese [debtId].
Future<void> openDebtDetail(BuildContext context, int debtId) {
  return Navigator.of(context).push(
    MaterialPageRoute<void>(builder: (_) => DebtDetailScreen(debtId: debtId)),
  );
}

/// Abre el formulario de pago de [debt] (S2-15, HU-20, HU-22).
Future<void> payDebt(BuildContext context, DebtModel debt) async {
  final provider = context.read<DebtProvider>();
  final messenger = ScaffoldMessenger.of(context);
  final s = AppStrings.read(context);
  final saved = await showPaySheet(
    context,
    title: s.payDebt,
    balanceLabel: s.debtRemaining,
    balance: debt.remainingBalance,
    check: Validators.checkDebtPayment,
    onPay: (amount, date, note) =>
        provider.pay(debt.id!, amount, date: date, note: note),
  );
  if (saved != null) {
    messenger.showSnackBar(SnackBar(content: Text(s.paymentSaved)));
  }
}

/// Detalle de una deuda (HU-19): saldo restante, mensualidad, próximo
/// vencimiento y estado, con las acciones Editar y Eliminar, y el pago
/// con su historial (S2-15).
///
/// Escucha [DebtProvider], así que después de editar muestra los datos
/// nuevos. Si la deuda se elimina, la pantalla se cierra.
class DebtDetailScreen extends StatelessWidget {
  final int debtId;

  const DebtDetailScreen({super.key, required this.debtId});

  Future<void> _edit(BuildContext context, DebtModel debt) async {
    final messenger = ScaffoldMessenger.of(context);
    final s = AppStrings.read(context);
    final saved = await showAddDebtSheet(context, initial: debt);
    if (saved != null) {
      messenger.showSnackBar(SnackBar(content: Text(s.debtSaved)));
    }
  }

  /// Pide confirmación. Cancelar conserva la deuda.
  Future<void> _delete(BuildContext context, DebtModel debt) async {
    final provider = context.read<DebtProvider>();
    final navigator = Navigator.of(context);
    final messenger = ScaffoldMessenger.of(context);
    final s = AppStrings.read(context);
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialog) => AlertDialog(
        title: Text(s.deleteDebtTitle),
        content: Text(
          '${AppStrings.fill(s.deleteDebtBody, [debt.name])} ${s.paymentsKept}',
        ),
        actions: [
          TextButton(
            key: const Key('debt-delete-cancel'),
            onPressed: () => Navigator.of(dialog).pop(false),
            child: Text(s.cancel),
          ),
          TextButton(
            key: const Key('debt-delete-confirm'),
            onPressed: () => Navigator.of(dialog).pop(true),
            style: TextButton.styleFrom(foregroundColor: AppColors.red),
            child: Text(s.remove),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    try {
      await provider.delete(debt.id!);
      navigator.pop();
      messenger.showSnackBar(SnackBar(content: Text(s.debtDeleted)));
    } catch (_) {
      messenger.showSnackBar(SnackBar(content: Text(s.removeError)));
    }
  }

  @override
  Widget build(BuildContext context) {
    final s = AppStrings.of(context);
    final debt = context.watch<DebtProvider>().byId(debtId);

    return Scaffold(
      backgroundColor: AppColors.bg,
      appBar: AppBar(
        backgroundColor: AppColors.bg,
        foregroundColor: AppColors.text,
        elevation: 0,
        title: Text(debt?.name ?? s.debtTitle),
        actions: debt == null
            ? null
            : [
                IconButton(
                  key: const Key('debt-edit'),
                  tooltip: s.edit,
                  icon: const Icon(Icons.edit_outlined),
                  onPressed: () => _edit(context, debt),
                ),
                IconButton(
                  key: const Key('debt-delete'),
                  tooltip: s.remove,
                  icon: const Icon(Icons.delete_outline_rounded),
                  onPressed: () => _delete(context, debt),
                ),
              ],
      ),
      body: debt == null
          ? Center(
              child: Text(s.debtGone, style: TextStyle(color: AppColors.text3)),
            )
          : _DebtDetailBody(debt: debt),
    );
  }
}

class _DebtDetailBody extends StatelessWidget {
  final DebtModel debt;

  const _DebtDetailBody({required this.debt});

  @override
  Widget build(BuildContext context) {
    final s = AppStrings.of(context);
    final status = debtStatusLabel(context, debt);

    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
      children: [
        Text(
          s.debtRemaining,
          style: TextStyle(fontSize: 13, color: AppColors.text2),
        ),
        const SizedBox(height: 4),
        Text(
          FormatUtils.money(debt.remainingBalance),
          key: const Key('debt-remaining-value'),
          style: TextStyle(
            fontSize: 32,
            fontWeight: FontWeight.w700,
            color: AppColors.text,
            letterSpacing: -0.8,
          ),
        ),
        const SizedBox(height: 24),
        _DetailRow(
          label: s.debtMonthly,
          value: FormatUtils.money(debt.monthlyPayment),
          valueKey: 'debt-monthly-value',
        ),
        _DetailRow(
          label: s.debtDueDate,
          value: FormatUtils.fullDate(debt.dueDate),
          valueKey: 'debt-due-value',
        ),
        _DetailRow(
          label: s.debtStatus,
          value: status.label,
          valueKey: 'debt-status-value',
          color: status.color,
          isLast: true,
        ),
        Padding(
          padding: const EdgeInsets.only(top: 20),
          child: SizedBox(
            height: 48,
            child: FilledButton.icon(
              key: const Key('debt-pay'),
              onPressed: debt.remainingBalance > 0
                  ? () => payDebt(context, debt)
                  : null,
              icon: const Icon(Icons.payments_outlined, size: 18),
              label: Text(s.recordPayment),
            ),
          ),
        ),
        if (debt.remainingBalance <= 0)
          Padding(
            padding: const EdgeInsets.only(top: 6),
            child: Text(
              s.nothingToPay,
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 12, color: AppColors.text3),
            ),
          ),
        PaymentsList(
          load: () => context.read<DebtProvider>().paymentsOf(debt.id!),
          refreshKey: debt.remainingBalance,
          onCancel: (payment) => cancelPayment(
            context,
            payment: payment,
            onCancel: (id) => context.read<DebtProvider>().cancelPayment(id),
          ),
        ),
      ],
    );
  }
}

class _DetailRow extends StatelessWidget {
  final String label;
  final String value;
  final String valueKey;
  final Color? color;
  final bool isLast;

  const _DetailRow({
    required this.label,
    required this.value,
    required this.valueKey,
    this.color,
    this.isLast = false,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 14),
      decoration: BoxDecoration(
        border: isLast
            ? null
            : Border(bottom: BorderSide(color: AppColors.hair, width: 1)),
      ),
      child: Row(
        children: [
          Expanded(
            child: Text(
              label,
              style: TextStyle(fontSize: 14, color: AppColors.text2),
            ),
          ),
          Text(
            value,
            key: Key(valueKey),
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: color ?? AppColors.text,
            ),
          ),
        ],
      ),
    );
  }
}
