import 'package:flutter/material.dart';

import '../data/accountant_sample_data.dart';
import '../utils/app_colors.dart';
import '../utils/app_strings.dart';
import '../utils/format_utils.dart';
import '../widgets/category_picker_sheet.dart';
import '../widgets/move_row.dart';
import '../widgets/sample_data_banner.dart';

/// Historial de un cliente en el mes elegido en el resumen (maqueta
/// S2-19, HU-40 y HU-42). Del más reciente al más antiguo. Las filas no
/// se pueden tocar: no hay edición, borrado ni botón +.
class AccountantHistoryScreen extends StatelessWidget {
  final SampleClient client;
  final DateTime month;

  const AccountantHistoryScreen({
    super.key,
    required this.client,
    required this.month,
  });

  @override
  Widget build(BuildContext context) {
    final s = AppStrings.of(context);
    final moves = client.movementsFor(month);

    return Scaffold(
      backgroundColor: AppColors.bg,
      appBar: AppBar(
        backgroundColor: AppColors.bg,
        foregroundColor: AppColors.text,
        elevation: 0,
        title: Text(s.historyTitle),
      ),
      body: ListView(
        children: [
          const SampleDataBanner(),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 4),
            child: Text(
              '${client.name} · ${FormatUtils.monthYear(month)}',
              key: const Key('history-period'),
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w600,
                color: AppColors.text,
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
            child: Row(
              children: [
                Icon(
                  Icons.lock_outline_rounded,
                  size: 14,
                  color: AppColors.text3,
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    s.readOnly,
                    key: const Key('history-read-only'),
                    style: TextStyle(fontSize: 12, color: AppColors.text3),
                  ),
                ),
              ],
            ),
          ),
          if (moves.isEmpty)
            Padding(
              padding: const EdgeInsets.all(20),
              child: Text(
                s.noMovementsMonth,
                key: const Key('history-empty'),
                style: TextStyle(fontSize: 13, color: AppColors.text3),
              ),
            )
          else
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 32),
              child: Column(
                children: [
                  for (var i = 0; i < moves.length; i++)
                    MoveRow(
                      key: Key('history-row-$i'),
                      emoji: moves[i].isPayment
                          ? '💳'
                          : categoryEmoji(moves[i].category),
                      title: moves[i].description,
                      subtitle:
                          '${moves[i].isExpense ? moves[i].category.toLowerCase() : s.incomeKind}'
                          ' · ${FormatUtils.shortDate(moves[i].date)}',
                      amountLabel: FormatUtils.money(moves[i].amount),
                      isPositive: !moves[i].isExpense,
                      isLast: i == moves.length - 1,
                    ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}
