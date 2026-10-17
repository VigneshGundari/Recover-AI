import 'package:isar/isar.dart';

part 'recovery_task_log_collection.g.dart';

@collection
class RecoveryTaskLog {
  Id id = Isar.autoIncrement;

  RecoveryTaskLog();

  @Index(type: IndexType.value)
  late int taskId; // Link to RecoveryTask

  late DateTime date; // The day this was completed

  @Index(type: IndexType.value)
  late String userId;

  bool isCompleted = true;

  @Index(type: IndexType.value)
  bool isSynced = false;

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'taskId': taskId,
      'userId': userId,
      'date': date.toIso8601String(),
      'isCompleted': isCompleted,
    };
  }

  factory RecoveryTaskLog.fromMap(Map<String, dynamic> map) {
    return RecoveryTaskLog()
      ..id = map['id'] ?? Isar.autoIncrement
      ..taskId = map['taskId'] ?? 0
      ..userId = map['userId'] ?? ''
      ..date = map['date'] != null ? DateTime.parse(map['date']) : DateTime.now()
      ..isCompleted = map['isCompleted'] ?? true
      ..isSynced = true;
  }
}
