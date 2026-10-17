import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:recover_ai/core/theme/app_theme.dart';
import 'package:recover_ai/features/health_tracking/data/daily_health_log_collection.dart';
import 'package:recover_ai/features/health_tracking/data/sync_repository.dart';

enum ClinicalStatus { healthy, recovering, warning, critical }

class ClinicalRisk {
  final ClinicalStatus status;
  final String label;
  final Color color;

  const ClinicalRisk({
    required this.status,
    required this.label,
    required this.color,
  });

  static const healthy = ClinicalRisk(
    status: ClinicalStatus.healthy,
    label: 'HEALTHY',
    color: AppTheme.primaryColor,
  );
}

final clinicalRiskProvider = StreamProvider.family<ClinicalRisk, String>((ref, patientUid) {
  final logsAsync = ref.watch(patientLogHistoryProvider(patientUid));
  
  return logsAsync.when(
    data: (logs) {
      if (logs.isEmpty) {
        return Stream.value(ClinicalRisk.healthy);
      }

      final latest = logs.first;
      ClinicalRisk? risk;

      // 1. CRITICAL: High Fever (Priority 1)
      if (latest.temperature != null && latest.temperature! >= 38.0) {
        risk = const ClinicalRisk(
          status: ClinicalStatus.critical,
          label: 'CRITICAL: HIGH FEVER',
          color: AppTheme.dangerColor,
        );
      }

      // 2. CRITICAL: Extreme Pain (Priority 2)
      if (risk == null && latest.painLevel >= 9) {
        risk = const ClinicalRisk(
          status: ClinicalStatus.critical,
          label: 'CRITICAL: EXTREME PAIN',
          color: AppTheme.dangerColor,
        );
      }

      // 3. WARNING: Pain Spike (Priority 3)
      if (risk == null && logs.length >= 2) {
        final spike = logs[0].painLevel - logs[1].painLevel;
        if (spike >= 3) {
          risk = const ClinicalRisk(
            status: ClinicalStatus.warning,
            label: 'WARNING: PAIN SPIKE',
            color: Colors.orange,
          );
        }
      }

      // 4. WARNING: Chronic Plateau (Priority 4)
      if (risk == null && logs.length >= 3) {
        if (logs[0].painLevel >= 7 && logs[1].painLevel >= 7 && logs[2].painLevel >= 7) {
          risk = const ClinicalRisk(
            status: ClinicalStatus.warning,
            label: 'WARNING: STAGNANT PAIN',
            color: Colors.orange,
          );
        }
      }

      // 5. WARNING: Mood Drop
      if (risk == null && (latest.sentimentScore ?? 0.0) < -0.6) {
        risk = const ClinicalRisk(
          status: ClinicalStatus.warning,
          label: 'WARNING: MOOD DROP',
          color: Colors.orange,
        );
      }

      // 6. DEFAULT: Healthy or Recovering
      return Stream.value(risk ?? (latest.painLevel > 3 ? 
        const ClinicalRisk(status: ClinicalStatus.recovering, label: 'RECOVERING', color: Colors.blue) : 
        ClinicalRisk.healthy));
    },
    loading: () => Stream.value(ClinicalRisk.healthy),
    error: (_, __) => Stream.value(ClinicalRisk.healthy),
  );
});
