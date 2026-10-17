import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:local_notifier/local_notifier.dart';
import 'package:recover_ai/features/health_tracking/data/medication_task_collection.dart';
import 'package:recover_ai/features/health_tracking/data/local_health_repository.dart';
import 'package:recover_ai/features/health_tracking/data/recovery_plan_collection.dart';
import 'package:recover_ai/features/health_tracking/data/recovery_plan_repository.dart';
import 'package:recover_ai/features/user/data/user_repository.dart';
import 'package:recover_ai/features/health_tracking/data/daily_health_log_collection.dart';
import 'package:recover_ai/features/user/data/user_model.dart';
import 'package:recover_ai/features/health_tracking/data/sync_repository.dart';

final notificationServiceProvider = Provider<NotificationService>((ref) {
  final service = NotificationService();
  service.setRef(ref); 
  return service;
});

class NotificationService {
  Ref? _ref;
  
  // Store active timers to allow cancellation
  final Map<int, Timer> _scheduledReminders = {};
  final Map<int, Timer> _scheduledSnoozes = {};

  NotificationService();

  // Inject Riverpod Ref for database operations in notification callbacks
  void setRef(Ref ref) => _ref = ref;

  Future<void> init() async {
    // localNotifier already setup in main.dart
    debugPrint('[Notification Engine]: Windows Lightweight Engine Started.');
  }

  /// Schedules a medication reminder using a Dart-native Timer.
  Future<void> scheduleMedicationReminder(List<MedicationTask> tasksAtTime) async {
    if (tasksAtTime.isEmpty) return;

    final firstTask = tasksAtTime.first;
    final now = DateTime.now();
    final scheduledDate = firstTask.scheduledTime;
    
    // Calculate delay in milliseconds
    final int delayMs = scheduledDate.difference(now).inMilliseconds;

    if (delayMs <= 0) {
      debugPrint('[Notification Engine]: Scheduled time is in the past. Skipping.');
      return;
    }

    // Unique ID for this time slot (based on time)
    final notificationId = firstTask.scheduledTime.hour * 60 + firstTask.scheduledTime.minute;

    // Cancel existing timer for this slot if rescheduling
    _scheduledReminders[notificationId]?.cancel();
    _scheduledSnoozes[notificationId]?.cancel();

    final medNames = tasksAtTime.map((t) => t.medicationName).join(', ');
    final medIdsCsv = tasksAtTime.map((t) => t.id).join(','); // CSV of IDs
    final medCount = tasksAtTime.length;

    // 1. Schedule Primary Reminder
    _scheduledReminders[notificationId] = Timer(Duration(milliseconds: delayMs), () {
      _showWindowsToast(
        id: notificationId,
        title: medCount > 1 ? '💊 Time for your Medications' : '💊 Medication Reminder',
        body: medCount > 1 ? 'It is time to take $medNames.' : 'It is time to take ${firstTask.medicationName} (${firstTask.dosage}).',
        taskIdsCsv: medIdsCsv,
        isMedication: true,
      );

      // 2. Automatically schedule Snooze (Nag) for 15 minutes later
      _scheduleSnooze(notificationId, medNames, medIdsCsv, isMedication: true);
    });

    debugPrint('[Notification Engine]: Timer set for $medNames in ${delayMs ~/ 1000}s');
  }

  Future<void> scheduleRecoveryTaskReminder(RecoveryTask task) async {
    if (task.scheduledTime == null) return;

    final timeRegex = RegExp(r'^([0-1]?[0-9]|2[0-3]):[0-5][0-9]$');
    if (!timeRegex.hasMatch(task.scheduledTime!)) {
      debugPrint('[Notification Engine]: Skipping invalid time format: ${task.scheduledTime}');
      return;
    }

    final now = DateTime.now();
    final parts = task.scheduledTime!.split(':');
    final scheduledDate = DateTime(now.year, now.month, now.day, int.parse(parts[0]), int.parse(parts[1]));
    
    final int delayMs = scheduledDate.difference(now).inMilliseconds;
    if (delayMs <= 0) return;

    final notificationId = (task.id + 50000).toInt(); // Offset for recovery tasks

    _scheduledReminders[notificationId]?.cancel();
    _scheduledSnoozes[notificationId]?.cancel();

    _scheduledReminders[notificationId] = Timer(Duration(milliseconds: delayMs), () {
      _showWindowsToast(
        id: notificationId,
        title: '🎯 Recovery Task: ${task.title}',
        body: 'Time for your ${task.type} activity: ${task.description}',
        taskIdsCsv: task.id.toString(),
        isMedication: false,
      );

      _scheduleSnooze(notificationId, task.title, task.id.toString(), isMedication: false);
    });

    debugPrint('[Notification Engine]: Timer set for Recovery Task ${task.title} in ${delayMs ~/ 1000}s');
  }

  void _scheduleSnooze(int id, String taskName, String taskIdsCsv, {required bool isMedication}) {
    const snoozeDuration = Duration(minutes: 15);
    
    _scheduledSnoozes[id] = Timer(snoozeDuration, () {
      _showWindowsToast(
        id: id + 10000,
        title: isMedication ? '⚠️ Still haven\'t taken your meds?' : '⚠️ Pending Recovery Task',
        body: 'Reminder for $taskName. Please mark as ${isMedication ? "taken" : "done"} in the dashboard.',
        taskIdsCsv: taskIdsCsv,
        isMedication: isMedication,
      );
    });
  }

  void _showWindowsToast({
    required int id, 
    required String title, 
    required String body,
    required String taskIdsCsv,
    required bool isMedication,
  }) {
    LocalNotification notification = LocalNotification(
      identifier: taskIdsCsv, 
      title: title,
      body: body,
      actions: [
        LocalNotificationAction(text: isMedication ? '💊 Mark as Taken' : '✅ Mark as Done'),
        LocalNotificationAction(text: 'Open App'),
      ],
    );

    notification.onClick = () {
      debugPrint('[Notification Engine]: User clicked notification $id');
    };

    notification.onClickAction = (index) async {
      debugPrint('[Notification Engine]: User clicked action index: $index');
      
      if (index == 0) {
        if (_ref == null) {
          debugPrint('[Notification Engine]: ERROR: Ref not initialized yet.');
          return;
        }

        if (isMedication) {
          final repository = _ref!.read(localHealthRepositoryProvider);
          final ids = taskIdsCsv.split(',').map((id) => int.parse(id)).toList();
          for (final medId in ids) {
            await repository.toggleMedicationTaken(medId, true);
          }
        } else {
          final repository = _ref!.read(recoveryPlanRepositoryProvider);
          final user = _ref!.read(currentUserProfileProvider).value;
          if (user != null) {
            final taskId = int.parse(taskIdsCsv);
            await repository.toggleTaskCompletion(user.uid, taskId, true);
          }
        }
        
        debugPrint('[Notification Engine]: Marked tasks $taskIdsCsv as completed from notification.');
        _scheduledSnoozes[id]?.cancel();
      }
    };

    notification.show();
  }

  Future<void> cancelReminder(int id) async {
    _scheduledReminders[id]?.cancel();
    _scheduledReminders.remove(id);
    _scheduledSnoozes[id]?.cancel();
    _scheduledSnoozes.remove(id);
    debugPrint('[Notification Engine]: Cancelled timers for ID: $id');
  }

  // --- Caretaker & Doctor Monitoring Logic ---

  final Set<String> _sentCaretakerAlerts = {};
  final Set<String> _sentDoctorAlerts = {};

  /// Checks for overdue items across linked patients and notifies the caretaker.
  void checkCaretakerOverdueItems(String caretakerUid, String patientUid, String patientName, List<MedicationTask> meds, List<RecoveryTask> tasks) {
    final now = DateTime.now();
    final threshold = now.subtract(const Duration(minutes: 15));

    // Check Meds
    for (final m in meds) {
      if (!m.isTaken && m.scheduledTime.isBefore(threshold)) {
        final alertId = "med_${patientUid}_${m.id}";
        if (!_sentCaretakerAlerts.contains(alertId)) {
          _showCaretakerAlert(
            title: '⚠️ Missed Medication: $patientName',
            body: '${patientName} missed their ${m.medicationName} (${m.dosage}) scheduled for ${m.scheduledTime.hour}:${m.scheduledTime.minute}.',
          );
          _sentCaretakerAlerts.add(alertId);
        }
      }
    }
  }

  /// Trio-Trend Analysis for Doctors
  void checkDoctorRiskAlerts(String doctorUid, String patientUid, String patientName, List<HealthLog> logs) {
    if (logs.isEmpty) return;

    final latest = logs[0];
    final now = DateTime.now();
    
    // Only alert on logs from today or yesterday to ensure relevancy
    if (now.difference(latest.timestamp).inHours > 36) return;

    // 1. Sudden Pain Spike (Increase of >= 3)
    if (logs.length >= 2) {
      final prev = logs[1];
      final spike = latest.painLevel - prev.painLevel;
      if (spike >= 3) {
        final alertId = "spike_${patientUid}_${latest.timestamp.millisecondsSinceEpoch}";
        if (!_sentDoctorAlerts.contains(alertId)) {
          _showDoctorAlert(
            title: '🚨 Pain Spike: $patientName',
            body: '$patientName reported a sudden pain increase of +$spike (Current: ${latest.painLevel}/10).',
          );
          _sentDoctorAlerts.add(alertId);
        }
      }
    }

    // 2. Persistent High Pain (3-day plateau >= 8)
    if (logs.length >= 3) {
      final p1 = logs[0].painLevel;
      final p2 = logs[1].painLevel;
      final p3 = logs[2].painLevel;
      if (p1 >= 8 && p2 >= 8 && p3 >= 8) {
        final alertId = "plateau_${patientUid}_${latest.timestamp.millisecondsSinceEpoch}";
        if (!_sentDoctorAlerts.contains(alertId)) {
          _showDoctorAlert(
            title: '🛑 Persistent High Pain: $patientName',
            body: '$patientName has been at a critical pain level (8+) for 3 consecutive days.',
          );
          _sentDoctorAlerts.add(alertId);
        }
      }
    }

    // 3. Mood / Sentiment Drop (AI Vibe < -0.5)
    if ((latest.sentimentScore ?? 0.0) < -0.5) {
      final alertId = "mood_${patientUid}_${latest.timestamp.millisecondsSinceEpoch}";
      if (!_sentDoctorAlerts.contains(alertId)) {
        _showDoctorAlert(
          title: '📉 Mood Drop: $patientName',
          body: 'AI analysis suggests a significant drop in $patientName\'s emotional wellbeing.',
        );
        _sentDoctorAlerts.add(alertId);
      }
    }
  }

  void _showCaretakerAlert({required String title, required String body}) {
    LocalNotification notification = LocalNotification(
      title: title,
      body: body,
      actions: [LocalNotificationAction(text: 'Open Dashboard')],
    );
    notification.show();
  }

  void _showDoctorAlert({required String title, required String body}) {
    LocalNotification notification = LocalNotification(
      title: title,
      body: body,
      actions: [LocalNotificationAction(text: 'Review Logs')],
    );
    notification.show();
  }
}

/// Provider that activates background monitoring for a caretaker.
final caretakerMonitorProvider = Provider.autoDispose<void>((ref) {
  final user = ref.watch(currentUserProfileProvider).value;
  if (user == null || user.role != UserRole.caretaker) return;

  final notificationService = ref.watch(notificationServiceProvider);

  for (final cid in user.linkedCircleIds) {
    final patientUid = cid.replaceFirst('circle_', '');
    final patientProfile = ref.watch(userProfileProvider(patientUid)).value;
    if (patientProfile == null) continue;

    final meds = ref.watch(patientMedicationsProvider(patientUid)).value ?? [];
    final tasks = ref.watch(patientRecoveryTasksProvider(patientUid)).value ?? [];

    notificationService.checkCaretakerOverdueItems(user.uid, patientUid, patientProfile.name ?? 'Patient', meds, tasks);
  }
});

/// Session 8.6: Active Remote Patient Monitoring for Doctors
final doctorMonitorProvider = Provider.autoDispose<void>((ref) {
  final user = ref.watch(currentUserProfileProvider).value;
  if (user == null || user.role != UserRole.doctor) return;

  final notificationService = ref.watch(notificationServiceProvider);

  for (final cid in user.linkedCircleIds) {
    final patientUid = cid.replaceFirst('circle_', '');
    final patientProfile = ref.watch(userProfileProvider(patientUid)).value;
    if (patientProfile == null) continue;

    final history = ref.watch(patientLogHistoryProvider(patientUid)).value ?? [];
    notificationService.checkDoctorRiskAlerts(user.uid, patientUid, patientProfile.name ?? 'Patient', history);
  }
});
