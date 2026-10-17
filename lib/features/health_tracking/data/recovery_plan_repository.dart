import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:isar/isar.dart';
import 'package:rxdart/rxdart.dart' as rxdart;
import 'package:recover_ai/core/services/notification_service.dart';
import 'recovery_plan_collection.dart';
import 'recovery_task_log_collection.dart';
import 'local_health_repository.dart';
import 'sync_repository.dart';
import '../../user/data/user_repository.dart';

final recoveryPlanRepositoryProvider = Provider<RecoveryPlanRepository>((ref) {
  final isar = ref.watch(isarProvider);
  final notificationService = ref.watch(notificationServiceProvider);
  final syncRepo = ref.watch(syncRepositoryProvider);
  return RecoveryPlanRepository(isar, notificationService, syncRepo);
});

final activeRecoveryPlanProvider = StreamProvider<RecoveryPlan?>((ref) {
  final repo = ref.watch(recoveryPlanRepositoryProvider);
  final user = ref.watch(currentUserProfileProvider).value;
  if (user == null) return Stream.value(null);
  return repo.watchActivePlan(user.uid);
});

final todaysRecoveryTasksProvider = StreamProvider<List<Map<String, dynamic>>>((ref) {
  final repo = ref.watch(recoveryPlanRepositoryProvider);
  final user = ref.watch(currentUserProfileProvider).value;
  if (user == null) return Stream.value([]);
  return repo.watchTodaysTasksWithLogs(user.uid);
});

class RecoveryPlanRepository {
  final Isar isar;
  final NotificationService notificationService;
  final SyncRepository syncRepo;

  RecoveryPlanRepository(this.isar, this.notificationService, this.syncRepo);

  Stream<RecoveryPlan?> watchActivePlan(String userId) {
    return isar.recoveryPlans
        .filter()
        .userIdEqualTo(userId)
        .isActiveEqualTo(true)
        .watch(fireImmediately: true)
        .map((plans) => plans.isNotEmpty ? plans.first : null);
  }

  Stream<List<Map<String, dynamic>>> watchTodaysTasksWithLogs(String userId) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);

    // Combine both streams for instant reactivity
    return rxdart.Rx.combineLatest2(
      isar.recoveryTasks.filter().userIdEqualTo(userId).watch(fireImmediately: true),
      isar.recoveryTaskLogs.filter().userIdEqualTo(userId).dateEqualTo(today).watch(fireImmediately: true),
      (tasks, logs) => _PlanDataPacket(tasks, logs),
    ).asyncMap((packet) async {
      final List<Map<String, dynamic>> results = [];
      
      // Get the active plan to know its end date for persistent visibility
      final activePlan = await isar.recoveryPlans
          .filter()
          .userIdEqualTo(userId)
          .isActiveEqualTo(true)
          .findFirst();
          
      if (activePlan == null) return [];

      for (final task in packet.tasks) {
        // Fallback for empty daysOfWeek
        final effectiveDays = task.daysOfWeek.isEmpty ? [1, 2, 3, 4, 5, 6, 7] : task.daysOfWeek;
        final isScheduledToday = effectiveDays.contains(now.weekday);
        
        // Fallback for missing/invalid startDate
        final taskStart = DateTime(task.startDate.year, task.startDate.month, task.startDate.day);
        final dayNum = today.difference(taskStart).inDays + 1;
        
        // Fallback for durationDays
        final effectiveDuration = task.durationDays == 0 ? activePlan.endDate.difference(activePlan.startDate).inDays + 1 : task.durationDays;
        
        // Check if today is within the task's individual duration
        final isWithinTaskDuration = dayNum >= 1 && dayNum <= effectiveDuration;

        // INSTANT MATCH: Use the logs from the stream packet instead of a fresh DB query
        final bool isCompletedToday = packet.logs.any((l) => l.taskId == task.id);

        // Logic for persistent visibility
        bool shouldShow = (isScheduledToday && isWithinTaskDuration) || isCompletedToday;

        if (!shouldShow && effectiveDuration <= 1) {
          // Check if it was completed at any time during this plan
          final hasAnyCompletion = await isar.recoveryTaskLogs
              .filter()
              .taskIdEqualTo(task.id)
              .userIdEqualTo(userId)
              .isCompletedEqualTo(true)
              .findFirst();
          if (hasAnyCompletion != null) {
            shouldShow = true; 
          }
        }

        if (shouldShow) {
          results.add({
            'task': task,
            'isCompleted': isCompletedToday,
            'dayXofY': 'Day $dayNum of $effectiveDuration',
            'planProgress': (dayNum / effectiveDuration).clamp(0.0, 1.0),
          });
        }
      }
      return results;
    });
  }

  Future<void> savePlan(String userId, Map<String, dynamic> planData, List<Map<String, dynamic>> tasksData, {String? reportPath}) async {
    await isar.writeTxn(() async {
      // 1. Deactivate existing plans
      final oldPlans = await isar.recoveryPlans.filter().userIdEqualTo(userId).isActiveEqualTo(true).findAll();
      for (var p in oldPlans) {
        p.isActive = false;
        await isar.recoveryPlans.put(p);
      }

      // 2. Create new plan
      final plan = RecoveryPlan()
        ..userId = userId
        ..title = planData['title']
        ..description = planData['description']
        ..startDate = DateTime.now()
        ..endDate = DateTime.now().add(Duration(days: planData['durationDays'] as int))
        ..reportPath = reportPath
        ..isActive = true;
      
      final planId = await isar.recoveryPlans.put(plan);

      // 3. Create tasks
      for (var td in tasksData) {
        final task = RecoveryTask()
          ..userId = userId
          ..planId = planId
          ..title = td['title']
          ..description = td['description']
          ..type = td['type']
          ..scheduledTime = td['scheduledTime']
          ..startDate = DateTime.now()
          ..durationDays = planData['durationDays'] as int
          ..daysOfWeek = [1, 2, 3, 4, 5, 6, 7];
        
        final taskId = await isar.recoveryTasks.put(task);
        task.id = taskId;
        
        // Schedule notification if time exists
        if (task.scheduledTime != null) {
          try {
            await notificationService.scheduleRecoveryTaskReminder(task);
          } catch (e) {
            debugPrint('Error scheduling task reminder for ${task.title}: $e');
          }
        }
      }
    });
    syncRepo.pushDirtyRecords();
  }

  Future<void> updateTask(RecoveryTask task) async {
    await isar.writeTxn(() async {
      await isar.recoveryTasks.put(task);
    });
    
    if (task.scheduledTime != null) {
      await notificationService.scheduleRecoveryTaskReminder(task);
    }
    syncRepo.pushDirtyRecords();
  }

  Future<void> updatePlanDuration(int planId, int newDurationDays) async {
    await isar.writeTxn(() async {
      final plan = await isar.recoveryPlans.get(planId);
      if (plan != null) {
        plan.endDate = plan.startDate.add(Duration(days: newDurationDays));
        plan.isSynced = false;
        await isar.recoveryPlans.put(plan);
      }
    });
    syncRepo.pushDirtyRecords();
  }

  Future<void> toggleTaskCompletion(String userId, int taskId, bool completed) async {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);

    await isar.writeTxn(() async {
      final existingLog = await isar.recoveryTaskLogs
          .filter()
          .taskIdEqualTo(taskId)
          .userIdEqualTo(userId)
          .dateEqualTo(today)
          .findFirst();

      if (completed && existingLog == null) {
        final log = RecoveryTaskLog()
          ..taskId = taskId
          ..userId = userId
          ..date = today
          ..isCompleted = true;
        await isar.recoveryTaskLogs.put(log);
      } else if (!completed && existingLog != null) {
        await isar.recoveryTaskLogs.delete(existingLog.id);
      }
    });
    syncRepo.pushDirtyRecords();
  }

  Future<void> deletePlan(int planId) async {
    await isar.writeTxn(() async {
      await isar.recoveryPlans.delete(planId);
      await isar.recoveryTasks.filter().planIdEqualTo(planId).deleteAll();
    });
    syncRepo.pushDirtyRecords();
  }
}

class _PlanDataPacket {
  final List<RecoveryTask> tasks;
  final List<RecoveryTaskLog> logs;
  _PlanDataPacket(this.tasks, this.logs);
}
