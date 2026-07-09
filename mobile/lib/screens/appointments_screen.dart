import 'package:flutter/material.dart';

import '../services/api_service.dart';
import '../theme/app_theme.dart';
import '../widgets/app_states.dart';

const _months = [
  'Ene',
  'Feb',
  'Mar',
  'Abr',
  'May',
  'Jun',
  'Jul',
  'Ago',
  'Sep',
  'Oct',
  'Nov',
  'Dic',
];

String _formatDate(DateTime date) {
  final day = date.day.toString().padLeft(2, '0');
  return '$day ${_months[date.month - 1]} ${date.year}';
}

String _formatTime(TimeOfDay time) {
  final hour = time.hour.toString().padLeft(2, '0');
  final minute = time.minute.toString().padLeft(2, '0');
  return '$hour:$minute';
}

/// Consultas medicas con registro, detalle y recordatorio
/// (PB-037/038/040/039).
class AppointmentsScreen extends StatefulWidget {
  const AppointmentsScreen({super.key, this.api});

  final UleamMedApi? api;

  @override
  State<AppointmentsScreen> createState() => _AppointmentsScreenState();
}

class _AppointmentsScreenState extends State<AppointmentsScreen> {
  late final UleamMedApi _api = widget.api ?? ApiService();
  late Future<List<Appointment>> _appointments = _api.listAppointments();

  void _reload() {
    setState(() {
      _appointments = _api.listAppointments();
    });
  }

  Future<void> _openForm([Appointment? appointment]) async {
    final saved = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (context) => _AppointmentForm(
        appointment: appointment,
        onSave: (item) => _api.saveAppointment(item),
      ),
    );
    if (saved == true && mounted) {
      _reload();
      showAppSnackBar(context, 'Cita guardada');
    }
  }

  Future<void> _openDetail(Appointment appointment) async {
    final changed = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (context) => _AppointmentDetail(
        appointment: appointment,
        onEdit: () async {
          Navigator.pop(context, false);
          await _openForm(appointment);
        },
        onToggleCompleted: () async {
          await _api.saveAppointment(
            appointment.copyWith(completed: !appointment.completed),
          );
          if (context.mounted) {
            Navigator.pop(context, true);
          }
        },
        onDelete: () async {
          await _api.deleteAppointment(appointment.id);
          if (context.mounted) {
            Navigator.pop(context, true);
          }
        },
      ),
    );
    if (changed == true && mounted) {
      _reload();
    }
  }

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Consultas'),
          bottom: const TabBar(
            tabs: [
              Tab(text: 'Proximas'),
              Tab(text: 'Pasadas'),
            ],
          ),
        ),
        floatingActionButton: FloatingActionButton.extended(
          heroTag: 'fab-appointments',
          onPressed: () => _openForm(),
          icon: const Icon(Icons.add),
          label: const Text('Agregar'),
        ),
        body: FutureBuilder<List<Appointment>>(
          future: _appointments,
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const LoadingView(message: 'Cargando consultas...');
            }
            if (snapshot.hasError) {
              return ErrorStateView(
                title: 'No se pudieron cargar las consultas',
                onRetry: _reload,
              );
            }

            final all = snapshot.data ?? const [];
            final upcoming = all.where((a) => !a.isPast).toList()
              ..sort(_byScheduled);
            final past = all.where((a) => a.isPast).toList()
              ..sort((a, b) => -_byScheduled(a, b));

            return TabBarView(
              children: [
                _AppointmentList(
                  appointments: upcoming,
                  emptyTitle: 'Sin consultas proximas',
                  emptyMessage: 'Agrega una consulta con el boton +.',
                  onTap: _openDetail,
                  onAdd: () => _openForm(),
                ),
                _AppointmentList(
                  appointments: past,
                  emptyTitle: 'Sin consultas pasadas',
                  emptyMessage: 'Aqui veras tus consultas realizadas.',
                  onTap: _openDetail,
                  onAdd: () => _openForm(),
                ),
              ],
            );
          },
        ),
      ),
    );
  }

  int _byScheduled(Appointment a, Appointment b) {
    final aDate = a.scheduledAt;
    final bDate = b.scheduledAt;
    if (aDate == null && bDate == null) {
      return 0;
    }
    if (aDate == null) {
      return 1;
    }
    if (bDate == null) {
      return -1;
    }
    return aDate.compareTo(bDate);
  }
}

class _AppointmentList extends StatelessWidget {
  const _AppointmentList({
    required this.appointments,
    required this.emptyTitle,
    required this.emptyMessage,
    required this.onTap,
    required this.onAdd,
  });

  final List<Appointment> appointments;
  final String emptyTitle;
  final String emptyMessage;
  final ValueChanged<Appointment> onTap;
  final VoidCallback onAdd;

  @override
  Widget build(BuildContext context) {
    if (appointments.isEmpty) {
      return EmptyStateView(
        icon: Icons.event_available,
        title: emptyTitle,
        message: emptyMessage,
        actionLabel: 'Agregar consulta',
        onAction: onAdd,
      );
    }
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 96),
      children: appointments
          .map((a) => _AppointmentCard(appointment: a, onTap: () => onTap(a)))
          .toList(),
    );
  }
}

class _AppointmentCard extends StatelessWidget {
  const _AppointmentCard({required this.appointment, required this.onTap});

  final Appointment appointment;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: AppColors.primary.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(
                      appointment.completed
                          ? Icons.event_available
                          : Icons.calendar_month,
                      color: AppColors.primary,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          appointment.doctor,
                          style: Theme.of(context).textTheme.titleLarge,
                        ),
                        Text(
                          appointment.specialty,
                          style: Theme.of(context).textTheme.bodyMedium,
                        ),
                      ],
                    ),
                  ),
                  const Icon(Icons.chevron_right),
                ],
              ),
              const SizedBox(height: 12),
              _InfoRow(
                icon: Icons.event,
                text: '${appointment.date} - ${appointment.time}',
              ),
              const SizedBox(height: 6),
              _InfoRow(
                icon: Icons.location_on_outlined,
                text: appointment.location.isEmpty
                    ? 'Sin lugar'
                    : appointment.location,
              ),
              if (appointment.completed ||
                  appointment.reminder != AppointmentReminder.none) ...[
                const SizedBox(height: 10),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    if (appointment.completed)
                      const Chip(
                        label: Text('Realizada'),
                        avatar: Icon(Icons.check, size: 18),
                      ),
                    if (appointment.reminder != AppointmentReminder.none)
                      Chip(
                        label: Text(appointment.reminder.label),
                        avatar: const Icon(Icons.notifications, size: 18),
                      ),
                  ],
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  const _InfoRow({required this.icon, required this.text});

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 20, color: AppColors.textSecondary),
        const SizedBox(width: 8),
        Expanded(
          child: Text(text, style: Theme.of(context).textTheme.bodyLarge),
        ),
      ],
    );
  }
}

class _AppointmentDetail extends StatelessWidget {
  const _AppointmentDetail({
    required this.appointment,
    required this.onEdit,
    required this.onToggleCompleted,
    required this.onDelete,
  });

  final Appointment appointment;
  final VoidCallback onEdit;
  final VoidCallback onToggleCompleted;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(20),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            appointment.doctor,
            style: Theme.of(context).textTheme.headlineMedium,
          ),
          Text(
            appointment.specialty,
            style: Theme.of(context).textTheme.bodyLarge,
          ),
          const SizedBox(height: 16),
          _InfoRow(
            icon: Icons.event,
            text: '${appointment.date} - ${appointment.time}',
          ),
          const SizedBox(height: 8),
          _InfoRow(
            icon: Icons.location_on_outlined,
            text: appointment.location.isEmpty
                ? 'Sin lugar'
                : appointment.location,
          ),
          const SizedBox(height: 8),
          _InfoRow(
            icon: Icons.notifications_outlined,
            text: appointment.reminder.label,
          ),
          if (appointment.notes.isNotEmpty) ...[
            const SizedBox(height: 12),
            Text('Notas', style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 4),
            Text(
              appointment.notes,
              style: Theme.of(context).textTheme.bodyLarge,
            ),
          ],
          const SizedBox(height: 20),
          Row(
            children: [
              Expanded(
                child: FilledButton.icon(
                  onPressed: onToggleCompleted,
                  icon: Icon(appointment.completed ? Icons.undo : Icons.check),
                  label: Text(
                    appointment.completed
                        ? 'Marcar pendiente'
                        : 'Marcar realizada',
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: onEdit,
                  icon: const Icon(Icons.edit),
                  label: const Text('Editar'),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: onDelete,
                  icon: const Icon(Icons.delete),
                  label: const Text('Eliminar'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _AppointmentForm extends StatefulWidget {
  const _AppointmentForm({required this.onSave, this.appointment});

  final Appointment? appointment;
  final Future<void> Function(Appointment appointment) onSave;

  @override
  State<_AppointmentForm> createState() => _AppointmentFormState();
}

class _AppointmentFormState extends State<_AppointmentForm> {
  final _formKey = GlobalKey<FormState>();
  late final _doctorController = TextEditingController(
    text: widget.appointment?.doctor ?? '',
  );
  late final _specialtyController = TextEditingController(
    text: widget.appointment?.specialty ?? '',
  );
  late final _locationController = TextEditingController(
    text: widget.appointment?.location ?? '',
  );
  late final _notesController = TextEditingController(
    text: widget.appointment?.notes ?? '',
  );
  DateTime? _date;
  TimeOfDay? _time;
  late AppointmentReminder _reminder =
      widget.appointment?.reminder ?? AppointmentReminder.none;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _date = widget.appointment?.scheduledAt;
    final scheduled = widget.appointment?.scheduledAt;
    if (scheduled != null) {
      _time = TimeOfDay(hour: scheduled.hour, minute: scheduled.minute);
    }
  }

  @override
  void dispose() {
    _doctorController.dispose();
    _specialtyController.dispose();
    _locationController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  Future<void> _pickDate() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _date ?? now,
      firstDate: DateTime(now.year - 1),
      lastDate: DateTime(now.year + 5),
    );
    if (picked != null) {
      setState(() => _date = picked);
    }
  }

  Future<void> _pickTime() async {
    final picked = await showTimePicker(
      context: context,
      initialTime: _time ?? TimeOfDay.now(),
    );
    if (picked != null) {
      setState(() => _time = picked);
    }
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }
    if (_date == null || _time == null) {
      showAppSnackBar(context, 'Selecciona fecha y hora', isError: true);
      return;
    }
    setState(() => _isSaving = true);
    final scheduled = DateTime(
      _date!.year,
      _date!.month,
      _date!.day,
      _time!.hour,
      _time!.minute,
    );
    final id =
        widget.appointment?.id ??
        'cita-${DateTime.now().millisecondsSinceEpoch}';
    final appointment = Appointment(
      id: id,
      doctor: _doctorController.text.trim(),
      specialty: _specialtyController.text.trim(),
      date: _formatDate(scheduled),
      time: _formatTime(_time!),
      location: _locationController.text.trim(),
      notes: _notesController.text.trim(),
      completed: widget.appointment?.completed ?? false,
      reminder: _reminder,
      scheduledAt: scheduled,
    );
    await widget.onSave(appointment);
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
              widget.appointment == null ? 'Nueva consulta' : 'Editar consulta',
              style: Theme.of(context).textTheme.headlineMedium,
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _doctorController,
              decoration: const InputDecoration(
                labelText: 'Medico',
                prefixIcon: Icon(Icons.person),
                border: OutlineInputBorder(),
              ),
              validator: (value) =>
                  (value ?? '').trim().isEmpty ? 'Ingresa el medico' : null,
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _specialtyController,
              decoration: const InputDecoration(
                labelText: 'Especialidad',
                prefixIcon: Icon(Icons.medical_services),
                border: OutlineInputBorder(),
              ),
              validator: (value) => (value ?? '').trim().isEmpty
                  ? 'Ingresa la especialidad'
                  : null,
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: _pickDate,
                    icon: const Icon(Icons.event),
                    label: Text(_date == null ? 'Fecha' : _formatDate(_date!)),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: _pickTime,
                    icon: const Icon(Icons.schedule),
                    label: Text(_time == null ? 'Hora' : _formatTime(_time!)),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _locationController,
              decoration: const InputDecoration(
                labelText: 'Lugar',
                prefixIcon: Icon(Icons.location_on_outlined),
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _notesController,
              maxLines: 3,
              decoration: const InputDecoration(
                labelText: 'Notas',
                prefixIcon: Icon(Icons.notes),
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<AppointmentReminder>(
              initialValue: _reminder,
              decoration: const InputDecoration(
                labelText: 'Recordatorio',
                prefixIcon: Icon(Icons.notifications_active),
                border: OutlineInputBorder(),
              ),
              items: AppointmentReminder.values
                  .map(
                    (option) => DropdownMenuItem(
                      value: option,
                      child: Text(option.label),
                    ),
                  )
                  .toList(),
              onChanged: (value) {
                if (value != null) {
                  setState(() => _reminder = value);
                }
              },
            ),
            const SizedBox(height: 16),
            FilledButton.icon(
              onPressed: _isSaving ? null : _save,
              icon: const Icon(Icons.save),
              label: const Text('Guardar'),
            ),
          ],
        ),
      ),
    );
  }
}
