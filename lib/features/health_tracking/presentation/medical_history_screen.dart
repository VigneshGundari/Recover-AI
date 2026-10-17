import 'dart:io';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:recover_ai/core/theme/app_theme.dart';
import '../data/medical_history_repository.dart';
import '../data/smart_scan_history_collection.dart';
import '../data/recovery_plan_collection.dart';
import '../../user/data/user_repository.dart';
import 'package:rxdart/rxdart.dart';

final unifiedHistoryProvider = StreamProvider<List<dynamic>>((ref) {
  final repo = ref.watch(medicalHistoryRepositoryProvider);
  final user = ref.watch(currentUserProfileProvider).value;
  if (user == null) return Stream.value([]);
  
  return Rx.combineLatest2(
    repo.watchSmartScanHistory(user.uid),
    repo.watchRecoveryPlanHistory(user.uid),
    (List<SmartScanHistory> scans, List<RecoveryPlan> plans) {
      final List<dynamic> combined = [...scans, ...plans];
      combined.sort((a, b) {
        final dateA = (a is SmartScanHistory) ? a.timestamp : a.startDate;
        final dateB = (b is SmartScanHistory) ? b.timestamp : b.startDate;
        return dateB.compareTo(dateA); // Descending order
      });
      return combined;
    },
  );
});

class MedicalHistoryScreen extends ConsumerWidget {
  const MedicalHistoryScreen({super.key});

  void _showDocumentPreview(BuildContext context, String path, String title) {
    showDialog(
      context: context,
      builder: (ctx) => Dialog(
        backgroundColor: Colors.transparent,
        insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  IconButton(
                    onPressed: () => Navigator.pop(ctx), 
                    icon: const Icon(Icons.close, color: Colors.white)
                  ),
                ],
              ),
              ClipRRect(
                borderRadius: BorderRadius.circular(20),
                child: Image.file(
                  File(path), 
                  fit: BoxFit.contain,
                ),
              ),
              const SizedBox(height: 16),
              Text(
                title, 
                style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final historyAsync = ref.watch(unifiedHistoryProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Medical History'),
            Text('Clinical Archive', style: TextStyle(fontSize: 12, color: AppTheme.primaryColor)),
          ],
        ),
      ),
      body: historyAsync.when(
        data: (items) {
          if (items.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.inventory_2_outlined, size: 64, color: AppTheme.textSecondary.withOpacity(0.5)),
                  const SizedBox(height: 16),
                  const Text('No clinical history found.', style: TextStyle(color: AppTheme.textSecondary)),
                ],
              ),
            );
          }

          return ListView.builder(
            padding: const EdgeInsets.all(20),
            itemCount: items.length,
            itemBuilder: (context, index) {
              final item = items[index];
              if (item is SmartScanHistory) {
                 return _buildScanTile(context, item);
              } else if (item is RecoveryPlan) {
                 return _buildPlanTile(context, item);
              }
              return const SizedBox.shrink();
            },
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Error: $e')),
      ),
    );
  }

  Widget _buildScanTile(BuildContext context, SmartScanHistory scan) {
    final List<dynamic> drugs = jsonDecode(scan.extractedJson);
    return Container(
      margin: const EdgeInsets.only(bottom: 20),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppTheme.surfaceColor,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: AppTheme.primaryColor.withOpacity(0.1)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Row(
                children: [
                   Icon(Icons.document_scanner_rounded, color: AppTheme.primaryColor, size: 18),
                   SizedBox(width: 8),
                   Text('Smart Prescription Scan', style: TextStyle(color: AppTheme.primaryColor, fontWeight: FontWeight.bold, fontSize: 12)),
                ],
              ),
              Text(_formatDate(scan.timestamp), style: const TextStyle(color: AppTheme.textSecondary, fontSize: 10)),
            ],
          ),
          const SizedBox(height: 16),
          // Drugs summary
          ...drugs.map((d) => Padding(
            padding: const EdgeInsets.only(bottom: 4.0),
            child: Row(
              children: [
                const Icon(Icons.medication_rounded, size: 14, color: Colors.white70),
                const SizedBox(width: 8),
                Text(d['name'], style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14)),
                const Spacer(),
                Text(d['dosage'], style: const TextStyle(color: AppTheme.textSecondary, fontSize: 12)),
              ],
            ),
          )),
          const SizedBox(height: 16),
          ElevatedButton.icon(
            onPressed: () => _showDocumentPreview(context, scan.imagePath, 'Prescription Scan'), 
            icon: const Icon(Icons.remove_red_eye_rounded, size: 18),
            label: const Text('View Original Document'),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.white.withOpacity(0.05),
              foregroundColor: Colors.white,
              minimumSize: const Size(double.infinity, 44),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              elevation: 0,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPlanTile(BuildContext context, RecoveryPlan plan) {
    return Container(
      margin: const EdgeInsets.only(bottom: 20),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppTheme.surfaceColor,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: Colors.blue.withOpacity(0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Row(
                children: [
                   Icon(Icons.health_and_safety_rounded, color: Colors.blue, size: 18),
                   SizedBox(width: 8),
                   Text('Recovery Strategy Generated', style: TextStyle(color: Colors.blue, fontWeight: FontWeight.bold, fontSize: 12)),
                ],
              ),
              Text(_formatDate(plan.startDate), style: const TextStyle(color: AppTheme.textSecondary, fontSize: 10)),
            ],
          ),
          const SizedBox(height: 12),
          Text(plan.title, style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
          const SizedBox(height: 4),
          Text(plan.description, style: const TextStyle(color: AppTheme.textSecondary, fontSize: 12)),
          
          if (plan.reportPath != null) ...[
            const SizedBox(height: 16),
            ElevatedButton.icon(
              onPressed: () => _showDocumentPreview(context, plan.reportPath!, 'Recovery Analysis Report'), 
              icon: const Icon(Icons.attachment_rounded, size: 18),
              label: const Text('View Reports Basis'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.blue.withOpacity(0.1),
                foregroundColor: Colors.blue,
                minimumSize: const Size(double.infinity, 44),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                elevation: 0,
              ),
            ),
          ],
        ],
      ),
    );
  }

  String _formatDate(DateTime date) {
    return "${date.day}/${date.month}/${date.year}";
  }
}
