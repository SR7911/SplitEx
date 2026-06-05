import 'package:cloud_firestore/cloud_firestore.dart';

class UserModel {
  final String uid;
  final String name;
  final String email;
  final String? avatarUrl;
  final String? upiId;
  final List<String> rooms;
  final DateTime createdAt;

  const UserModel({
    required this.uid,
    required this.name,
    required this.email,
    this.avatarUrl,
    this.upiId,
    this.rooms = const [],
    required this.createdAt,
  });

  factory UserModel.fromMap(Map<String, dynamic> map, String uid) {
    return UserModel(
      uid: uid,
      name: map['name'] ?? '',
      email: map['email'] ?? '',
      avatarUrl: map['avatarUrl'],
      upiId: map['upiId'],
      rooms: List<String>.from(map['rooms'] ?? []),
      createdAt: (map['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'name': name,
      'email': email,
      'avatarUrl': avatarUrl,
      'upiId': upiId,
      'rooms': rooms,
      'createdAt': FieldValue.serverTimestamp(),
    };
  }

  UserModel copyWith({
    String? name,
    String? avatarUrl,
    String? upiId,
    List<String>? rooms,
  }) {
    return UserModel(
      uid: uid,
      name: name ?? this.name,
      email: email,
      avatarUrl: avatarUrl ?? this.avatarUrl,
      upiId: upiId ?? this.upiId,
      rooms: rooms ?? this.rooms,
      createdAt: createdAt,
    );
  }

  bool get hasUpiId => upiId != null && upiId!.isNotEmpty;
}
