import 'package:flutter/material.dart';

import '../data/accountant_sample_data.dart';
import '../utils/app_colors.dart';
import '../utils/app_strings.dart';
import '../utils/format_utils.dart';
import '../widgets/sample_data_banner.dart';
import 'accountant_history_screen.dart';

/// Resumen de un cliente (maqueta S2-19, HU-40): selector de mes,
/// balance, ingresos, gastos y pagos de tarjeta del periodo. Solo
/// lectura: no hay botones para crear ni editar (HU-42).
class AccountantSummaryScreen extends StatefulWidget {
  final SampleClient client;

  /// Mes que se muestra al abrir. Por omisión, el actual.
  final DateTime? initialMonth;

  const AccountantSummaryScreen({
    super.key,
    required this.client,
    this.initialMonth,
  });

  @override
  State<AccountantSummaryScreen> createState() =>
      _AccountantSummaryScreenState();
}

class _AccountantSummaryScreenState extends State<AccountantSummaryScreen> {
  late DateTime _month;

  @override
  void initState() {
    super.initState();
    final start = widget.initialMonth ?? DateTime.now();
    _month = DateTime(start.year, start.month);
  }

  void _changeMonth(int delta) =>
      setState(() => _month = DateTime(_month.year, _month.month + delta));

  @override
  Widget build(BuildContext context) {
    final s = AppStrings.of(context);
    final summary = PeriodSummary.of(widget.client.movements, _month);
    final balanceColor = summary.balance >= 0 ? AppColors.green : AppColors.red;

    return Scaffold(
      backgroundColor: AppColors.bg,
      appBar: AppBar(
        backgroundColor: AppColors.bg,
        foregroundColor: AppColors.text,
        elevation: 0,
        title: Text(widget.client.name),
      ),
      body: ListView(
        children: [
          const SampleDataBanner(),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: Row(
              children: [
                IconButton(
                  key: const Key('summary-prev-month'),
                  icon: const Icon(Icons.chevron_left_rounded),
                  color: AppColors.text2,
                  onPressed: () => _changeMonth(-1),
                ),
                Expanded(
                  child: Text(
                    FormatUtils.monthYear(_month),
                    key: const Key('summary-month'),
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                      color: AppColors.text,
                    ),
                  ),
                ),
                IconButton(
                  key: const Key('summary-next-month'),
                  icon: const Icon(Icons.chevron_right_rounded),
                  color: AppColors.text2,
                  onPressed: () => _changeMonth(1),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 4),
            child: Text(
              s.monthBalance,
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w500,
                color: AppColors.text3,
                letterSpacing: 1.2,
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: FittedBox(
              fit: BoxFit.scaleDown,
              alignment: Alignment.centerLeft,
              child: Text(
                '${summary.balance < 0 ? '−' : ''}'
                '${FormatUtils.money(summary.balance)}',
                key: const Key('summary-balance'),
                style: TextStyle(
                  fontSize: 40,
                  fontWeight: FontWeight.w600,
                  color: balanceColor,
                  letterSpacing: -1.2,
                ),
              ),
            ),
          ),
          const SizedBox(height: 16),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Column(
              children: [
                _StatRow(
                  label: s.income,
                  value: FormatUtils.money(summary.income),
                  valueKey: 'summary-income',
                  color: AppColors.green,
                ),
                _StatRow(
                  label: s.expenses,
                  value: FormatUtils.money(summary.expenses),
                  valueKey: 'summary-expenses',
                ),
                _StatRow(
                  label: s.cardPayments,
                  value: FormatUtils.money(summary.cardPayments),
                  valueKey: 'summary-payments',
                  isLast: true,
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 32),
            child: OutlinedButton.icon(
              key: const Key('summary-view-movements'),
              style: OutlinedButton.styleFrom(
                foregroundColor: AppColors.green,
                side: BorderSide(color: AppColors.green),
                padding: const EdgeInsets.symmetric(vertical: 14),
              ),
              icon: const Icon(Icons.receipt_long_outlined, size: 18),
              label: Text(s.viewMovements),
              onPressed: () => Navigator.of(context).push(
                MaterialPageRoute<void>(
                  builder: (_) => AccountantHistoryScreen(
                    client: widget.client,
                    month: _month,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _StatRow extends StatelessWidget {
  final String label;
  final String value;
  final String valueKey;
  final Color? color;
  final bool isLast;

  const _StatRow({
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
              fontSize: 15,
              fontWeight: FontWeight.w600,
              color: color ?? AppColors.text,
            ),
          ),
        ],
      ),
    );
  }
}
