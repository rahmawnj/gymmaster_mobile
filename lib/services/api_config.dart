class ApiConfig {
  static const String _defaultBaseUrl =
      // 'http://192.168.10.104/GYMMASTERAPP/api_gymmaster_id/api';
      'https://be.gymmaster.id/api/v1/web/';

  static const String baseUrl = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: _defaultBaseUrl,
  );

  static String get apiBase =>
      baseUrl.endsWith('/') ? baseUrl : '$baseUrl/';

  static String get displayBaseUrl => baseUrl;

  static String get serverHint =>
      'Pastikan API aktif di $displayBaseUrl. Untuk HP fisik, pakai IP laptop/PC, bukan localhost.';
}
