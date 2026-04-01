import 'dart:convert';

/// The signed-in Google user profile, returned from the backend after
/// verifying the Google idToken.
class AuthUser {
  final String id;
  final String email;
  final String? displayName;
  final String? avatarUrl;

  const AuthUser({
    required this.id,
    required this.email,
    this.displayName,
    this.avatarUrl,
  });

  factory AuthUser.fromJson(Map<String, dynamic> json) => AuthUser(
        id: json['id'] as String,
        email: json['email'] as String,
        displayName: json['display_name'] as String?,
        avatarUrl: json['avatar_url'] as String?,
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'email': email,
        'display_name': displayName,
        'avatar_url': avatarUrl,
      };

  String toJsonString() => jsonEncode(toJson());

  factory AuthUser.fromJsonString(String s) =>
      AuthUser.fromJson(jsonDecode(s) as Map<String, dynamic>);
}
