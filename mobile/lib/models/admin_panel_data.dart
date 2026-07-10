import 'app_role.dart';

/// Datos de vista previa del panel de administracion.
/// Se reemplazaran por endpoints reales cuando el backend este disponible.
class AdminUserRecord {
  const AdminUserRecord({
    required this.id,
    required this.fullName,
    required this.email,
    required this.role,
    required this.isActive,
    required this.lastActivityLabel,
  });

  final String id;
  final String fullName;
  final String email;
  final AppRole role;
  final bool isActive;
  final String lastActivityLabel;
}

class AdminDashboardStats {
  const AdminDashboardStats({
    required this.totalUsers,
    required this.activeUsers,
    required this.activeLinks,
    required this.compliancePercent,
    required this.openIncidents,
  });

  final int totalUsers;
  final int activeUsers;
  final int activeLinks;
  final int compliancePercent;
  final int openIncidents;
}

class AdminReportMetric {
  const AdminReportMetric({
    required this.label,
    required this.value,
    required this.detail,
  });

  final String label;
  final double value;
  final String detail;
}

enum AdminModuleStatus { operational, pending, degraded }

class AdminSystemModule {
  const AdminSystemModule({
    required this.name,
    required this.description,
    required this.status,
  });

  final String name;
  final String description;
  final AdminModuleStatus status;
}

class AdminPanelData {
  AdminPanelData._();

  static const _users = [
    AdminUserRecord(
      id: '1',
      fullName: 'Roberto Andrade',
      email: 'roberto@uleam.edu.ec',
      role: AppRole.patient,
      isActive: true,
      lastActivityLabel: 'Hace 2 h',
    ),
    AdminUserRecord(
      id: '2',
      fullName: 'Carla Mendoza',
      email: 'carla.cuidador@uleam.edu.ec',
      role: AppRole.caregiver,
      isActive: true,
      lastActivityLabel: 'Hace 35 min',
    ),
    AdminUserRecord(
      id: '3',
      fullName: 'Dr. Luis Paredes',
      email: 'l.paredes@uleam.edu.ec',
      role: AppRole.professional,
      isActive: true,
      lastActivityLabel: 'Ayer',
    ),
    AdminUserRecord(
      id: '4',
      fullName: 'Ana Villacis',
      email: 'ana.admin@uleam.edu.ec',
      role: AppRole.admin,
      isActive: true,
      lastActivityLabel: 'En linea',
    ),
    AdminUserRecord(
      id: '5',
      fullName: 'Maria Soto',
      email: 'maria.soto@uleam.edu.ec',
      role: AppRole.patient,
      isActive: false,
      lastActivityLabel: 'Hace 12 dias',
    ),
  ];

  static List<AdminUserRecord> users({AppRole? role, String query = ''}) {
    final normalized = query.trim().toLowerCase();
    return _users.where((user) {
      final matchesRole = role == null || user.role == role;
      final matchesQuery = normalized.isEmpty ||
          user.fullName.toLowerCase().contains(normalized) ||
          user.email.toLowerCase().contains(normalized);
      return matchesRole && matchesQuery;
    }).toList();
  }

  static AdminDashboardStats dashboardStats() {
    final activeUsers = _users.where((user) => user.isActive).length;
    return AdminDashboardStats(
      totalUsers: _users.length,
      activeUsers: activeUsers,
      activeLinks: 3,
      compliancePercent: 78,
      openIncidents: 1,
    );
  }

  static const reportMetrics = [
    AdminReportMetric(
      label: 'Pacientes con medicamentos',
      value: 0.82,
      detail: '41 de 50 cuentas activas',
    ),
    AdminReportMetric(
      label: 'Cumplimiento semanal',
      value: 0.78,
      detail: 'Promedio de tomas confirmadas',
    ),
    AdminReportMetric(
      label: 'Vinculos cuidador activos',
      value: 0.64,
      detail: '32 vinculos aprobados',
    ),
    AdminReportMetric(
      label: 'Alertas resueltas',
      value: 0.91,
      detail: 'Ultimos 30 dias',
    ),
  ];

  static const systemModules = [
    AdminSystemModule(
      name: 'API FastAPI',
      description: 'Autenticacion, medicamentos y vinculacion cuidador.',
      status: AdminModuleStatus.operational,
    ),
    AdminSystemModule(
      name: 'Almacenamiento de fotos',
      description: 'Supabase Storage o almacenamiento local del backend.',
      status: AdminModuleStatus.operational,
    ),
    AdminSystemModule(
      name: 'Administracion de usuarios',
      description: 'Listado, roles y activacion de cuentas.',
      status: AdminModuleStatus.pending,
    ),
    AdminSystemModule(
      name: 'Reportes globales',
      description: 'Metricas agregadas de cumplimiento e incidencias.',
      status: AdminModuleStatus.pending,
    ),
    AdminSystemModule(
      name: 'Correo y notificaciones',
      description: 'Recuperacion de contrasena y alertas push.',
      status: AdminModuleStatus.degraded,
    ),
  ];
}
