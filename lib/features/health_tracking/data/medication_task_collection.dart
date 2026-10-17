import 'package:isar/isar.dart';

part 'medication_task_collection.g.dart'; // Isar Generator dependency

@collection
class MedicationTask {
  Id id = Isar.autoIncrement;

  MedicationTask();

  @Index(type: IndexType.value)
  late String userId;

  @Index(type: IndexType.value)
  late String medicationName;

  late String dosage;

  @Index(type: IndexType.value)
  late DateTime scheduledTime;

  @Index(type: IndexType.value)
  late DateTime startDate; // The day the overall prescription started

  bool isTaken = false;

  // New fields for scheduling logic
  int frequency = 1; // Times per day
  int durationDays = 1; // Total number of days

  // Sync state for syncing later with Firebase.
  @Index(type: IndexType.value)
  bool isSynced = false;

  // Local Audited Deletion Tracking
  @Index(type: IndexType.value)
  bool isDeleted = false;
  String? deletionReason;

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'userId': userId,
      'medicationName': medicationName,
      'dosage': dosage,
      'scheduledTime': scheduledTime.toIso8601String(),
      'startDate': startDate.toIso8601String(),
      'isTaken': isTaken,
      'frequency': frequency,
      'durationDays': durationDays,
      'isDeleted': isDeleted,
      'deletionReason': deletionReason,
    };
  }

  factory MedicationTask.fromMap(Map<String, dynamic> map) {
    return MedicationTask()
      ..id = map['id'] as int? ?? 0
      ..userId = map['userId'] as String? ?? ''
      ..medicationName = map['medicationName'] as String? ?? ''
      ..dosage = map['dosage'] as String? ?? ''
      ..scheduledTime = DateTime.parse(map['scheduledTime'] as String)
      ..startDate = DateTime.parse(map['startDate'] as String? ?? map['scheduledTime'] as String)
      ..isTaken = map['isTaken'] as bool? ?? false
      ..frequency = map['frequency'] as int? ?? 1
      ..durationDays = map['durationDays'] as int? ?? 1
      ..isDeleted = map['isDeleted'] as bool? ?? false
      ..deletionReason = map['deletionReason'] as String?;
  }
}
