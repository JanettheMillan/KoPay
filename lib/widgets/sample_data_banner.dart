import 'package:flutter/material.dart';

import '../utils/app_colors.dart';
import '../utils/app_strings.dart';

/// Ámbar de aviso; la paleta no tiene uno y aquí solo marca la maqueta.
const Color _amber = Color(0xFFE8A33D);

/// Aviso fijo de la maqueta de contador (S2-19): deja claro que los
/// datos son de ejemplo y que no hay conexión con cuentas reales.
class SampleDataBanner extends StatelessWidget {
  const SampleDataBanner({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      key: const Key('sample-data-banner'),
      width: double.infinity,
      margin: const EdgeInsets.fromLTRB(20, 4, 20, 12),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: _amber.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: _amber.withValues(alpha: 0.5)),
      ),
      child: Row(
        children: [
          Icon(Icons.science_outlined, size: 18, color: _amber),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              AppStrings.of(context).sampleBanner,
              style: TextStyle(fontSize: 12.5, color: AppColors.text),
            ),
          ),
        ],
      ),
    );
  }
}
