// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'user_model.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

User _$UserFromJson(Map<String, dynamic> json) => User(
      id: json['id'] as String,
      username: json['username'] as String,
      email: json['email'] as String,
      fullName: json['fullName'] as String,
      role: json['role'] as String? ?? 'user',
      createdAt: DateTime.parse(json['createdAt'] as String),
      lastLogin: json['lastLogin'] == null
          ? null
          : DateTime.parse(json['lastLogin'] as String),
    );

Map<String, dynamic> _$UserToJson(User instance) => <String, dynamic>{
      'id': instance.id,
      'username': instance.username,
      'email': instance.email,
      'fullName': instance.fullName,
      'role': instance.role,
      'createdAt': instance.createdAt.toIso8601String(),
      'lastLogin': instance.lastLogin?.toIso8601String(),
    };

UserCredential _$UserCredentialFromJson(Map<String, dynamic> json) =>
    UserCredential(
      username: json['username'] as String,
      password: json['password'] as String,
    );

Map<String, dynamic> _$UserCredentialToJson(UserCredential instance) =>
    <String, dynamic>{
      'username': instance.username,
      'password': instance.password,
    };
