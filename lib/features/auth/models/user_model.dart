import '../../../core/constants.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class UserModel {
  final String uid;
  final String email;
  final String displayName;
  final String phoneNumber;
  final String address;
  final UserRole role;
  final DateTime createdAt;

  const UserModel({
    required this.uid,
    required this.email,
    this.displayName = '',
    this.phoneNumber = '',
    this.address = '',
    required this.role,
    required this.createdAt,
  });

  factory UserModel.fromMap(String uid, Map<String, dynamic> map) {
    return UserModel(
      uid: uid,
      email: (map['email'] as String?) ?? '',
      displayName: (map['displayName'] as String?) ?? '',
      phoneNumber: (map['phoneNumber'] as String?) ?? '',
      address: (map['address'] as String?) ?? '',
      role: UserRole.fromString((map['role'] as String?) ?? 'customer'),
      createdAt: _readDateTime(map['createdAt']),
    );
  }

  Map<String, dynamic> toMap() => {
        'email': email,
        'displayName': displayName,
        'phoneNumber': phoneNumber,
        'address': address,
        'role': role.asString,
        'createdAt': createdAt,
      };
}

DateTime _readDateTime(dynamic value) {
  if (value is DateTime) return value;
  if (value is Timestamp) return value.toDate();
  return DateTime.fromMillisecondsSinceEpoch(0);
}

