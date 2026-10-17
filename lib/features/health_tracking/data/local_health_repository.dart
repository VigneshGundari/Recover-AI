import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:isar/isar.dart';
import 'medication_task_collection.dart';
import 'daily_health_log_collection.dart';
import 'sync_repository.dart';
import '../../user/data/user_repository.dart';
import '../../../core/services/notification_service.dart';

final isarProvider = Provider<Isar>((ref) => throw UnimplementedError('Initialized in main'));

final localHealthRepositoryProvider = Provider<LocalHealthRepository>((ref) {
  final isar = ref.watch(isarProvider);
  final notificationService = ref.watch(notificationServiceProvider);
  final syncRepo = ref.watch(syncRepositoryProvider);
  return LocalHealthRepository(isar, notificationService, syncRepo);
});

final todaysMedicationsProvider = StreamProvider<List<MedicationTask>>((ref) {
  final repo = ref.watch(localHealthRepositoryProvider);
  final user = ref.watch(currentUserProfileProvider).value;
  if (user == null) return Stream.value([]);
  return repo.watchTodaysMedications(user.uid);
});

final latestHealthLogProvider = StreamProvider<HealthLog?>((ref) {
  final repo = ref.watch(localHealthRepositoryProvider);
  final user = ref.watch(currentUserProfileProvider).value;
  if (user == null) return Stream.value(null);
  return repo.watchLatestHealthLog(user.uid);
});

class LocalHealthRepository {
  final Isar isar;
  final NotificationService notificationService;
  final SyncRepository syncRepo;

  LocalHealthRepository(this.isar, this.notificationService, this.syncRepo);

  Future<void> addMedicationTasks(String userId, MedicationTask baseTask, List<TimeOfDay> times) async {
    final startOfPrescription = DateTime(
      baseTask.scheduledTime.year,
      baseTask.scheduledTime.month,
      baseTask.scheduledTime.day,
    );

    await isar.writeTxn(() async {
      for (int day = 0; day < baseTask.durationDays; day++) {
        for (final time in times) {
          final scheduledDate = DateTime(
            baseTask.scheduledTime.year,
            baseTask.scheduledTime.month,
            baseTask.scheduledTime.day,
            time.hour,
            time.minute,
          ).add(Duration(days: day));

          final newTask = MedicationTask()
            ..userId = userId
            ..medicationName = baseTask.medicationName
            ..dosage = baseTask.dosage
            ..scheduledTime = scheduledDate
            ..startDate = startOfPrescription
            ..frequency = baseTask.frequency
            ..durationDays = baseTask.durationDays
            ..isTaken = false
            ..isSynced = false;

          await isar.medicationTasks.put(newTask);
        }
      }
    });
    
    // Trigger instant cloud sync
    syncRepo.pushDirtyRecords();
    
    // Schedule notifications for the first day's tasks
    for (final time in times) {
      final firstDayTime = DateTime(
        baseTask.scheduledTime.year,
        baseTask.scheduledTime.month,
        baseTask.scheduledTime.day,
        time.hour,
        time.minute,
      );
      await _rescheduleNotificationsAtTime(userId, firstDayTime);
    }
  }

  Future<void> _rescheduleNotificationsAtTime(String userId, DateTime time) async {
    // Fetch all meds for THIS user at this exact minute
    final tasks = await isar.medicationTasks
        .filter()
        .userIdEqualTo(userId)
        .isDeletedEqualTo(false)
        .isTakenEqualTo(false) // Only schedule for pending meds
        .scheduledTimeEqualTo(time)
        .findAll();

    if (tasks.isNotEmpty) {
      await notificationService.scheduleMedicationReminder(tasks);
    }
  }

  Stream<List<MedicationTask>> watchTodaysMedications(String userId) {
    final now = DateTime.now();
    final startOfDay = DateTime(now.year, now.month, now.day);
    final endOfDay = startOfDay.add(const Duration(days: 1));

    return isar.medicationTasks
        .filter()
        .userIdEqualTo(userId)
        .isDeletedEqualTo(false)
        .scheduledTimeBetween(startOfDay, endOfDay)
        .sortByScheduledTime()
        .watch(fireImmediately: true);
  }

  Stream<HealthLog?> watchLatestHealthLog(String userId) {
    return isar.healthLogs
        .filter()
        .userIdEqualTo(userId)
        .sortByTimestampDesc()
        .limit(1)
        .watch(fireImmediately: true)
        .map((logs) => logs.isNotEmpty ? logs.first : null);
  }

  /// Fetches the last N health logs for trend analysis.
  Stream<List<HealthLog>> watchPatientLogHistory(String userId, {int limit = 3}) {
    return isar.healthLogs
        .filter()
        .userIdEqualTo(userId)
        .sortByTimestampDesc()
        .limit(limit)
        .watch(fireImmediately: true);
  }

  Future<List<HealthLog>> getPatientLogHistory(String userId, {int limit = 3}) async {
    return await isar.healthLogs
        .filter()
        .userIdEqualTo(userId)
        .sortByTimestampDesc()
        .limit(limit)
        .findAll();
  }

  Future<void> toggleMedicationTaken(int id, bool isTaken) async {
    final task = await isar.medicationTasks.get(id);
    if (task != null) {
      await isar.writeTxn(() async {
        task.isTaken = isTaken;
        task.isSynced = false;
        await isar.medicationTasks.put(task);
      });
      // Trigger instant cloud sync
      syncRepo.pushDirtyRecords();
    }
  }

  Future<void> softDeleteMedication(int id, String reason) async {
    final task = await isar.medicationTasks.get(id);
    if (task != null) {
      await isar.writeTxn(() async {
        task.isDeleted = true;
        task.deletionReason = reason;
        task.isSynced = false;
        await isar.medicationTasks.put(task);
      });
      // Trigger instant cloud sync
      syncRepo.pushDirtyRecords();
    }
  }

  Future<void> addHealthLog(String userId, HealthLog log) async {
    await isar.writeTxn(() async {
      log.userId = userId;
      log.isSynced = false;
      await isar.healthLogs.put(log);
    });
    
    // Trigger instant cloud sync
    syncRepo.pushDirtyRecords();
  }

  Future<void> clearAllTasksAndLogs() async {
    await isar.writeTxn(() async {
      await isar.medicationTasks.clear();
      await isar.healthLogs.clear();
    });
  }
}
