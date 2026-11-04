import 'package:flutter/material.dart';

import '../utils/app_colors.dart';

/// Fila de un movimiento: icono de categoría, descripción, detalle y monto.
class MoveRow extends StatelessWidget {
  final String emoji;
  final String title;
  final String subtitle;
  final String amountLabel;
  final bool isPositive;
  final bool isLast;
  final VoidCallback? onTap;

  const MoveRow({
    super.key,
    required this.emoji,
    required this.title,
    required this.subtitle,
    required this.amountLabel,
    required this.isPositive,
    this.isLast = false,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        splashColor: AppColors.hair.withValues(alpha: 0.5),
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
                width: 36,
                height: 36,
                margin: const EdgeInsets.only(right: 14),
                decoration: BoxDecoration(
                  color: AppColors.surface,
                  borderRadius: BorderRadius.circular(10),
                ),
                alignment: Alignment.center,
                child: Text(emoji, style: const TextStyle(fontSize: 18)),
              ),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                        color: AppColors.text,
                        letterSpacing: -0.2,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      style: TextStyle(
                        fontSize: 12,
                        color: AppColors.text3,
                        letterSpacing: -0.1,
                      ),
                    ),
                  ],
                ),
              ),
              Text(
                '${isPositive ? '+' : '−'}$amountLabel',
                style: TextStyle(
                  fontSize: 15,
                  color: isPositive ? AppColors.green : AppColors.text,
                  letterSpacing: -0.3,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
