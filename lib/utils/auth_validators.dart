/// Reglas del registro e inicio de sesión del contrato
/// (docs/contrato-api-acceso.md §3.1 y §3.2). Son las mismas que aplica
/// Node en `backend/src/validators/auth.validator.js`; la app las revisa
/// antes de enviar (S3-10, S3-11), pero la API decide.
class AuthValidators {
  AuthValidators._();

  static const String nameRequired = 'Escribe tu nombre';
  static const String nameTooLong = 'El nombre puede tener hasta 80 caracteres';
  static const String emailInvalid = 'Escribe un correo válido';
  static const String passwordRequired = 'Escribe tu contraseña';
  static const String emailRequired = 'Escribe tu correo';
  static const String passwordTooShort =
      'La contraseña debe tener al menos 8 caracteres';
  static const String passwordTooLong =
      'La contraseña puede tener hasta 72 caracteres';
  static const String passwordWeak =
      'La contraseña debe tener al menos una letra y un número';

  static const int nameMax = 80;
  static const int emailMax = 254;
  static const int passwordMin = 8;
  static const int passwordMax = 72;

  /// `texto@dominio.ext`, sin espacios ni una segunda arroba.
  static final RegExp _email = RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]+$');
  static final RegExp _letter = RegExp(r'\p{L}', unicode: true);
  static final RegExp _digit = RegExp(r'\d');

  /// Correo sin espacios al inicio o al final y en minúsculas.
  static String normalizeEmail(String? email) =>
      (email ?? '').trim().toLowerCase();

  /// Longitud en caracteres; un emoji cuenta como uno, igual que en Node.
  static int _length(String text) => text.runes.length;

  static String? name(String? text) {
    final value = (text ?? '').trim();
    if (value.isEmpty) return nameRequired;
    if (_length(value) > nameMax) return nameTooLong;
    return null;
  }

  static String? email(String? text) {
    final value = normalizeEmail(text);
    if (value.length > emailMax || !_email.hasMatch(value)) return emailInvalid;
    return null;
  }

  /// Contraseña del registro. No se recorta: los espacios cuentan.
  static String? newPassword(String? text) {
    final value = text ?? '';
    if (_length(value) < passwordMin) return passwordTooShort;
    if (_length(value) > passwordMax) return passwordTooLong;
    if (!_letter.hasMatch(value) || !_digit.hasMatch(value)) {
      return passwordWeak;
    }
    return null;
  }

  /// Contraseña del login: solo obligatoria (contrato §3.2).
  static String? password(String? text) =>
      (text ?? '').isEmpty ? passwordRequired : null;

  /// Todos los errores del registro a la vez, como `fields` de la API.
  static Map<String, String> registration({
    required String name,
    required String email,
    required String password,
  }) {
    final nameError = AuthValidators.name(name);
    final emailError = AuthValidators.email(email);
    final passwordError = newPassword(password);
    return {
      'name': ?nameError,
      'email': ?emailError,
      'password': ?passwordError,
    };
  }
}
