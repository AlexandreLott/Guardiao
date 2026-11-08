import 'package:shared_preferences/shared_preferences.dart';

/// Para que este aparelho é usado. Escolhido uma vez, no primeiro acesso.
enum DeviceRole {
  /// Aparelho do pai/mãe: vê os apps do filho e define limites.
  parent,

  /// Aparelho da criança ou do adolescente: mostra o tempo restante e aplica
  /// os limites.
  child;

  static DeviceRole? parse(String? value) {
    for (final role in values) {
      if (role.name == value) return role;
    }
    return null;
  }
}

/// Guarda a função escolhida neste aparelho.
abstract class RoleStore {
  Future<DeviceRole?> read();

  /// `null` apaga a escolha (volta para a tela de escolha).
  Future<void> write(DeviceRole? role);
}

/// Guarda no próprio aparelho (preferências do Android/Windows).
class SharedPrefsRoleStore implements RoleStore {
  static const _key = 'device_role';

  @override
  Future<DeviceRole?> read() async {
    final prefs = await SharedPreferences.getInstance();
    return DeviceRole.parse(prefs.getString(_key));
  }

  @override
  Future<void> write(DeviceRole? role) async {
    final prefs = await SharedPreferences.getInstance();
    if (role == null) {
      await prefs.remove(_key);
    } else {
      await prefs.setString(_key, role.name);
    }
  }
}

/// Usada em testes.
class MemoryRoleStore implements RoleStore {
  MemoryRoleStore([this._role]);

  DeviceRole? _role;

  @override
  Future<DeviceRole?> read() async => _role;

  @override
  Future<void> write(DeviceRole? role) async => _role = role;
}
