import 'user_model.dart';

class LoginResponseModel {
  final String message;
  final String userType;
  final String accessToken;
  final DateTime expiresAt;
  final String sessionId;
  final UserModel user;

  LoginResponseModel({
    required this.message,
    required this.userType,
    required this.accessToken,
    required this.expiresAt,
    required this.sessionId,
    required this.user,
  });

  factory LoginResponseModel.fromJson(Map<String, dynamic> json) {
    return LoginResponseModel(
      message: json['message'] ?? '',
      userType: json['user_type'] ?? '',
      accessToken: json['access_token'] ?? '',
      expiresAt: json['expires_at'] != null 
          ? DateTime.parse(json['expires_at']) 
          : DateTime.now(),
      sessionId: json['session_id'] ?? '',
      user: UserModel.fromJson(json['user'] ?? {}),
    );
  }
}