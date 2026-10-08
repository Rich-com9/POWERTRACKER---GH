class ApiConstants {
  static const String serverHost = String.fromEnvironment(
    'API_HOST',
    defaultValue: 'http://192.168.124.68:8000',
  );

  static String get baseUrl =>
      '${serverHost.replaceFirst(RegExp(r'/+$'), '')}/api';

  static String get login => '$baseUrl/auth/token/';

  static String get register => '$baseUrl/auth/register/';

  static String get refreshToken => '$baseUrl/auth/token/refresh/';

  static String get profile => '$baseUrl/auth/profile/';

  static String get changePassword => '$baseUrl/auth/change-password/';

  static String get passwordResetRequest =>
      '$baseUrl/auth/password-reset/request/';

  static String get passwordResetConfirm =>
      '$baseUrl/auth/password-reset/confirm/';

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
