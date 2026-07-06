enum SyncStatus {
  synced,
  pending,
  failed;

  static SyncStatus fromJson(Object? value) {
    return SyncStatus.values.firstWhere(
      (status) => status.name == value,
      orElse: () => SyncStatus.synced,
    );
  }
}

enum DoseStatus {
  taken,
  omitted,
  postponed;

  static DoseStatus fromJson(Object? value) {
    return DoseStatus.values.firstWhere(
      (status) => status.name == value,
      orElse: () => DoseStatus.taken,
    );
  }
}

class MedicalProfile {
  const MedicalProfile({
    this.birthDate = '',
    this.bloodType = '',
    this.conditions = '',
    this.allergies = '',
    this.importantNotes = '',
    this.emergencyContactName = '',
    this.emergencyContactPhone = '',
    this.shareWithCaregivers = false,
    this.syncStatus = SyncStatus.synced,
    this.createdAt,
    this.updatedAt,
  });

  factory MedicalProfile.fromJson(Map<String, dynamic> json) {
    return MedicalProfile(
      birthDate: json['birthDate']?.toString() ?? '',
      bloodType: json['bloodType']?.toString() ?? '',
      conditions: json['conditions']?.toString() ?? '',
      allergies: json['allergies']?.toString() ?? '',
      importantNotes: json['importantNotes']?.toString() ?? '',
      emergencyContactName: json['emergencyContactName']?.toString() ?? '',
      emergencyContactPhone: json['emergencyContactPhone']?.toString() ?? '',
      shareWithCaregivers: json['shareWithCaregivers'] == true,
      syncStatus: SyncStatus.fromJson(json['syncStatus']),
      createdAt: _parseDate(json['createdAt']),
      updatedAt: _parseDate(json['updatedAt']),
    );
  }

  final String birthDate;
  final String bloodType;
  final String conditions;
  final String allergies;
  final String importantNotes;
  final String emergencyContactName;
  final String emergencyContactPhone;
  final bool shareWithCaregivers;
  final SyncStatus syncStatus;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  MedicalProfile copyWith({
    String? birthDate,
    String? bloodType,
    String? conditions,
    String? allergies,
    String? importantNotes,
    String? emergencyContactName,
    String? emergencyContactPhone,
    bool? shareWithCaregivers,
    SyncStatus? syncStatus,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return MedicalProfile(
      birthDate: birthDate ?? this.birthDate,
      bloodType: bloodType ?? this.bloodType,
      conditions: conditions ?? this.conditions,
      allergies: allergies ?? this.allergies,
      importantNotes: importantNotes ?? this.importantNotes,
      emergencyContactName: emergencyContactName ?? this.emergencyContactName,
      emergencyContactPhone:
          emergencyContactPhone ?? this.emergencyContactPhone,
      shareWithCaregivers: shareWithCaregivers ?? this.shareWithCaregivers,
      syncStatus: syncStatus ?? this.syncStatus,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'birthDate': birthDate,
      'bloodType': bloodType,
      'conditions': conditions,
      'allergies': allergies,
      'importantNotes': importantNotes,
      'emergencyContactName': emergencyContactName,
      'emergencyContactPhone': emergencyContactPhone,
      'shareWithCaregivers': shareWithCaregivers,
      'syncStatus': syncStatus.name,
      'createdAt': createdAt?.toIso8601String(),
      'updatedAt': updatedAt?.toIso8601String(),
    };
  }
}

class MedicationItem {
  const MedicationItem({
    required this.id,
    required this.name,
    required this.dose,
    required this.time,
    required this.taken,
    this.frequency = 'Diario',
    this.duration = '',
    this.instructions = '',
    this.isImportant = true,
    this.syncStatus = SyncStatus.synced,
    this.createdAt,
    this.updatedAt,
  });

  factory MedicationItem.fromJson(Map<String, dynamic> json) {
    return MedicationItem(
      id: json['id'].toString(),
      name: json['name'].toString(),
      dose: json['dose'].toString(),
      time: json['time'].toString(),
      taken: json['taken'] == true,
      frequency: json['frequency']?.toString() ?? 'Diario',
      duration: json['duration']?.toString() ?? '',
      instructions: json['instructions']?.toString() ?? '',
      isImportant: json['isImportant'] != false,
      syncStatus: SyncStatus.fromJson(json['syncStatus']),
      createdAt: _parseDate(json['createdAt']),
      updatedAt: _parseDate(json['updatedAt']),
    );
  }

  final String id;
  final String name;
  final String dose;
  final String time;
  final bool taken;
  final String frequency;
  final String duration;
  final String instructions;
  final bool isImportant;
  final SyncStatus syncStatus;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  MedicationItem copyWith({
    String? id,
    String? name,
    String? dose,
    String? time,
    bool? taken,
    String? frequency,
    String? duration,
    String? instructions,
    bool? isImportant,
    SyncStatus? syncStatus,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return MedicationItem(
      id: id ?? this.id,
      name: name ?? this.name,
      dose: dose ?? this.dose,
      time: time ?? this.time,
      taken: taken ?? this.taken,
      frequency: frequency ?? this.frequency,
      duration: duration ?? this.duration,
      instructions: instructions ?? this.instructions,
      isImportant: isImportant ?? this.isImportant,
      syncStatus: syncStatus ?? this.syncStatus,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'dose': dose,
      'time': time,
      'taken': taken,
      'frequency': frequency,
      'duration': duration,
      'instructions': instructions,
      'isImportant': isImportant,
      'syncStatus': syncStatus.name,
      'createdAt': createdAt?.toIso8601String(),
      'updatedAt': updatedAt?.toIso8601String(),
    };
  }

  static List<MedicationItem> demoList() {
    return const [
      MedicationItem(
        id: 'metformina',
        name: 'Metformina',
        dose: '500 mg',
        time: '08:00',
        taken: true,
        instructions: 'Tomar con el desayuno.',
      ),
      MedicationItem(
        id: 'losartan',
        name: 'Losartan',
        dose: '50 mg',
        time: '08:00',
        taken: true,
        instructions: 'Tomar con agua.',
      ),
      MedicationItem(
        id: 'omeprazol',
        name: 'Omeprazol',
        dose: '20 mg',
        time: '14:00',
        taken: false,
        instructions: 'Tomar antes de comer.',
      ),
      MedicationItem(
        id: 'atorvastatina',
        name: 'Atorvastatina',
        dose: '10 mg',
        time: '20:00',
        taken: false,
        instructions: 'Tomar en la noche.',
      ),
    ];
  }
}

class MedicationSchedule {
  const MedicationSchedule({
    required this.medicationId,
    required this.time,
    this.frequency = 'Diario',
    this.instructions = '',
  });

  factory MedicationSchedule.fromJson(Map<String, dynamic> json) {
    return MedicationSchedule(
      medicationId: json['medicationId'].toString(),
      time: json['time'].toString(),
      frequency: json['frequency']?.toString() ?? 'Diario',
      instructions: json['instructions']?.toString() ?? '',
    );
  }

  final String medicationId;
  final String time;
  final String frequency;
  final String instructions;

  Map<String, dynamic> toJson() {
    return {
      'medicationId': medicationId,
      'time': time,
      'frequency': frequency,
      'instructions': instructions,
    };
  }
}

class DoseConfirmation {
  const DoseConfirmation({
    required this.id,
    required this.medicationId,
    required this.medicationName,
    required this.status,
    required this.recordedAt,
    this.note = '',
    this.syncStatus = SyncStatus.pending,
  });

  factory DoseConfirmation.fromJson(Map<String, dynamic> json) {
    return DoseConfirmation(
      id: json['id'].toString(),
      medicationId: json['medicationId'].toString(),
      medicationName: json['medicationName'].toString(),
      status: DoseStatus.fromJson(json['status']),
      recordedAt: _parseDate(json['recordedAt']) ?? DateTime.now(),
      note: json['note']?.toString() ?? '',
      syncStatus: SyncStatus.fromJson(json['syncStatus']),
    );
  }

  final String id;
  final String medicationId;
  final String medicationName;
  final DoseStatus status;
  final DateTime recordedAt;
  final String note;
  final SyncStatus syncStatus;

  DoseConfirmation copyWith({SyncStatus? syncStatus}) {
    return DoseConfirmation(
      id: id,
      medicationId: medicationId,
      medicationName: medicationName,
      status: status,
      recordedAt: recordedAt,
      note: note,
      syncStatus: syncStatus ?? this.syncStatus,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'medicationId': medicationId,
      'medicationName': medicationName,
      'status': status.name,
      'recordedAt': recordedAt.toIso8601String(),
      'note': note,
      'syncStatus': syncStatus.name,
    };
  }
}

enum AppointmentReminder {
  none('Sin recordatorio'),
  oneDayBefore('1 dia antes'),
  twoHoursBefore('2 horas antes');

  const AppointmentReminder(this.label);

  final String label;

  static AppointmentReminder fromJson(Object? value) {
    return AppointmentReminder.values.firstWhere(
      (option) => option.name == value,
      orElse: () => AppointmentReminder.none,
    );
  }
}

class Appointment {
  const Appointment({
    required this.id,
    required this.doctor,
    required this.specialty,
    required this.date,
    required this.time,
    required this.location,
    this.notes = '',
    this.completed = false,
    this.reminder = AppointmentReminder.none,
    this.scheduledAt,
    this.syncStatus = SyncStatus.synced,
  });

  factory Appointment.fromJson(Map<String, dynamic> json) {
    return Appointment(
      id: json['id'].toString(),
      doctor: json['doctor'].toString(),
      specialty: json['specialty'].toString(),
      date: json['date'].toString(),
      time: json['time'].toString(),
      location: json['location'].toString(),
      notes: json['notes']?.toString() ?? '',
      completed: json['completed'] == true,
      reminder: AppointmentReminder.fromJson(json['reminder']),
      scheduledAt: _parseDate(json['scheduledAt']),
      syncStatus: SyncStatus.fromJson(json['syncStatus']),
    );
  }

  final String id;
  final String doctor;
  final String specialty;
  final String date;
  final String time;
  final String location;
  final String notes;
  final bool completed;
  final AppointmentReminder reminder;
  final DateTime? scheduledAt;
  final SyncStatus syncStatus;

  bool get isPast {
    if (completed) {
      return true;
    }
    final when = scheduledAt;
    if (when == null) {
      return false;
    }
    return when.isBefore(DateTime.now());
  }

  Appointment copyWith({
    String? id,
    String? doctor,
    String? specialty,
    String? date,
    String? time,
    String? location,
    String? notes,
    bool? completed,
    AppointmentReminder? reminder,
    DateTime? scheduledAt,
    SyncStatus? syncStatus,
  }) {
    return Appointment(
      id: id ?? this.id,
      doctor: doctor ?? this.doctor,
      specialty: specialty ?? this.specialty,
      date: date ?? this.date,
      time: time ?? this.time,
      location: location ?? this.location,
      notes: notes ?? this.notes,
      completed: completed ?? this.completed,
      reminder: reminder ?? this.reminder,
      scheduledAt: scheduledAt ?? this.scheduledAt,
      syncStatus: syncStatus ?? this.syncStatus,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'doctor': doctor,
      'specialty': specialty,
      'date': date,
      'time': time,
      'location': location,
      'notes': notes,
      'completed': completed,
      'reminder': reminder.name,
      'scheduledAt': scheduledAt?.toIso8601String(),
      'syncStatus': syncStatus.name,
    };
  }
}

class EmergencyContact {
  const EmergencyContact({
    required this.id,
    required this.name,
    required this.phone,
    this.relationship = '',
    this.isPrimary = false,
    this.syncStatus = SyncStatus.synced,
  });

  factory EmergencyContact.fromJson(Map<String, dynamic> json) {
    return EmergencyContact(
      id: json['id'].toString(),
      name: json['name'].toString(),
      phone: json['phone'].toString(),
      relationship: json['relationship']?.toString() ?? '',
      isPrimary: json['isPrimary'] == true,
      syncStatus: SyncStatus.fromJson(json['syncStatus']),
    );
  }

  final String id;
  final String name;
  final String phone;
  final String relationship;
  final bool isPrimary;
  final SyncStatus syncStatus;

  EmergencyContact copyWith({
    String? id,
    String? name,
    String? phone,
    String? relationship,
    bool? isPrimary,
    SyncStatus? syncStatus,
  }) {
    return EmergencyContact(
      id: id ?? this.id,
      name: name ?? this.name,
      phone: phone ?? this.phone,
      relationship: relationship ?? this.relationship,
      isPrimary: isPrimary ?? this.isPrimary,
      syncStatus: syncStatus ?? this.syncStatus,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'phone': phone,
      'relationship': relationship,
      'isPrimary': isPrimary,
      'syncStatus': syncStatus.name,
    };
  }
}

class CaregiverPermission {
  const CaregiverPermission({
    required this.id,
    required this.caregiverName,
    required this.caregiverEmail,
    this.canViewMedications = true,
    this.canReceiveAlerts = true,
    this.status = 'pendiente',
    this.syncStatus = SyncStatus.pending,
  });

  factory CaregiverPermission.fromJson(Map<String, dynamic> json) {
    return CaregiverPermission(
      id: json['id'].toString(),
      caregiverName: json['caregiverName'].toString(),
      caregiverEmail: json['caregiverEmail'].toString(),
      canViewMedications: json['canViewMedications'] != false,
      canReceiveAlerts: json['canReceiveAlerts'] != false,
      status: json['status']?.toString() ?? 'pendiente',
      syncStatus: SyncStatus.fromJson(json['syncStatus']),
    );
  }

  final String id;
  final String caregiverName;
  final String caregiverEmail;
  final bool canViewMedications;
  final bool canReceiveAlerts;
  final String status;
  final SyncStatus syncStatus;

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'caregiverName': caregiverName,
      'caregiverEmail': caregiverEmail,
      'canViewMedications': canViewMedications,
      'canReceiveAlerts': canReceiveAlerts,
      'status': status,
      'syncStatus': syncStatus.name,
    };
  }
}

enum HealthEntryKind {
  condition,
  allergy;

  static HealthEntryKind fromJson(Object? value) {
    return HealthEntryKind.values.firstWhere(
      (kind) => kind.name == value,
      orElse: () => HealthEntryKind.condition,
    );
  }
}

enum SeverityLevel {
  low('Leve'),
  medium('Moderada'),
  high('Severa');

  const SeverityLevel(this.label);

  final String label;

  static SeverityLevel fromJson(Object? value) {
    return SeverityLevel.values.firstWhere(
      (level) => level.name == value,
      orElse: () => SeverityLevel.low,
    );
  }
}

/// Enfermedad, condicion cronica o alergia del paciente (PB-033/034/035).
class HealthEntry {
  const HealthEntry({
    required this.id,
    required this.kind,
    required this.name,
    this.severity = SeverityLevel.low,
    this.detail = '',
    this.date = '',
    this.active = true,
    this.syncStatus = SyncStatus.pending,
  });

  factory HealthEntry.fromJson(Map<String, dynamic> json) {
    return HealthEntry(
      id: json['id'].toString(),
      kind: HealthEntryKind.fromJson(json['kind']),
      name: json['name'].toString(),
      severity: SeverityLevel.fromJson(json['severity']),
      detail: json['detail']?.toString() ?? '',
      date: json['date']?.toString() ?? '',
      active: json['active'] != false,
      syncStatus: SyncStatus.fromJson(json['syncStatus']),
    );
  }

  final String id;
  final HealthEntryKind kind;
  final String name;
  final SeverityLevel severity;
  final String detail;
  final String date;
  final bool active;
  final SyncStatus syncStatus;

  bool get isSevereAllergy =>
      kind == HealthEntryKind.allergy && severity == SeverityLevel.high;

  HealthEntry copyWith({
    String? id,
    HealthEntryKind? kind,
    String? name,
    SeverityLevel? severity,
    String? detail,
    String? date,
    bool? active,
    SyncStatus? syncStatus,
  }) {
    return HealthEntry(
      id: id ?? this.id,
      kind: kind ?? this.kind,
      name: name ?? this.name,
      severity: severity ?? this.severity,
      detail: detail ?? this.detail,
      date: date ?? this.date,
      active: active ?? this.active,
      syncStatus: syncStatus ?? this.syncStatus,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'kind': kind.name,
      'name': name,
      'severity': severity.name,
      'detail': detail,
      'date': date,
      'active': active,
      'syncStatus': syncStatus.name,
    };
  }
}

class MedicationMarkResult {
  const MedicationMarkResult({
    required this.medication,
    required this.takenCount,
    required this.totalCount,
  });

  factory MedicationMarkResult.fromJson(Map<String, dynamic> json) {
    return MedicationMarkResult(
      medication: MedicationItem.fromJson(
        json['medication'] as Map<String, dynamic>,
      ),
      takenCount: json['taken_count'] as int,
      totalCount: json['total_count'] as int,
    );
  }

  final MedicationItem medication;
  final int takenCount;
  final int totalCount;
}

class SyncSummary {
  const SyncSummary({
    required this.processed,
    required this.pending,
    required this.message,
  });

  final int processed;
  final int pending;
  final String message;
}

DateTime? _parseDate(Object? value) {
  if (value == null) {
    return null;
  }
  return DateTime.tryParse(value.toString());
}
