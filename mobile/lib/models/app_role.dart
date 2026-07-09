enum AppRole {
  patient('Paciente'),
  caregiver('Cuidador'),
  professional('Medico'),
  admin('Administrador'),
  unknown('Rol no reconocido');

  const AppRole(this.label);

  final String label;

  static AppRole fromJson(Object? value) {
    return AppRole.values.firstWhere(
      (role) => role.name == value,
      orElse: () => AppRole.unknown,
    );
  }
}
