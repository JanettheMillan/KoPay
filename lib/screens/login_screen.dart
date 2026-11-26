import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../providers/session_provider.dart';
import '../services/auth_api.dart';
import '../utils/app_colors.dart';
import '../utils/app_strings.dart';
import '../utils/auth_validators.dart';
import '../widgets/ui_kit.dart';
import 'register_screen.dart';

/// Iniciar sesión (S3-11, HU-31).
///
/// Pide correo y contraseña. Aquí solo se revisa que no falten: las
/// reglas de longitud son del registro (contrato §3.2). Inicia sesión con
/// [SessionProvider.login], que guarda la sesión en el dispositivo
/// (S4-08). Quién abre la vista del rol después es la navegación (S3-12),
/// que escucha [SessionProvider.status].
///
/// Errores según el `code` del contrato (§2):
/// - `VALIDATION_FAILED`: bajo cada campo.
/// - `INVALID_CREDENTIALS`: arriba del formulario, y limpia la contraseña.
/// - `TOO_MANY_ATTEMPTS`, `INTERNAL`, `UNAVAILABLE` o sin red: arriba, y
///   permite reintentar.
///
/// Nunca muestra la contraseña ni dice si el correo tiene cuenta.
class LoginScreen extends StatefulWidget {
  /// Correo que llega escrito, por ejemplo al volver de Crear cuenta.
  final String? initialEmail;

  /// Se llama después de iniciar sesión. La navegación de S3-12 no lo
  /// necesita; sirve para abrir esta pantalla sola.
  final VoidCallback? onSignedIn;

  const LoginScreen({super.key, this.initialEmail, this.onSignedIn});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

/// Cuánto se desactiva el botón después de un `429 TOO_MANY_ATTEMPTS`
/// (contrato §2: "desactiva el botón un momento", D-12).
const Duration loginRetryDelay = Duration(seconds: 30);

class _LoginScreenState extends State<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _email;
  final _password = TextEditingController();

  bool _submitted = false;
  bool _sending = false;

  /// Activo mientras dura la espera después de un `429` (D-12).
  Timer? _retryTimer;
  bool get _waiting => _retryTimer?.isActive ?? false;
  bool _showPassword = false;
  Map<String, String> _serverFields = const {};
  String? _banner;

  @override
  void initState() {
    super.initState();
    _email = TextEditingController(text: widget.initialEmail ?? '');
  }

  @override
  void dispose() {
    _retryTimer?.cancel();
    _email.dispose();
    _password.dispose();
    super.dispose();
  }

  static String? _requiredEmail(String? text) =>
      AuthValidators.normalizeEmail(text).isEmpty
      ? AuthValidators.emailRequired
      : null;

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

    final session = context.read<SessionProvider>();
    setState(() => _sending = true);
    try {
      await session.login(
        email: AuthValidators.normalizeEmail(_email.text),
        password: _password.text,
      );
      if (!mounted) return;
      setState(() => _sending = false);
      widget.onSignedIn?.call();
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() {
        _sending = false;
        if (e.code == ApiErrorCode.validationFailed && e.fields.isNotEmpty) {
          _serverFields = e.fields;
        } else {
          _banner = e.message;
          // Contrato §2: con credenciales incorrectas se limpia la
          // contraseña. El aviso de arriba basta: no se marca el campo
          // vacío hasta el siguiente intento.
          if (e.code == ApiErrorCode.invalidCredentials) {
            _password.clear();
            _submitted = false;
          }
          // Contrato §2: con 429 se desactiva el botón un momento (D-12).
          if (e.code == ApiErrorCode.tooManyAttempts) {
            _retryTimer?.cancel();
            _retryTimer = Timer(loginRetryDelay, () {
              if (mounted) setState(() {});
            });
          }
        }
      });
      if (_serverFields.isNotEmpty) _formKey.currentState!.validate();
    } catch (_) {
      // Sin red, tiempo agotado o respuesta que no es JSON (contrato §2).
      if (!mounted) return;
      setState(() {
        _sending = false;
        _banner = NetworkException.message;
      });
    }
  }

  /// Abre Crear cuenta. Si se registra, regresa con el correo escrito.
  Future<void> _openRegister() async {
    final email = await Navigator.of(
      context,
    ).push<String>(MaterialPageRoute(builder: (_) => const RegisterScreen()));
    if (email != null && mounted) {
      setState(() {
        _email.text = email;
        _password.clear();
        _banner = null;
        _serverFields = const {};
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final s = AppStrings.of(context);
    final expired = context.select<SessionProvider, bool>(
      (p) => p.sessionExpired,
    );
    return Scaffold(
      backgroundColor: AppColors.bg,
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(24, 32, 24, 32),
          children: [
            Text(
              s.loginTitle,
              key: const Key('login-title'),
              style: TextStyle(
                fontSize: 28,
                fontWeight: FontWeight.w700,
                color: AppColors.text,
                letterSpacing: -0.8,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              s.loginSubtitle,
              style: TextStyle(fontSize: 14, color: AppColors.text2),
            ),
            const SizedBox(height: 12),
            if (expired && _banner == null)
              _Notice(
                key: const Key('login-expired'),
                text: s.sessionExpiredNotice,
                color: AppColors.text2,
                icon: Icons.info_outline_rounded,
              ),
            if (_banner != null)
              _Notice(
                key: const Key('login-banner'),
                text: _banner!,
                color: AppColors.red,
                icon: Icons.error_outline_rounded,
              ),
            Form(
              key: _formKey,
              autovalidateMode: _submitted
                  ? AutovalidateMode.onUserInteraction
                  : AutovalidateMode.disabled,
              child: AutofillGroup(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    FieldLabel(s.emailLabel),
                    TextFormField(
                      key: const Key('login-email'),
                      controller: _email,
                      enabled: !_sending,
                      keyboardType: TextInputType.emailAddress,
                      textInputAction: TextInputAction.next,
                      autocorrect: false,
                      autofillHints: const [AutofillHints.email],
                      decoration: InputDecoration(hintText: s.emailHint),
                      onChanged: (_) => _clearServerError('email'),
                      validator: _validator('email', _requiredEmail),
                    ),
                    FieldLabel(s.passwordLabel),
                    TextFormField(
                      key: const Key('login-password'),
                      controller: _password,
                      enabled: !_sending,
                      obscureText: !_showPassword,
                      textInputAction: TextInputAction.done,
                      autocorrect: false,
                      enableSuggestions: false,
                      autofillHints: const [AutofillHints.password],
                      decoration: InputDecoration(
                        suffixIcon: IconButton(
                          key: const Key('login-toggle-password'),
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
                      onFieldSubmitted: (_) =>
                          _sending || _waiting ? null : _submit(),
                      validator: _validator(
                        'password',
                        AuthValidators.password,
                      ),
                    ),
                    SaveButton(
                      key: const Key('login-submit'),
                      label: s.signIn,
                      saving: _sending,
                      onPressed: _waiting ? null : _submit,
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 12),
            TextButton(
              key: const Key('login-to-register'),
              onPressed: _sending ? null : _openRegister,
              child: Text(s.noAccount),
            ),
          ],
        ),
      ),
    );
  }
}

class _Notice extends StatelessWidget {
  final String text;
  final Color color;
  final IconData icon;

  const _Notice({
    super.key,
    required this.text,
    required this.color,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(top: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Icon(icon, size: 18, color: color),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              text,
              style: TextStyle(fontSize: 13, color: AppColors.text),
            ),
          ),
        ],
      ),
    );
  }
}
