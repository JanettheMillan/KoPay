import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';

import '../utils/app_colors.dart';
import '../widgets/move_row.dart';

/// Movimiento de ejemplo mientras no hay modelos ni base de datos.
class _SampleMove {
  final String emoji;
  final String description;
  final String category;
  final double amount; // positivo = ingreso, negativo = gasto
  final DateTime date;

  const _SampleMove(
    this.emoji,
    this.description,
    this.category,
    this.amount,
    this.date,
  );
}

const _monthNames = [
  'enero', 'febrero', 'marzo', 'abril', 'mayo', 'junio',
  'julio', 'agosto', 'septiembre', 'octubre', 'noviembre', 'diciembre',
];

final _money = NumberFormat.currency(
  locale: 'es_MX',
  symbol: r'$',
  decimalDigits: 2,
);

final _moneyCompact = NumberFormat.currency(
  locale: 'es_MX',
  symbol: r'$',
  decimalDigits: 0,
);

/// Datos fijos para el mes actual y el anterior.
List<_SampleMove> _sampleMoves() {
  final now = DateTime.now();
  DateTime day(int monthOffset, int d) =>
      DateTime(now.year, now.month + monthOffset, d);

  return [
    _SampleMove('💼', 'Salario', 'Ingreso', 12000, day(0, 1)),
    _SampleMove('🛒', 'Súper', 'Comida', -1350.50, day(0, 3)),
    _SampleMove('🚌', 'Transporte', 'Transporte', -280, day(0, 4)),
    _SampleMove('🎬', 'Cine', 'Entretenimiento', -320, day(0, 6)),
    _SampleMove('💡', 'Luz', 'Servicios', -540, day(0, 8)),
    _SampleMove('💼', 'Salario', 'Ingreso', 12000, day(-1, 1)),
    _SampleMove('🏠', 'Renta', 'Vivienda', -4500, day(-1, 2)),
    _SampleMove('🛒', 'Súper', 'Comida', -1890, day(-1, 10)),
  ];
}

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  late DateTime _selectedMonth;
  final List<_SampleMove> _moves = _sampleMoves();

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    _selectedMonth = DateTime(now.year, now.month);
  }

  void _changeMonth(int delta) {
    setState(() {
      _selectedMonth = DateTime(
        _selectedMonth.year,
        _selectedMonth.month + delta,
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    final monthMoves = _moves
        .where((m) =>
            m.date.year == _selectedMonth.year &&
            m.date.month == _selectedMonth.month)
        .toList()
      ..sort((a, b) => b.date.compareTo(a.date));

    final income = monthMoves
        .where((m) => m.amount > 0)
        .fold(0.0, (s, m) => s + m.amount);
    final expenses = monthMoves
        .where((m) => m.amount < 0)
        .fold(0.0, (s, m) => s + m.amount.abs());

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: AppColors.systemOverlay,
      child: ColoredBox(
        color: AppColors.bg,
        child: SingleChildScrollView(
          physics: const BouncingScrollPhysics(
            parent: AlwaysScrollableScrollPhysics(),
          ),
          padding: const EdgeInsets.only(bottom: 32),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const _Header(),
              _Hero(
                income: income,
                expenses: expenses,
                selectedMonth: _selectedMonth,
                onMonthChange: _changeMonth,
              ),
              _MovementsSection(moves: monthMoves),
            ],
          ),
        ),
      ),
    );
  }
}

// ── Header ─────────────────────────────────────────────────────

class _Header extends StatelessWidget {
  const _Header();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.fromLTRB(
        20,
        MediaQuery.of(context).padding.top + 20,
        20,
        20,
      ),
      child: RichText(
        text: TextSpan(
          style: TextStyle(
            fontSize: 19,
            fontWeight: FontWeight.w600,
            color: AppColors.text,
            letterSpacing: -0.4,
          ),
          children: [
            const TextSpan(text: 'kopay'),
            TextSpan(text: '.', style: TextStyle(color: AppColors.green)),
          ],
        ),
      ),
    );
  }
}

// ── Hero: saldo, ingresos y gastos del mes ─────────────────────

class _Hero extends StatelessWidget {
  final double income;
  final double expenses;
  final DateTime selectedMonth;
  final void Function(int) onMonthChange;

  const _Hero({
    required this.income,
    required this.expenses,
    required this.selectedMonth,
    required this.onMonthChange,
  });

  @override
  Widget build(BuildContext context) {
    final balance = income - expenses;
    final isPositive = balance >= 0;
    final color = isPositive ? AppColors.green : AppColors.red;
    final balStr = _money.format(balance.abs());
    final balMain = balStr.contains('.') ? balStr.split('.').first : balStr;
    final balDec = balStr.contains('.') ? '.${balStr.split('.').last}' : '';

    final now = DateTime.now();
    final isCurrentMonth =
        selectedMonth.year == now.year && selectedMonth.month == now.month;
    final monthLabel =
        '${_monthNames[selectedMonth.month - 1]} ${selectedMonth.year}';

    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 4, 20, 28),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  'BALANCE DEL MES',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w500,
                    color: AppColors.text3,
                    letterSpacing: 1.2,
                  ),
                ),
              ),
              const SizedBox(width: 6),
              Flexible(
                child: Align(
                  alignment: Alignment.centerRight,
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    alignment: Alignment.centerRight,
                    child: _MonthNav(
                      label: monthLabel,
                      isCurrentMonth: isCurrentMonth,
                      onPrev: () => onMonthChange(-1),
                      onNext: () => onMonthChange(1),
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              if (!isPositive)
                Text(
                  '−',
                  style: TextStyle(
                    fontSize: 32,
                    color: color,
                    letterSpacing: -1,
                    height: 1.4,
                  ),
                ),
              Text(
                balMain,
                key: const Key('home-balance'),
                style: TextStyle(
                  fontSize: 52,
                  fontWeight: FontWeight.w500,
                  color: color,
                  letterSpacing: -2.2,
                  height: 1,
                ),
              ),
              Text(
                balDec,
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w500,
                  color: color,
                  letterSpacing: -0.8,
                  height: 1,
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: _BalanceStat(
                  label: 'Ingresos',
                  value: _moneyCompact.format(income),
                  valueColor: AppColors.green,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _BalanceStat(
                  label: 'Gastos',
                  value: _moneyCompact.format(expenses),
                  valueColor: AppColors.text,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// ── Movimientos del mes ────────────────────────────────────────

class _MovementsSection extends StatelessWidget {
  final List<_SampleMove> moves;

  const _MovementsSection({required this.moves});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _HomeSectionHeader(
            title: 'MOVIMIENTOS',
            count: moves.length,
            accent: AppColors.green,
          ),
          const SizedBox(height: 4),
          if (moves.isEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 12),
              child: Text(
                'Sin movimientos este mes.',
                style: TextStyle(fontSize: 13, color: AppColors.text3),
              ),
            )
          else
            for (var i = 0; i < moves.length; i++)
              MoveRow(
                emoji: moves[i].emoji,
                title: moves[i].description,
                subtitle:
                    '${moves[i].category.toLowerCase()} · ${moves[i].date.day} ${_monthNames[moves[i].date.month - 1].substring(0, 3)}',
                amountLabel: _moneyCompact.format(moves[i].amount.abs()),
                isPositive: moves[i].amount > 0,
                isLast: i == moves.length - 1,
              ),
        ],
      ),
    );
  }
}

class _HomeSectionHeader extends StatelessWidget {
  final String title;
  final Color accent;
  final int? count;

  const _HomeSectionHeader({
    required this.title,
    required this.accent,
    this.count,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 3,
          height: 14,
          decoration: BoxDecoration(
            color: accent,
            borderRadius: BorderRadius.circular(2),
          ),
        ),
        const SizedBox(width: 8),
        Text(
          title,
          style: TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w700,
            color: AppColors.text,
            letterSpacing: -0.2,
          ),
        ),
        if (count != null) ...[
          const SizedBox(width: 7),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
            decoration: BoxDecoration(
              color: AppColors.surfaceHi,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              '$count',
              style: TextStyle(fontSize: 10, color: AppColors.text3),
            ),
          ),
        ],
      ],
    );
  }
}

// ── Selector de mes ────────────────────────────────────────────

class _MonthNav extends StatelessWidget {
  final String label;
  final bool isCurrentMonth;
  final VoidCallback onPrev;
  final VoidCallback onNext;

  const _MonthNav({
    required this.label,
    required this.isCurrentMonth,
    required this.onPrev,
    required this.onNext,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        GestureDetector(
          key: const Key('month-prev'),
          onTap: onPrev,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            child: Icon(
              Icons.chevron_left_rounded,
              color: AppColors.text,
              size: 26,
            ),
          ),
        ),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
          decoration: BoxDecoration(
            color: isCurrentMonth
                ? AppColors.green.withValues(alpha: 0.15)
                : AppColors.hair2,
            borderRadius: BorderRadius.circular(20),
          ),
          child: Text(
            label,
            style: TextStyle(
              fontSize: 17,
              fontWeight: FontWeight.w600,
              color: isCurrentMonth ? AppColors.green : AppColors.text,
              letterSpacing: -0.3,
            ),
          ),
        ),
        GestureDetector(
          key: const Key('month-next'),
          onTap: onNext,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            child: Icon(
              Icons.chevron_right_rounded,
              color: AppColors.text,
              size: 26,
            ),
          ),
        ),
      ],
    );
  }
}

// ── Chip de ingresos / gastos ──────────────────────────────────

class _BalanceStat extends StatelessWidget {
  final String label;
  final String value;
  final Color valueColor;

  const _BalanceStat({
    required this.label,
    required this.value,
    required this.valueColor,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: 11,
              color: AppColors.text3,
              letterSpacing: 0.2,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w600,
              color: valueColor,
              letterSpacing: -0.4,
            ),
          ),
        ],
      ),
    );
  }
}
