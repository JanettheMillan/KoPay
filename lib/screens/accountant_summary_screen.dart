import 'package:flutter/material.dart';

import '../models/accountant_client.dart';
import '../services/accountant_data.dart';
import '../services/auth_api.dart';
import '../utils/app_colors.dart';
import '../utils/app_strings.dart';
import '../utils/format_utils.dart';
import '../widgets/sample_data_banner.dart';
import 'accountant_history_screen.dart';

/// Muestra el aviso de acceso retirado (HU-41) para [clientName]. Lo usan
/// el resumen y el historial cuando la API responde que ya no hay permiso.
Future<void> showClientAccessRevoked(BuildContext context, String clientName) {
  final s = AppStrings.read(context);
  return showDialog<void>(
    context: context,
    barrierDismissible: false,
    builder: (dialogContext) => AlertDialog(
      key: const Key('access-revoked-dialog'),
      title: Text(s.accessRevoked),
      content: Text(AppStrings.fill(s.clientAccessRevoked, [clientName])),
      actions: [
        TextButton(
          key: const Key('access-revoked-ok'),
          onPressed: () => Navigator.of(dialogContext).pop(),
          child: Text(MaterialLocalizations.of(dialogContext).okButtonLabel),
        ),
      ],
    ),
  );
}

/// Mensaje de un error al leer los datos del contador.
String accountantErrorMessage(BuildContext context, Object? error) =>
    error is NetworkException
    ? NetworkException.message
    : AppStrings.of(context).clientsLoadError;

/// Resumen de un cliente (S2-19 y S5-09, HU-40): selector de mes,
/// balance, ingresos, gastos y pagos de tarjeta del periodo. Solo
/// lectura: no hay botones para crear ni editar (HU-42).
///
/// Pide a [data] solo el cliente y el mes que se ven. Si la persona ya
/// no da acceso (HU-41), muestra el aviso y regresa a la lista con
/// `true`, para que la lista se recargue.
class AccountantSummaryScreen extends StatefulWidget {
  final ClientInfo client;
  final AccountantData data;

  /// Mes que se muestra al abrir. Por omisión, el actual.
  final DateTime? initialMonth;

  const AccountantSummaryScreen({
    super.key,
    required this.client,
    required this.data,
    this.initialMonth,
  });

  @override
  State<AccountantSummaryScreen> createState() =>
      _AccountantSummaryScreenState();
}

class _AccountantSummaryScreenState extends State<AccountantSummaryScreen> {
  late DateTime _month;
  late Future<PeriodSummary> _summary;
  bool _leaving = false;

  @override
  void initState() {
    super.initState();
    final start = widget.initialMonth ?? DateTime.now();
    _month = DateTime(start.year, start.month);
    _summary = _read();
  }

  Future<PeriodSummary> _read() {
    final future = widget.data.summary(widget.client.id, _month);
    future.then(
      (_) {},
      onError: (Object e) {
        if (e is ClientAccessRevoked) _revoked();
      },
    );
    return future;
  }

  void _changeMonth(int delta) => setState(() {
    _month = DateTime(_month.year, _month.month + delta);
    _summary = _read();
  });

  void _retry() => setState(() {
    _summary = _read();
  });

  /// Ya no hay permiso: avisa (si no avisó ya el historial) y regresa a
  /// la lista con `true`.
  Future<void> _revoked({bool notified = false}) async {
    if (!mounted || _leaving) return;
    _leaving = true;
    if (!notified) await showClientAccessRevoked(context, widget.client.name);
    if (mounted) Navigator.of(context).pop(true);
  }

  Future<void> _openHistory() async {
    final revoked = await Navigator.of(context).push<bool>(
      MaterialPageRoute<bool>(
        builder: (_) => AccountantHistoryScreen(
          client: widget.client,
          data: widget.data,
          month: _month,
        ),
      ),
    );
    if (revoked == true) await _revoked(notified: true);
  }

  @override
  Widget build(BuildContext context) {
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
          if (widget.data.isSample) const SampleDataBanner(),
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
          FutureBuilder<PeriodSummary>(
            future: _summary,
            builder: (context, snapshot) {
              if (snapshot.connectionState != ConnectionState.done) {
                return const AccountantLoading(key: Key('summary-loading'));
              }
              final summary = snapshot.data;
              if (summary == null) {
                if (snapshot.error is ClientAccessRevoked) {
                  return const SizedBox.shrink();
                }
                return AccountantLoadError(
                  message: accountantErrorMessage(context, snapshot.error),
                  onRetry: _retry,
                );
              }
              return _Totals(summary: summary, onViewMovements: _openHistory);
            },
          ),
        ],
      ),
    );
  }
}

/// Balance, ingresos, gastos, pagos y el botón "Ver movimientos".
class _Totals extends StatelessWidget {
  final PeriodSummary summary;
  final VoidCallback onViewMovements;

  const _Totals({required this.summary, required this.onViewMovements});

  @override
  Widget build(BuildContext context) {
    final s = AppStrings.of(context);
    final balanceColor = summary.balance >= 0 ? AppColors.green : AppColors.red;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
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
            onPressed: onViewMovements,
          ),
        ),
      ],
    );
  }
}

/// Indicador mientras llega la respuesta de la API.
class AccountantLoading extends StatelessWidget {
  const AccountantLoading({super.key});

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.all(32),
    child: Center(child: CircularProgressIndicator(color: AppColors.green)),
  );
}

/// Mensaje de error con botón para volver a intentar.
class AccountantLoadError extends StatelessWidget {
  final String message;
  final VoidCallback onRetry;

  const AccountantLoadError({
    super.key,
    required this.message,
    required this.onRetry,
  });

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.all(20),
    child: Column(
      children: [
        Text(
          message,
          key: const Key('accountant-load-error'),
          textAlign: TextAlign.center,
          style: TextStyle(fontSize: 14, color: AppColors.text3),
        ),
        const SizedBox(height: 12),
        OutlinedButton(
          key: const Key('accountant-retry'),
          style: OutlinedButton.styleFrom(
            foregroundColor: AppColors.green,
            side: BorderSide(color: AppColors.green),
          ),
          onPressed: onRetry,
          child: Text(AppStrings.of(context).retry),
        ),
      ],
    ),
  );
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
