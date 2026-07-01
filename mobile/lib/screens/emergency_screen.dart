import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

class EmergencyScreen extends StatelessWidget {
  const EmergencyScreen({super.key});

  static const _contacts = [
  _Contact(name: 'Emergencias', phone: '911', isEmergency: true),
  _Contact(name: 'María (hija)', phone: '555-1234', isEmergency: false),
  _Contact(name: 'José (hijo)', phone: '555-5678', isEmergency: false),
  _Contact(name: 'Dr. González', phone: '555-9012', isEmergency: false),
  _Contact(name: 'Vecino - Pedro', phone: '555-3456', isEmergency: false),
];

  @override
  Widget build(BuildContext context) {
  return Scaffold(
    appBar: AppBar(title: const Text('Contactos de Emergencia')),
    body: ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Container(
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
                '¿Necesitas ayuda urgente?',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                'Presiona el botón para llamar a emergencias',
                style: TextStyle(color: Colors.white70, fontSize: 16),
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
        ),
        const SizedBox(height: 20),
        Text('Contactos frecuentes', style: Theme.of(context).textTheme.headlineMedium),
        const SizedBox(height: 12),
        ..._contacts.map((contact) => _ContactCard(contact: contact)),
      ],
    ),
  );
  }
}

class _Contact {
  const _Contact({
    required this.name,
    required this.phone,
    required this.isEmergency,
  });

  final String name;
  final String phone;
  final bool isEmergency;
}

class _ContactCard extends StatelessWidget {
  const _ContactCard({required this.contact});

  final _Contact contact;

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        leading: CircleAvatar(
          backgroundColor: contact.isEmergency
              ? Colors.red.withValues(alpha: 0.15)
              : AppColors.primary.withValues(alpha: 0.15),
          child: Icon(
            contact.isEmergency ? Icons.emergency : Icons.person,
            color: contact.isEmergency ? Colors.red : AppColors.primary,
          ),
        ),
        title: Text(
          contact.name,
          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
        ),
        subtitle: Text(contact.phone, style: const TextStyle(fontSize: 16)),
        trailing: IconButton(
          onPressed: () {},
          icon: const Icon(Icons.phone, color: AppColors.primary, size: 28),
          style: IconButton.styleFrom(
            backgroundColor: AppColors.surface,
          ),
        ),
      ),
    );
  }
}
