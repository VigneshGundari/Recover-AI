import 'dart:math';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'user_model.dart';
import '../../auth/data/auth_repository.dart';

final firebaseFirestoreProvider = Provider<FirebaseFirestore>((ref) {
  return FirebaseFirestore.instance;
});

final userRepositoryProvider = Provider<UserRepository>((ref) {
  return UserRepository(ref.watch(firebaseFirestoreProvider));
});

final currentUserProfileProvider = StreamProvider<UserModel?>((ref) {
  final user = ref.watch(authStateProvider).value;
  if (user == null) return Stream.value(null);
  return ref.watch(userRepositoryProvider).watchUser(user.uid);
});

final userProfileProvider = StreamProvider.family<UserModel?, String>((ref, uid) {
  return ref.watch(userRepositoryProvider).watchUser(uid);
});

/// Finds the first connected doctor for the current patient
final linkedDoctorProvider = StreamProvider<UserModel?>((ref) {
  final user = ref.watch(currentUserProfileProvider).value;
  if (user == null || user.role != UserRole.patient) return Stream.value(null);

  final firestore = ref.watch(firebaseFirestoreProvider);
  
  // A doctor is linked if they share a care circle with the patient
  // For simplicity, we check if any doctor has the patient's circle in their linkedCircleIds
  final patientCircleId = 'circle_${user.uid}';
  
  return firestore.collection('users')
      .where('role', isEqualTo: 'doctor')
      .where('linkedCircleIds', arrayContains: patientCircleId)
      .limit(1)
      .snapshots()
      .map((snapshot) {
        if (snapshot.docs.isEmpty) return null;
        return UserModel.fromMap(snapshot.docs.first.data(), snapshot.docs.first.id);
      });
});

/// Finds all caretakers linked to the current patient
final linkedCaretakersProvider = StreamProvider<List<UserModel>>((ref) {
  final user = ref.watch(currentUserProfileProvider).value;
  if (user == null || user.role != UserRole.patient) return Stream.value([]);

  final firestore = ref.watch(firebaseFirestoreProvider);
  final patientCircleId = 'circle_${user.uid}';
  
  return firestore.collection('users')
      .where('role', isEqualTo: 'caretaker')
      .where('linkedCircleIds', arrayContains: patientCircleId)
      .snapshots()
      .map((snapshot) {
        return snapshot.docs.map((doc) => UserModel.fromMap(doc.data(), doc.id)).toList();
      });
});

/// Finds the primary doctor for a specific patient UID
final linkedDoctorByPatientUidProvider = StreamProvider.family<UserModel?, String>((ref, patientUid) {
  final firestore = ref.watch(firebaseFirestoreProvider);
  final patientCircleId = 'circle_$patientUid';
  
  return firestore.collection('users')
      .where('role', isEqualTo: 'doctor')
      .where('linkedCircleIds', arrayContains: patientCircleId)
      .limit(1)
      .snapshots()
      .map((snapshot) {
        if (snapshot.docs.isEmpty) return null;
        return UserModel.fromMap(snapshot.docs.first.data(), snapshot.docs.first.id);
      });
});

/// Finds all caretakers for a specific patient UID (for doctors/peers)
final linkedCaretakersByPatientUidProvider = StreamProvider.family<List<UserModel>, String>((ref, patientUid) {
  final firestore = ref.watch(firebaseFirestoreProvider);
  final patientCircleId = 'circle_$patientUid';
  
  return firestore.collection('users')
      .where('role', isEqualTo: 'caretaker')
      .where('linkedCircleIds', arrayContains: patientCircleId)
      .snapshots()
      .map((snapshot) {
        return snapshot.docs.map((doc) => UserModel.fromMap(doc.data(), doc.id)).toList();
      });
});

class UserRepository {
  final FirebaseFirestore _firestore;

  UserRepository(this._firestore);

  CollectionReference get _users => _firestore.collection('users');

  Future<void> createUser(UserModel user) async {
    await _users.doc(user.uid).set(user.toMap(), SetOptions(merge: true));
  }

  Future<void> updateUser(String uid, Map<String, dynamic> data) async {
    await _users.doc(uid).set(data, SetOptions(merge: true));
  }

  Future<UserModel?> getUser(String uid) async {
    final doc = await _users.doc(uid).get();
    if (!doc.exists || doc.data() == null) return null;
    return UserModel.fromMap(doc.data() as Map<String, dynamic>, doc.id);
  }

  Stream<UserModel?> watchUser(String uid) {
    return _users.doc(uid).snapshots().asyncMap((doc) async {
      if (!doc.exists || doc.data() == null) return null;
      final data = doc.data() as Map<String, dynamic>;
      
      // Automatic Field Fix: If we find old naming, fix it silently on the server
      if (data.containsKey('linked_circle_id') || data.containsKey('linkedCircleId') || data.containsKey('onboarding_completed')) {
        final oldId = data['linkedCircleId'] ?? data['linked_circle_id'];
        final fixed = {
          'onboardingCompleted': data['onboardingCompleted'] ?? data['onboarding_completed'],
        };
        if (oldId != null && data['linkedCircleIds'] == null) {
          fixed['linkedCircleIds'] = [oldId];
        }
        // Clean up the old fields while merging
        await _users.doc(uid).set(fixed, SetOptions(merge: true));
      }

      // Practice Code Generation for Doctors
      if (data['role'] == 'doctor' && data['practiceCode'] == null) {
        const chars = 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789';
        final rnd = Random();
        final code = 'DR-${String.fromCharCodes(Iterable.generate(4, (_) => chars.codeUnitAt(rnd.nextInt(chars.length))))}';
        await _users.doc(uid).update({'practiceCode': code});
      }

      return UserModel.fromMap(data, doc.id);
    });
  }
}
