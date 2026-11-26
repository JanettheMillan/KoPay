import 'package:flutter/material.dart';

import '../data/accountant_sample_data.dart';
import '../utils/app_colors.dart';
import '../utils/app_strings.dart';
import '../utils/format_utils.dart';
import '../widgets/sample_data_banner.dart';
import 'accountant_summary_screen.dart';

/// Abre la maqueta de la vista de contador con los clientes de ejemplo.
Future<void> openAccountantPreview(BuildContext context) {
  return Navigator.of(context).push(
    MaterialPageRoute<void>(
      builder: (_) =>
          AccountantClientsScreen(clients: accountantSampleClients()),
    ),
  );
}

/// Clientes autorizados (maqueta S2-19, HU-39): nombre, correo y fecha
/// de autorización. Tocar uno abre su resumen.
///
/// En la maqueta los clientes son de ejemplo. El cierre de sesión y la
/// lista real llegan con S4-12 y S5-09.
class AccountantClientsScreen extends StatelessWidget {
  final List<SampleClient> clients;

  const AccountantClientsScreen({super.key, required this.clients});

  @override
  Widget build(BuildContext context) {
    final s = AppStrings.of(context);
    return Scaffold(
      backgroundColor: AppColors.bg,
      appBar: AppBar(
        backgroundColor: AppColors.bg,
        foregroundColor: AppColors.text,
        elevation: 0,
        title: Text(s.clientsTitle),
      ),
      body: ListView(
        children: [
          const SampleDataBanner(),
          if (clients.isEmpty)
            Padding(
              padding: const EdgeInsets.all(20),
              child: Text(
                s.noClients,
                key: const Key('clients-empty'),
                style: TextStyle(fontSize: 14, color: AppColors.text3),
              ),
            )
          else
            for (var i = 0; i < clients.length; i++)
              _ClientRow(client: clients[i], isLast: i == clients.length - 1),
        ],
      ),
    );
  }
}

class _ClientRow extends StatelessWidget {
  final SampleClient client;
  final bool isLast;

  const _ClientRow({required this.client, required this.isLast});

  @override
  Widget build(BuildContext context) {
    final s = AppStrings.of(context);
    final initial = client.name.isEmpty ? '?' : client.name[0];
    return Material(
      color: Colors.transparent,
      child: InkWell(
        key: Key('client-${client.id}'),
        onTap: () => Navigator.of(context).push(
          MaterialPageRoute<void>(
            builder: (_) => AccountantSummaryScreen(client: client),
          ),
        ),
        child: Container(
          margin: const EdgeInsets.symmetric(horizontal: 20),
          padding: const EdgeInsets.symmetric(vertical: 14),
          decoration: BoxDecoration(
            border: isLast
                ? null
                : Border(bottom: BorderSide(color: AppColors.hair, width: 1)),
          ),
          child: Row(
            children: [
              CircleAvatar(
                radius: 20,
                backgroundColor: AppColors.surfaceHi,
                child: Text(
                  initial,
                  style: TextStyle(
                    color: AppColors.green,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      client.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(fontSize: 15, color: AppColors.text),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      client.email,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(fontSize: 12, color: AppColors.text3),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      AppStrings.fill(s.authorizedOn, [
                        FormatUtils.fullDate(client.authorizedAt),
                      ]),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(fontSize: 12, color: AppColors.text3),
                    ),
                  ],
                ),
              ),
              Icon(Icons.chevron_right_rounded, color: AppColors.text3),
            ],
          ),
        ),
      ),
    );
  }
}
