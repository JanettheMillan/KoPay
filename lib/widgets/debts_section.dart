import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/debt_model.dart';
import '../providers/debt_provider.dart';
import '../screens/debt_detail_screen.dart';
import '../utils/app_colors.dart';
import '../utils/app_strings.dart';
import '../utils/format_utils.dart';
import 'add_debt_sheet.dart';

/// Estado que se muestra de una deuda: pagada, vencida (pendiente con
/// fecha anterior a [today]) o pendiente.
({String label, Color color}) debtStatusLabel(
  BuildContext context,
  DebtModel debt, {
  DateTime? today,
}) {
  final s = AppStrings.of(context);
  if (debt.isPaid) return (label: s.debtPaid, color: AppColors.green);
  final now = today ?? DateTime.now();
  final day = DateTime(now.year, now.month, now.day);
  if (debt.dueDate.isBefore(day)) {
    return (label: s.debtOverdue, color: AppColors.red);
  }
  return (label: s.debtPending, color: AppColors.text2);
}

/// Sección de deudas de Inicio (HU-19): lista las deudas de la que vence
/// antes a la que vence después, con saldo, vencimiento y estado. Tocar
/// una abre su detalle. Si no hay [DebtProvider] en el árbol, no muestra
/// nada.
class DebtsSection extends StatelessWidget {
  const DebtsSection({super.key});

  Future<void> _add(BuildContext context) async {
    final messenger = ScaffoldMessenger.of(context);
    final saved = await showAddDebtSheet(context);
    if (saved != null && context.mounted) {
      messenger.showSnackBar(
        SnackBar(content: Text(AppStrings.read(context).debtSaved)),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<DebtProvider?>();
    if (provider == null) return const SizedBox.shrink();
    final s = AppStrings.of(context);
    final debts = provider.debts;

    return Padding(
      key: const Key('home-debts'),
      // Espacio abajo para que el botón + no tape la última fila.
      padding: const EdgeInsets.fromLTRB(20, 24, 20, 72),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 3,
                height: 14,
                decoration: BoxDecoration(
                  color: AppColors.red,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  s.debtsHeader,
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    color: AppColors.text,
                    letterSpacing: -0.2,
                  ),
                ),
              ),
              TextButton.icon(
                key: const Key('debts-add'),
                onPressed: () => _add(context),
                icon: const Icon(Icons.add_rounded, size: 18),
                label: Text(s.addDebt),
              ),
            ],
          ),
          if (debts.isEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Text(
                s.noDebts,
                key: const Key('debts-empty'),
                style: TextStyle(fontSize: 13, color: AppColors.text3),
              ),
            )
          else
            for (var i = 0; i < debts.length; i++)
              _DebtRow(
                key: Key('debt-row-${debts[i].id}'),
                debt: debts[i],
                isLast: i == debts.length - 1,
                onTap: () => openDebtDetail(context, debts[i].id!),
              ),
        ],
      ),
    );
  }
}

/// Fila de una deuda: nombre, vencimiento, saldo restante y estado.
class _DebtRow extends StatelessWidget {
  final DebtModel debt;
  final bool isLast;
  final VoidCallback onTap;

  const _DebtRow({
    super.key,
    required this.debt,
    required this.isLast,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final s = AppStrings.of(context);
    final status = debtStatusLabel(context, debt);
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        highlightColor: Colors.transparent,
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 14),
          decoration: BoxDecoration(
            border: isLast
                ? null
                : Border(bottom: BorderSide(color: AppColors.hair, width: 1)),
          ),
          child: Row(
            children: [
              Container(
                width: 40,
                height: 40,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: AppColors.surfaceHi,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Text('🧾', style: TextStyle(fontSize: 20)),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      debt.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(fontSize: 15, color: AppColors.text),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      AppStrings.fill(s.debtDue, [
                        FormatUtils.shortDate(debt.dueDate),
                      ]),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(fontSize: 12, color: AppColors.text3),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    FormatUtils.money(debt.remainingBalance),
                    style: TextStyle(fontSize: 14, color: AppColors.text),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    status.label,
                    key: Key('debt-status-${debt.id}'),
                    style: TextStyle(fontSize: 12, color: status.color),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
