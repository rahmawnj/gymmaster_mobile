class GymAccessRequest {
  final String requestToken;
  final String status;
  final String displayState;
  final String qrPayload;
  final String scanUrl;
  final String statusUrl;
  final DateTime? requestedAt;
  final DateTime? expiresAt;
  final int expiresInSeconds;
  final int refreshAfterSeconds;
  final bool isExpired;
  final bool isScanned;
  final DateTime? scannedAt;
  final String flashType;
  final String flashTitle;
  final String flashMessage;

  const GymAccessRequest({
    required this.requestToken,
    required this.status,
    required this.displayState,
    required this.qrPayload,
    required this.scanUrl,
    required this.statusUrl,
    this.requestedAt,
    this.expiresAt,
    required this.expiresInSeconds,
    required this.refreshAfterSeconds,
    required this.isExpired,
    required this.isScanned,
    this.scannedAt,
    required this.flashType,
    required this.flashTitle,
    required this.flashMessage,
  });

  factory GymAccessRequest.fromApiJson(Map<String, dynamic> json) {
    DateTime? parseDate(String? v) {
      if (v == null || v.isEmpty) return null;
      try {
        return DateTime.parse(v).toLocal();
      } catch (_) {
        return null;
      }
    }

    final flash = json['flash'];
    final parsedStatus = json['status']?.toString().toLowerCase() ?? '';
    final parsedDisplayState = json['display_state']?.toString() ?? '';
    final parsedIsExpired = json['is_expired'] == true || parsedStatus == 'expired';
    final parsedIsScanned = json['is_scanned'] == true || parsedStatus == 'scanned';

    return GymAccessRequest(
      requestToken: json['request_token']?.toString() ?? '',
      status: parsedStatus,
      displayState: parsedDisplayState,
      qrPayload: json['qr_payload']?.toString() ?? '',
      scanUrl: json['scan_url']?.toString() ?? '',
      statusUrl: json['status_url']?.toString() ?? '',
      requestedAt: parseDate(json['requested_at']?.toString()),
      expiresAt: parseDate(json['expires_at']?.toString()),
      expiresInSeconds: int.tryParse(json['expires_in_seconds']?.toString() ?? '') ?? 0,
      refreshAfterSeconds:
          int.tryParse(json['refresh_after_seconds']?.toString() ?? '') ?? 0,
      isExpired: parsedIsExpired,
      isScanned: parsedIsScanned,
      scannedAt: parseDate(json['scanned_at']?.toString()),
      flashType: flash is Map<String, dynamic> ? flash['type']?.toString() ?? '' : '',
      flashTitle:
          flash is Map<String, dynamic> ? flash['title']?.toString() ?? '' : '',
      flashMessage:
          flash is Map<String, dynamic> ? flash['message']?.toString() ?? '' : '',
    );
  }

  GymAccessRequest copyWith({
    String? requestToken,
    String? status,
    String? displayState,
    String? qrPayload,
    String? scanUrl,
    String? statusUrl,
    DateTime? requestedAt,
    DateTime? expiresAt,
    int? expiresInSeconds,
    int? refreshAfterSeconds,
    bool? isExpired,
    bool? isScanned,
    DateTime? scannedAt,
    String? flashType,
    String? flashTitle,
    String? flashMessage,
  }) {
    return GymAccessRequest(
      requestToken: requestToken ?? this.requestToken,
      status: status ?? this.status,
      displayState: displayState ?? this.displayState,
      qrPayload: qrPayload ?? this.qrPayload,
      scanUrl: scanUrl ?? this.scanUrl,
      statusUrl: statusUrl ?? this.statusUrl,
      requestedAt: requestedAt ?? this.requestedAt,
      expiresAt: expiresAt ?? this.expiresAt,
      expiresInSeconds: expiresInSeconds ?? this.expiresInSeconds,
      refreshAfterSeconds: refreshAfterSeconds ?? this.refreshAfterSeconds,
      isExpired: isExpired ?? this.isExpired,
      isScanned: isScanned ?? this.isScanned,
      scannedAt: scannedAt ?? this.scannedAt,
      flashType: flashType ?? this.flashType,
      flashTitle: flashTitle ?? this.flashTitle,
      flashMessage: flashMessage ?? this.flashMessage,
    );
  }
}
