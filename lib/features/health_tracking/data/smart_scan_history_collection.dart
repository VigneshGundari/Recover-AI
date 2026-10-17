import 'package:isar/isar.dart';

part 'smart_scan_history_collection.g.dart';

@collection
class SmartScanHistory {
  Id id = Isar.autoIncrement;

  SmartScanHistory();

  @Index(type: IndexType.value)
  late String userId;

  late DateTime timestamp;
  
  late String imagePath; // Local path to the scanned image
  
  late String extractedJson; // The clinical data Gemini extracted

  @Index(type: IndexType.value)
  bool isSynced = false;

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'userId': userId,
      'timestamp': timestamp.toIso8601String(),
      'imagePath': imagePath,
      'extractedJson': extractedJson,
    };
  }

  factory SmartScanHistory.fromMap(Map<String, dynamic> map) {
    return SmartScanHistory()
      ..id = map['id'] ?? Isar.autoIncrement
      ..userId = map['userId'] ?? ''
      ..timestamp = map['timestamp'] != null ? DateTime.parse(map['timestamp']) : DateTime.now()
      ..imagePath = map['imagePath'] ?? ''
      ..extractedJson = map['extractedJson'] ?? '{}'
      ..isSynced = true;
  }
}
