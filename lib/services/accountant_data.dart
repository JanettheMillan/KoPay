import '../models/accountant_client.dart';
import '../models/movement_model.dart';
import '../providers/session_provider.dart';
import 'auth_api.dart';
import 'clients_api.dart';

/// La persona ya no autoriza al contador: revocó, o el permiso ya no está
/// vigente (HU-41). La API responde `403` y la pantalla muestra el aviso
/// de acceso retirado y regresa a la lista de clientes, que se recarga.
class ClientAccessRevoked implements Exception {
  const ClientAccessRevoked();
}

/// De dónde leen las pantallas del contador (S5-09): la API con la sesión
/// de contador ([ApiAccountantData]) o los datos de ejemplo de la maqueta
/// de Ajustes (`SampleAccountantData`, S2-19).
abstract class AccountantData {
  /// `true` en la maqueta: las pantallas muestran el aviso de datos de
  /// ejemplo.
  bool get isSample;

  /// Personas que autorizaron al contador y siguen vigentes (HU-39).
  Future<List<ClientInfo>> clients();

  /// Totales del mes de [clientId] (HU-40). Lanza [ClientAccessRevoked]
  /// si ya no hay permiso.
  Future<PeriodSummary> summary(String clientId, DateTime month);

  /// Movimientos e ingresos del mes de [clientId], del más reciente al más
  /// antiguo (HU-40). Lanza [ClientAccessRevoked] si ya no hay permiso.
  Future<List<Movement>> movements(String clientId, DateTime month);
}

/// [AccountantData] de la API (`/api/clients`). Cada consulta pide solo
/// el cliente y el mes que se muestran, y pasa por
/// [SessionProvider.authorized], que renueva el token si venció.
class ApiAccountantData implements AccountantData {
  ApiAccountantData({required this.session, required this.api});

  final SessionProvider session;
  final ClientsApi api;

  @override
  bool get isSample => false;

  @override
  Future<List<ClientInfo>> clients() => session.authorized(api.list);

  @override
  Future<PeriodSummary> summary(String clientId, DateTime month) =>
      _forClient((t) => api.summary(t, clientId, month));

  @override
  Future<List<Movement>> movements(String clientId, DateTime month) =>
      _forClient((t) => api.movements(t, clientId, month));

  Future<T> _forClient<T>(Future<T> Function(String token) call) async {
    try {
      return await session.authorized(call);
    } on ApiException catch (e) {
      // §3.10: el 403 es el mismo si revocó, si no existe o si el id está
      // mal; para el contador, en todos los casos ya no tiene acceso.
      if (e.status == 403) throw const ClientAccessRevoked();
      rethrow;
    }
  }
}
