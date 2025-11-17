import 'package:json_annotation/json_annotation.dart';

part 'user_model.g.dart';

@JsonSerializable()
class User {
  final String id;
  final String username;
  final String email;
  final String fullName;
  final String role; // admin, user
  final DateTime createdAt;
  final DateTime? lastLogin;

  User({
    required this.id,
    required this.username,
    required this.email,
    required this.fullName,
    this.role = 'user',
    required this.createdAt,
    this.lastLogin,
  });

  factory User.fromJson(Map<String, dynamic> json) => _$UserFromJson(json);
  Map<String, dynamic> toJson() => _$UserToJson(this);

  User copyWith({
    String? id,
    String? username,
    String? email,
    String? fullName,
    String? role,
    DateTime? createdAt,
    DateTime? lastLogin,
  }) {
    return User(
      id: id ?? this.id,
      username: username ?? this.username,
      email: email ?? this.email,
      fullName: fullName ?? this.fullName,
      role: role ?? this.role,
      createdAt: createdAt ?? this.createdAt,
      lastLogin: lastLogin ?? this.lastLogin,
    );
  }
}

@JsonSerializable()
class UserCredential {
  final String username;
  final String password;

  UserCredential({
    required this.username,
    required this.password,
  });

  factory UserCredential.fromJson(Map<String, dynamic> json) =>
      _$UserCredentialFromJson(json);
  Map<String, dynamic> toJson() => _$UserCredentialToJson(this);
}
