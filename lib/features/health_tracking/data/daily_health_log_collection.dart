import 'package:isar/isar.dart';

part 'daily_health_log_collection.g.dart';

@collection
class HealthLog {
  Id id = Isar.autoIncrement;

  HealthLog();
  
  @Index(type: IndexType.value)
  late String userId;

  // Quantitative 1-10 metrics for graphs and trends
  late int painLevel;
  late int moodLevel;
  
  // New fields for Session 7 and 8
  double? temperature;
  double? sentimentScore; // AI Sentiment -1 to 1
  List<String> symptoms = [];

  // Qualitative Large String mapped to the AI analysis layer
  late String aiJournalEntry;

  @Index(type: IndexType.value)
  late DateTime timestamp;

  // Sync state for syncing later with Firebase.
  @Index(type: IndexType.value)
  bool isSynced = false;

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'userId': userId,
      'painLevel': painLevel,
      'moodLevel': moodLevel,
      'temperature': temperature,
      'sentimentScore': sentimentScore,
      'symptoms': symptoms,
      'aiJournalEntry': aiJournalEntry,
      'timestamp': timestamp.toIso8601String(),
    };
  }

  factory HealthLog.fromMap(Map<String, dynamic> map) {
    return HealthLog()
      ..id = map['id'] as int? ?? 0
      ..userId = map['userId'] as String? ?? ''
      ..painLevel = map['painLevel'] as int? ?? 5
      ..moodLevel = map['moodLevel'] as int? ?? 3
      ..temperature = (map['temperature'] as num?)?.toDouble()
      ..sentimentScore = (map['sentimentScore'] as num?)?.toDouble()
      ..symptoms = List<String>.from(map['symptoms'] ?? [])
      ..aiJournalEntry = map['aiJournalEntry'] as String? ?? ''
      ..timestamp = DateTime.parse(map['timestamp'] as String);
  }
}
