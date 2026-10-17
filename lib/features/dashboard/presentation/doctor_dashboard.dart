import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:recover_ai/core/theme/app_theme.dart';
import 'package:recover_ai/features/user/data/user_repository.dart';
import 'package:recover_ai/features/health_tracking/data/sync_repository.dart';
import 'package:recover_ai/features/user/data/user_model.dart';
import 'package:recover_ai/core/widgets/progress_ring.dart';
import 'package:recover_ai/features/dashboard/presentation/patient_detail_screen.dart';
import 'package:recover_ai/core/services/notification_service.dart';
import 'package:recover_ai/features/dashboard/presentation/doctor_profile_dialog.dart';
import 'package:recover_ai/features/health_tracking/data/clinical_risk_provider.dart';

class DoctorDashboard extends ConsumerStatefulWidget {
  const DoctorDashboard({super.key});

  @override
  ConsumerState<DoctorDashboard> createState() => _DoctorDashboardState();
}

class _DoctorDashboardState extends ConsumerState<DoctorDashboard> with SingleTickerProviderStateMixin {
  late AnimationController _pulseController;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _pulseController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Session 8.6: Activate Remote Patient Monitoring Alerts
    ref.watch(doctorMonitorProvider);

    final theme = Theme.of(context);
    final userProfile = ref.watch(currentUserProfileProvider).value;

    if (userProfile == null) return const Center(child: CircularProgressIndicator());

    final patientCircleIds = userProfile.linkedCircleIds;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Practice Header
        Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: AppTheme.surfaceColor,
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: AppTheme.primaryColor.withOpacity(0.2)),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.2),
                blurRadius: 10,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Row(
            children: [
              CircleAvatar(
                radius: 30,
                backgroundColor: AppTheme.primaryColor.withOpacity(0.1),
                child: const Icon(Icons.medical_services_rounded, color: AppTheme.primaryColor, size: 30),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Clinical Practice', style: theme.textTheme.bodyLarge?.copyWith(color: AppTheme.textSecondary)),
                    Text('Dr. ${userProfile.name ?? "Specialist"}', style: theme.textTheme.headlineSmall),
                  ],
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  const Text('Practice Code', style: TextStyle(color: AppTheme.textSecondary, fontSize: 10, fontWeight: FontWeight.bold)),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: AppTheme.primaryColor,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      userProfile.practiceCode ?? '---',
                      style: const TextStyle(color: AppTheme.backgroundColor, fontWeight: FontWeight.w900, fontSize: 16),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),

        const SizedBox(height: 32),

        // 1.5 Clinical Profile Prompt (Lean Onboarding Follow-up)
        if (userProfile.medicalDegree == null || userProfile.clinicAddress == null)
          _buildProfileCompletionPrompt(userProfile),

        // Triage Section Header
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text('Remote Patient Monitoring', style: theme.textTheme.titleLarge),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: Colors.red.withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                children: [
                  const Icon(Icons.error_outline_rounded, color: Colors.red, size: 14),
                  const SizedBox(width: 4),
                  Text('${patientCircleIds.length} Total', style: const TextStyle(color: Colors.red, fontSize: 12, fontWeight: FontWeight.bold)),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),

        // Patient List
        if (patientCircleIds.isEmpty)
          _buildEmptyPracticePrompt()
        else
          ListView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: patientCircleIds.length,
            itemBuilder: (context, index) {
              final circleId = patientCircleIds[index];
              final patientUid = circleId.replaceFirst('circle_', '');
              return _PatientMonitoringCard(patientUid: patientUid, pulseAnimation: _pulseController);
            },
          ),
      ],
    );
  }

  Widget _buildProfileCompletionPrompt(UserModel userProfile) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 32),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [AppTheme.primaryColor.withOpacity(0.1), Colors.transparent],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: AppTheme.primaryColor.withOpacity(0.2)),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AppTheme.primaryColor.withOpacity(0.1),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.verified_user_outlined, color: AppTheme.primaryColor, size: 24),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Complete Professional Profile', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                const SizedBox(height: 4),
                Text('Add your medical degree and clinic address for patients.', style: TextStyle(color: AppTheme.textSecondary, fontSize: 12)),
              ],
            ),
          ),
          ElevatedButton(
            onPressed: () => DoctorProfileDialog.show(context, userProfile),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.primaryColor,
              foregroundColor: AppTheme.backgroundColor,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            ),
            child: const Text('Complete', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyPracticePrompt() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(40),
      decoration: BoxDecoration(
        color: AppTheme.surfaceColor.withOpacity(0.5),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: Colors.white.withOpacity(0.05), style: BorderStyle.solid),
      ),
      child: const Column(
        children: [
          Icon(Icons.people_outline_rounded, size: 48, color: Colors.white24),
          SizedBox(height: 16),
          Text(
            'No Patients Connected',
            style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
          ),
          SizedBox(height: 8),
          Text(
            'Share your Practice Code with your patients to begin remote monitoring.',
            textAlign: TextAlign.center,
            style: TextStyle(color: Colors.white38, fontSize: 12),
          ),
        ],
      ),
    );
  }
}

class _PatientMonitoringCard extends ConsumerWidget {
  final String patientUid;
  final Animation<double> pulseAnimation;
  const _PatientMonitoringCard({required this.patientUid, required this.pulseAnimation});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final patientProfileAsync = ref.watch(userProfileProvider(patientUid));
    final progressAsync = ref.watch(patientRecoveryProgressProvider(patientUid));
    final historyAsync = ref.watch(patientLogHistoryProvider(patientUid));
    final riskAsync = ref.watch(clinicalRiskProvider(patientUid));

    return patientProfileAsync.when(
      data: (patient) {
        if (patient == null) return const SizedBox.shrink();

        return historyAsync.when(
          data: (logs) {
            final latest = logs.isNotEmpty ? logs.first : null;

            return riskAsync.when(
              data: (risk) {
                final isHighRisk = risk.status == ClinicalStatus.critical || risk.status == ClinicalStatus.warning;
                final riskLabel = risk.label;

                return AnimatedBuilder(
                  animation: pulseAnimation,
                  builder: (context, child) {
                    return InkWell(
                      onTap: () => PatientDetailScreen.show(context, patientUid),
                      borderRadius: BorderRadius.circular(20),
                      child: Container(
                        margin: const EdgeInsets.only(bottom: 16),
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: AppTheme.surfaceColor,
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(
                            color: isHighRisk 
                              ? Colors.red.withOpacity(0.3 + (pulseAnimation.value * 0.4)) 
                              : Colors.white10,
                            width: isHighRisk ? 2.0 : 1.0,
                          ),
                          boxShadow: isHighRisk ? [
                            BoxShadow(
                              color: Colors.red.withOpacity(0.1 * pulseAnimation.value),
                              blurRadius: 10,
                              spreadRadius: 2,
                            )
                          ] : null,
                        ),
                        child: child,
                      ),
                    );
                  },
                  child: Row(
                    children: [
                      SizedBox(
                        width: 60, height: 60,
                        child: progressAsync.when(
                          data: (val) => _MiniProgress(progress: val),
                          loading: () => const CircularProgressIndicator(strokeWidth: 2),
                          error: (_, __) => const _MiniProgress(progress: 0.0),
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Text(patient.name ?? 'Guest User', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                                if (isHighRisk)
                                  Container(
                                    margin: const EdgeInsets.only(left: 8),
                                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                    decoration: BoxDecoration(color: Colors.red, borderRadius: BorderRadius.circular(4)),
                                    child: Text(riskLabel.split(' ')[0], style: const TextStyle(color: Colors.white, fontSize: 8, fontWeight: FontWeight.bold)),
                                  ),
                              ],
                            ),
                            Text(
                              isHighRisk ? riskLabel : (latest != null ? 'Last Log: ${latest.timestamp.toString().split(' ')[0]}' : 'No recent logs'),
                              style: TextStyle(
                                color: isHighRisk ? Colors.redAccent : AppTheme.textSecondary, 
                                fontSize: 12, 
                                fontWeight: isHighRisk ? FontWeight.bold : FontWeight.normal
                              ),
                            ),
                            if (isHighRisk || patient.phone != null)
                              Padding(
                                padding: const EdgeInsets.only(top: 8.0),
                                child: Row(
                                  children: [
                                    Icon(Icons.phone_in_talk_rounded, size: 10, color: isHighRisk ? Colors.redAccent : AppTheme.primaryColor),
                                    const SizedBox(width: 4),
                                    Text(
                                      patient.phone ?? 'No Phone',
                                      style: TextStyle(
                                        color: isHighRisk ? Colors.redAccent : AppTheme.textPrimary,
                                        fontSize: 10,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                    if (patient.emergencyContactPhone != null) ...[
                                      const SizedBox(width: 8),
                                      const Text('|', style: TextStyle(color: Colors.white10, fontSize: 10)),
                                      const SizedBox(width: 8),
                                      const Icon(Icons.emergency_rounded, size: 10, color: Colors.orangeAccent),
                                      const SizedBox(width: 4),
                                      Text(
                                        patient.emergencyContactPhone!,
                                        style: const TextStyle(color: Colors.orangeAccent, fontSize: 10, fontWeight: FontWeight.bold),
                                      ),
                                    ],
                                  ],
                                ),
                              ),
                          ],
                        ),
                      ),
                      Row(
                        children: [
                          _VitalsMini(icon: Icons.favorite, label: 'Pain', value: '${latest?.painLevel ?? "--"}', color: (latest?.painLevel ?? 0) > 7 ? Colors.red : Colors.grey),
                          const SizedBox(width: 12),
                          _VitalsMini(icon: Icons.mood, label: 'Vibe', value: latest?.sentimentScore != null ? (latest!.sentimentScore! * 100).toInt().toString() : "--", color: (latest?.sentimentScore ?? 0.0) < -0.5 ? Colors.red : Colors.grey),
                        ],
                      ),
                      const Icon(Icons.chevron_right_rounded, color: Colors.white24),
                    ],
                  ),
                );
              },
              loading: () => const Center(child: CircularProgressIndicator(strokeWidth: 2)),
              error: (_, __) => const SizedBox.shrink(),
            );
          },
          loading: () => const Center(child: LinearProgressIndicator()),
          error: (e, __) => Text('Log Error: $e'),
        );
      },
      loading: () => const SizedBox.shrink(),
      error: (e, __) => Text('Profile Error: $e'),
    );
  }
}

class _MiniProgress extends StatelessWidget {
  final double progress;
  const _MiniProgress({required this.progress});

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        Center(
          child: CircularProgressIndicator(
            value: progress,
            strokeWidth: 6,
            backgroundColor: Colors.white10,
            valueColor: const AlwaysStoppedAnimation<Color>(AppTheme.primaryColor),
          ),
        ),
        Center(
          child: Text(
            '${(progress * 100).toInt()}%',
            style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.white),
          ),
        ),
      ],
    );
  }
}

class _VitalsMini extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final Color color;

  const _VitalsMini({required this.icon, required this.label, required this.value, required this.color});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Icon(icon, size: 14, color: color),
        Text(value, style: TextStyle(color: color, fontWeight: FontWeight.bold, fontSize: 12)),
        Text(label, style: const TextStyle(color: Colors.white38, fontSize: 8)),
      ],
    );
  }
}
