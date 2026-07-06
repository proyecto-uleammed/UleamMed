import 'package:flutter/material.dart';

import '../services/api_service.dart';
import '../theme/app_theme.dart';

class EmergencyScreen extends StatefulWidget {
  const EmergencyScreen({super.key, this.api});

  final UleamMedApi? api;

  @override
  State<EmergencyScreen> createState() => _EmergencyScreenState();
}

class _EmergencyScreenState extends State<EmergencyScreen> {
  late final UleamMedApi _api = widget.api ?? ApiService();
  late Future<List<EmergencyContact>> _contacts = _api.listEmergencyContacts();

  void _reload() {
    setState(() {
      _contacts = _api.listEmergencyContacts();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Contactos de emergencia')),
      body: FutureBuilder<List<EmergencyContact>>(
        future: _contacts,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return _EmergencyError(onRetry: _reload);
          }
          final contacts = snapshot.data ?? [];
          final primaryContact = _primaryContact(contacts);
          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              _EmergencyBanner(primaryContact: primaryContact),
              const SizedBox(height: 20),
              Text('Contactos frecuentes', style: Theme.of(context).textTheme.headlineMedium),
              const SizedBox(height: 12),
              ...contacts.map((contact) => _ContactCard(contact: contact)),
            ],
          );
        },
      ),
    );
  }

  EmergencyContact? _primaryContact(List<EmergencyContact> contacts) {
    for (final contact in contacts) {
      if (contact.isPrimary) {
        return contact;
      }
    }
    return contacts.isEmpty ? null : contacts.first;
  }
}

class _EmergencyBanner extends StatelessWidget {
  const _EmergencyBanner({required this.primaryContact});

  final EmergencyContact? primaryContact;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.primary,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        children: [
          const Icon(Icons.emergency, color: Colors.white, size: 48),
          const SizedBox(height: 12),
          const Text(
            'Datos clave disponibles offline',
            style: TextStyle(
              color: Colors.white,
              fontSize: 20,
              fontWeight: FontWeight.bold,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 8),
          Text(
            primaryContact == null
                ? 'Guarda contactos para emergencias.'
                : 'Contacto principal: ${primaryContact!.name} - ${primaryContact!.phone}',
            style: const TextStyle(color: Colors.white70, fontSize: 16),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 16),
          ElevatedButton.icon(
            onPressed: () {},
            icon: const Icon(Icons.phone, color: AppColors.primary),
            label: const Text(
              'Llamar al 911',
              style: TextStyle(fontSize: 18, color: AppColors.primary),
            ),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 14),
            ),
          ),
        ],
      ),
    );
  }
}

class _ContactCard extends StatelessWidget {
  const _ContactCard({required this.contact});

  final EmergencyContact contact;

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        leading: CircleAvatar(
          backgroundColor: contact.isPrimary
              ? Colors.red.withValues(alpha: 0.15)
              : AppColors.primary.withValues(alpha: 0.15),
          child: Icon(
            contact.isPrimary ? Icons.emergency : Icons.person,
            color: contact.isPrimary ? Colors.red : AppColors.primary,
          ),
        ),
        title: Text(
          contact.relationship.isEmpty
              ? contact.name
              : '${contact.name} (${contact.relationship})',
          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
        ),
        subtitle: Text(contact.phone, style: const TextStyle(fontSize: 16)),
        trailing: IconButton(
          onPressed: () {},
          icon: const Icon(Icons.phone, color: AppColors.primary, size: 28),
          style: IconButton.styleFrom(backgroundColor: AppColors.surface),
        ),
      ),
    );
  }
}

class _EmergencyError extends StatelessWidget {
  const _EmergencyError({required this.onRetry});

  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.cloud_off, color: AppColors.primary, size: 48),
            const SizedBox(height: 12),
            Text(
              'No se pudieron cargar los contactos',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 16),
            FilledButton.icon(
              onPressed: onRetry,
              icon: const Icon(Icons.refresh),
              label: const Text('Reintentar'),
            ),
          ],
        ),
      ),
    );
  }
}
