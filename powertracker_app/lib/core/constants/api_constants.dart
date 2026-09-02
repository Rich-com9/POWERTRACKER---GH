class ApiConstants {
  static const String _defaultBaseUrl = 'https://powertracker-gh-e3o5.onrender.com/api';
  static const bool _isRelease = bool.fromEnvironment('dart.vm.product');
  static String _resolvedBaseUrl = '';

  static Future<void> initialize() async {
    const envBaseUrl = String.fromEnvironment('API_BASE_URL', defaultValue: '');
    if (envBaseUrl.isNotEmpty) {
      _resolvedBaseUrl = envBaseUrl;
      return;
    }

    _resolvedBaseUrl = _defaultBaseUrl;
  }

  static String get baseUrl => _resolvedBaseUrl.isNotEmpty
      ? _resolvedBaseUrl
      : (_isRelease ? '' : _defaultBaseUrl);

  static String get login => '$baseUrl/auth/token/';

  static String get register => '$baseUrl/auth/register/';

  static String get profile => '$baseUrl/auth/profile/';

  static String get changePassword => '$baseUrl/auth/change-password/';

  static String get passwordResetRequest => '$baseUrl/auth/password-reset/request/';

  static String get passwordResetConfirm => '$baseUrl/auth/password-reset/confirm/';

  static String get emailVerificationConfirm => '$baseUrl/auth/email-verification/confirm/';

  static String get emailVerificationRequest => '$baseUrl/auth/email-verification/request/';

  static String get savedAreas => '$baseUrl/auth/saved-areas/';

  static String get analytics => '$baseUrl/auth/analytics/';

  static String get adminDashboard => '$baseUrl/auth/admin/dashboard/';

  static String get outages => '$baseUrl/outages/';

  static String get activeOutages => '$baseUrl/outages/active/';

  static String get latestUpdates => '$baseUrl/outages/latest/';

  static String get notifications => '$baseUrl/notifications/';

  static String get deviceToken => '$baseUrl/notifications/device-token/';

  static String get areas => '$baseUrl/areas/';
}