import 'dart:math';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'user_model.dart';
import 'user_repository.dart';

final careCircleRepositoryProvider = Provider<CareCircleRepository>((ref) {
  return CareCircleRepository(ref.watch(firebaseFirestoreProvider), ref.read(userRepositoryProvider));
});

class CareCircleRepository {
  final FirebaseFirestore _firestore;
  final UserRepository _userRepo;

  CareCircleRepository(this._firestore, this._userRepo);

  CollectionReference get _circles => _firestore.collection('care_circles');
  CollectionReference get _invitations => _firestore.collection('invitations');

  // Generate a unique 6-character invite code
  Future<String> createInviteCode(String patientUid) async {
    int retryCount = 0;
    const maxRetries = 3;

    while (retryCount < maxRetries) {
      try {
        // Check for existing unused invite for this patient
        final existing = await _invitations
            .where('patient_uid', isEqualTo: patientUid)
            .where('is_used', isEqualTo: false)
            .limit(1)
            .get();
        
        if (existing.docs.isNotEmpty) {
          return existing.docs.first.id;
        }

        const chars = 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789'; 
        final rnd = Random();
        final code = String.fromCharCodes(Iterable.generate(
          6, (_) => chars.codeUnitAt(rnd.nextInt(chars.length)),
        ));

        await _invitations.doc(code).set({
          'patient_uid': patientUid,
          'created_at': FieldValue.serverTimestamp(),
          'is_used': false,
        });

        return code;
      } catch (e) {
        retryCount++;
        if (retryCount >= maxRetries) rethrow;
        await Future.delayed(Duration(milliseconds: 500 * retryCount));
      }
    }
    throw Exception('Failed to generate code after $maxRetries retries');
  }

  // A Caretaker or Doctor joins a patient's circle via code
  Future<void> joinCircle(String joiningUserUid, String inviteCode) async {
    final inviteDoc = await _invitations.doc(inviteCode).get();
    
    if (!inviteDoc.exists) {
      throw Exception('Invalid Invitation Code');
    }

    final data = inviteDoc.data() as Map<String, dynamic>;
    if (data['is_used'] == true) {
      throw Exception('Invitation Code already used');
    }

    final patientUid = data['patient_uid'] as String;

    // 1. Find or Create the CareCircle document
    // For simplicity, we create a circle named after the patientUid
    final circleId = 'circle_$patientUid';
    
    await _circles.doc(circleId).set({
      'patient_uid': patientUid,
      'members': FieldValue.arrayUnion([joiningUserUid]),
      'last_updated': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));

    // 2. Update the Joining User's profile
    await _userRepo.updateUser(joiningUserUid, {
      'linkedCircleIds': FieldValue.arrayUnion([circleId]),
    });

    // 3. Update the Patient's profile (ensure they point to their own circle)
    await _userRepo.updateUser(patientUid, {
      'linkedCircleIds': FieldValue.arrayUnion([circleId]),
    });

    // 4. Invalidate the code
    await _invitations.doc(inviteCode).update({'is_used': true});
  }

  // New Reverse Join: Patient joins Doctor's Practice
  Future<void> joinDoctorPractice(String patientUid, String practiceCode) async {
    // 1. Find the Doctor by Practice Code
    final doctorQuery = await _firestore.collection('users')
        .where('role', isEqualTo: 'doctor')
        .where('practiceCode', isEqualTo: practiceCode)
        .limit(1)
        .get();

    if (doctorQuery.docs.isEmpty) {
      throw Exception('Practice Code not found');
    }

    final doctorUid = doctorQuery.docs.first.id;
    final circleId = 'circle_$patientUid';

    // 2. Create/Update Circle
    await _circles.doc(circleId).set({
      'patient_uid': patientUid,
      'members': FieldValue.arrayUnion([doctorUid]), // Add doctor to patient's circle
      'last_updated': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));

    // 3. Update Doctor's profile
    await _userRepo.updateUser(doctorUid, {
      'linkedCircleIds': FieldValue.arrayUnion([circleId]),
    });

    // 4. Update Patient's profile
    await _userRepo.updateUser(patientUid, {
      'linkedCircleIds': FieldValue.arrayUnion([circleId]),
    });
  }

  // Fetch all members of a circle
  Stream<List<UserModel>> watchCircleMembers(String circleId) {
     return _circles.doc(circleId).snapshots().asyncMap((doc) async {
       if (!doc.exists || doc.data() == null) return [];
       final data = doc.data() as Map<String, dynamic>;
       final members = List<String>.from(data['members'] ?? []);
       
       final users = <UserModel>[];
       for (final uid in members) {
         final u = await _userRepo.getUser(uid);
         if (u != null) users.add(u);
       }
       return users;
     });
  }
}
