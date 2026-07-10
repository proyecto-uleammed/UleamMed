import 'package:flutter/material.dart';

import '../../models/admin_panel_data.dart';
import '../../theme/app_theme.dart';
import '../../widgets/role_dashboard.dart';

class AdminReportsScreen extends StatefulWidget {
  const AdminReportsScreen({super.key});

  @override
  State<AdminReportsScreen> createState() => _AdminReportsScreenState();
}

class _AdminReportsScreenState extends State<AdminReportsScreen> {
  late AdminDashboardStats _stats = AdminPanelData.dashboardStats();

  Future<void> _refresh() async {
    setState(() {
      _stats = AdminPanelData.dashboardStats();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Reportes'),
      ),
      body: RefreshIndicator(
        onRefresh: _refresh,
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
          children: [
            Text(
              'Vista previa de metricas globales',
              style: Theme.of(context).textTheme.bodyMedium,
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                RoleSummaryCard(
                  icon: Icons.people_outline,
                  label: 'Usuarios activos',
                  value: '${_stats.activeUsers}',
                  color: const Color(0xFF37474F),
                ),
                const SizedBox(width: 12),
                RoleSummaryCard(
                  icon: Icons.link,
                  label: 'Vinculos',
                  value: '${_stats.activeLinks}',
                  color: const Color(0xFF546E7A),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                RoleSummaryCard(
                  icon: Icons.check_circle_outline,
                  label: 'Cumplimiento',
                  value: '${_stats.compliancePercent}%',
                  color: AppColors.primary,
                ),
                const SizedBox(width: 12),
                RoleSummaryCard(
                  icon: Icons.report_problem_outlined,
                  label: 'Incidencias',
                  value: '${_stats.openIncidents}',
                  color: const Color(0xFFF57C00),
                ),
              ],
            ),
            const SizedBox(height: 24),
            Text(
              'Indicadores clave',
              style: Theme.of(context).textTheme.headlineMedium,
            ),
            const SizedBox(height: 12),
            ...AdminPanelData.reportMetrics.map(
              (metric) => _ReportMetricCard(metric: metric),
            ),
            const SizedBox(height: 16),
            Card(
              child: ListTile(
                leading: const Icon(Icons.info_outline),
                title: const Text('Datos de demostracion'),
                subtitle: Text(
                  'Los reportes reales se conectaran al backend de '
                  'administracion cuando este disponible.',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ReportMetricCard extends StatelessWidget {
  const _ReportMetricCard({required this.metric});

  final AdminReportMetric metric;

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    metric.label,
                    style: const TextStyle(fontWeight: FontWeight.w600),
                  ),
                ),
                Text('${(metric.value * 100).round()}%'),
              ],
            ),
            const SizedBox(height: 8),
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: LinearProgressIndicator(
                value: metric.value,
                minHeight: 8,
                backgroundColor: AppColors.surface,
                color: const Color(0xFF546E7A),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              metric.detail,
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ],
        ),
      ),
    );
  }
}
