import 'dart:async';

import 'package:flutter/material.dart';

import '../services/api_service.dart';
import '../theme/app_theme.dart';
import '../utils/form_inputs.dart';
import '../utils/time_picker_utils.dart';
import '../widgets/app_states.dart';
import '../widgets/role_shell_scaffold.dart';

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
  const AppointmentsScreen({
    super.key,
    this.api,
    this.caregiverPatientId,
    this.title,
    this.shellTabIndex,
  });

  final UleamMedApi? api;
  final int? caregiverPatientId;
  final String? title;
  final int? shellTabIndex;

  @override
  State<AppointmentsScreen> createState() => _AppointmentsScreenState();
}

class _AppointmentsScreenState extends State<AppointmentsScreen>
    with SingleTickerProviderStateMixin {
  late final UleamMedApi _api = widget.api ?? ApiService();
  late Future<List<Appointment>> _appointments = _loadAppointments();
  int? _lastShellTabIndex;
  late final TabController _tabController =
      TabController(length: 2, vsync: this)..addListener(() {
        if (!_tabController.indexIsChanging) {
          setState(() {});
        }
      });

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final shellTabIndex = widget.shellTabIndex;
    if (shellTabIndex == null) {
      return;
    }
    final activeIndex = roleShellActiveTabIndex(context);
    if (activeIndex == shellTabIndex &&
        _lastShellTabIndex != null &&
        _lastShellTabIndex != activeIndex) {
      unawaited(_refresh());
    }
    _lastShellTabIndex = activeIndex;
  }

  Future<List<Appointment>> _loadAppointments() {
    final patientId = widget.caregiverPatientId;
    if (patientId != null) {
      return _api.listCaregiverPatientAppointments(patientId);
    }
    return _api.listAppointments();
  }

  Future<Appointment> _saveAppointment(Appointment appointment) {
    final patientId = widget.caregiverPatientId;
    if (patientId != null) {
      return _api.saveCaregiverPatientAppointment(patientId, appointment);
    }
    return _api.saveAppointment(appointment);
  }

  Future<void> _deleteAppointment(String appointmentId) {
    final patientId = widget.caregiverPatientId;
    if (patientId != null) {
      return _api.deleteCaregiverPatientAppointment(patientId, appointmentId);
    }
    return _api.deleteAppointment(appointmentId);
  }

  Future<void> _refresh() async {
    setState(() {
      _appointments = _loadAppointments();
    });
    await _appointments;
  }

  Future<void> _openForm([Appointment? appointment]) async {
    final saved = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (context) => _AppointmentForm(
        appointment: appointment,
        readonlySchedule: appointment?.isPast ?? false,
        onSave: (item) async {
          await _saveAppointment(item);
        },
      ),
    );
    if (saved == true && mounted) {
      await _refresh();
      if (!mounted) {
        return;
      }
      showAppSnackBar(context, 'Consulta guardada');
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
          await _saveAppointment(
            appointment.copyWith(completed: !appointment.completed),
          );
          if (context.mounted) {
            Navigator.pop(context, true);
          }
        },
        onDelete: () async {
          await _deleteAppointment(appointment.id);
          if (context.mounted) {
            Navigator.pop(context, true);
          }
        },
      ),
    );
    if (changed == true && mounted) {
      await _refresh();
    }
  }

  @override
  Widget build(BuildContext context) {
    final showAddButton = _tabController.index == 0;

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.title ?? 'Consultas'),
        bottom: TabBar(
          controller: _tabController,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white70,
          indicatorColor: Colors.white,
          tabs: const [
            Tab(text: 'Proximas'),
            Tab(text: 'Pasadas'),
          ],
        ),
      ),
      floatingActionButton: showAddButton
          ? FloatingActionButton.extended(
              heroTag: 'fab-appointments',
              onPressed: () => _openForm(),
              icon: const Icon(Icons.add),
              label: const Text('Agregar'),
            )
          : null,
      body: FutureBuilder<List<Appointment>>(
        future: _appointments,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting &&
              !snapshot.hasData) {
            return const LoadingView(message: 'Cargando consultas...');
          }
          if (snapshot.hasError) {
            return RefreshableScrollView(
              onRefresh: _refresh,
              child: const ErrorStateView(
                title: 'No se pudieron cargar las consultas',
              ),
            );
          }

          final all = snapshot.data ?? const [];
          final upcoming = all.where((a) => !a.isPast).toList()
            ..sort(_byScheduled);
          final past = all.where((a) => a.isPast).toList()
            ..sort((a, b) => -_byScheduled(a, b));

          return TabBarView(
            controller: _tabController,
            children: [
              _AppointmentList(
                appointments: upcoming,
                emptyTitle: 'Sin consultas proximas',
                emptyMessage: 'Agrega una consulta con el boton +.',
                onTap: _openDetail,
                onRefresh: _refresh,
                showAddAction: true,
                onAdd: () => _openForm(),
              ),
              _AppointmentList(
                appointments: past,
                emptyTitle: 'Sin historial de consultas',
                emptyMessage:
                    'Las consultas realizadas o vencidas apareceran aqui.',
                onTap: _openDetail,
                onRefresh: _refresh,
                showAddAction: false,
              ),
            ],
          );
        },
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
    required this.onRefresh,
    this.showAddAction = false,
    this.onAdd,
  });

  final List<Appointment> appointments;
  final String emptyTitle;
  final String emptyMessage;
  final ValueChanged<Appointment> onTap;
  final Future<void> Function() onRefresh;
  final bool showAddAction;
  final VoidCallback? onAdd;

  @override
  Widget build(BuildContext context) {
    if (appointments.isEmpty) {
      return RefreshableScrollView(
        onRefresh: onRefresh,
        child: EmptyStateView(
          icon: Icons.event_available,
          title: emptyTitle,
          message: emptyMessage,
          actionLabel: showAddAction ? 'Agregar consulta' : null,
          onAction: showAddAction ? onAdd : null,
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: onRefresh,
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 96),
        children: appointments
            .map((a) => _AppointmentCard(appointment: a, onTap: () => onTap(a)))
            .toList(),
      ),
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
  const _AppointmentForm({
    required this.onSave,
    this.appointment,
    this.readonlySchedule = false,
  });

  final Appointment? appointment;
  final bool readonlySchedule;
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

  static const _locale = Locale('es', 'ES');

  DateTime get _today {
    final now = DateTime.now();
    return DateTime(now.year, now.month, now.day);
  }

  Future<void> _pickDate() async {
    if (widget.readonlySchedule) {
      return;
    }
    final today = _today;
    final lastDate = DateTime(today.year + 5);
    var initialDate = _date ?? today;
    if (initialDate.isBefore(today)) {
      initialDate = today;
    } else if (initialDate.isAfter(lastDate)) {
      initialDate = lastDate;
    }
    final picked = await showDatePicker(
      context: context,
      locale: _locale,
      initialDate: initialDate,
      firstDate: today,
      lastDate: lastDate,
      helpText: 'Seleccionar fecha',
      cancelText: 'Cancelar',
      confirmText: 'Aceptar',
    );
    if (picked != null) {
      setState(() => _date = picked);
    }
  }

  Future<void> _pickTime() async {
    if (widget.readonlySchedule) {
      return;
    }
    final picked = await showSpanishTimePicker(
      context: context,
      initialTime: _time ?? TimeOfDay.now(),
      helpText: 'Seleccionar hora',
    );
    if (picked == null) {
      return;
    }
    if (_date != null) {
      final selected = DateTime(
        _date!.year,
        _date!.month,
        _date!.day,
        picked.hour,
        picked.minute,
      );
      if (!selected.isAfter(DateTime.now())) {
        if (mounted) {
          showAppSnackBar(context, 'Selecciona una hora futura', isError: true);
        }
        return;
      }
    }
    setState(() => _time = picked);
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
    try {
      final scheduled = DateTime(
        _date!.year,
        _date!.month,
        _date!.day,
        _time!.hour,
        _time!.minute,
      );
      if (!widget.readonlySchedule && !scheduled.isAfter(DateTime.now())) {
        showAppSnackBar(
          context,
          'La consulta debe programarse en el futuro',
          isError: true,
        );
        return;
      }
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
      if (!mounted) {
        return;
      }
      Navigator.pop(context, true);
    } catch (error) {
      if (mounted) {
        final message = error is ApiException
            ? error.message
            : 'No se pudo guardar la consulta';
        showAppSnackBar(context, message, isError: true);
      }
    } finally {
      if (mounted) {
        setState(() => _isSaving = false);
      }
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
              inputFormatters: FormInputs.personName,
              decoration: const InputDecoration(
                labelText: 'Medico',
                prefixIcon: Icon(Icons.person),
                border: OutlineInputBorder(),
              ),
              validator: (value) => FormInputs.personNameValidator(value),
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _specialtyController,
              decoration: const InputDecoration(
                labelText: 'Especialidad',
                prefixIcon: Icon(Icons.medical_services),
                border: OutlineInputBorder(),
              ),
              validator: (value) => FormInputs.requiredText(
                value,
                message: 'Ingresa la especialidad',
              ),
            ),
            const SizedBox(height: 12),
            if (widget.readonlySchedule) ...[
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.event),
                title: Text(_date == null ? 'Sin fecha' : _formatDate(_date!)),
                subtitle: Text(
                  _time == null ? 'Sin hora' : _formatTime(_time!),
                ),
              ),
            ] else ...[
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: _pickDate,
                      icon: const Icon(Icons.event),
                      label: Text(
                        _date == null ? 'Fecha' : _formatDate(_date!),
                      ),
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
            ],
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
