import 'package:flutter/material.dart';

import '../models/accountant_client.dart';
import '../models/movement_model.dart';
import '../services/accountant_data.dart';
import '../utils/app_colors.dart';
import '../utils/app_strings.dart';
import '../utils/format_utils.dart';
import '../widgets/category_picker_sheet.dart';
import '../widgets/move_row.dart';
import '../widgets/sample_data_banner.dart';
import 'accountant_summary_screen.dart';

/// Historial de un cliente en el mes elegido en el resumen (S2-19 y
/// S5-09, HU-40 y HU-42). Del más reciente al más antiguo. Las filas no
/// se pueden tocar: no hay edición, borrado ni botón +.
///
/// Si la persona ya no da acceso (HU-41), muestra el aviso y regresa con
/// `true`; el resumen regresa entonces a la lista.
class AccountantHistoryScreen extends StatefulWidget {
  final ClientInfo client;
  final AccountantData data;
  final DateTime month;

  const AccountantHistoryScreen({
    super.key,
    required this.client,
    required this.data,
    required this.month,
  });

  @override
  State<AccountantHistoryScreen> createState() =>
      _AccountantHistoryScreenState();
}

class _AccountantHistoryScreenState extends State<AccountantHistoryScreen> {
  late Future<List<Movement>> _moves;
  bool _leaving = false;

  @override
  void initState() {
    super.initState();
    _moves = _read();
  }

  Future<List<Movement>> _read() {
    final future = widget.data.movements(widget.client.id, widget.month);
    future.then(
      (_) {},
      onError: (Object e) {
        if (e is ClientAccessRevoked) _revoked();
      },
    );
    return future;
  }

  Future<void> _revoked() async {
    if (!mounted || _leaving) return;
    _leaving = true;
    await showClientAccessRevoked(context, widget.client.name);
    if (mounted) Navigator.of(context).pop(true);
  }

  @override
  Widget build(BuildContext context) {
    final s = AppStrings.of(context);

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
          if (widget.data.isSample) const SampleDataBanner(),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 4),
            child: Text(
              '${widget.client.name} · ${FormatUtils.monthYear(widget.month)}',
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
          FutureBuilder<List<Movement>>(
            future: _moves,
            builder: (context, snapshot) {
              if (snapshot.connectionState != ConnectionState.done) {
                return const AccountantLoading(key: Key('history-loading'));
              }
              final moves = snapshot.data;
              if (moves == null) {
                if (snapshot.error is ClientAccessRevoked) {
                  return const SizedBox.shrink();
                }
                return AccountantLoadError(
                  message: accountantErrorMessage(context, snapshot.error),
                  onRetry: () => setState(() {
                    _moves = _read();
                  }),
                );
              }
              if (moves.isEmpty) {
                return Padding(
                  padding: const EdgeInsets.all(20),
                  child: Text(
                    s.noMovementsMonth,
                    key: const Key('history-empty'),
                    style: TextStyle(fontSize: 13, color: AppColors.text3),
                  ),
                );
              }
              return Padding(
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
              );
            },
          ),
        ],
      ),
    );
  }
}
