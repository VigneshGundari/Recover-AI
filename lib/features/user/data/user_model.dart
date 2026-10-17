import 'package:cloud_firestore/cloud_firestore.dart';

enum UserRole {
  patient,
  caretaker,
  doctor,
}

class PhysicalStats {
  final double heightCm;
  final double weightKg;
  final double bmi;

  PhysicalStats({
    required this.heightCm,
    required this.weightKg,
    required this.bmi,
  });

  Map<String, dynamic> toMap() {
    return {
      'height_cm': heightCm,
      'weight_kg': weightKg,
      'bmi': bmi,
      'last_updated': FieldValue.serverTimestamp(),
    };
  }

  factory PhysicalStats.fromMap(Map<String, dynamic> map) {
    return PhysicalStats(
      heightCm: (map['height_cm'] ?? 0).toDouble(),
      weightKg: (map['weight_kg'] ?? 0).toDouble(),
      bmi: (map['bmi'] ?? 0).toDouble(),
    );
  }
}

class UserModel {
  final String uid;
  final String email;
  final String? name;
  final String? phone;
  final String? address;
  final String? emergencyContactName;
  final String? emergencyContactPhone;
  final DateTime? dateOfBirth;
  final String? gender;
  final String? bloodGroup;
  final List<String> allergies;
  final PhysicalStats? stats;
  final bool onboardingCompleted;
  final String recoveryStatus;
  final DateTime? createdAt;
  
  // Care Circle & Multi-Role logic
  final UserRole role;
  final List<String> linkedCircleIds; // Supports monitoring multiple patients
  final List<String> permissions; // For caretakers/doctors
  final String? practiceCode; // Mandatory persistent code for doctors
  
  // Clinical Profile for Doctors
  final String? medicalDegree; // e.g. MD, MBBS, BHMS
  final String? alternativePhone; // Alternative contact for patients
  final String? clinicAddress; // Clinic or Hospital address

  UserModel({
    required this.uid,
    required this.email,
    this.name,
    this.phone,
    this.address,
    this.emergencyContactName,
    this.emergencyContactPhone,
    this.dateOfBirth,
    this.gender,
    this.bloodGroup,
    this.allergies = const [],
    this.stats,
    this.onboardingCompleted = false,
    this.recoveryStatus = 'healthy',
    this.createdAt,
    this.role = UserRole.patient,
    this.linkedCircleIds = const [],
    this.permissions = const [],
    this.practiceCode,
    this.medicalDegree,
    this.alternativePhone,
    this.clinicAddress,
  });

  Map<String, dynamic> toMap() {
    return {
      'uid': uid,
      'email': email,
      'name': name,
      'phone': phone,
      'address': address,
      'emergency_contact_name': emergencyContactName,
      'emergency_contact_phone': emergencyContactPhone,
      'date_of_birth': dateOfBirth != null ? Timestamp.fromDate(dateOfBirth!) : null,
      'gender': gender,
      'blood_group': bloodGroup,
      'allergies': allergies,
      'physical_stats': stats?.toMap(),
      'onboardingCompleted': onboardingCompleted,
      'recovery_status': recoveryStatus,
      'created_at': createdAt != null ? Timestamp.fromDate(createdAt!) : FieldValue.serverTimestamp(),
      'role': role.name,
      'linkedCircleIds': linkedCircleIds,
      'permissions': permissions,
      'practiceCode': practiceCode,
      'medical_degree': medicalDegree,
      'alternative_phone': alternativePhone,
      'clinic_address': clinicAddress,
    };
  }

  factory UserModel.fromMap(Map<String, dynamic> map, String docId) {
    // Migration logic for old single linkedCircleId
    List<String> circleIds = [];
    if (map['linkedCircleIds'] != null) {
      circleIds = List<String>.from(map['linkedCircleIds']);
    } else if (map['linkedCircleId'] != null || map['linked_circle_id'] != null) {
      final oldId = (map['linkedCircleId'] ?? map['linked_circle_id']) as String;
      circleIds = [oldId];
    }

    return UserModel(
      uid: docId,
      email: map['email'] ?? '',
      name: map['name'],
      phone: map['phone'],
      address: map['address'],
      emergencyContactName: map['emergency_contact_name'],
      emergencyContactPhone: map['emergency_contact_phone'],
      dateOfBirth: (map['date_of_birth'] as Timestamp?)?.toDate(),
      gender: map['gender'],
      bloodGroup: map['blood_group'],
      allergies: List<String>.from(map['allergies'] ?? []),
      stats: map['physical_stats'] != null ? PhysicalStats.fromMap(map['physical_stats']) : null,
      onboardingCompleted: map['onboardingCompleted'] ?? map['onboarding_completed'] ?? false,
      recoveryStatus: map['recovery_status'] ?? 'healthy',
      createdAt: (map['created_at'] as Timestamp?)?.toDate(),
      role: UserRole.values.firstWhere(
        (e) => e.name == (map['role'] ?? 'patient'),
        orElse: () => UserRole.patient,
      ),
      linkedCircleIds: circleIds,
      permissions: List<String>.from(map['permissions'] ?? []),
      practiceCode: map['practiceCode'],
      medicalDegree: map['medical_degree'],
      alternativePhone: map['alternative_phone'],
      clinicAddress: map['clinic_address'],
    );
  }

  UserModel copyWith({
    String? name,
    String? phone,
    String? address,
    String? emergencyContactName,
    String? emergencyContactPhone,
    DateTime? dateOfBirth,
    String? gender,
    String? bloodGroup,
    List<String>? allergies,
    PhysicalStats? stats,
    bool? onboardingCompleted,
    String? recoveryStatus,
    UserRole? role,
    List<String>? linkedCircleIds,
    List<String>? permissions,
    String? practiceCode,
    String? medicalDegree,
    String? alternativePhone,
    String? clinicAddress,
  }) {
    return UserModel(
      uid: uid,
      email: email,
      name: name ?? this.name,
      phone: phone ?? this.phone,
      address: address ?? this.address,
      emergencyContactName: emergencyContactName ?? this.emergencyContactName,
      emergencyContactPhone: emergencyContactPhone ?? this.emergencyContactPhone,
      dateOfBirth: dateOfBirth ?? this.dateOfBirth,
      gender: gender ?? this.gender,
      bloodGroup: bloodGroup ?? this.bloodGroup,
      allergies: allergies ?? this.allergies,
      stats: stats ?? this.stats,
      onboardingCompleted: onboardingCompleted ?? this.onboardingCompleted,
      recoveryStatus: recoveryStatus ?? this.recoveryStatus,
      createdAt: createdAt,
      role: role ?? this.role,
      linkedCircleIds: linkedCircleIds ?? this.linkedCircleIds,
      permissions: permissions ?? this.permissions,
      practiceCode: practiceCode ?? this.practiceCode,
      medicalDegree: medicalDegree ?? this.medicalDegree,
      alternativePhone: alternativePhone ?? this.alternativePhone,
      clinicAddress: clinicAddress ?? this.clinicAddress,
    );
  }
}
