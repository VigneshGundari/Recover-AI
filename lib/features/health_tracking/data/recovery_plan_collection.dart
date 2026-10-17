import 'package:isar/isar.dart';

part 'recovery_plan_collection.g.dart';

@collection
class RecoveryPlan {
  Id id = Isar.autoIncrement;

  RecoveryPlan();

  @Index(type: IndexType.value)
  late String userId;

  late String title;
  late String description;

  late DateTime startDate;
  late DateTime endDate;

  String? reportPath; // Local path to the report image/PDF
  // For simplicity and better querying (today's tasks), we use a separate collection for Tasks.
  
  bool isActive = true;

  @Index(type: IndexType.value)
  bool isSynced = false;

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'userId': userId,
      'title': title,
      'description': description,
      'startDate': startDate.toIso8601String(),
      'endDate': endDate.toIso8601String(),
      'isActive': isActive,
      'reportPath': reportPath,
    };
  }

  factory RecoveryPlan.fromMap(Map<String, dynamic> map) {
    return RecoveryPlan()
      ..id = map['id'] ?? Isar.autoIncrement
      ..userId = map['userId'] ?? ''
      ..title = map['title'] ?? ''
      ..description = map['description'] ?? ''
      ..startDate = map['startDate'] != null ? DateTime.parse(map['startDate']) : DateTime.now()
      ..endDate = map['endDate'] != null ? DateTime.parse(map['endDate']) : DateTime.now()
      ..isActive = map['isActive'] ?? true
      ..reportPath = map['reportPath']
      ..isSynced = true;
  }
}

@collection
class RecoveryTask {
  Id id = Isar.autoIncrement;

  RecoveryTask();

  @Index(type: IndexType.value)
  late int planId; // Link to RecoveryPlan

  @Index(type: IndexType.value)
  late String userId;

  late String title;
  late String description;
  
  // Type: Exercise, Nutrition, Habit, Meds (Optional)
  late String type;

  // e.g., "09:00", "20:00" or null for "anytime"
  String? scheduledTime; 

  late DateTime startDate;
  int durationDays = 1;
  List<int> daysOfWeek = [1, 2, 3, 4, 5, 6, 7]; // 1=Mon, 7=Sun

  @Index(type: IndexType.value)
  bool isSynced = false;

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'planId': planId,
      'userId': userId,
      'title': title,
      'description': description,
      'type': type,
      'scheduledTime': scheduledTime,
      'startDate': startDate.toIso8601String(),
      'durationDays': durationDays,
      'daysOfWeek': daysOfWeek,
    };
  }

  factory RecoveryTask.fromMap(Map<String, dynamic> map) {
    return RecoveryTask()
      ..id = map['id'] ?? Isar.autoIncrement
      ..planId = map['planId'] ?? 0
      ..userId = map['userId'] ?? ''
      ..title = map['title'] ?? ''
      ..description = map['description'] ?? ''
      ..type = map['type'] ?? 'General'
      ..scheduledTime = map['scheduledTime']
      ..startDate = map['startDate'] != null ? DateTime.parse(map['startDate']) : DateTime.now()
      ..durationDays = map['durationDays'] ?? 1
      ..daysOfWeek = map['daysOfWeek'] != null ? List<int>.from(map['daysOfWeek']) : [1, 2, 3, 4, 5, 6, 7]
      ..isSynced = true;
  }
}
