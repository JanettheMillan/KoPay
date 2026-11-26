import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../providers/card_provider.dart';
import '../screens/card_detail_screen.dart';
import '../utils/app_colors.dart';
import '../utils/app_strings.dart';
import '../utils/format_utils.dart';
import 'add_card_sheet.dart';

/// Sección de tarjetas de Inicio (HU-13): lista las tarjetas con su
/// crédito disponible, abre el detalle al tocar una y permite agregar
/// otra. Si no hay [CardProvider] en el árbol, no muestra nada.
class CardsSection extends StatelessWidget {
  const CardsSection({super.key});

  Future<void> _add(BuildContext context) async {
    final messenger = ScaffoldMessenger.of(context);
    final saved = await showAddCardSheet(context);
    if (saved != null) {
      messenger.showSnackBar(const SnackBar(content: Text('Tarjeta guardada')));
    }
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<CardProvider?>();
    if (provider == null) return const SizedBox.shrink();
    final s = AppStrings.of(context);
    final cards = provider.cards;

    return Padding(
      key: const Key('home-cards'),
      // Deudas va debajo y deja el espacio para el botón + (S2-14).
      padding: const EdgeInsets.fromLTRB(20, 24, 20, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 3,
                height: 14,
                decoration: BoxDecoration(
                  color: AppColors.green,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  s.cardsHeader,
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    color: AppColors.text,
                    letterSpacing: -0.2,
                  ),
                ),
              ),
              TextButton.icon(
                key: const Key('cards-add'),
                onPressed: () => _add(context),
                icon: const Icon(Icons.add_rounded, size: 18),
                label: Text(s.addCard),
              ),
            ],
          ),
          if (cards.isEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Text(
                s.noCards,
                key: const Key('cards-empty'),
                style: TextStyle(fontSize: 13, color: AppColors.text3),
              ),
            )
          else
            for (var i = 0; i < cards.length; i++)
              _CardRow(
                key: Key('card-row-${cards[i].id}'),
                title: cards[i].name,
                subtitle: cards[i].bank,
                available:
                    '${FormatUtils.money(cards[i].available)} '
                    '${s.cardAvailable}',
                isLast: i == cards.length - 1,
                onTap: () => openCardDetail(context, cards[i].id!),
              ),
        ],
      ),
    );
  }
}

/// Fila de una tarjeta: icono, nombre, banco y crédito disponible.
class _CardRow extends StatelessWidget {
  final String title;
  final String subtitle;
  final String available;
  final bool isLast;
  final VoidCallback onTap;

  const _CardRow({
    super.key,
    required this.title,
    required this.subtitle,
    required this.available,
    required this.isLast,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
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
                child: const Text('💳', style: TextStyle(fontSize: 20)),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(fontSize: 15, color: AppColors.text),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(fontSize: 12, color: AppColors.text3),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Text(
                available,
                style: TextStyle(fontSize: 14, color: AppColors.green),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
