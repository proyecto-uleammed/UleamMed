import 'package:flutter/material.dart';

import '../../models/admin_panel_data.dart';
import '../../models/app_role.dart';
import '../../theme/app_theme.dart';
import '../../widgets/app_states.dart';

class AdminUsersScreen extends StatefulWidget {
  const AdminUsersScreen({super.key});

  @override
  State<AdminUsersScreen> createState() => _AdminUsersScreenState();
}

class _AdminUsersScreenState extends State<AdminUsersScreen> {
  final _searchController = TextEditingController();
  AppRole? _roleFilter;

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  List<AdminUserRecord> get _users => AdminPanelData.users(
    role: _roleFilter,
    query: _searchController.text,
  );

  void _reload() => setState(() {});

  void _showPendingAction(String action) {
    showAppSnackBar(
      context,
      '$action estara disponible cuando el modulo de administracion '
      'del backend este listo.',
    );
  }

  @override
  Widget build(BuildContext context) {
    final users = _users;
    return Scaffold(
      appBar: AppBar(
        title: const Text('Gestion de usuarios'),
        actions: [
          IconButton(
            tooltip: 'Actualizar',
            onPressed: _reload,
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        heroTag: 'admin-invite-user',
        onPressed: () => _showPendingAction('La invitacion de usuarios'),
        icon: const Icon(Icons.person_add_alt_1),
        label: const Text('Invitar'),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
            child: TextField(
              controller: _searchController,
              onChanged: (_) => setState(() {}),
              decoration: InputDecoration(
                hintText: 'Buscar por nombre o correo',
                prefixIcon: const Icon(Icons.search),
                suffixIcon: _searchController.text.isEmpty
                    ? null
                    : IconButton(
                        onPressed: () {
                          _searchController.clear();
                          setState(() {});
                        },
                        icon: const Icon(Icons.clear),
                      ),
                border: const OutlineInputBorder(),
              ),
            ),
          ),
          SizedBox(
            height: 48,
            child: ListView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              children: [
                _RoleFilterChip(
                  label: 'Todos',
                  selected: _roleFilter == null,
                  onSelected: () => setState(() => _roleFilter = null),
                ),
                ...AppRole.values
                    .where(
                      (role) =>
                          role != AppRole.unknown &&
                          role != AppRole.admin,
                    )
                    .map(
                      (role) => _RoleFilterChip(
                        label: role.label,
                        selected: _roleFilter == role,
                        onSelected: () => setState(() => _roleFilter = role),
                      ),
                    ),
                _RoleFilterChip(
                  label: AppRole.admin.label,
                  selected: _roleFilter == AppRole.admin,
                  onSelected: () => setState(() => _roleFilter = AppRole.admin),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
            child: Align(
              alignment: Alignment.centerLeft,
              child: Text(
                'Vista previa · ${users.length} usuario(s)',
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ),
          ),
          Expanded(
            child: users.isEmpty
                ? const EmptyStateView(
                    icon: Icons.manage_accounts_outlined,
                    title: 'Sin resultados',
                    message:
                        'No hay usuarios que coincidan con la busqueda actual.',
                  )
                : RefreshIndicator(
                    onRefresh: () async => _reload(),
                    child: ListView.separated(
                      padding: const EdgeInsets.fromLTRB(16, 12, 16, 96),
                      itemCount: users.length,
                      separatorBuilder: (_, _) => const SizedBox(height: 10),
                      itemBuilder: (context, index) {
                        final user = users[index];
                        return _AdminUserCard(
                          user: user,
                          onToggleActive: () => _showPendingAction(
                            user.isActive
                                ? 'La desactivacion de cuentas'
                                : 'La activacion de cuentas',
                          ),
                          onChangeRole: () =>
                              _showPendingAction('El cambio de rol'),
                        );
                      },
                    ),
                  ),
          ),
        ],
      ),
    );
  }
}

class _RoleFilterChip extends StatelessWidget {
  const _RoleFilterChip({
    required this.label,
    required this.selected,
    required this.onSelected,
  });

  final String label;
  final bool selected;
  final VoidCallback onSelected;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: FilterChip(
        label: Text(label),
        selected: selected,
        onSelected: (_) => onSelected(),
      ),
    );
  }
}

class _AdminUserCard extends StatelessWidget {
  const _AdminUserCard({
    required this.user,
    required this.onToggleActive,
    required this.onChangeRole,
  });

  final AdminUserRecord user;
  final VoidCallback onToggleActive;
  final VoidCallback onChangeRole;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 12, 8, 8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                CircleAvatar(
                  backgroundColor: const Color(0xFF546E7A).withValues(alpha: 0.2),
                  child: Text(
                    user.fullName.characters.first.toUpperCase(),
                    style: const TextStyle(
                      color: Color(0xFF37474F),
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        user.fullName,
                        style: const TextStyle(
                          fontWeight: FontWeight.w700,
                          fontSize: 16,
                        ),
                      ),
                      Text(user.email),
                      const SizedBox(height: 4),
                      Text(
                        'Ultima actividad: ${user.lastActivityLabel}',
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    ],
                  ),
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Chip(
                      label: Text(user.role.label),
                      visualDensity: VisualDensity.compact,
                    ),
                    Chip(
                      label: Text(user.isActive ? 'Activo' : 'Inactivo'),
                      backgroundColor: user.isActive
                          ? AppColors.primaryLight.withValues(alpha: 0.25)
                          : AppColors.surface,
                      visualDensity: VisualDensity.compact,
                    ),
                  ],
                ),
              ],
            ),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                TextButton.icon(
                  onPressed: onChangeRole,
                  icon: const Icon(Icons.swap_horiz),
                  label: const Text('Rol'),
                ),
                TextButton.icon(
                  onPressed: onToggleActive,
                  icon: Icon(
                    user.isActive ? Icons.block : Icons.check_circle_outline,
                  ),
                  label: Text(user.isActive ? 'Desactivar' : 'Activar'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
