import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:rxdart/rxdart.dart' as rxdart;
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:isar/isar.dart';
import 'package:recover_ai/features/health_tracking/data/local_health_repository.dart';
import 'package:recover_ai/features/user/data/user_repository.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'medication_task_collection.dart';
import 'daily_health_log_collection.dart';
import 'recovery_plan_collection.dart';
import 'recovery_task_log_collection.dart';
import 'smart_scan_history_collection.dart';

final syncRepositoryProvider = Provider<SyncRepository>((ref) {
  final isar = ref.watch(isarProvider);
  final userProfileAsync = ref.watch(currentUserProfileProvider);
  
  return SyncRepository(
    isar: isar,
    firestore: FirebaseFirestore.instance,
    userId: userProfileAsync.value?.uid,
  );
});

final patientMedicationsProvider = StreamProvider.family<List<MedicationTask>, String>((ref, patientUid) {
  final syncRepo = ref.watch(syncRepositoryProvider);
  return syncRepo.watchUserMedications(patientUid);
});

final patientLatestLogProvider = StreamProvider.family<HealthLog?, String>((ref, patientUid) {
  final syncRepo = ref.watch(syncRepositoryProvider);
  return syncRepo.watchUserLatestLog(patientUid);
});

final patientRecoveryProgressProvider = StreamProvider.family<double, String>((ref, patientUid) {
  final syncRepo = ref.watch(syncRepositoryProvider);
  return syncRepo.watchUserRecoveryProgress(patientUid);
});

final patientRecoveryTasksProvider = StreamProvider.family<List<RecoveryTask>, String>((ref, patientUid) {
  final syncRepo = ref.watch(syncRepositoryProvider);
  return syncRepo.watchUserRecoveryTasks(patientUid);
});

final patientLogHistoryProvider = StreamProvider.family<List<HealthLog>, String>((ref, patientUid) {
  final syncRepo = ref.watch(syncRepositoryProvider);
  return syncRepo.watchUserRecentLogs(patientUid, limit: 3);
});

final backgroundSyncProvider = Provider<void>((ref) {
  final syncRepo = ref.watch(syncRepositoryProvider);
  
  // Fire primary bi-directional sync on mount
  syncRepo.pushDirtyRecords();
  syncRepo.pullAllFromCloud();

  // Periodic heartbeat sync
  final timer = Timer.periodic(const Duration(minutes: 5), (_) {
    syncRepo.pushDirtyRecords();
    syncRepo.pullAllFromCloud();
  });

  // Cleanup to prevent memory leaks if the user logs out
  ref.onDispose(() => timer.cancel());
});

class SyncRepository {
  final Isar isar;
  final FirebaseFirestore firestore;
  final String? userId;
  bool _isSyncing = false;

  SyncRepository({
    required this.isar,
    required this.firestore,
    required this.userId,
  }) {
    // ignore: avoid_print
    print('[RECOVER_AI_DEBUG] SyncRepository: Initialized for User $userId');
  }

  Future<void> pushDirtyRecords() async {
    if (userId == null || _isSyncing) return; 
    _isSyncing = true;

    debugPrint('[RECOVER_AI_DEBUG] SyncRepository: Pushing all dirty records to Firestore');

    try {
      // Periodic Auth Refresh
      try {
        await FirebaseAuth.instance.currentUser?.getIdToken(true);
      } catch (_) {}

      // 1. Sync Medication Tasks
      final dirtyMeds = await isar.medicationTasks.filter()
          .isSyncedEqualTo(false)
          .and()
          .userIdEqualTo(userId!)
          .findAll();
      for (var task in dirtyMeds) {
        await _syncCollectionRecord('medications', task.id.toString(), task.toMap());
        await isar.writeTxn(() async {
          task.isSynced = true;
          await isar.medicationTasks.put(task);
        });
      }

      // 2. Sync Health Logs
      final dirtyHealthLogs = await isar.healthLogs.filter()
          .isSyncedEqualTo(false)
          .and()
          .userIdEqualTo(userId!)
          .findAll();
      for (var log in dirtyHealthLogs) {
        await _syncCollectionRecord('healthLogs', log.id.toString(), log.toMap());
        await isar.writeTxn(() async {
          log.isSynced = true;
          await isar.healthLogs.put(log);
        });
      }

      // 3. Sync Recovery Plans
      final dirtyPlans = await isar.recoveryPlans.filter()
          .isSyncedEqualTo(false)
          .and()
          .userIdEqualTo(userId!)
          .findAll();
      for (var plan in dirtyPlans) {
        await _syncCollectionRecord('recoveryPlans', plan.id.toString(), plan.toMap());
        await isar.writeTxn(() async {
          plan.isSynced = true;
          await isar.recoveryPlans.put(plan);
        });
      }

      // 4. Sync Recovery Task Logs
      final dirtyTaskLogs = await isar.recoveryTaskLogs.filter()
          .isSyncedEqualTo(false)
          .and()
          .userIdEqualTo(userId!)
          .findAll();
      for (var tl in dirtyTaskLogs) {
        await _syncCollectionRecord('recoveryTaskLogs', tl.id.toString(), tl.toMap());
        await isar.writeTxn(() async {
          tl.isSynced = true;
          await isar.recoveryTaskLogs.put(tl);
        });
      }

      // 5. Sync Smart Scan History
      final dirtyScans = await isar.smartScanHistorys.filter()
          .isSyncedEqualTo(false)
          .and()
          .userIdEqualTo(userId!)
          .findAll();
      for (var scan in dirtyScans) {
        await _syncCollectionRecord('smartScanHistory', scan.id.toString(), scan.toMap());
        await isar.writeTxn(() async {
          scan.isSynced = true;
          await isar.smartScanHistorys.put(scan);
        });
      }

    } finally {
      _isSyncing = false;
    }
  }

  Future<void> _syncCollectionRecord(String collectionName, String docId, Map<String, dynamic> data) async {
    try {
      await firestore
          .collection('users')
          .doc(userId)
          .collection(collectionName)
          .doc(docId)
          .set(data, SetOptions(merge: true));
    } catch (e) {
      debugPrint('[Sync Error]: Record push failed for $collectionName: $e');
    }
  }

  /// Global hydration from cloud
  Future<void> pullAllFromCloud() async {
    if (userId == null) return;
    debugPrint('[RECOVER_AI_DEBUG] SyncRepository: Pulling all global records from Firestore');

    await _pullCollection('medications', (data) => MedicationTask.fromMap(data), isar.medicationTasks);
    await _pullCollection('healthLogs', (data) => HealthLog.fromMap(data), isar.healthLogs);
    await _pullCollection('recoveryPlans', (data) => RecoveryPlan.fromMap(data), isar.recoveryPlans);
    await _pullCollection('recoveryTasks', (data) => RecoveryTask.fromMap(data), isar.recoveryTasks);
    await _pullCollection('recoveryTaskLogs', (data) => RecoveryTaskLog.fromMap(data), isar.recoveryTaskLogs);
    await _pullCollection('smartScanHistory', (data) => SmartScanHistory.fromMap(data), isar.smartScanHistorys);
  }

  /// Specialized hydration for a specific patient (used by Doctors/Caretakers)
  Future<void> pullUserFromCloud(String targetUid) async {
    debugPrint('[RECOVER_AI_DEBUG] SyncRepository: Hydrating patient data for $targetUid');
    
    await _pullCollection('medications', (data) => MedicationTask.fromMap(data), isar.medicationTasks, targetUid: targetUid);
    await _pullCollection('healthLogs', (data) => HealthLog.fromMap(data), isar.healthLogs, targetUid: targetUid);
    await _pullCollection('recoveryPlans', (data) => RecoveryPlan.fromMap(data), isar.recoveryPlans, targetUid: targetUid);
    await _pullCollection('recoveryTasks', (data) => RecoveryTask.fromMap(data), isar.recoveryTasks, targetUid: targetUid);
    await _pullCollection('recoveryTaskLogs', (data) => RecoveryTaskLog.fromMap(data), isar.recoveryTaskLogs, targetUid: targetUid);
    await _pullCollection('smartScanHistory', (data) => SmartScanHistory.fromMap(data), isar.smartScanHistorys, targetUid: targetUid);
  }

  Future<void> _pullCollection<T>(
    String collectionName, 
    T Function(Map<String, dynamic>) factory, 
    IsarCollection<T> localCollection,
    {String? targetUid}
  ) async {
    final effectiveUid = targetUid ?? userId;
    if (effectiveUid == null) return;

    try {
      final snapshot = await firestore.collection('users').doc(effectiveUid).collection(collectionName).get();
      if (snapshot.docs.isEmpty) return;

      await isar.writeTxn(() async {
        for (var doc in snapshot.docs) {
          final data = doc.data();
          data['isSynced'] = true; 
          final cloudItem = factory(data);

          // DEDUPLICATION: Attempt to find a local record that matches this cloud record
          // We look for records with the same UID and unique identifiers (Title/Time)
          // to prevent duplicates if IDs became misaligned.
          dynamic existing;
          if (cloudItem is MedicationTask) {
            existing = await isar.medicationTasks.filter()
                .userIdEqualTo(cloudItem.userId)
                .and()
                .medicationNameEqualTo(cloudItem.medicationName)
                .and()
                .scheduledTimeEqualTo(cloudItem.scheduledTime)
                .findFirst();
            if (existing != null) (cloudItem as MedicationTask).id = (existing as MedicationTask).id;
          } else if (cloudItem is HealthLog) {
            existing = await isar.healthLogs.filter()
                .userIdEqualTo(cloudItem.userId)
                .and()
                .timestampEqualTo(cloudItem.timestamp)
                .findFirst();
            if (existing != null) (cloudItem as HealthLog).id = (existing as HealthLog).id;
          } else if (cloudItem is RecoveryTask) {
            existing = await isar.recoveryTasks.filter()
                .userIdEqualTo(cloudItem.userId)
                .and()
                .titleEqualTo(cloudItem.title)
                .and()
                .startDateEqualTo(cloudItem.startDate)
                .findFirst();
            if (existing != null) (cloudItem as RecoveryTask).id = (existing as RecoveryTask).id;
          }

          // Put will update by ID if it exists, or create new
          await localCollection.put(cloudItem);
        }
      });
    } catch (e) {
      debugPrint('[Sync Error]: Pull failed for $collectionName: $e');
    }
  }

  /// Nuclear Deletion of current user's medical history in Cloud Firestore
  Future<void> wipeFirestoreData() async {
    if (userId == null) return;

    final medBatch = firestore.batch();
    final healthBatch = firestore.batch();

    // 1. Queue all medications for deletion
    final meds = await firestore.collection('users').doc(userId).collection('medications').get();
    for (var doc in meds.docs) {
      medBatch.delete(doc.reference);
    }
    await medBatch.commit();

    // 2. Queue all health logs for deletion
    final logs = await firestore.collection('users').doc(userId).collection('healthLogs').get();
    for (var doc in logs.docs) {
      healthBatch.delete(doc.reference);
    }
    await healthBatch.commit();
  }

  /// Watch medications for a specific user (for Caretakers/Doctors)
  Stream<List<MedicationTask>> watchUserMedications(String targetUid) {
    // We now watch the local ISAR collection instead of a direct Firestore stream 
    // to benefit from our unified progress math, but with STRICT UID filtering.
    return isar.medicationTasks.filter()
        .userIdEqualTo(targetUid)
        .and()
        .isDeletedEqualTo(false)
        .watch(fireImmediately: true);
  }

  /// Watch recent health logs for a specific user
  Stream<List<HealthLog>> watchUserRecentLogs(String targetUid, {int limit = 3}) {
    return isar.healthLogs.filter()
        .userIdEqualTo(targetUid)
        .sortByTimestampDesc()
        .limit(limit)
        .watch(fireImmediately: true);
  }

  /// Watch latest health log for a specific user
  Stream<HealthLog?> watchUserLatestLog(String targetUid) {
    return watchUserRecentLogs(targetUid, limit: 1).map((logs) => logs.isEmpty ? null : logs.first);
  }

  /// Watch recovery tasks for a specific user
  Stream<List<RecoveryTask>> watchUserRecoveryTasks(String targetUid) {
    return isar.recoveryTasks.filter()
        .userIdEqualTo(targetUid)
        .watch(fireImmediately: true);
  }

  /// Data-Driven Recovery Progress Algorithm (Dynamic AI Logic)
  /// Progress = Sum of (Daily Max * Performance)
  /// Performance = 50% Adherence (Meds/Tasks) + 50% Health (Pain/Mood/AI Sentiment)
  Stream<double> watchUserRecoveryProgress(String targetUid) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);

    return rxdart.Rx.combineLatest4(
      isar.recoveryPlans.filter().userIdEqualTo(targetUid).isActiveEqualTo(true).watch(fireImmediately: true),
      isar.medicationTasks.filter().userIdEqualTo(targetUid).watch(fireImmediately: true),
      isar.healthLogs.filter().userIdEqualTo(targetUid).watch(fireImmediately: true),
      isar.recoveryTaskLogs.filter().userIdEqualTo(targetUid).watch(fireImmediately: true),
      (plans, meds, logs, taskLogs) => plans.isNotEmpty ? plans.first : null,
    ).asyncMap((plan) async {
      if (plan == null) return _calculateDailyBaseline(targetUid);

      final planStart = DateTime(plan.startDate.year, plan.startDate.month, plan.startDate.day);
      final totalPlanDays = plan.endDate.difference(planStart).inDays.abs() + 1;
      if (totalPlanDays <= 0) return 0.0;

      final dailyMaxIncrement = 100.0 / totalPlanDays;
      double cumulativeProgress = 0.0;
      double yesterdayPerformance = -1.0;
      int consecutiveImprovements = 0;

      // Iterate through every day from plan start to today
      final currentDayCount = today.difference(planStart).inDays + 1;
      final effectiveElapsedDays = currentDayCount.clamp(1, totalPlanDays);

      for (int i = 0; i < effectiveElapsedDays; i++) {
        final currentDay = planStart.add(Duration(days: i));
        final nextDay = currentDay.add(const Duration(days: 1));

        // 1. Adherence Score (50% weight)
        final dayMeds = await isar.medicationTasks
            .filter()
            .userIdEqualTo(targetUid)
            .isDeletedEqualTo(false)
            .scheduledTimeBetween(currentDay, nextDay)
            .findAll();
        double medScore = dayMeds.isEmpty ? 1.0 : (dayMeds.where((m) => m.isTaken).length / dayMeds.length);

        final dayTasks = await isar.recoveryTasks
            .filter()
            .userIdEqualTo(targetUid)
            .planIdEqualTo(plan.id)
            .findAll();
        double taskScore = 1.0;
        if (dayTasks.isNotEmpty) {
          int completed = 0;
          for (final t in dayTasks) {
            final log = await isar.recoveryTaskLogs.filter().taskIdEqualTo(t.id).dateEqualTo(currentDay).findFirst();
            if (log != null) completed++;
          }
          taskScore = completed / dayTasks.length;
        }
        final adherenceScore = (medScore + taskScore) / 2.0;

        // 2. Health Score (50% weight)
        final dayLog = await isar.healthLogs
            .filter()
            .userIdEqualTo(targetUid)
            .timestampBetween(currentDay, nextDay)
            .findFirst();
        
        double healthScore = 0.0;
        if (dayLog != null) {
          final painFactor = (10 - dayLog.painLevel) / 10.0;
          final moodFactor = dayLog.moodLevel / 5.0; // 1-5 Scale (Emojis)
          final sentimentFactor = dayLog.sentimentScore ?? 0.0; // -1 to 1

          // Normalizing: Pain 40%, Mood 40%, Sentiment 20%
          healthScore = (painFactor * 0.4) + (moodFactor * 0.4) + ((sentimentFactor + 1) / 2 * 0.2);
        }

        // 3. Daily Contribution
        final dailyPerformance = (0.5 * adherenceScore) + (0.5 * healthScore);
        double dayIncrement = dailyMaxIncrement * dailyPerformance;

        // 4. Bonus Logic (Covering missed days via consistency)
        if (i > 0 && dailyPerformance > yesterdayPerformance && dailyPerformance > 0.6) {
          consecutiveImprovements++;
          if (consecutiveImprovements >= 3) {
            dayIncrement += (dailyMaxIncrement * 0.15); // 15% Bonus for consistency
          }
        } else {
          consecutiveImprovements = 0;
        }

        cumulativeProgress += dayIncrement;
        yesterdayPerformance = dailyPerformance;
      }

      debugPrint('[RECOVER_AI_PROGRESS] Calculation for $targetUid: TotalDays: $totalPlanDays, Cumulative: ${cumulativeProgress.toStringAsFixed(2)}%');

      // 5. Accuracy & Capping
      if (today.isBefore(plan.endDate)) {
        cumulativeProgress = cumulativeProgress.clamp(0.0, 99.0);
      } else {
        cumulativeProgress = cumulativeProgress.clamp(0.0, 100.0);
      }

      return cumulativeProgress / 100.0; // 0.0 to 1.0 for UI
    });
  }

  Future<double> _calculateDailyBaseline(String targetUid) async {
    final now = DateTime.now();
    final date = DateTime(now.year, now.month, now.day);
    return await _calculateAdherenceForDay(targetUid, date, -1);
  }

  Future<double> _calculateAdherenceForDay(String userId, DateTime date, int planId) async {
    final startOfDay = DateTime(date.year, date.month, date.day);
    final endOfDay = startOfDay.add(const Duration(days: 1));

    final dayMeds = await isar.medicationTasks.filter().userIdEqualTo(userId).isDeletedEqualTo(false).scheduledTimeBetween(startOfDay, endOfDay).findAll();
    double medScore = dayMeds.isEmpty ? 1.0 : (dayMeds.where((m) => m.isTaken).length / dayMeds.length);

    double taskScore = 1.0;
    if (planId != -1) {
      final dayTasks = await isar.recoveryTasks.filter().userIdEqualTo(userId).planIdEqualTo(planId).findAll();
      if (dayTasks.isNotEmpty) {
        int comp = 0;
        for (final t in dayTasks) {
          final log = await isar.recoveryTaskLogs.filter().taskIdEqualTo(t.id).dateEqualTo(startOfDay).findFirst();
          if (log != null) comp++;
        }
        taskScore = comp / dayTasks.length;
      }
    }

    final dayLog = await isar.healthLogs.filter().userIdEqualTo(userId).timestampBetween(startOfDay, endOfDay).findFirst();
    double logScore = dayLog != null ? 1.0 : 0.0;

    return (medScore * 0.4) + (taskScore * 0.4) + (logScore * 0.2);
  }
}
