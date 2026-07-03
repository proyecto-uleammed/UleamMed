import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

abstract class UleamMedApi {
  Future<DemoSession> loadDemoSession();
  Future<List<MedicationItem>> listMedications();
  Future<MedicationMarkResult> markMedicationTaken(String medicationId);
}

class ApiService implements UleamMedApi {
  ApiService({http.Client? client, String? baseUrl})
    : _client = client ?? http.Client(),
      _baseUrl = baseUrl ?? _defaultBaseUrl;

  final http.Client _client;
  final String _baseUrl;
  String? _accessToken;

  static const _demoEmail = 'roberto@uleammed.demo';
  static const _demoPassword = 'clave-segura-123';
  static const _demoName = 'Roberto Andrade';

  static String get _defaultBaseUrl {
    const configuredUrl = String.fromEnvironment('ULEAMMED_API_URL');
    if (configuredUrl.isNotEmpty) {
      return configuredUrl;
    }

    if (kIsWeb) {
      return 'http://127.0.0.1:8000';
    }

    switch (defaultTargetPlatform) {
      case TargetPlatform.android:
        return 'http://10.0.2.2:8000';
      default:
        return 'http://127.0.0.1:8000';
    }
  }

  @override
  Future<DemoSession> loadDemoSession() async {
    final health = await _getJson(Uri.parse('$_baseUrl/health'));

    final token = await _ensureAccessToken();
    final user = await _getJson(
      Uri.parse('$_baseUrl/api/v1/users/me'),
      headers: {'Authorization': 'Bearer $token'},
    );

    return DemoSession(
      apiUrl: _baseUrl,
      environment: health['environment']?.toString() ?? 'development',
      user: DemoUser(
        id: user['id'] as int,
        email: user['email'].toString(),
        fullName: user['full_name']?.toString() ?? 'Usuario demo',
        isActive: user['is_active'] == true,
      ),
    );
  }

  @override
  Future<List<MedicationItem>> listMedications() async {
    final token = await _ensureAccessToken();
    final data = await _getJson(
      Uri.parse('$_baseUrl/api/v1/medications'),
      headers: {'Authorization': 'Bearer $token'},
    );

    final items = data['items'];
    if (items is! List) {
      throw const ApiException('Respuesta inesperada de medicamentos');
    }

    return items
        .whereType<Map<String, dynamic>>()
        .map(MedicationItem.fromJson)
        .toList();
  }

  @override
  Future<MedicationMarkResult> markMedicationTaken(String medicationId) async {
    final token = await _ensureAccessToken();
    final data = await _postJson(
      Uri.parse('$_baseUrl/api/v1/medications/$medicationId/take'),
      headers: {'Authorization': 'Bearer $token'},
    );

    return MedicationMarkResult.fromJson(data);
  }

  Future<String> _ensureAccessToken() async {
    if (_accessToken != null) {
      return _accessToken!;
    }

    await _ensureDemoUser();
    _accessToken = await _loginDemoUser();
    return _accessToken!;
  }

  Future<void> _ensureDemoUser() async {
    final response = await _client.post(
      Uri.parse('$_baseUrl/api/v1/auth/register'),
      headers: _jsonHeaders,
      body: jsonEncode({
        'email': _demoEmail,
        'password': _demoPassword,
        'full_name': _demoName,
      }),
    );

    if (response.statusCode == 201 || response.statusCode == 409) {
      return;
    }

    throw ApiException(
      'No se pudo preparar el usuario demo',
      response.statusCode,
    );
  }

  Future<String> _loginDemoUser() async {
    final response = await _client.post(
      Uri.parse('$_baseUrl/api/v1/auth/login'),
      headers: _jsonHeaders,
      body: jsonEncode({'email': _demoEmail, 'password': _demoPassword}),
    );

    if (response.statusCode != 200) {
      throw ApiException('No se pudo iniciar sesion demo', response.statusCode);
    }

    final data = _decodeObject(response);
    return data['access_token'].toString();
  }

  Future<Map<String, dynamic>> _getJson(
    Uri uri, {
    Map<String, String>? headers,
  }) async {
    final response = await _client.get(uri, headers: headers);
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw ApiException(
        'La API no respondio correctamente',
        response.statusCode,
      );
    }

    return _decodeObject(response);
  }

  Future<Map<String, dynamic>> _postJson(
    Uri uri, {
    Map<String, String>? headers,
    Object? body,
  }) async {
    final response = await _client.post(
      uri,
      headers: {..._jsonHeaders, ...?headers},
      body: body == null ? null : jsonEncode(body),
    );
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw ApiException(
        'La API no respondio correctamente',
        response.statusCode,
      );
    }

    return _decodeObject(response);
  }

  Map<String, dynamic> _decodeObject(http.Response response) {
    final decoded = jsonDecode(response.body);
    if (decoded is Map<String, dynamic>) {
      return decoded;
    }

    throw const ApiException('Respuesta inesperada del backend');
  }

  static const _jsonHeaders = {
    'Content-Type': 'application/json',
    'Accept': 'application/json',
  };
}

class DemoSession {
  const DemoSession({
    required this.apiUrl,
    required this.environment,
    required this.user,
  });

  final String apiUrl;
  final String environment;
  final DemoUser user;
}

class DemoUser {
  const DemoUser({
    required this.id,
    required this.email,
    required this.fullName,
    required this.isActive,
  });

  final int id;
  final String email;
  final String fullName;
  final bool isActive;
}

class MedicationItem {
  const MedicationItem({
    required this.id,
    required this.name,
    required this.dose,
    required this.time,
    required this.taken,
  });

  factory MedicationItem.fromJson(Map<String, dynamic> json) {
    return MedicationItem(
      id: json['id'].toString(),
      name: json['name'].toString(),
      dose: json['dose'].toString(),
      time: json['time'].toString(),
      taken: json['taken'] == true,
    );
  }

  final String id;
  final String name;
  final String dose;
  final String time;
  final bool taken;
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

class ApiException implements Exception {
  const ApiException(this.message, [this.statusCode]);

  final String message;
  final int? statusCode;

  @override
  String toString() {
    if (statusCode == null) {
      return message;
    }

    return '$message (HTTP $statusCode)';
  }
}
