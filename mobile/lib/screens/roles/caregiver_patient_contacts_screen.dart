import 'package:flutter/material.dart';

import '../../services/api_service.dart';
import '../../theme/app_theme.dart';
import '../../widgets/app_states.dart';

class CaregiverPatientContactsScreen extends StatefulWidget {
  const CaregiverPatientContactsScreen({
    super.key,
    required this.api,
    required this.patientId,
    required this.patientName,
  });

  final UleamMedApi api;
  final int patientId;
  final String patientName;

  @override
  State<CaregiverPatientContactsScreen> createState() =>
      _CaregiverPatientContactsScreenState();
}

class _CaregiverPatientContactsScreenState
    extends State<CaregiverPatientContactsScreen> {
  late Future<_ContactsData> _data = _load();

  Future<_ContactsData> _load() async {
    try {
      final profile = await widget.api.loadCaregiverPatientMedicalProfile(
        widget.patientId,
      );
      final contacts = await widget.api.listCaregiverPatientEmergencyContacts(
        widget.patientId,
      );
      return _ContactsData(profile: profile, contacts: contacts);
    } on ApiException catch (error) {
      if (error.statusCode == 403) {
        return const _ContactsData(notShared: true);
      }
      rethrow;
    }
  }

  void _reload() {
    setState(() {
      _data = _load();
    });
  }

  Future<void> _refresh() async {
    setState(() {
      _data = _load();
    });
    await _data;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Contactos de ${widget.patientName}'),
      ),
      body: FutureBuilder<_ContactsData>(
        future: _data,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const LoadingView();
          }
          if (snapshot.hasError) {
            return ErrorStateView(onRetry: _reload);
          }

          final data = snapshot.data ?? const _ContactsData();
          if (data.notShared) {
            return RefreshIndicator(
              onRefresh: _refresh,
              child: ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.all(24),
                children: const [
                  _NotSharedBanner(),
                ],
              ),
            );
          }

          final profile = data.profile;
          final contacts = data.contacts;
          final profileContact = profile == null
              ? null
              : (profile.emergencyContactName.isNotEmpty ||
                    profile.emergencyContactPhone.isNotEmpty)
              ? profile
              : null;

          if (profileContact == null && contacts.isEmpty) {
            return RefreshIndicator(
              onRefresh: _refresh,
              child: ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                children: const [
                  EmptyStateView(
                    title: 'Sin contactos registrados',
                    message:
                        'El paciente aun no comparte contactos de emergencia.',
                  ),
                ],
              ),
            );
          }

          return RefreshIndicator(
            onRefresh: _refresh,
            child: ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
              children: [
                if (profileContact != null) ...[
                  Text(
                    'Contacto principal del perfil',
                    style: Theme.of(context).textTheme.headlineMedium,
                  ),
                  const SizedBox(height: 8),
                  _ContactCard(
                    name: profileContact.emergencyContactName,
                    phone: profileContact.emergencyContactPhone,
                    relationship: 'Perfil medico',
                    isPrimary: true,
                  ),
                  const SizedBox(height: 20),
                ],
                if (contacts.isNotEmpty) ...[
                  Text(
                    'Contactos de emergencia',
                    style: Theme.of(context).textTheme.headlineMedium,
                  ),
                  const SizedBox(height: 8),
                  ...contacts.map(
                    (contact) => _ContactCard(
                      name: contact.name,
                      phone: contact.phone,
                      relationship: contact.relationship.isEmpty
                          ? 'Contacto'
                          : contact.relationship,
                      isPrimary: contact.isPrimary,
                    ),
                  ),
                ],
              ],
            ),
          );
        },
      ),
    );
  }
}

class _ContactsData {
  const _ContactsData({
    this.profile,
    this.contacts = const [],
    this.notShared = false,
  });

  final MedicalProfile? profile;
  final List<EmergencyContact> contacts;
  final bool notShared;
}

class _NotSharedBanner extends StatelessWidget {
  const _NotSharedBanner();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.primary.withValues(alpha: 0.3)),
      ),
      child: Column(
        children: [
          Icon(Icons.lock, color: AppColors.primary, size: 48),
          const SizedBox(height: 12),
          Text(
            'Informacion no compartida',
            style: Theme.of(context).textTheme.titleLarge,
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 8),
          Text(
            'El paciente debe activar compartir con cuidadores en su perfil medico.',
            style: Theme.of(context).textTheme.bodyLarge,
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}

class _ContactCard extends StatelessWidget {
  const _ContactCard({
    required this.name,
    required this.phone,
    required this.relationship,
    required this.isPrimary,
  });

  final String name;
  final String phone;
  final String relationship;
  final bool isPrimary;

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: AppColors.primary.withValues(alpha: 0.15),
          child: Icon(Icons.contact_phone, color: AppColors.primary),
        ),
        title: Text(name.isEmpty ? 'Sin nombre' : name),
        subtitle: Text('$relationship · ${phone.isEmpty ? 'Sin telefono' : phone}'),
        trailing: isPrimary
            ? const Chip(label: Text('Principal'))
            : null,
      ),
    );
  }
}
