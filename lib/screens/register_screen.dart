import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../services/auth_api.dart';
import '../utils/app_colors.dart';
import '../utils/app_strings.dart';
import '../utils/auth_validators.dart';
import '../widgets/ui_kit.dart';

/// Crear cuenta (S3-10, HU-30).
///
/// Revisa los tres campos a la vez antes de enviar, con las reglas del
/// contrato (S3-13). Mientras envía, bloquea el formulario y muestra el
/// progreso. Si la API responde con errores, los muestra bajo cada campo
/// (`VALIDATION_FAILED`, `EMAIL_TAKEN`) o arriba del formulario (sin red,
/// `INTERNAL`, `UNAVAILABLE`), y permite reintentar.
///
/// El registro no abre sesión: al terminar, la pantalla se cierra y
/// devuelve el correo para que Iniciar sesión (S3-11) lo deje escrito.
class RegisterScreen extends StatefulWidget {
  /// API que se usa; si es `null`, se lee [AuthApi] del árbol.
  final AuthApi? api;

  const RegisterScreen({super.key, this.api});

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  final _formKey = GlobalKey<FormState>();
  final _name = TextEditingController();
  final _email = TextEditingController();
  final _password = TextEditingController();

  bool _submitted = false;
  bool _sending = false;
  bool _showPassword = false;

  /// Errores que devolvió la API, por campo. Se borran al editar el campo.
  Map<String, String> _serverFields = const {};

  /// Error general arriba del formulario.
  String? _banner;

  @override
  void dispose() {
    _name.dispose();
    _email.dispose();
    _password.dispose();
    super.dispose();
  }

  String? Function(String?) _validator(
    String field,
    String? Function(String?) local,
  ) {
    return (text) => _serverFields[field] ?? local(text);
  }

  void _clearServerError(String field) {
    if (_serverFields.containsKey(field) || _banner != null) {
      setState(() {
        _serverFields = Map.of(_serverFields)..remove(field);
        _banner = null;
      });
    }
  }

  Future<void> _submit() async {
    FocusScope.of(context).unfocus();
    setState(() {
      _submitted = true;
      _serverFields = const {};
      _banner = null;
    });
    if (!_formKey.currentState!.validate()) return;

    final api = widget.api ?? context.read<AuthApi>();
    final navigator = Navigator.of(context);
    setState(() => _sending = true);
    try {
      final user = await api.register(
        name: _name.text.trim(),
        email: AuthValidators.normalizeEmail(_email.text),
        password: _password.text,
      );
      if (!mounted) return;
      navigator.pop(user.email);
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() {
        _sending = false;
        if (e.code == ApiErrorCode.validationFailed && e.fields.isNotEmpty) {
          _serverFields = e.fields;
        } else if (e.code == ApiErrorCode.emailTaken) {
          _serverFields = {'email': e.message};
        } else {
          _banner = e.message;
        }
      });
      _formKey.currentState!.validate();
    } catch (_) {
      // Sin red, tiempo agotado o respuesta que no es JSON (contrato §2).
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
    return Scaffold(
      backgroundColor: AppColors.bg,
      appBar: AppBar(
        backgroundColor: AppColors.bg,
        foregroundColor: AppColors.text,
        elevation: 0,
      ),
      body: SafeArea(
        top: false,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(24, 0, 24, 32),
          children: [
            Text(
              s.registerTitle,
              key: const Key('register-title'),
              style: TextStyle(
                fontSize: 28,
                fontWeight: FontWeight.w700,
                color: AppColors.text,
                letterSpacing: -0.8,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              s.registerSubtitle,
              style: TextStyle(fontSize: 14, color: AppColors.text2),
            ),
            const SizedBox(height: 12),
            if (_banner != null)
              Container(
                key: const Key('register-banner'),
                margin: const EdgeInsets.only(top: 8),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppColors.red.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  children: [
                    Icon(
                      Icons.error_outline_rounded,
                      size: 18,
                      color: AppColors.red,
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        _banner!,
                        style: TextStyle(fontSize: 13, color: AppColors.text),
                      ),
                    ),
                  ],
                ),
              ),
            Form(
              key: _formKey,
              autovalidateMode: _submitted
                  ? AutovalidateMode.onUserInteraction
                  : AutovalidateMode.disabled,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  FieldLabel(s.nameLabel),
                  TextFormField(
                    key: const Key('register-name'),
                    controller: _name,
                    enabled: !_sending,
                    textCapitalization: TextCapitalization.words,
                    textInputAction: TextInputAction.next,
                    autofillHints: const [AutofillHints.name],
                    decoration: InputDecoration(hintText: s.nameHint),
                    onChanged: (_) => _clearServerError('name'),
                    validator: _validator('name', AuthValidators.name),
                  ),
                  FieldLabel(s.emailLabel),
                  TextFormField(
                    key: const Key('register-email'),
                    controller: _email,
                    enabled: !_sending,
                    keyboardType: TextInputType.emailAddress,
                    textInputAction: TextInputAction.next,
                    autocorrect: false,
                    autofillHints: const [AutofillHints.email],
                    decoration: InputDecoration(hintText: s.emailHint),
                    onChanged: (_) => _clearServerError('email'),
                    validator: _validator('email', AuthValidators.email),
                  ),
                  FieldLabel(s.passwordLabel),
                  TextFormField(
                    key: const Key('register-password'),
                    controller: _password,
                    enabled: !_sending,
                    obscureText: !_showPassword,
                    textInputAction: TextInputAction.done,
                    autocorrect: false,
                    enableSuggestions: false,
                    autofillHints: const [AutofillHints.newPassword],
                    decoration: InputDecoration(
                      hintText: s.passwordHint,
                      suffixIcon: IconButton(
                        key: const Key('register-toggle-password'),
                        tooltip: _showPassword
                            ? s.hidePassword
                            : s.showPassword,
                        icon: Icon(
                          _showPassword
                              ? Icons.visibility_off_outlined
                              : Icons.visibility_outlined,
                          color: AppColors.text2,
                        ),
                        onPressed: () =>
                            setState(() => _showPassword = !_showPassword),
                      ),
                    ),
                    onChanged: (_) => _clearServerError('password'),
                    onFieldSubmitted: (_) => _sending ? null : _submit(),
                    validator: _validator(
                      'password',
                      AuthValidators.newPassword,
                    ),
                  ),
                  SaveButton(
                    key: const Key('register-submit'),
                    label: s.createAccount,
                    saving: _sending,
                    onPressed: _submit,
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            TextButton(
              key: const Key('register-to-login'),
              onPressed: _sending ? null : () => Navigator.of(context).pop(),
              child: Text(s.haveAccount),
            ),
          ],
        ),
      ),
    );
  }
}
