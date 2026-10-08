import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

import '../core/constants/api_constants.dart';
import '../core/storage/token_storage.dart';

class ApiService {
  final http.Client _client;

  ApiService({http.Client? client})
      : _client = client ?? http.Client();

  // ============================================================
  // LOGIN
  // ============================================================

  Future<Map<String, dynamic>> login(
    String email,
    String password,
  ) async {
    final response = await _client.post(
      Uri.parse(ApiConstants.login),
      headers: {
        'Content-Type': 'application/json',
      },
      body: jsonEncode({
        'email': email,
        'password': password,
      }),
    ).timeout(
      const Duration(seconds: 15),
      onTimeout: () => throw Exception(
        'Login request timed out. Check your connection and try again.',
      ),
    );

    final data = jsonDecode(response.body);

    if (response.statusCode >= 200 &&
        response.statusCode < 300) {
      return Map<String, dynamic>.from(data);
    }

    if (data is Map && data.containsKey('detail')) {
      throw Exception(data['detail']);
    }

    if (data is Map && data.containsKey('message')) {
      throw Exception(data['message']);
    }

    throw Exception('Login failed.');
  }

  Future<String?> refreshAccessToken(String refreshToken) async {
    final response = await _client.post(
      Uri.parse(ApiConstants.refreshToken),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'refresh': refreshToken}),
    ).timeout(const Duration(seconds: 15));

    if (response.statusCode < 200 || response.statusCode >= 300) {
      return null;
    }

    final data = jsonDecode(response.body);
    final accessToken = data is Map ? data['access']?.toString() : null;
    if (accessToken == null || accessToken.isEmpty) return null;

    await TokenStorage().saveTokens(accessToken: accessToken);
    return accessToken;
  }

  // ============================================================
  // REGISTER
  // ============================================================

  Future<Map<String, dynamic>> register({
    required String username,
    required String name,
    required String email,
    required String phone,
    required String password,
  }) async {
    final response = await _client.post(
      Uri.parse(ApiConstants.register),
      headers: {
        'Content-Type': 'application/json',
      },
      body: jsonEncode({
        'username': username,
        'name': name,
        'email': email,
        'phone': phone,
        'password': password,
      }),
    );

    debugPrint('REGISTER STATUS: ${response.statusCode}');
    debugPrint('REGISTER RESPONSE: ${response.body}');

    final data = jsonDecode(response.body);

    if (response.statusCode >= 200 &&
        response.statusCode < 300) {
      return Map<String, dynamic>.from(data);
    }

    if (data is Map &&
        data.containsKey('detail')) {
      throw Exception(data['detail']);
    }

    if (data is Map) {
      final errors = <String>[];

      for (final entry in data.entries) {
        final value = entry.value;

        if (value is List) {
          errors.addAll(
            value.map((item) => item.toString()),
          );
        } else {
          errors.add(value.toString());
        }
      }

      if (errors.isNotEmpty) {
        throw Exception(errors.join(', '));
      }
    }

    throw Exception('Unable to create account.');
  }

  Future<void> changePassword({
    required String token,
    required String currentPassword,
    required String newPassword,
    required String confirmPassword,
  }) async {
    final response = await _client.post(
      Uri.parse(ApiConstants.changePassword),
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token',
      },
      body: jsonEncode({
        'current_password': currentPassword,
        'new_password': newPassword,
        'confirm_password': confirmPassword,
      }),
    );

    if (response.statusCode >= 200 && response.statusCode < 300) return;

    final data = jsonDecode(response.body);
    if (data is Map) {
      final errors = <String>[];
      for (final value in data.values) {
        if (value is List) {
          errors.addAll(value.map((item) => item.toString()));
        } else {
          errors.add(value.toString());
        }
      }
      if (errors.isNotEmpty) throw Exception(errors.join(', '));
    }

    throw Exception('Unable to change password.');
  }

  Future<void> requestPasswordReset(String email) async {
    final response = await _client.post(
      Uri.parse(ApiConstants.passwordResetRequest),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'email': email}),
    );
    final data = jsonDecode(response.body);
    if (response.statusCode >= 200 && response.statusCode < 300) return;
    if (data is Map && data.containsKey('detail')) {
      throw Exception(data['detail']);
    }
    throw Exception('Unable to request a password reset.');
  }

  Future<void> confirmPasswordReset({
    required String email,
    required String code,
    required String newPassword,
    required String confirmPassword,
  }) async {
    final response = await _client.post(
      Uri.parse(ApiConstants.passwordResetConfirm),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'email': email,
        'code': code,
        'new_password': newPassword,
        'confirm_password': confirmPassword,
      }),
    );
    final data = jsonDecode(response.body);
    if (response.statusCode >= 200 && response.statusCode < 300) return;
    if (data is Map) {
      final errors = <String>[];
      for (final value in data.values) {
        if (value is List) {
          errors.addAll(value.map((item) => item.toString()));
        } else {
          errors.add(value.toString());
        }
      }
      if (errors.isNotEmpty) throw Exception(errors.join(', '));
    }
    throw Exception('Unable to reset password.');
  }

  // ============================================================
  // GET ALL OUTAGES
  // ============================================================

  Future<List<dynamic>> getAllOutages(
    String token,
  ) async {
    var response = await _client.get(
      Uri.parse(ApiConstants.outages),
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token',
      },
    );

    if (response.statusCode == 401) {
      final refreshToken = await TokenStorage().getRefreshToken();
      if (refreshToken != null && refreshToken.isNotEmpty) {
        final refreshedToken = await refreshAccessToken(refreshToken);
        if (refreshedToken != null) {
          response = await _client.get(
            Uri.parse(ApiConstants.outages),
            headers: {
              'Content-Type': 'application/json',
              'Authorization': 'Bearer $refreshedToken',
            },
          );
        }
      }
    }

    debugPrint(
      'ALL OUTAGES STATUS: ${response.statusCode}',
    );

    final data = jsonDecode(response.body);

    if (response.statusCode >= 200 &&
        response.statusCode < 300) {
      if (data is List) {
        return data;
      }

      if (data is Map &&
          data.containsKey('results')) {
        return List<dynamic>.from(data['results']);
      }

      return [];
    }

    if (data is Map &&
        data.containsKey('detail')) {
      if (response.statusCode == 401) {
        await TokenStorage().clearTokens();
        throw Exception('Your session has expired. Please log in again.');
      }
      throw Exception(data['detail']);
    }

    throw Exception('Unable to load outages.');
  }

  // ============================================================
  // GET ACTIVE OUTAGES
  // ============================================================

  Future<List<dynamic>> getActiveOutages(
    String token,
  ) async {
    final response = await _client.get(
      Uri.parse(ApiConstants.activeOutages),
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token',
      },
    );

    debugPrint(
      'ACTIVE OUTAGES STATUS: ${response.statusCode}',
    );

    debugPrint(
      'ACTIVE OUTAGES RESPONSE: ${response.body}',
    );

    final data = jsonDecode(response.body);

    if (response.statusCode >= 200 &&
        response.statusCode < 300) {
      if (data is List) {
        return data;
      }

      if (data is Map &&
          data.containsKey('results')) {
        return List<dynamic>.from(
          data['results'],
        );
      }

      return [];
    }

    if (data is Map &&
        data.containsKey('detail')) {
      throw Exception(data['detail']);
    }

    throw Exception(
      'Unable to load active outages.',
    );
  }

  Future<List<dynamic>> getLatestUpdates(
    String token,
  ) async {
    final response = await _client.get(
      Uri.parse(ApiConstants.latestUpdates),
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token',
      },
    );

    final data = jsonDecode(response.body);
    if (response.statusCode >= 200 &&
        response.statusCode < 300) {
      if (data is List) return data;
      if (data is Map && data['results'] is List) {
        return List<dynamic>.from(data['results']);
      }
      return [];
    }

    if (data is Map && data['detail'] != null) {
      throw Exception(data['detail']);
    }

    throw Exception('Unable to load latest updates.');
  }

  // ============================================================
  // CONFIRM OUTAGE
  // ============================================================

  Future<Map<String, dynamic>> confirmOutage({
    required String token,
    required int outageId,
  }) async {
    final response = await _client.post(
      Uri.parse('${ApiConstants.outages}$outageId/confirm/'),
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token',
      },
    );

    final data = jsonDecode(response.body);

    if (response.statusCode >= 200 &&
        response.statusCode < 300) {
      return Map<String, dynamic>.from(data);
    }

    if (data is Map &&
        data.containsKey('detail')) {
      throw Exception(data['detail']);
    }

    throw Exception('Unable to confirm outage.');
  }

  Future<Map<String, dynamic>> resolveOutage({
    required String token,
    required int outageId,
  }) async {
    final response = await _client.post(
      Uri.parse('${ApiConstants.outages}$outageId/resolve/'),
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token',
      },
    );

    final data = jsonDecode(response.body);

    if (response.statusCode >= 200 && response.statusCode < 300) {
      return Map<String, dynamic>.from(data);
    }

    if (data is Map && data.containsKey('detail')) {
      throw Exception(data['detail']);
    }

    throw Exception('Unable to mark outage as restored.');
  }

  Future<Map<String, dynamic>> verifyOutage({
    required String token,
    required int outageId,
    required bool isAccurate,
  }) async {
    final response = await _client.post(
      Uri.parse('${ApiConstants.outages}$outageId/verify/'),
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token',
      },
      body: jsonEncode({'is_accurate': isAccurate}),
    );

    final data = jsonDecode(response.body);

    if (response.statusCode >= 200 && response.statusCode < 300) {
      return Map<String, dynamic>.from(data);
    }

    if (data is Map && data.containsKey('detail')) {
      throw Exception(data['detail']);
    }

    throw Exception('Unable to verify outage.');
  }

  Future<void> rejectOutage({
    required String token,
    required int outageId,
  }) async {
    final response = await _client.post(
      Uri.parse('${ApiConstants.outages}$outageId/reject/'),
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token',
      },
    );

    if (response.statusCode >= 200 && response.statusCode < 300) return;

    final data = jsonDecode(response.body);
    if (data is Map && data.containsKey('detail')) {
      throw Exception(data['detail']);
    }

    throw Exception('Unable to reject outage report.');
  }

  Future<void> createOutageUpdate({
    required String token,
    required int outageId,
    required String message,
  }) async {
    final response = await _client.post(
      Uri.parse('${ApiConstants.outages}$outageId/updates/'),
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token',
      },
      body: jsonEncode({'message': message}),
    );

    if (response.statusCode >= 200 && response.statusCode < 300) return;

    final data = jsonDecode(response.body);
    if (data is Map && data.containsKey('detail')) {
      throw Exception(data['detail']);
    }

    throw Exception('Unable to send outage update.');
  }

  Future<Map<String, dynamic>> createScheduledOutage({
    required String token,
    required int areaId,
    required String description,
    required String locationAddress,
    required String latitude,
    required String longitude,
    required String scheduledFor,
  }) async {
    final response = await _client.post(
      Uri.parse('${ApiConstants.outages}scheduled/'),
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token',
      },
      body: jsonEncode({
        'area': areaId,
        'description': description,
        'location_address': locationAddress,
        'latitude': latitude,
        'longitude': longitude,
        'scheduled_for': scheduledFor,
      }),
    );

    final data = jsonDecode(response.body);
    if (response.statusCode >= 200 && response.statusCode < 300) {
      return Map<String, dynamic>.from(data);
    }
    if (data is Map && data.containsKey('detail')) {
      throw Exception(data['detail']);
    }
    throw Exception('Unable to create scheduled outage.');
  }

  // ============================================================
  // NOTIFICATIONS
  // ============================================================

  Future<List<dynamic>> getNotifications(
    String token,
  ) async {
    final response = await _client.get(
      Uri.parse(ApiConstants.notifications),
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token',
      },
    );

    final data = jsonDecode(response.body);

    if (response.statusCode >= 200 &&
        response.statusCode < 300) {
      if (data is List) return data;
      if (data is Map && data['results'] is List) {
        return List<dynamic>.from(data['results']);
      }
      return [];
    }

    if (data is Map && data.containsKey('detail')) {
      throw Exception(data['detail']);
    }

    throw Exception('Unable to load notifications.');
  }

  Future<void> markNotificationRead({
    required String token,
    required int notificationId,
  }) async {
    final response = await _client.patch(
      Uri.parse('${ApiConstants.notifications}$notificationId/read/'),
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token',
      },
      body: jsonEncode({'is_read': true}),
    );

    if (response.statusCode >= 200 &&
        response.statusCode < 300) {
      return;
    }

    final data = jsonDecode(response.body);
    if (data is Map && data.containsKey('detail')) {
      throw Exception(data['detail']);
    }

    throw Exception('Unable to mark notification as read.');
  }

  // ============================================================
  // PROFILE
  // ============================================================

  Future<Map<String, dynamic>> getProfile(
    String token,
  ) async {
    final response = await _client.get(
      Uri.parse(ApiConstants.profile),
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token',
      },
    );

    final data = jsonDecode(response.body);

    if (response.statusCode >= 200 &&
        response.statusCode < 300) {
      return Map<String, dynamic>.from(data);
    }

    if (data is Map && data.containsKey('detail')) {
      throw Exception(data['detail']);
    }

    throw Exception('Unable to load profile.');
  }

  Future<Map<String, dynamic>> updateProfile({
    required String token,
    required String username,
    required String name,
    required String email,
    required String phone,
  }) async {
    final response = await _client.patch(
      Uri.parse(ApiConstants.profile),
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token',
      },
      body: jsonEncode({
        'username': username,
        'name': name,
        'email': email,
        'phone': phone,
      }),
    );

    final data = jsonDecode(response.body);

    if (response.statusCode >= 200 && response.statusCode < 300) {
      return Map<String, dynamic>.from(data);
    }

    if (data is Map && data.containsKey('detail')) {
      throw Exception(data['detail']);
    }

    if (data is Map) {
      throw Exception(data.values.expand((value) {
        return value is List
            ? value.map((item) => item.toString())
            : [value.toString()];
      }).join(', '));
    }

    throw Exception('Unable to update profile.');
  }

  // ============================================================
  // SAVED AREAS
  // ============================================================

  Future<List<dynamic>> getSavedAreas(
    String token,
  ) async {
    final response = await _client.get(
      Uri.parse(ApiConstants.savedAreas),
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token',
      },
    );

    final data = jsonDecode(response.body);

    if (response.statusCode >= 200 && response.statusCode < 300) {
      if (data is List) return data;
      if (data is Map && data['results'] is List) {
        return List<dynamic>.from(data['results']);
      }
      return [];
    }

    if (data is Map && data.containsKey('detail')) {
      throw Exception(data['detail']);
    }

    throw Exception('Unable to load saved areas.');
  }

  Future<Map<String, dynamic>> saveArea({
    required String token,
    required int areaId,
  }) async {
    final response = await _client.post(
      Uri.parse(ApiConstants.savedAreas),
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token',
      },
      body: jsonEncode({'area': areaId}),
    );

    final data = jsonDecode(response.body);

    if (response.statusCode >= 200 && response.statusCode < 300) {
      return Map<String, dynamic>.from(data);
    }

    if (data is Map && data.containsKey('detail')) {
      throw Exception(data['detail']);
    }

    if (data is Map) {
      throw Exception(data.values.expand((value) {
        return value is List ? value.map((item) => item.toString()) : [value.toString()];
      }).join(', '));
    }

    throw Exception('Unable to save area.');
  }

  Future<void> deleteSavedArea({
    required String token,
    required int savedAreaId,
  }) async {
    final response = await _client.delete(
      Uri.parse('${ApiConstants.savedAreas}$savedAreaId/'),
      headers: {
        'Authorization': 'Bearer $token',
      },
    );

    if (response.statusCode >= 200 && response.statusCode < 300) return;

    final data = jsonDecode(response.body);
    if (data is Map && data.containsKey('detail')) {
      throw Exception(data['detail']);
    }

    throw Exception('Unable to remove saved area.');
  }

  Future<Map<String, dynamic>> getAnalytics(
    String token,
  ) async {
    final response = await _client.get(
      Uri.parse(ApiConstants.analytics),
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token',
      },
    );

    final data = jsonDecode(response.body);

    if (response.statusCode >= 200 && response.statusCode < 300) {
      return Map<String, dynamic>.from(data);
    }

    if (data is Map && data.containsKey('detail')) {
      throw Exception(data['detail']);
    }

    throw Exception('Unable to load analytics.');
  }

  Future<Map<String, dynamic>> getAdminDashboard(
    String token,
  ) async {
    final response = await _client.get(
      Uri.parse(ApiConstants.adminDashboard),
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token',
      },
    );

    final data = jsonDecode(response.body);

    if (response.statusCode >= 200 && response.statusCode < 300) {
      return Map<String, dynamic>.from(data);
    }

    if (data is Map && data.containsKey('detail')) {
      throw Exception(data['detail']);
    }

    throw Exception('Unable to load admin dashboard.');
  }

  Future<void> registerDeviceToken({
    required String token,
    required String deviceToken,
    String platform = 'android',
  }) async {
    final response = await _client.post(
      Uri.parse(ApiConstants.deviceToken),
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token',
      },
      body: jsonEncode({
        'token': deviceToken,
        'platform': platform,
      }),
    );

    if (response.statusCode >= 200 && response.statusCode < 300) return;

    final data = jsonDecode(response.body);
    if (data is Map && data.containsKey('detail')) {
      throw Exception(data['detail']);
    }
    throw Exception('Unable to register device notifications.');
  }

  // ============================================================
  // GET ALL AREAS
  // ============================================================

  Future<List<dynamic>> getAreas(
    String token,
  ) async {
    final response = await _client.get(
      Uri.parse(ApiConstants.areas),
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token',
      },
    );

    debugPrint(
      'AREAS STATUS: ${response.statusCode}',
    );

    debugPrint(
      'AREAS RESPONSE: ${response.body}',
    );

    final data = jsonDecode(response.body);

    if (response.statusCode >= 200 &&
        response.statusCode < 300) {
      if (data is List) {
        return data;
      }

      if (data is Map &&
          data.containsKey('results')) {
        return List<dynamic>.from(
          data['results'],
        );
      }

      return [];
    }

    if (data is Map &&
        data.containsKey('detail')) {
      throw Exception(data['detail']);
    }

    throw Exception(
      'Unable to load areas.',
    );
  }

  // ============================================================
  // CREATE / REPORT OUTAGE
  // ============================================================

  Future<Map<String, dynamic>> createOutage({
    required String token,
    required int areaId,
    required String description,
    required String locationAddress,
    required String latitude,
    required String longitude,
    required String outageType,
    required String outageTime,
    String? imagePath,
  }) async {
    final request = http.MultipartRequest(
      'POST',
      Uri.parse(ApiConstants.outages),
    )
      ..headers['Authorization'] = 'Bearer $token'
      ..fields['area'] = areaId.toString()
      ..fields['description'] = description
      ..fields['location_address'] = locationAddress
      ..fields['latitude'] = latitude
      ..fields['longitude'] = longitude
      ..fields['outage_type'] = outageType
      ..fields['outage_time'] = outageTime;

    if (imagePath != null && imagePath.isNotEmpty) {
      request.files.add(
        await http.MultipartFile.fromPath('image', imagePath),
      );
    }

    final streamedResponse = await _client.send(request);
    final response = await http.Response.fromStream(streamedResponse);

    debugPrint(
      'CREATE OUTAGE STATUS: ${response.statusCode}',
    );

    debugPrint(
      'CREATE OUTAGE RESPONSE: ${response.body}',
    );

    final data = jsonDecode(response.body);

    if (response.statusCode >= 200 &&
        response.statusCode < 300) {
      return Map<String, dynamic>.from(data);
    }

    if (data is Map &&
        data.containsKey('detail')) {
      throw Exception(data['detail']);
    }

    if (data is Map) {
      final errors = <String>[];

      for (final entry in data.entries) {
        final value = entry.value;

        if (value is List) {
          errors.addAll(
            value.map((item) => item.toString()),
          );
        } else {
          errors.add(value.toString());
        }
      }

      if (errors.isNotEmpty) {
        throw Exception(errors.join(', '));
      }
    }

    throw Exception(
      'Unable to report outage.',
    );
  }
}
