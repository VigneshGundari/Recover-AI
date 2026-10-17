import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:recover_ai/core/theme/app_theme.dart';
import 'package:recover_ai/features/health_tracking/data/sync_repository.dart';
import 'package:recover_ai/features/user/data/user_repository.dart';
import 'package:recover_ai/features/health_tracking/data/local_health_repository.dart';
import 'package:recover_ai/core/widgets/progress_ring.dart';
import 'package:recover_ai/core/widgets/medication_card.dart';
import 'package:recover_ai/features/health_tracking/data/medication_task_collection.dart';
import 'package:recover_ai/features/health_tracking/data/recovery_plan_collection.dart';
import 'package:recover_ai/features/health_tracking/data/daily_health_log_collection.dart';

class PatientDetailScreen extends ConsumerStatefulWidget {
  final String patientUid;
  const PatientDetailScreen({super.key, required this.patientUid});

  static void show(BuildContext context, String patientUid) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => PatientDetailScreen(patientUid: patientUid),
      ),
    );
  }

  @override
  ConsumerState<PatientDetailScreen> createState() => _PatientDetailScreenState();
}

class _PatientDetailScreenState extends ConsumerState<PatientDetailScreen> {
  bool _isSyncing = true;

  @override
  void initState() {
    super.initState();
    _hydratePatientData();
  }

  Future<void> _hydratePatientData() async {
    try {
      await ref.read(syncRepositoryProvider).pullUserFromCloud(widget.patientUid);
    } finally {
      if (mounted) setState(() => _isSyncing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final patientProfileAsync = ref.watch(userProfileProvider(widget.patientUid));
    final progressAsync = ref.watch(patientRecoveryProgressProvider(widget.patientUid));
    final latestLogAsync = ref.watch(patientLatestLogProvider(widget.patientUid));

    return Scaffold(
      backgroundColor: AppTheme.backgroundColor,
      appBar: AppBar(
        title: const Text('Clinical Overview', style: TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: AppTheme.surfaceColor,
        elevation: 0,
        actions: [
          if (_isSyncing)
            const Center(child: Padding(padding: EdgeInsets.only(right: 16), child: CircularProgressIndicator(strokeWidth: 2))),
        ],
      ),
      body: patientProfileAsync.when(
        data: (patient) {
          if (patient == null) return const Center(child: Text('Patient not found'));
          
          return SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildPatientHeader(patient, progressAsync),
                const SizedBox(height: 24),
                _buildCaregiversSection(),
                const SizedBox(height: 32),
                _buildVitalsSection(latestLogAsync),
                const SizedBox(height: 32),
                _buildClinicalTimeline(),
                const SizedBox(height: 32),
              ],
            ),
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, __) => Center(child: Text('Error: $e')),
      ),
    );
  }

  Widget _buildPatientHeader(dynamic patient, AsyncValue<double> progressAsync) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: AppTheme.surfaceColor,
        borderRadius: BorderRadius.circular(24),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(patient.name ?? 'Guest User', style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
                const SizedBox(height: 4),
                Text(patient.email, style: const TextStyle(color: AppTheme.textSecondary)),
                const SizedBox(height: 16),
                Row(
                  children: [
                    _buildContactBadge(Icons.phone, patient.phone ?? 'No Phone'),
                    const SizedBox(width: 8),
                    _buildContactBadge(Icons.emergency_rounded, patient.emergencyContactPhone ?? 'No Emergency #', color: Colors.orange),
                  ],
                ),
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(color: AppTheme.primaryColor.withOpacity(0.1), borderRadius: BorderRadius.circular(12)),
                  child: Text(
                    'RECOVERY STATUS: ${patient.recoveryStatus.toUpperCase()}',
                    style: const TextStyle(color: AppTheme.primaryColor, fontSize: 10, fontWeight: FontWeight.w900),
                  ),
                ),
              ],
            ),
          ),
          SizedBox(
            width: 100,
            height: 100,
            child: progressAsync.when(
              data: (val) => ProgressRing(progress: val),
              loading: () => const CircularProgressIndicator(),
              error: (_, __) => const ProgressRing(progress: 0.0),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildContactBadge(IconData icon, String label, {Color color = AppTheme.primaryColor}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withOpacity(0.2)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: color),
          const SizedBox(width: 4),
          Text(label, style: TextStyle(color: color, fontSize: 10, fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }

  Widget _buildVitalsSection(AsyncValue<HealthLog?> latestLogAsync) {
    return latestLogAsync.when(
      data: (log) {
        if (log == null) return const _EmptyCard(label: 'No vitals logged recently');
        
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Current Vitals', style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(child: _VitalDetail(icon: Icons.thermostat, label: 'Temp', value: '${log.temperature ?? "--"}°C')),
                const SizedBox(width: 16),
                Expanded(child: _VitalDetail(icon: Icons.favorite, label: 'Pain', value: '${log.painLevel}/10')),
                const SizedBox(width: 16),
                Expanded(child: _VitalDetail(icon: Icons.mood, label: 'Mood', value: '${log.moodLevel}/5')),
              ],
            ),
            if (log.aiJournalEntry.isNotEmpty) ...[
              const SizedBox(height: 16),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(color: Colors.white.withOpacity(0.05), borderRadius: BorderRadius.circular(16)),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('PATIENT JOURNAL', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: AppTheme.textSecondary)),
                    const SizedBox(height: 8),
                    Text(log.aiJournalEntry, style: const TextStyle(height: 1.5)),
                  ],
                ),
              ),
            ]
          ],
        );
      },
      loading: () => const LinearProgressIndicator(),
      error: (e, __) => Text('Error: $e'),
    );
  }

  Widget _buildClinicalTimeline() {
    final medicationsAsync = ref.watch(patientMedicationsProvider(widget.patientUid));
    final tasksAsync = ref.watch(patientRecoveryTasksProvider(widget.patientUid));

    return medicationsAsync.when(
      data: (meds) => tasksAsync.when(
        data: (recoveryTasks) {
          if (meds.isEmpty && recoveryTasks.isEmpty) return const _EmptyCard(label: 'No roadmap or medications prescribed.');

          // 1. DEDUPLICATION: UI side safety
          final seenMeds = <String>{};
          final cleanMeds = meds.where((m) => seenMeds.add("${m.medicationName}_${m.scheduledTime.hour}:${m.scheduledTime.minute}")).toList();

          // 2. INTERLEAVING
          final List<Map<String, dynamic>> timeline = [];
          for (final m in cleanMeds) {
            timeline.add({'type': 'med', 'time': m.scheduledTime.hour * 60 + m.scheduledTime.minute, 'data': m});
          }
          for (final t in recoveryTasks) {
            int time = 1440;
            if (t.scheduledTime != null) {
              final parts = t.scheduledTime!.split(':');
              if (parts.length == 2) time = int.parse(parts[0]) * 60 + int.parse(parts[1]);
            }
            timeline.add({'type': 'task', 'time': time, 'data': t});
          }

          timeline.sort((a, b) => (a['time'] as int).compareTo(b['time'] as int));

          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Today\'s Clinical Roadmap', style: Theme.of(context).textTheme.titleLarge),
              const SizedBox(height: 16),
              ...timeline.map((item) {
                if (item['type'] == 'med') {
                  final m = item['data'] as MedicationTask;
                  return MedicationCard(
                    medicationName: m.medicationName,
                    dosage: m.dosage,
                    time: "${m.scheduledTime.hour.toString().padLeft(2, '0')}:${m.scheduledTime.minute.toString().padLeft(2, '0')}",
                    isTaken: m.isTaken,
                  );
                } else {
                  final t = item['data'] as RecoveryTask;
                  return _buildTaskTile(t);
                }
              }).toList(),
            ],
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, __) => Text('Task Error: $e'),
      ),
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, __) => Text('Med Error: $e'),
    );
  }

  Widget _buildTaskTile(RecoveryTask t) {
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 8),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppTheme.surfaceColor,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: Colors.white10),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(color: AppTheme.primaryColor.withOpacity(0.1), shape: BoxShape.circle),
            child: Icon(_getTaskIcon(t.type), color: AppTheme.primaryColor),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(t.title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                const SizedBox(height: 4),
                Text(t.description, style: const TextStyle(color: AppTheme.textSecondary, fontSize: 12), maxLines: 2, overflow: TextOverflow.ellipsis),
              ],
            ),
          ),
          Text(t.scheduledTime ?? 'Daily', style: const TextStyle(color: AppTheme.primaryColor, fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }

  Widget _buildCaregiversSection() {
    final caretakersAsync = ref.watch(linkedCaretakersByPatientUidProvider(widget.patientUid));

    return caretakersAsync.when(
      data: (caretakers) {
        if (caretakers.isEmpty) return const SizedBox.shrink();
        
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Emergency Caregivers', style: TextStyle(color: AppTheme.primaryColor, fontWeight: FontWeight.bold, fontSize: 14)),
            const SizedBox(height: 12),
            ...caretakers.map((c) => Container(
              margin: const EdgeInsets.only(bottom: 8),
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppTheme.surfaceColor,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: Colors.white.withOpacity(0.05)),
              ),
              child: Row(
                children: [
                  CircleAvatar(
                    radius: 18,
                    backgroundColor: Colors.blue.withOpacity(0.1),
                    child: const Icon(Icons.person, color: Colors.blue, size: 18),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(c.name ?? 'Unnamed Caregiver', style: const TextStyle(fontWeight: FontWeight.bold)),
                        const SizedBox(height: 4),
                        Row(
                          children: [
                            _buildContactBadge(Icons.phone, c.phone ?? 'N/A', color: Colors.blue),
                            if (c.alternativePhone != null) ...[
                              const SizedBox(width: 8),
                              _buildContactBadge(Icons.contact_phone, c.alternativePhone!, color: Colors.blue),
                            ],
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            )).toList(),
          ],
        );
      },
      loading: () => const SizedBox.shrink(),
      error: (_, __) => const SizedBox.shrink(),
    );
  }

  IconData _getTaskIcon(String type) {
    switch (type.toLowerCase()) {
      case 'nutrition': return Icons.restaurant_rounded;
      case 'exercise': return Icons.fitness_center_rounded;
      case 'habit': return Icons.self_improvement_rounded;
      default: return Icons.task_alt_rounded;
    }
  }
}

class _VitalDetail extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  const _VitalDetail({required this.icon, required this.label, required this.value});
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: AppTheme.surfaceColor, borderRadius: BorderRadius.circular(20)),
      child: Column(children: [Icon(icon, color: AppTheme.primaryColor, size: 20), const SizedBox(height: 8), Text(value, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18)), Text(label, style: const TextStyle(color: AppTheme.textSecondary, fontSize: 10))]),
    );
  }
}

class _EmptyCard extends StatelessWidget {
  final String label;
  const _EmptyCard({required this.label});
  @override
  Widget build(BuildContext context) {
    return Container(width: double.infinity, padding: const EdgeInsets.all(32), decoration: BoxDecoration(color: AppTheme.surfaceColor, borderRadius: BorderRadius.circular(24)), child: Center(child: Text(label, style: const TextStyle(color: AppTheme.textSecondary))));
  }
}
