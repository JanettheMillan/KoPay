import 'package:flutter/material.dart';

import '../data/accountant_sample_data.dart';
import '../services/accountant_data.dart';
import '../utils/app_colors.dart';
import '../utils/app_strings.dart';
import '../utils/format_utils.dart';
import '../widgets/sample_data_banner.dart';
import 'accountant_summary_screen.dart';

/// Abre la maqueta de la vista de contador con los clientes de ejemplo.
Future<void> openAccountantPreview(BuildContext context) {
  return Navigator.of(context).push(
    MaterialPageRoute<void>(
      builder: (_) => AccountantClientsScreen(data: SampleAccountantData()),
    ),
  );
}

/// Clientes autorizados (S2-19 y S5-09, HU-39): nombre, correo y fecha
/// de autorización. Tocar uno abre su resumen.
///
/// Con sesión de contador, [data] lee `GET /api/clients`: solo aparecen
/// las personas con permiso vigente. La lista se vuelve a leer al regresar
/// de un cliente, así que quien revocó ya no aparece (HU-41). En la
/// maqueta de Ajustes, [data] son los clientes de ejemplo.
class AccountantClientsScreen extends StatefulWidget {
  final AccountantData data;

  const AccountantClientsScreen({super.key, required this.data});

  @override
  State<AccountantClientsScreen> createState() =>
      _AccountantClientsScreenState();
}

class _AccountantClientsScreenState extends State<AccountantClientsScreen> {
  late Future<List<ClientInfo>> _clients;

  @override
  void initState() {
    super.initState();
    _clients = widget.data.clients();
  }

  Future<void> _reload() {
    final future = widget.data.clients();
    setState(() {
      _clients = future;
    });
    return future.then((_) {}, onError: (_) {});
  }

  Future<void> _open(ClientInfo client) async {
    await Navigator.of(context).push<bool>(
      MaterialPageRoute<bool>(
        builder: (_) =>
            AccountantSummaryScreen(client: client, data: widget.data),
      ),
    );
    if (mounted) await _reload();
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
        title: Text(s.clientsTitle),
      ),
      body: RefreshIndicator(
        color: AppColors.green,
        onRefresh: _reload,
        child: FutureBuilder<List<ClientInfo>>(
          future: _clients,
          builder: (context, snapshot) {
            final clients = snapshot.data;
            return ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              children: [
                if (widget.data.isSample) const SampleDataBanner(),
                if (snapshot.connectionState != ConnectionState.done &&
                    clients == null)
                  const AccountantLoading(key: Key('clients-loading'))
                else if (snapshot.hasError)
                  AccountantLoadError(
                    message: accountantErrorMessage(context, snapshot.error),
                    onRetry: _reload,
                  )
                else if (clients == null || clients.isEmpty)
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
                    _ClientRow(
                      client: clients[i],
                      isLast: i == clients.length - 1,
                      onTap: () => _open(clients[i]),
                    ),
              ],
            );
          },
        ),
      ),
    );
  }
}

class _ClientRow extends StatelessWidget {
  final ClientInfo client;
  final bool isLast;
  final VoidCallback onTap;

  const _ClientRow({
    required this.client,
    required this.isLast,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final s = AppStrings.of(context);
    final initial = client.name.isEmpty ? '?' : client.name[0];
    return Material(
      color: Colors.transparent,
      child: InkWell(
        key: Key('client-${client.id}'),
        onTap: onTap,
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
                        FormatUtils.fullDate(client.grantedAt),
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
