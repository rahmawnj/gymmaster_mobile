import 'user.dart';

class AuthSession {
  final bool status;
  final String message;
  final String token;
  final String tokenType;
  final User user;

  const AuthSession({
    required this.status,
    required this.message,
    required this.token,
    required this.tokenType,
    required this.user,
  });

  factory AuthSession.fromJson(Map<String, dynamic> json) {
    final data = (json['data'] as Map<String, dynamic>? ?? <String, dynamic>{});
    final rawTokenType = (data['token_type'] ?? '').toString();

    return AuthSession(
      status: json['status'] == true,
      message: (json['message'] ?? '').toString(),
      token: (data['token'] ?? '').toString(),
      tokenType: rawTokenType.isEmpty ? 'Bearer' : rawTokenType,
      user: User.fromJson(data['user'] as Map<String, dynamic>? ?? {}),
    );
  }

  factory AuthSession.fromStorage(Map<String, dynamic> json) {
    final rawTokenType = (json['token_type'] ?? '').toString();
    return AuthSession(
      status: json['status'] == true,
      message: (json['message'] ?? '').toString(),
      token: (json['token'] ?? '').toString(),
      tokenType: rawTokenType.isEmpty ? 'Bearer' : rawTokenType,
      user: User.fromJson(json['user'] as Map<String, dynamic>? ?? {}),
    );
  }

  Map<String, dynamic> toStorageJson() {
    return {
      'status': status,
      'message': message,
      'token': token,
      'token_type': tokenType,
      'user': user.toJson(),
    };
  }
}
