import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../theme/app_theme.dart';
import 'package:recover_ai/features/user/data/user_model.dart';
import 'package:recover_ai/features/health_tracking/data/sync_repository.dart';
import 'package:recover_ai/features/health_tracking/data/daily_health_log_collection.dart';
import 'package:recover_ai/features/health_tracking/data/clinical_risk_provider.dart';

class PatientStatusCard extends ConsumerWidget {
  final UserModel patient;
  final VoidCallback onTap;

  const PatientStatusCard({
    super.key,
    required this.patient,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final progressAsync = ref.watch(patientRecoveryProgressProvider(patient.uid));
    final latestLogAsync = ref.watch(patientLatestLogProvider(patient.uid));
    final riskAsync = ref.watch(clinicalRiskProvider(patient.uid));

    return riskAsync.when(
      data: (risk) => _buildCard(context, ref, progressAsync, latestLogAsync, risk),
      loading: () => const Center(child: LinearProgressIndicator()),
      error: (_, __) => _buildCard(context, ref, progressAsync, latestLogAsync, ClinicalRisk.healthy),
    );
  }

  Widget _buildCard(
    BuildContext context, 
    WidgetRef ref, 
    AsyncValue<double> progressAsync, 
    AsyncValue<HealthLog?> latestLogAsync,
    ClinicalRisk risk,
  ) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 10),
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: AppTheme.surfaceColor,
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: AppTheme.primaryColor.withOpacity(0.1)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.2),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          children: [
            Row(
              children: [
                CircleAvatar(
                  radius: 25,
                  backgroundColor: AppTheme.primaryColor.withOpacity(0.2),
                  child: Text(
                    patient.name?[0].toUpperCase() ?? 'P',
                    style: const TextStyle(color: AppTheme.primaryColor, fontWeight: FontWeight.bold),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        patient.name ?? 'Unknown Patient',
                        style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 18),
                      ),
                      Text(
                        risk.label,
                        style: TextStyle(
                          color: risk.color,
                          fontSize: 10,
                          fontWeight: FontWeight.w900,
                          letterSpacing: 1.2,
                        ),
                      ),
                    ],
                  ),
                ),
                _buildProgressIndicator(progressAsync),
              ],
            ),
            const SizedBox(height: 20),
            const Divider(color: Colors.white10),
            const SizedBox(height: 16),
            latestLogAsync.when(
              data: (log) => _buildVitalsRow(log),
              loading: () => const LinearProgressIndicator(),
              error: (_, __) => const Text('Vitals unavailable', style: TextStyle(color: Colors.white24, fontSize: 12)),
            ),
            if (patient.address != null || patient.emergencyContactName != null) ...[
              const SizedBox(height: 16),
              const Divider(color: Colors.white10),
              const SizedBox(height: 12),
              if (patient.address != null)
                _buildDetailRow(Icons.home_rounded, patient.address!, AppTheme.textSecondary),
              if (patient.emergencyContactName != null) ...[
                const SizedBox(height: 8),
                _buildDetailRow(
                  Icons.contact_phone_rounded,
                  '${patient.emergencyContactName} (${patient.emergencyContactPhone ?? "No Phone"})',
                  Colors.orange.withOpacity(0.8),
                ),
              ],
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildDetailRow(IconData icon, String text, Color color) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 14, color: color),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            text,
            style: TextStyle(color: Colors.white70, fontSize: 12, height: 1.2),
          ),
        ),
      ],
    );
  }

  Widget _buildProgressIndicator(AsyncValue<double> progress) {
    return progress.when(
      data: (value) => Stack(
        alignment: Alignment.center,
        children: [
          CircularProgressIndicator(
            value: value,
            strokeWidth: 6,
            backgroundColor: Colors.white10,
            valueColor: AlwaysStoppedAnimation<Color>(_getProgressColor(value)),
          ),
          Text(
            '${(value * 100).toInt()}%',
            style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12),
          ),
        ],
      ),
      loading: () => const CircularProgressIndicator(strokeWidth: 2),
      error: (_, __) => const Icon(Icons.error_outline, color: AppTheme.dangerColor),
    );
  }

  Widget _buildVitalsRow(HealthLog? log) {
    if (log == null) {
      return const Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text('No logs submitted today', style: TextStyle(color: Colors.white24, fontSize: 13)),
        ],
      );
    }

    final isHighTemp = (log.temperature ?? 0) >= 38.0;
    final isHighPain = log.painLevel >= 8;
    final isPoorMood = log.moodLevel <= 2;

    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceAround,
      children: [
        _VitalsMini(
          icon: Icons.thermostat_rounded, 
          value: '${log.temperature ?? "--"}°C', 
          color: isHighTemp ? AppTheme.dangerColor : AppTheme.primaryColor
        ),
        _VitalsMini(
          icon: Icons.favorite_rounded, 
          value: '${log.painLevel}/10', 
          color: isHighPain ? AppTheme.dangerColor : (log.painLevel > 4 ? Colors.orange : Colors.green)
        ),
        _VitalsMini(
          icon: Icons.mood_rounded, 
          value: '${log.moodLevel}/5', 
          color: isPoorMood ? Colors.orange : Colors.blue
        ),
      ],
    );
  }

  Color _getStatusColor(String status) {
    switch (status.toLowerCase()) {
      case 'healthy': return AppTheme.primaryColor;
      case 'recovering': return Colors.orange;
      case 'critical': return AppTheme.dangerColor;
      default: return Colors.white54;
    }
  }

  Color _getProgressColor(double progress) {
    if (progress > 0.8) return AppTheme.primaryColor;
    if (progress > 0.5) return Colors.orange;
    return AppTheme.dangerColor;
  }
}

class _VitalsMini extends StatelessWidget {
  final IconData icon;
  final String value;
  final Color color;

  const _VitalsMini({required this.icon, required this.value, required this.color});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, color: color.withOpacity(0.7), size: 16),
        const SizedBox(width: 6),
        Text(value, style: const TextStyle(color: Colors.white70, fontSize: 14, fontWeight: FontWeight.w500)),
      ],
    );
  }
}

// End of file
