enum CaregiverLinkStatus {
  pending,
  active,
  rejected,
  revoked,
  unknown;

  static CaregiverLinkStatus fromJson(Object? value) {
    return CaregiverLinkStatus.values.firstWhere(
      (status) => status.name == value,
      orElse: () => CaregiverLinkStatus.unknown,
    );
  }
}

class CaregiverInvitation {
  const CaregiverInvitation({
    required this.id,
    required this.code,
    required this.expiresAt,
  });

  factory CaregiverInvitation.fromJson(Map<String, dynamic> json) {
    return CaregiverInvitation(
      id: json['id'] as int,
      code: json['code'].toString(),
      expiresAt: DateTime.parse(json['expires_at'].toString()),
    );
  }

  final int id;
  final String code;
  final DateTime expiresAt;
}

class CaregiverLink {
  const CaregiverLink({
    required this.id,
    required this.status,
    required this.counterpartUserId,
    required this.counterpartName,
    required this.counterpartEmailMasked,
    required this.requestedAt,
    this.decidedAt,
    this.revokedAt,
  });

  factory CaregiverLink.fromJson(Map<String, dynamic> json) {
    return CaregiverLink(
      id: json['id'] as int,
      status: CaregiverLinkStatus.fromJson(json['status']),
      counterpartUserId: json['counterpart_user_id'] as int,
      counterpartName: json['counterpart_name'].toString(),
      counterpartEmailMasked: json['counterpart_email_masked'].toString(),
      requestedAt: DateTime.parse(json['requested_at'].toString()),
      decidedAt: _parseDate(json['decided_at']),
      revokedAt: _parseDate(json['revoked_at']),
    );
  }

  final int id;
  final CaregiverLinkStatus status;
  final int counterpartUserId;
  final String counterpartName;
  final String counterpartEmailMasked;
  final DateTime requestedAt;
  final DateTime? decidedAt;
  final DateTime? revokedAt;
}

class CaregiverPatient {
  const CaregiverPatient({required this.id, required this.fullName});

  factory CaregiverPatient.fromJson(Map<String, dynamic> json) {
    return CaregiverPatient(
      id: json['id'] as int,
      fullName: json['full_name'].toString(),
    );
  }

  final int id;
  final String fullName;
}

DateTime? _parseDate(Object? value) {
  if (value == null) {
    return null;
  }
  return DateTime.tryParse(value.toString());
}
