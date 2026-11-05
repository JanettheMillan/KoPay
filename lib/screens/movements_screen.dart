import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../models/income_model.dart';
import '../models/movement_model.dart';
import '../providers/income_provider.dart';
import '../providers/movement_provider.dart';
import '../utils/app_colors.dart';
import '../utils/format_utils.dart';
import '../widgets/add_income_sheet.dart';
import '../widgets/add_movement_sheet.dart';
import '../widgets/category_picker_sheet.dart';
import '../widgets/move_row.dart';

/// Fila del historial: un movimiento o un ingreso.
class HistoryEntry {
  final Movement? movement;
  final Income? income;

  const HistoryEntry.movement(Movement this.movement) : income = null;
  const HistoryEntry.income(Income this.income) : movement = null;

  bool get isIncome => income != null;

  /// Vista común: un ingreso se muestra como movimiento positivo.
  Movement get asMovement => movement ?? income!.toMovement();

  DateTime get date => asMovement.date;
}

/// Junta movimientos e ingresos en una sola lista, de la fecha más
/// reciente a la más antigua. Si dos registros tienen la misma fecha,
/// conserva el orden con que llegaron (primero movimientos).
List<HistoryEntry> buildHistory(
  List<Movement> movements,
  List<Income> incomes,
) {
  final entries = [
    ...movements.map(HistoryEntry.movement),
    ...incomes.map(HistoryEntry.income),
  ];
  // List.sort no es estable; se ordena por fecha y luego por posición.
  final indexed = entries.indexed.toList()
    ..sort((a, b) {
      final byDate = b.$2.date.compareTo(a.$2.date);
      return byDate != 0 ? byDate : a.$1.compareTo(b.$1);
    });
  return [for (final e in indexed) e.$2];
}

/// Historial de gastos, entradas e ingresos, agrupado por mes.
/// Tocar una fila abre su formulario para editarla.
class MovementsScreen extends StatelessWidget {
  const MovementsScreen({super.key});

  Future<void> _edit(BuildContext context, HistoryEntry entry) async {
    if (entry.isIncome) {
      await showAddIncomeSheet(context, initial: entry.income);
    } else {
      await showAddMovementSheet(context, initial: entry.movement);
    }
  }

  @override
  Widget build(BuildContext context) {
    final movements = context.watch<MovementProvider>();
    final incomes = context.watch<IncomeProvider>();
    final loading =
        (movements.isLoading || incomes.isLoading) &&
        !(movements.isLoaded && incomes.isLoaded);
    final history = buildHistory(movements.movements, incomes.incomes);

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: AppColors.systemOverlay,
      child: ColoredBox(
        color: AppColors.bg,
        child: CustomScrollView(
          physics: const BouncingScrollPhysics(
            parent: AlwaysScrollableScrollPhysics(),
          ),
          slivers: [
            SliverToBoxAdapter(
              child: Padding(
                padding: EdgeInsets.fromLTRB(
                  20,
                  MediaQuery.of(context).padding.top + 20,
                  20,
                  8,
                ),
                child: Text(
                  'Movimientos',
                  style: TextStyle(
                    fontSize: 26,
                    fontWeight: FontWeight.w600,
                    color: AppColors.text,
                    letterSpacing: -0.8,
                  ),
                ),
              ),
            ),
            if (loading)
              const SliverFillRemaining(
                hasScrollBody: false,
                child: Center(child: CircularProgressIndicator()),
              )
            else if (history.isEmpty)
              SliverFillRemaining(
                hasScrollBody: false,
                child: Center(
                  child: Padding(
                    padding: const EdgeInsets.all(32),
                    child: Text(
                      'Aún no hay movimientos.\nToca + para registrar uno.',
                      key: const Key('history-empty'),
                      textAlign: TextAlign.center,
                      style: TextStyle(fontSize: 14, color: AppColors.text3),
                    ),
                  ),
                ),
              )
            else
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 96),
                sliver: SliverList.builder(
                  itemCount: history.length,
                  itemBuilder: (context, i) {
                    final entry = history[i];
                    final previous = i == 0 ? null : history[i - 1];
                    final next = i + 1 < history.length ? history[i + 1] : null;
                    final newMonth =
                        previous == null ||
                        !FormatUtils.isSameMonth(entry.date, previous.date);
                    final lastOfMonth =
                        next == null ||
                        !FormatUtils.isSameMonth(entry.date, next.date);
                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (newMonth) _MonthHeader(entry.date),
                        _HistoryRow(
                          entry: entry,
                          isLast: lastOfMonth,
                          onTap: () => _edit(context, entry),
                        ),
                      ],
                    );
                  },
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _MonthHeader extends StatelessWidget {
  final DateTime month;

  const _MonthHeader(this.month);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 20, bottom: 2),
      child: Text(
        FormatUtils.monthYear(month).toUpperCase(),
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w600,
          color: AppColors.text3,
          letterSpacing: 1.2,
        ),
      ),
    );
  }
}

class _HistoryRow extends StatelessWidget {
  final HistoryEntry entry;
  final bool isLast;
  final VoidCallback onTap;

  const _HistoryRow({
    required this.entry,
    required this.isLast,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final m = entry.asMovement;
    final kind = entry.isIncome ? 'ingreso' : m.category.toLowerCase();
    return MoveRow(
      key: Key('history-${entry.isIncome ? 'income' : 'movement'}-${m.id}'),
      emoji: entry.isIncome ? '💼' : categoryEmoji(m.category),
      title: m.description,
      subtitle: '$kind · ${FormatUtils.shortDate(m.date)}',
      amountLabel: FormatUtils.money(m.amount),
      isPositive: !m.isExpense,
      isLast: isLast,
      onTap: onTap,
    );
  }
}
