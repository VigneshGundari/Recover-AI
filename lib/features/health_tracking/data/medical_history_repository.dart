import 'dart:io';
import 'dart:typed_data';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:isar/isar.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;
import 'local_health_repository.dart';
import 'recovery_plan_collection.dart';
import 'smart_scan_history_collection.dart';
import 'sync_repository.dart';
import '../../user/data/user_repository.dart';

final medicalHistoryRepositoryProvider = Provider<MedicalHistoryRepository>((ref) {
  final isar = ref.watch(isarProvider);
  final syncRepo = ref.watch(syncRepositoryProvider);
  return MedicalHistoryRepository(isar, syncRepo);
});

final smartScanHistoryProvider = StreamProvider<List<SmartScanHistory>>((ref) {
  final repo = ref.watch(medicalHistoryRepositoryProvider);
  final user = ref.watch(currentUserProfileProvider).value;
  if (user == null) return Stream.value([]);
  return repo.watchSmartScanHistory(user.uid);
});

class MedicalHistoryRepository {
  final Isar isar;
  final SyncRepository syncRepo;

  MedicalHistoryRepository(this.isar, this.syncRepo);

  /// Saves a file to local application documents and returns the path
  Future<String> saveDocumentLocally(Uint8List bytes, String prefix) async {
    final dir = await getApplicationDocumentsDirectory();
    final folder = Directory(p.join(dir.path, 'medical_documents'));
    if (!await folder.exists()) {
      await folder.create(recursive: true);
    }
    
    final fileName = '${prefix}_${DateTime.now().millisecondsSinceEpoch}.jpg';
    final file = File(p.join(folder.path, fileName));
    await file.writeAsBytes(bytes);
    return file.path;
  }

  Future<void> saveScanHistory({
    required String userId,
    required String imagePath,
    required String extractedJson,
  }) async {
    await isar.writeTxn(() async {
      final history = SmartScanHistory()
        ..userId = userId
        ..timestamp = DateTime.now()
        ..imagePath = imagePath
        ..extractedJson = extractedJson;
      await isar.smartScanHistorys.put(history);
    });
    syncRepo.pushDirtyRecords();
  }

  Stream<List<SmartScanHistory>> watchSmartScanHistory(String userId) {
    return isar.smartScanHistorys
        .filter()
        .userIdEqualTo(userId)
        .sortByTimestampDesc()
        .watch(fireImmediately: true);
  }

  Stream<List<RecoveryPlan>> watchRecoveryPlanHistory(String userId) {
    return isar.recoveryPlans
        .filter()
        .userIdEqualTo(userId)
        .sortByStartDateDesc()
        .watch(fireImmediately: true);
  }

  Future<void> deleteScan(int id) async {
    await isar.writeTxn(() async {
      final scan = await isar.smartScanHistorys.get(id);
      if (scan != null) {
        final file = File(scan.imagePath);
        if (await file.exists()) await file.delete();
        await isar.smartScanHistorys.delete(id);
      }
    });
  }
}
