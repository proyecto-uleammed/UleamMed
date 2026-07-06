import 'local_store.dart';

/// Guarda y valida el PIN local de bloqueo (PB-053).
/// El PIN se persiste en almacenamiento seguro cifrado del dispositivo.
class LockService {
  LockService({JsonStore? store}) : _store = store ?? SecureJsonStore();

  final JsonStore _store;

  static const _key = 'uleammed_app_pin';

  Future<bool> hasPin() async {
    try {
      final value = await _store.read(_key);
      return value != null && value.isNotEmpty;
    } catch (_) {
      return false;
    }
  }

  Future<void> setPin(String pin) async {
    await _store.write(_key, pin);
  }

  Future<bool> verifyPin(String pin) async {
    try {
      return (await _store.read(_key)) == pin;
    } catch (_) {
      return false;
    }
  }

  Future<void> clearPin() async {
    try {
      await _store.delete(_key);
    } catch (_) {
      // Ignorar si no existe.
    }
  }
}
