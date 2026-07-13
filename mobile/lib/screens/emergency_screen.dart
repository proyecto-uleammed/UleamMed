import 'package:flutter/material.dart';

import '../services/api_service.dart';
import '../theme/app_theme.dart';
import '../utils/form_inputs.dart';
import '../utils/phone_launch_utils.dart';
import '../widgets/app_states.dart';

/// Pantalla de emergencia con datos clave, contactos y llamada rapida.
/// Disponible offline (PB-046/047/048/013).
class EmergencyScreen extends StatefulWidget {
  const EmergencyScreen({super.key, this.api});

  final UleamMedApi? api;

  @override
  State<EmergencyScreen> createState() => _EmergencyScreenState();
}

class _EmergencyScreenState extends State<EmergencyScreen> {
  late final UleamMedApi _api = widget.api ?? ApiService();
  late Future<_EmergencyData> _data = _loadData();

  Future<_EmergencyData> _loadData() async {
    final contacts = await _api.listEmergencyContacts();
    final profile = await _api.loadMedicalProfile();
    List<MedicationItem> medications;
    try {
      medications = await _api.listMedications();
    } catch (_) {
      medications = const [];
    }
    return _EmergencyData(
      contacts: contacts,
      profile: profile,
      medications: medications,
    );
  }

  void _reload() {
    setState(() {
      _data = _loadData();
    });
  }

  Future<void> _refresh() async {
    setState(() {
      _data = _loadData();
    });
    await _data;
  }

  Future<void> _call(String rawPhone, {String? contactName}) =>
      confirmAndCallPhone(
        context,
        rawPhone: rawPhone,
        contactName: contactName,
        allowShortCode: rawPhone.trim() == '911',
      );

  Future<void> _openContactForm([EmergencyContact? contact]) async {
    final saved = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (context) => _ContactForm(
        contact: contact,
        onSave: (item) => _api.saveEmergencyContact(item),
        onDelete: contact == null
            ? null
            : () => _api.deleteEmergencyContact(contact.id),
      ),
    );

    if (saved == true && mounted) {
      _reload();
      showAppSnackBar(context, 'Contacto guardado');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Emergencia')),
      floatingActionButton: FloatingActionButton.extended(
        heroTag: 'fab-emergency',
        onPressed: () => _openContactForm(),
        icon: const Icon(Icons.person_add),
        label: const Text('Contacto'),
      ),
      body: FutureBuilder<_EmergencyData>(
        future: _data,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const LoadingView(
              message: 'Cargando datos de emergencia...',
            );
          }
          if (snapshot.hasError) {
            return RefreshableScrollView(
              onRefresh: _refresh,
              child: const ErrorStateView(
                title: 'No se pudieron cargar los datos',
              ),
            );
          }

          final data = snapshot.data!;
          final primary = data.primaryContact;
          return RefreshIndicator(
            onRefresh: _refresh,
            child: ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 96),
              children: [
                _EmergencyHeader(
                  primaryContact: primary,
                  onCall911: () => _call('911'),
                  onCallPrimary: primary == null
                      ? null
                      : () => _call(primary.phone, contactName: primary.name),
                ),
                const SizedBox(height: 20),
                _MedicalKeyData(data: data),
                const SizedBox(height: 20),
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        'Contactos',
                        style: Theme.of(context).textTheme.headlineMedium,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                if (data.contacts.isEmpty)
                  const EmptyStateView(
                    icon: Icons.contact_phone,
                    title: 'Sin contactos guardados',
                    message: 'Agrega contactos para llamarlos con un toque.',
                  )
                else
                  ...data.contacts.map(
                    (contact) => _ContactCard(
                      contact: contact,
                      onCall: () =>
                          _call(contact.phone, contactName: contact.name),
                      onEdit: () => _openContactForm(contact),
                    ),
                  ),
              ],
            ),
          );
        },
      ),
    );
  }
}

class _EmergencyData {
  const _EmergencyData({
    required this.contacts,
    required this.profile,
    required this.medications,
  });

  final List<EmergencyContact> contacts;
  final MedicalProfile profile;
  final List<MedicationItem> medications;

  EmergencyContact? get primaryContact {
    for (final contact in contacts) {
      if (contact.isPrimary) {
        return contact;
      }
    }
    return contacts.isEmpty ? null : contacts.first;
  }
}

class _EmergencyHeader extends StatelessWidget {
  const _EmergencyHeader({
    required this.primaryContact,
    required this.onCall911,
    required this.onCallPrimary,
  });

  final EmergencyContact? primaryContact;
  final VoidCallback onCall911;
  final VoidCallback? onCallPrimary;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: const Color(0xFFC62828),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        children: [
          const Icon(Icons.emergency, color: Colors.white, size: 52),
          const SizedBox(height: 10),
          const Text(
            'Datos clave disponibles sin internet',
            style: TextStyle(
              color: Colors.white,
              fontSize: 20,
              fontWeight: FontWeight.bold,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: onCall911,
              icon: const Icon(Icons.phone, color: Color(0xFFC62828)),
              label: const Text(
                'Llamar al 911',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFFC62828),
                ),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 16),
              ),
            ),
          ),
          if (primaryContact != null) ...[
            const SizedBox(height: 10),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: onCallPrimary,
                icon: const Icon(Icons.call, color: Colors.white),
                label: Text(
                  'Llamar a ${primaryContact!.name}',
                  style: const TextStyle(fontSize: 18, color: Colors.white),
                ),
                style: OutlinedButton.styleFrom(
                  side: const BorderSide(color: Colors.white),
                  padding: const EdgeInsets.symmetric(vertical: 14),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _MedicalKeyData extends StatelessWidget {
  const _MedicalKeyData({required this.data});

  final _EmergencyData data;

  @override
  Widget build(BuildContext context) {
    final profile = data.profile;
    final activeMeds = data.medications;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Informacion medica',
            style: Theme.of(context).textTheme.headlineMedium,
          ),
          const SizedBox(height: 12),
          _KeyRow(
            icon: Icons.bloodtype,
            label: 'Tipo de sangre',
            value: profile.bloodType.isEmpty
                ? 'No registrado'
                : profile.bloodType,
          ),
          _KeyRow(
            icon: Icons.warning_amber,
            label: 'Alergias',
            value: profile.allergies.isEmpty
                ? 'Ninguna registrada'
                : profile.allergies,
            highlight: profile.allergies.isNotEmpty,
          ),
          _KeyRow(
            icon: Icons.monitor_heart,
            label: 'Enfermedades',
            value: profile.conditions.isEmpty
                ? 'Ninguna registrada'
                : profile.conditions,
          ),
          if (profile.importantNotes.isNotEmpty)
            _KeyRow(
              icon: Icons.notes,
              label: 'Indicaciones',
              value: profile.importantNotes,
            ),
          const SizedBox(height: 8),
          Text(
            'Medicamentos actuales',
            style: Theme.of(context).textTheme.titleLarge,
          ),
          const SizedBox(height: 6),
          if (activeMeds.isEmpty)
            Text(
              'Sin medicamentos registrados.',
              style: Theme.of(context).textTheme.bodyMedium,
            )
          else
            ...activeMeds.map(
              (med) => Padding(
                padding: const EdgeInsets.only(bottom: 4),
                child: Row(
                  children: [
                    const Icon(
                      Icons.medication,
                      size: 18,
                      color: AppColors.primary,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        '${med.name} - ${med.dose} (${med.time})',
                        style: Theme.of(context).textTheme.bodyLarge,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          const SizedBox(height: 12),
          Row(
            children: [
              const Icon(
                Icons.update,
                size: 16,
                color: AppColors.textSecondary,
              ),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  'Ultima actualizacion: ${_lastUpdate(profile)}',
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  String _lastUpdate(MedicalProfile profile) {
    final date = profile.updatedAt ?? profile.createdAt;
    if (date == null) {
      return 'Sin cambios guardados';
    }
    final d = date.toLocal();
    final day = d.day.toString().padLeft(2, '0');
    final month = d.month.toString().padLeft(2, '0');
    final hour = d.hour.toString().padLeft(2, '0');
    final minute = d.minute.toString().padLeft(2, '0');
    return '$day/$month/${d.year} $hour:$minute';
  }
}

class _KeyRow extends StatelessWidget {
  const _KeyRow({
    required this.icon,
    required this.label,
    required this.value,
    this.highlight = false,
  });

  final IconData icon;
  final String label;
  final String value;
  final bool highlight;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            icon,
            size: 20,
            color: highlight ? const Color(0xFFC62828) : AppColors.primary,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: Theme.of(context).textTheme.bodyMedium),
                Text(
                  value,
                  style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                    fontWeight: FontWeight.w600,
                    color: highlight ? const Color(0xFFC62828) : null,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ContactCard extends StatelessWidget {
  const _ContactCard({
    required this.contact,
    required this.onCall,
    required this.onEdit,
  });

  final EmergencyContact contact;
  final VoidCallback onCall;
  final VoidCallback onEdit;

  @override
  Widget build(BuildContext context) {
    final phone = normalizeEcuadorPhoneForDialer(contact.phone);
    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      child: ListTile(
        onTap: onCall,
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        leading: CircleAvatar(
          backgroundColor: contact.isPrimary
              ? const Color(0xFFC62828).withValues(alpha: 0.15)
              : AppColors.primary.withValues(alpha: 0.15),
          child: Icon(
            contact.isPrimary ? Icons.star : Icons.person,
            color: contact.isPrimary
                ? const Color(0xFFC62828)
                : AppColors.primary,
          ),
        ),
        title: Text(
          contact.relationship.isEmpty
              ? contact.name
              : '${contact.name} (${contact.relationship})',
          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
        ),
        subtitle: Text(
          phone ?? contact.phone,
          style: const TextStyle(fontSize: 16),
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            IconButton(
              tooltip: 'Editar',
              onPressed: onEdit,
              icon: const Icon(Icons.edit),
            ),
            IconButton(
              tooltip: 'Llamar',
              onPressed: onCall,
              icon: const Icon(Icons.phone, color: AppColors.primary, size: 28),
              style: IconButton.styleFrom(backgroundColor: AppColors.surface),
            ),
          ],
        ),
      ),
    );
  }
}

class _ContactForm extends StatefulWidget {
  const _ContactForm({required this.onSave, this.contact, this.onDelete});

  final EmergencyContact? contact;
  final Future<void> Function(EmergencyContact contact) onSave;
  final Future<void> Function()? onDelete;

  @override
  State<_ContactForm> createState() => _ContactFormState();
}

class _ContactFormState extends State<_ContactForm> {
  final _formKey = GlobalKey<FormState>();
  late final _nameController = TextEditingController(
    text: widget.contact?.name ?? '',
  );
  late final _relationshipController = TextEditingController(
    text: widget.contact?.relationship ?? '',
  );
  late final _phoneController = TextEditingController(
    text: widget.contact?.phone ?? '',
  );
  late bool _isPrimary = widget.contact?.isPrimary ?? false;
  bool _isSaving = false;

  @override
  void dispose() {
    _nameController.dispose();
    _relationshipController.dispose();
    _phoneController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }
    setState(() => _isSaving = true);
    final id =
        widget.contact?.id ??
        'contacto-${DateTime.now().millisecondsSinceEpoch}';
    final contact = EmergencyContact(
      id: id,
      name: _nameController.text.trim(),
      phone: _phoneController.text.trim(),
      relationship: _relationshipController.text.trim(),
      isPrimary: _isPrimary,
    );
    await widget.onSave(contact);
    if (mounted) {
      Navigator.pop(context, true);
    }
  }

  Future<void> _delete() async {
    setState(() => _isSaving = true);
    await widget.onDelete?.call();
    if (mounted) {
      Navigator.pop(context, true);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        left: 20,
        right: 20,
        top: 20,
        bottom: MediaQuery.of(context).viewInsets.bottom + 20,
      ),
      child: Form(
        key: _formKey,
        child: ListView(
          shrinkWrap: true,
          children: [
            Text(
              widget.contact == null ? 'Agregar contacto' : 'Editar contacto',
              style: Theme.of(context).textTheme.headlineMedium,
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _nameController,
              inputFormatters: FormInputs.personName,
              decoration: const InputDecoration(
                labelText: 'Nombre',
                prefixIcon: Icon(Icons.person),
                border: OutlineInputBorder(),
              ),
              validator: (value) => FormInputs.personNameValidator(value),
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _relationshipController,
              inputFormatters: FormInputs.personName,
              decoration: const InputDecoration(
                labelText: 'Relacion',
                hintText: 'Hija, medico, vecino...',
                prefixIcon: Icon(Icons.group),
                border: OutlineInputBorder(),
              ),
              validator: (value) =>
                  FormInputs.personNameValidator(value, required: false),
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _phoneController,
              keyboardType: TextInputType.phone,
              inputFormatters: FormInputs.phone,
              decoration: const InputDecoration(
                labelText: 'Telefono',
                prefixIcon: Icon(Icons.phone),
                border: OutlineInputBorder(),
              ),
              validator: FormInputs.phoneValidator,
            ),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Contacto principal'),
              subtitle: const Text('Se mostrara primero en emergencias.'),
              value: _isPrimary,
              onChanged: (value) => setState(() => _isPrimary = value),
            ),
            const SizedBox(height: 12),
            FilledButton.icon(
              onPressed: _isSaving ? null : _save,
              icon: const Icon(Icons.save),
              label: const Text('Guardar'),
            ),
            if (widget.onDelete != null) ...[
              const SizedBox(height: 8),
              OutlinedButton.icon(
                onPressed: _isSaving ? null : _delete,
                icon: const Icon(Icons.delete),
                label: const Text('Eliminar'),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
