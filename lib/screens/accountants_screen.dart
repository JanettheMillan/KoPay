import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../providers/session_provider.dart';
import '../services/accountants_api.dart';
import '../services/auth_api.dart';
import '../utils/app_colors.dart';
import '../utils/app_strings.dart';
import '../utils/format_utils.dart';
import '../utils/route_policy.dart';
import '../widgets/authorize_accountant_sheet.dart';
import '../widgets/role_guard.dart';
import '../widgets/ui_kit.dart';

/// Abre Contadores autorizados detrás de la guarda de S4-09: solo una
/// cuenta `user` la ve. La API vuelve a comprobarlo (S4-05).
Future<void> openAccountants(BuildContext context) {
  return Navigator.of(context).push(
    MaterialPageRoute<void>(
      builder: (_) => RoleGuard(
        screen: AppScreen.manageAccountants,
        denied: (_, _) => const Scaffold(),
        child: const AccountantsScreen(),
      ),
    ),
  );
}

/// Contadores autorizados (S4-11, HU-38, HU-41): lista de permisos
/// vigentes, **Autorizar contador** y **Revocar** en cada uno, con
/// confirmación. Las llamadas pasan por `SessionProvider.authorized`, que
/// renueva la sesión si el token venció.
class AccountantsScreen extends StatefulWidget {
  const AccountantsScreen({super.key});

  @override
  State<AccountantsScreen> createState() => _AccountantsScreenState();
}

class _AccountantsScreenState extends State<AccountantsScreen> {
  List<AccountantGrant>? _grants;
  bool _loading = true;
  String? _error;
  String? _revoking;

  @override
  void initState() {
    super.initState();
    _load();
  }

  static String _message(Object error) =>
      error is ApiException ? error.message : NetworkException.message;

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    final session = context.read<SessionProvider>();
    final api = context.read<AccountantsApi>();
    try {
      final grants = await session.authorized(api.list);
      if (mounted) {
        setState(() {
          _grants = grants;
          _loading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _loading = false;
          _error = _message(e);
        });
      }
    }
  }

  void _notify(String text) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(text)));
  }

  Future<void> _authorize() async {
    final s = AppStrings.read(context);
    final grant = await showKopaySheet<AccountantGrant>(
      context,
      const AuthorizeAccountantSheet(),
    );
    if (grant == null || !mounted) return;
    setState(() {
      final list = [...?_grants]..removeWhere((g) => g.id == grant.id);
      _grants = list..add(grant);
    });
    _notify(s.accountantAuthorized);
  }

  Future<void> _revoke(AccountantGrant grant) async {
    final s = AppStrings.read(context);
    final ok = await showDialog<bool>(
      context: context,
      builder: (dialog) => AlertDialog(
        title: Text(AppStrings.fill(s.revokeTitle, [grant.accountantName])),
        content: Text(s.revokeBody),
        actions: [
          TextButton(
            key: const Key('accountant-revoke-cancel'),
            onPressed: () => Navigator.of(dialog).pop(false),
            child: Text(s.cancel),
          ),
          TextButton(
            key: const Key('accountant-revoke-confirm'),
            onPressed: () => Navigator.of(dialog).pop(true),
            style: TextButton.styleFrom(foregroundColor: AppColors.red),
            child: Text(s.revoke),
          ),
        ],
      ),
    );
    if (ok != true || !mounted) return;

    final session = context.read<SessionProvider>();
    final api = context.read<AccountantsApi>();
    setState(() => _revoking = grant.id);
    try {
      await session.authorized((t) => api.revoke(t, grant.id));
    } on ApiException catch (e) {
      // 404: ya estaba revocado (por ejemplo, en otro dispositivo). El
      // resultado es el mismo, así que se quita de la lista.
      if (e.code != ApiErrorCode.notFound) {
        if (mounted) {
          setState(() => _revoking = null);
          _notify(e.message);
        }
        return;
      }
    } catch (e) {
      if (mounted) {
        setState(() => _revoking = null);
        _notify(_message(e));
      }
      return;
    }
    if (!mounted) return;
    setState(() {
      _revoking = null;
      _grants = [...?_grants]..removeWhere((g) => g.id == grant.id);
    });
    _notify(s.accessRevoked);
  }

  @override
  Widget build(BuildContext context) {
    final s = AppStrings.of(context);
    final grants = _grants ?? const <AccountantGrant>[];
    return Scaffold(
      backgroundColor: AppColors.bg,
      appBar: AppBar(
        backgroundColor: AppColors.bg,
        title: Text(s.accountantsTitle, key: const Key('accountants-title')),
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
          children: [
            Text(
              s.accountantsSubtitle,
              style: TextStyle(fontSize: 14, color: AppColors.text2),
            ),
            const SizedBox(height: 16),
            if (_loading)
              const Padding(
                padding: EdgeInsets.all(24),
                child: Center(
                  child: CircularProgressIndicator(
                    key: Key('accountants-loading'),
                  ),
                ),
              )
            else if (_error != null)
              Container(
                key: const Key('accountants-error'),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppColors.red.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        _error!,
                        style: TextStyle(fontSize: 13, color: AppColors.text),
                      ),
                    ),
                    TextButton(
                      key: const Key('accountants-retry'),
                      onPressed: _load,
                      child: Text(s.retry),
                    ),
                  ],
                ),
              )
            else if (grants.isEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 24),
                child: Text(
                  s.accountantsEmpty,
                  key: const Key('accountants-empty'),
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 14, color: AppColors.text3),
                ),
              )
            else
              Container(
                decoration: BoxDecoration(
                  color: AppColors.surface,
                  borderRadius: BorderRadius.circular(16),
                ),
                clipBehavior: Clip.antiAlias,
                child: Column(
                  children: [
                    for (final (i, g) in grants.indexed) ...[
                      if (i > 0) Divider(height: 1, color: AppColors.hair),
                      _GrantRow(
                        grant: g,
                        busy: _revoking == g.id,
                        onRevoke: () => _revoke(g),
                      ),
                    ],
                  ],
                ),
              ),
            if (!_loading && _error == null)
              SaveButton(
                key: const Key('accountants-authorize'),
                label: s.authorizeAccountant,
                saving: false,
                onPressed: _authorize,
              ),
          ],
        ),
      ),
    );
  }
}

class _GrantRow extends StatelessWidget {
  final AccountantGrant grant;
  final bool busy;
  final VoidCallback onRevoke;

  const _GrantRow({
    required this.grant,
    required this.busy,
    required this.onRevoke,
  });

  @override
  Widget build(BuildContext context) {
    final s = AppStrings.of(context);
    final date = grant.grantedAt.toLocal();
    return Padding(
      key: Key('accountant-${grant.id}'),
      padding: const EdgeInsets.fromLTRB(16, 12, 8, 12),
      child: Row(
        children: [
          Icon(Icons.badge_outlined, color: AppColors.text2, size: 22),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  grant.accountantName,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w500,
                    color: AppColors.text,
                  ),
                ),
                Text(
                  grant.accountantEmail,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(fontSize: 13, color: AppColors.text2),
                ),
                Text(
                  AppStrings.fill(s.grantedOn, [
                    '${FormatUtils.shortDate(date)} ${date.year}',
                  ]),
                  style: TextStyle(fontSize: 12, color: AppColors.text3),
                ),
              ],
            ),
          ),
          TextButton(
            key: Key('accountant-revoke-${grant.id}'),
            onPressed: busy ? null : onRevoke,
            style: TextButton.styleFrom(foregroundColor: AppColors.red),
            child: Text(s.revoke),
          ),
        ],
      ),
    );
  }
}
