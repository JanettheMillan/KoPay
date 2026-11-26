import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../providers/session_provider.dart';
import '../services/accountants_api.dart';
import '../services/auth_api.dart';
import '../utils/app_colors.dart';
import '../utils/app_strings.dart';
import '../utils/auth_validators.dart';
import 'ui_kit.dart';

/// Autorizar a un contador por su correo (S4-11, HU-38).
///
/// Sigue el consentimiento de docs/navegacion-usuario-contador.md §3:
/// 1. Se escribe el correo; si no es válido no se envía nada.
/// 2. Un diálogo dice quién recibe el permiso, qué verá (resumen e
///    historial), que es de solo lectura y que se puede revocar.
/// 3. Solo **Confirmar** llama a `POST /api/accountants`. **Cancelar** no
///    guarda nada y deja la hoja abierta.
/// 4. Si no hay un contador con ese correo (`404`), el error se muestra
///    bajo el campo y no se crea nada.
///
/// Cierra la hoja con el [AccountantGrant] creado.
class AuthorizeAccountantSheet extends StatefulWidget {
  const AuthorizeAccountantSheet({super.key});

  @override
  State<AuthorizeAccountantSheet> createState() =>
      _AuthorizeAccountantSheetState();
}

class _AuthorizeAccountantSheetState extends State<AuthorizeAccountantSheet> {
  final _formKey = GlobalKey<FormState>();
  final _email = TextEditingController();
  bool _sending = false;
  bool _submitted = false;
  String? _serverError;
  String? _banner;

  @override
  void dispose() {
    _email.dispose();
    super.dispose();
  }

  String? _validate(String? text) => _serverError ?? AuthValidators.email(text);

  Future<bool> _confirm(String email) async {
    final s = AppStrings.read(context);
    final ok = await showDialog<bool>(
      context: context,
      builder: (dialog) => AlertDialog(
        key: const Key('authorize-confirm-dialog'),
        title: Text(AppStrings.fill(s.authorizeConfirmTitle, [email])),
        content: Text(s.authorizeConfirmBody),
        actions: [
          TextButton(
            key: const Key('authorize-cancel'),
            onPressed: () => Navigator.of(dialog).pop(false),
            child: Text(s.cancel),
          ),
          TextButton(
            key: const Key('authorize-confirm'),
            onPressed: () => Navigator.of(dialog).pop(true),
            child: Text(s.confirm),
          ),
        ],
      ),
    );
    return ok == true;
  }

  Future<void> _submit() async {
    setState(() {
      _submitted = true;
      _serverError = null;
      _banner = null;
    });
    if (!_formKey.currentState!.validate()) return;
    final email = AuthValidators.normalizeEmail(_email.text);
    if (!await _confirm(email) || !mounted) return;

    final session = context.read<SessionProvider>();
    final api = context.read<AccountantsApi>();
    setState(() => _sending = true);
    try {
      final grant = await session.authorized((t) => api.grant(t, email));
      if (mounted) Navigator.of(context).pop(grant);
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() {
        _sending = false;
        if (e.code == ApiErrorCode.notFound) {
          _serverError = e.message;
        } else if (e.fields['accountantEmail'] != null) {
          _serverError = e.fields['accountantEmail'];
        } else {
          _banner = e.message;
        }
      });
      if (_serverError != null) _formKey.currentState!.validate();
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _sending = false;
        _banner = NetworkException.message;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final s = AppStrings.of(context);
    return KopaySheet(
      title: s.authorizeAccountant,
      child: Form(
        key: _formKey,
        autovalidateMode: _submitted
            ? AutovalidateMode.onUserInteraction
            : AutovalidateMode.disabled,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              s.accountantsSubtitle,
              style: TextStyle(fontSize: 13, color: AppColors.text2),
            ),
            if (_banner != null)
              Container(
                key: const Key('authorize-banner'),
                margin: const EdgeInsets.only(top: 12),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppColors.red.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  _banner!,
                  style: TextStyle(fontSize: 13, color: AppColors.text),
                ),
              ),
            FieldLabel(s.accountantEmailLabel),
            TextFormField(
              key: const Key('authorize-email'),
              controller: _email,
              enabled: !_sending,
              keyboardType: TextInputType.emailAddress,
              textInputAction: TextInputAction.done,
              autocorrect: false,
              decoration: InputDecoration(hintText: s.accountantEmailHint),
              onChanged: (_) {
                if (_serverError != null) setState(() => _serverError = null);
              },
              onFieldSubmitted: (_) => _sending ? null : _submit(),
              validator: _validate,
            ),
            SaveButton(
              key: const Key('authorize-continue'),
              label: s.continueLabel,
              saving: _sending,
              onPressed: _submit,
            ),
          ],
        ),
      ),
    );
  }
}
