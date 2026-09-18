import 'package:flutter/foundation.dart';

/// Proveedor de estado global para el espacio de trabajo activo.
///
/// Almacena el [tenantId] del espacio seleccionado (y su nombre visible)
/// y notifica a todos los widgets que dependan de este valor cuando cambia.
class TenantProvider extends ChangeNotifier {
  int? _tenantId;
  String? _workspaceName;

  /// El ID del tenant activo, o `null` si no se ha seleccionado ninguno.
  int? get tenantId => _tenantId;

  /// Nombre visible del espacio activo (ya resuelto, con su fallback).
  String? get workspaceName => _workspaceName;

  /// `true` si hay un espacio seleccionado.
  bool get hasTenant => _tenantId != null;

  /// Establece el espacio activo (con su nombre visible) y notifica.
  void setTenant(int id, {required String name}) {
    _tenantId = id;
    _workspaceName = name;
    notifyListeners();
  }

  /// Actualiza solo el nombre visible del espacio activo (tras renombrarlo).
  void updateWorkspaceName(String name) {
    _workspaceName = name;
    notifyListeners();
  }

  /// Limpia el espacio activo (cerrar sesión) y notifica a los listeners.
  void clearTenant() {
    _tenantId = null;
    _workspaceName = null;
    notifyListeners();
  }
}
