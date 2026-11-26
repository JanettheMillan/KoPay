import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/card_model.dart';
import '../providers/card_provider.dart';
import '../utils/app_colors.dart';
import '../utils/format_utils.dart';
import '../widgets/add_card_sheet.dart';

/// Abre el detalle de la tarjeta con ese [cardId].
Future<void> openCardDetail(BuildContext context, int cardId) {
  return Navigator.of(context).push(
    MaterialPageRoute<void>(builder: (_) => CardDetailScreen(cardId: cardId)),
  );
}

/// Detalle de una tarjeta (HU-13 a HU-15): límite, saldo usado, crédito
/// disponible, días de corte y de pago, y las acciones Editar y Eliminar.
///
/// Escucha [CardProvider], así que después de editar muestra los datos
/// nuevos. Si la tarjeta se elimina, la pantalla se cierra.
class CardDetailScreen extends StatelessWidget {
  final int cardId;

  const CardDetailScreen({super.key, required this.cardId});

  Future<void> _edit(BuildContext context, CardModel card) async {
    final messenger = ScaffoldMessenger.of(context);
    final saved = await showAddCardSheet(context, initial: card);
    if (saved != null) {
      messenger.showSnackBar(const SnackBar(content: Text('Tarjeta guardada')));
    }
  }

  /// Pide confirmación (HU-15). Cancelar conserva la tarjeta.
  Future<void> _delete(BuildContext context, CardModel card) async {
    final provider = context.read<CardProvider>();
    final navigator = Navigator.of(context);
    final messenger = ScaffoldMessenger.of(context);
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialog) => AlertDialog(
        title: const Text('¿Eliminar tarjeta?'),
        content: Text(
          'Se eliminará "${card.name}" de ${card.bank}. '
          'Esta acción no se puede deshacer.',
        ),
        actions: [
          TextButton(
            key: const Key('card-delete-cancel'),
            onPressed: () => Navigator.of(dialog).pop(false),
            child: const Text('Cancelar'),
          ),
          TextButton(
            key: const Key('card-delete-confirm'),
            onPressed: () => Navigator.of(dialog).pop(true),
            style: TextButton.styleFrom(foregroundColor: AppColors.red),
            child: const Text('Eliminar'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    try {
      await provider.delete(card.id!);
      navigator.pop();
      messenger.showSnackBar(
        const SnackBar(content: Text('Tarjeta eliminada')),
      );
    } catch (_) {
      messenger.showSnackBar(
        const SnackBar(content: Text('No se pudo eliminar. Intenta de nuevo.')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final card = context.watch<CardProvider>().byId(cardId);

    return Scaffold(
      backgroundColor: AppColors.bg,
      appBar: AppBar(
        backgroundColor: AppColors.bg,
        foregroundColor: AppColors.text,
        elevation: 0,
        title: Text(card?.name ?? 'Tarjeta'),
        actions: card == null
            ? null
            : [
                IconButton(
                  key: const Key('card-edit'),
                  tooltip: 'Editar',
                  icon: const Icon(Icons.edit_outlined),
                  onPressed: () => _edit(context, card),
                ),
                IconButton(
                  key: const Key('card-delete'),
                  tooltip: 'Eliminar',
                  icon: const Icon(Icons.delete_outline_rounded),
                  onPressed: () => _delete(context, card),
                ),
              ],
      ),
      body: card == null
          ? Center(
              child: Text(
                'La tarjeta ya no existe.',
                style: TextStyle(color: AppColors.text3),
              ),
            )
          : _CardDetailBody(card: card),
    );
  }
}

class _CardDetailBody extends StatelessWidget {
  final CardModel card;

  const _CardDetailBody({required this.card});

  @override
  Widget build(BuildContext context) {
    final usage = card.creditLimit <= 0
        ? 0.0
        : (card.usedBalance / card.creditLimit).clamp(0.0, 1.0);

    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
      children: [
        Text(card.bank, style: TextStyle(fontSize: 13, color: AppColors.text3)),
        const SizedBox(height: 16),
        Text(
          'Crédito disponible',
          style: TextStyle(fontSize: 13, color: AppColors.text2),
        ),
        const SizedBox(height: 4),
        Text(
          FormatUtils.money(card.available),
          key: const Key('card-available'),
          style: TextStyle(
            fontSize: 32,
            fontWeight: FontWeight.w700,
            color: AppColors.text,
            letterSpacing: -0.8,
          ),
        ),
        const SizedBox(height: 16),
        ClipRRect(
          borderRadius: BorderRadius.circular(4),
          child: LinearProgressIndicator(
            value: usage,
            minHeight: 8,
            backgroundColor: AppColors.surfaceHi,
            color: usage >= 0.9 ? AppColors.red : AppColors.green,
          ),
        ),
        const SizedBox(height: 24),
        _DetailRow(
          label: 'Límite de crédito',
          value: FormatUtils.money(card.creditLimit),
          valueKey: 'card-limit-value',
        ),
        _DetailRow(
          label: 'Saldo usado',
          value: FormatUtils.money(card.usedBalance),
          valueKey: 'card-used-value',
        ),
        _DetailRow(
          label: 'Día de corte',
          value: 'Día ${card.cutDay}',
          valueKey: 'card-cut-value',
        ),
        _DetailRow(
          label: 'Día de pago',
          value: 'Día ${card.paymentDay}',
          valueKey: 'card-payment-value',
        ),
        _DetailRow(
          label: 'Pago mínimo',
          value: FormatUtils.money(card.minimumPayment),
          valueKey: 'card-minimum-value',
          isLast: true,
        ),
      ],
    );
  }
}

class _DetailRow extends StatelessWidget {
  final String label;
  final String value;
  final String valueKey;
  final bool isLast;

  const _DetailRow({
    required this.label,
    required this.value,
    required this.valueKey,
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
              color: AppColors.text,
            ),
          ),
        ],
      ),
    );
  }
}
