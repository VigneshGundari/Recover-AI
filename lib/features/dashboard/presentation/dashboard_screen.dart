import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:recover_ai/core/theme/app_theme.dart';
import 'package:recover_ai/core/widgets/progress_ring.dart';
import 'package:recover_ai/core/widgets/medication_card.dart';
import 'package:recover_ai/features/user/data/user_repository.dart';
import 'package:recover_ai/features/health_tracking/data/local_health_repository.dart';
import 'package:recover_ai/features/health_tracking/data/medication_task_collection.dart';
import 'package:recover_ai/features/health_tracking/data/daily_health_log_collection.dart';
import 'package:recover_ai/features/health_tracking/data/sync_repository.dart';
import 'package:recover_ai/features/copilot/data/ai_service.dart';
import 'package:recover_ai/features/copilot/data/neo4j_service.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:go_router/go_router.dart';
import 'package:recover_ai/features/dashboard/presentation/interaction_checker_widget.dart';
import 'package:recover_ai/features/health_tracking/presentation/health_log_dialog.dart';
import 'package:recover_ai/features/user/data/user_model.dart';
import 'package:recover_ai/features/user/data/care_circle_repository.dart';
import 'package:recover_ai/features/health_tracking/data/recovery_plan_repository.dart';
import 'package:recover_ai/features/health_tracking/data/recovery_plan_collection.dart';
import 'package:recover_ai/features/dashboard/presentation/doctor_dashboard.dart';
import 'package:recover_ai/features/dashboard/presentation/connect_doctor_dialog.dart';
import 'package:recover_ai/features/dashboard/presentation/doctor_profile_dialog.dart';
import 'package:recover_ai/features/dashboard/presentation/caretaker_profile_dialog.dart';
import 'package:recover_ai/core/widgets/patient_status_card.dart';
import 'package:recover_ai/core/services/notification_service.dart';

final selectedPatientProvider = StateProvider<String?>((ref) => null);

class DashboardScreen extends ConsumerWidget {
  const DashboardScreen({super.key});

  String _getGreeting() {
    final hour = TimeOfDay.now().hour;
    if (hour < 12) return 'Good Morning,';
    if (hour < 17) return 'Good Afternoon,';
    return 'Good Evening,';
  }

  String _formatTime(DateTime time) {
    int hour = time.hour;
    final minute = time.minute.toString().padLeft(2, '0');
    final period = hour >= 12 ? 'PM' : 'AM';
    hour = hour % 12;
    if (hour == 0) hour = 12;
    return '$hour:$minute $period';
  }

  void _showAddMedicationDialog(BuildContext context, WidgetRef ref) {
    final nameCtrl = TextEditingController();
    final doseCtrl = TextEditingController();
    final durationCtrl = TextEditingController(text: '7');
    int frequency = 1;
    List<TimeOfDay> selectedTimes = [TimeOfDay.now(), TimeOfDay(hour: 12, minute: 0), TimeOfDay(hour: 20, minute: 0)];

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          backgroundColor: AppTheme.surfaceColor,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
          title: const Text('Prescribe Medication', style: TextStyle(fontWeight: FontWeight.bold)),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: nameCtrl,
                  style: const TextStyle(color: Colors.white),
                  decoration: InputDecoration(
                    labelText: 'Medication Name',
                    prefixIcon: const Icon(Icons.medication_rounded, color: AppTheme.primaryColor),
                    filled: true,
                    fillColor: Colors.black12,
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none),
                  ),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: doseCtrl,
                  style: const TextStyle(color: Colors.white),
                  decoration: InputDecoration(
                    labelText: 'Dosage (e.g. 500mg)',
                    prefixIcon: const Icon(Icons.shutter_speed_rounded, color: AppTheme.primaryColor),
                    filled: true,
                    fillColor: Colors.black12,
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none),
                  ),
                ),
                const SizedBox(height: 20),
                Row(
                  children: [
                    Expanded(
                      child: DropdownButtonFormField<int>(
                        value: frequency,
                        dropdownColor: AppTheme.surfaceColor,
                        decoration: InputDecoration(
                          labelText: 'Frequency',
                          filled: true,
                          fillColor: Colors.black12,
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none),
                        ),
                        items: [1, 2, 3].map((f) => DropdownMenuItem(value: f, child: Text('$f times/day', style: const TextStyle(color: Colors.white)))).toList(),
                        onChanged: (val) => setState(() => frequency = val!),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: TextField(
                        controller: durationCtrl,
                        keyboardType: TextInputType.number,
                        style: const TextStyle(color: Colors.white),
                        decoration: InputDecoration(
                          labelText: 'Duration (Days)',
                          filled: true,
                          fillColor: Colors.black12,
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 24),
                const Align(
                  alignment: Alignment.centerLeft,
                  child: Text('Dose Times', style: TextStyle(color: AppTheme.textSecondary, fontSize: 13, fontWeight: FontWeight.bold)),
                ),
                const SizedBox(height: 8),
                ...List.generate(frequency, (index) => Padding(
                  padding: const EdgeInsets.only(bottom: 8.0),
                  child: ListTile(
                    dense: true,
                    tileColor: Colors.black12,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    title: Text('Dose ${index + 1}: ${selectedTimes[index].format(context)}', style: const TextStyle(color: AppTheme.primaryColor, fontWeight: FontWeight.bold)),
                    trailing: const Icon(Icons.access_time_rounded, color: AppTheme.primaryColor, size: 20),
                    onTap: () async {
                      final time = await showTimePicker(context: context, initialTime: selectedTimes[index]);
                      if (time != null) setState(() => selectedTimes[index] = time);
                    },
                  ),
                )),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel', style: TextStyle(color: AppTheme.textSecondary)),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.primaryColor,
                foregroundColor: AppTheme.backgroundColor,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              onPressed: () {
                if (nameCtrl.text.isNotEmpty) {
                  final rawName = nameCtrl.text.trim();
                  final userProfile = ref.read(currentUserProfileProvider).value;
                  if (userProfile == null) return;
                  
                  final duration = int.tryParse(durationCtrl.text) ?? 7;

                  final baseTask = MedicationTask()
                    ..medicationName = rawName
                    ..dosage = doseCtrl.text.trim()
                    ..scheduledTime = DateTime.now() // Reference starting point
                    ..frequency = frequency
                    ..durationDays = duration;
                  
                  ref.read(localHealthRepositoryProvider).addMedicationTasks(
                    userProfile.uid,
                    baseTask,
                    selectedTimes.sublist(0, frequency),
                  );
                  
                  // Graph Sync
                  ref.read(copilotServiceProvider).extractActiveIngredients(rawName).then((ingredients) {
                     ref.read(neo4jServiceProvider).logMedicationGraph(userProfile.uid, rawName, ingredients);
                  }).catchError((e) => debugPrint("Graph Sync Failed: $e"));

                  Navigator.pop(context);
                }
              },
              child: const Text('Confirm Schedule'),
            )
          ],
        ),
      ),
    );
  }

  void _showHealthLoggerDialog(BuildContext context, WidgetRef ref) {
    HealthLogDialog.show(context);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Session 8.5: Activate Caretaker Proactive Alerts (Always-on while app is active)
    ref.watch(caretakerMonitorProvider);

    final theme = Theme.of(context);
    final userAsync = ref.watch(currentUserProfileProvider);
    final userProfile = userAsync.value;
    final userRole = userProfile?.role;
    final medicationsAsync = ref.watch(todaysMedicationsProvider);
    final latestLogAsync = ref.watch(latestHealthLogProvider);
    
    // Connects Riverpod lifecycle to the Background Sync Engine
    ref.watch(backgroundSyncProvider);

    final currentPatientUid = ref.watch(selectedPatientProvider);
    final isPatient = userRole == UserRole.patient;

    return Scaffold(
      floatingActionButton: isPatient 
        ? FloatingActionButton.extended(
            onPressed: () => _showAddMedicationDialog(context, ref),
            backgroundColor: AppTheme.primaryColor,
            foregroundColor: AppTheme.backgroundColor,
            icon: const Icon(Icons.add_rounded),
            label: const Text('Add Med', style: TextStyle(fontWeight: FontWeight.bold)),
          )
        : null,
      body: SafeArea(
        child: SingleChildScrollView(
          physics: const BouncingScrollPhysics(),
          padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 20.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _getGreeting(),
                        style: Theme.of(context).textTheme.bodyLarge?.copyWith(color: AppTheme.textSecondary),
                      ),
                      Text(
                        userProfile?.name?.split(' ').first ?? 'User',
                        style: Theme.of(context).textTheme.headlineMedium,
                      ),
                      if (userProfile?.role != UserRole.patient)
                        Container(
                          margin: const EdgeInsets.only(top: 4),
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                          decoration: BoxDecoration(
                            color: AppTheme.primaryColor.withOpacity(0.2),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            userProfile?.role.name.toUpperCase() ?? '',
                            style: const TextStyle(color: AppTheme.primaryColor, fontSize: 10, fontWeight: FontWeight.bold),
                          ),
                        ),
                    ],
                  ),
                  Row(
                    children: [
                      if (isPatient)
                        IconButton(
                          icon: const Icon(Icons.person_add_alt_1_rounded, color: AppTheme.primaryColor),
                          onPressed: () => ConnectDoctorDialog.show(context),
                          tooltip: 'Connect Doctor',
                        ),
                      const Icon(Icons.cloud_done_rounded, color: AppTheme.primaryColor, size: 20),
                      const SizedBox(width: 12),
                      _buildSyncResetButton(context, ref),
                      const SizedBox(width: 12),
                      _buildLogoutButton(context),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 32),
              
              if (isPatient) 
                ..._buildPatientView(context, ref, userProfile!, latestLogAsync, medicationsAsync)
              else if (userProfile?.role == UserRole.caretaker)
                ..._buildCaretakerView(context, ref, userProfile!)
              else if (userProfile?.role == UserRole.doctor)
                const DoctorDashboard()
              else
                const Center(child: Text('Unauthorized view')),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSyncResetButton(BuildContext context, WidgetRef ref) {
    return GestureDetector(
      onTap: () async {
        final confirm = await showDialog<bool>(
          context: context,
          builder: (ctx) => AlertDialog(
            backgroundColor: AppTheme.surfaceColor,
            title: const Text('Triple-Sync Reset', style: TextStyle(color: AppTheme.dangerColor)),
            content: const Text('This will wipe all Medications and Logs from Isar, Firestore, and Neo4j. Proceed?'),
            actions: [
              TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
              TextButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('RESET ALL', style: TextStyle(color: AppTheme.dangerColor))),
            ],
          ),
        );

        if (confirm == true) {
          final localRepo = ref.read(localHealthRepositoryProvider);
          final syncRepo = ref.read(syncRepositoryProvider);
          final userProfile = ref.read(currentUserProfileProvider).value;
          if (userProfile == null) return;
          
          await syncRepo.wipeFirestoreData();
          final resetUrl = Uri.parse('https://recover-ai-zoma.onrender.com/api/graph/reset/${userProfile.uid}');
          try { await http.delete(resetUrl); } catch (e) { debugPrint('Graph Reset failed: $e'); }
          await localRepo.clearAllTasksAndLogs();

          if (context.mounted) {
            await FirebaseAuth.instance.signOut();
            context.go('/login');
          }
        }
      },
      child: const CircleAvatar(
        radius: 22,
        backgroundColor: AppTheme.surfaceColor,
        child: Icon(Icons.refresh_rounded, color: AppTheme.primaryColor, size: 20),
      ),
    );
  }

  Widget _buildLogoutButton(BuildContext context) {
    return GestureDetector(
      onTap: () async {
        await FirebaseAuth.instance.signOut();
        if (context.mounted) context.go('/login');
      },
      child: const CircleAvatar(
        radius: 22,
        backgroundColor: AppTheme.surfaceColor,
        child: Icon(Icons.logout_rounded, color: AppTheme.dangerColor, size: 20),
      ),
    );
  }

  List<Widget> _buildPatientView(
    BuildContext context, 
    WidgetRef ref, 
    UserModel user,
    AsyncValue<HealthLog?> latestLogAsync,
    AsyncValue<List<MedicationTask>> medicationsAsync,
  ) {
    final theme = Theme.of(context);
    final userAsync = ref.watch(currentUserProfileProvider);
    final currentUser = userAsync.value;
    final userRole = currentUser?.role;
    final currentPatientUid = ref.watch(selectedPatientProvider);
    
    final progressAsync = ref.watch(patientRecoveryProgressProvider(user.uid));
    final profileIncomplete = user.phone == null || user.address == null || user.emergencyContactPhone == null;
    final planTasksAsync = ref.watch(todaysRecoveryTasksProvider);
    final activePlanAsync = ref.watch(activeRecoveryPlanProvider);

    return [
      if (profileIncomplete)
        Container(
          margin: const EdgeInsets.only(bottom: 24),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: AppTheme.dangerColor.withOpacity(0.1),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: AppTheme.dangerColor.withOpacity(0.3)),
          ),
          child: Row(
            children: [
              const Icon(Icons.warning_amber_rounded, color: AppTheme.dangerColor),
              const SizedBox(width: 16),
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Profile Incomplete', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                    Text('Add emergency contact & address for your safety.', style: TextStyle(color: Colors.white70, fontSize: 12)),
                  ],
                ),
              ),
              TextButton(
                onPressed: () => context.push('/profile'),
                child: const Text('Complete'),
              ),
            ],
          ),
        ),

      // 1. Daily Vitals Summary Card
      latestLogAsync.when(
        data: (log) {
          if (log == null) return const SizedBox.shrink();
          final isToday = log.timestamp.day == DateTime.now().day;
          if (!isToday) return const SizedBox.shrink();

          return Container(
            width: double.infinity,
            margin: const EdgeInsets.only(bottom: 24),
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: AppTheme.surfaceColor,
              borderRadius: BorderRadius.circular(24),
              border: Border.all(color: AppTheme.primaryColor.withOpacity(0.2)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text('Daily Status', style: theme.textTheme.titleMedium?.copyWith(color: AppTheme.primaryColor)),
                    Text('Refreshed just now', style: theme.textTheme.bodySmall?.copyWith(color: AppTheme.textSecondary)),
                  ],
                ),
                const SizedBox(height: 16),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: [
                    Expanded(child: _VitalsIndicator(icon: Icons.thermostat_rounded, label: 'Temp', value: '${log.temperature ?? "--"}°C', color: (log.temperature ?? 36.6) > 37.5 ? Colors.orange : Colors.blue)),
                    Expanded(child: _VitalsIndicator(icon: Icons.favorite_rounded, label: 'Pain', value: '${log.painLevel}/10', color: log.painLevel > 7 ? Colors.red : log.painLevel > 4 ? Colors.orange : Colors.green)),
                    Expanded(child: _VitalsIndicator(icon: Icons.mood_rounded, label: 'Vibe', value: log.moodLevel == 5 ? 'Great' : log.moodLevel == 4 ? 'Good' : 'Okay', color: AppTheme.primaryColor)),
                  ],
                ),
              ],
            ),
          );
        },
        loading: () => const SizedBox.shrink(),
        error: (_, __) => const SizedBox.shrink(),
      ),

      Center(
        child: SizedBox(
          width: 200,
          height: 200,
          child: progressAsync.when(
            data: (val) => ProgressRing(progress: val),
            loading: () => const CircularProgressIndicator(),
            error: (_, __) => const ProgressRing(progress: 0.0),
          ),
        ),
      ),
      const SizedBox(height: 32),

      // Caretaker Profile Completion Prompt (Safety Check)
      if (userRole == UserRole.caretaker && userAsync.value != null && userAsync.value!.gender == null)
        Padding(
          padding: const EdgeInsets.only(bottom: 24),
          child: _buildCaretakerProfilePrompt(context, userAsync.value!),
        ),

      // Doctor Info for Caretaker (Emergency Contact)
      if (userRole == UserRole.caretaker && currentPatientUid != null)
        ref.watch(linkedDoctorByPatientUidProvider(currentPatientUid)).when(
          data: (doctor) => doctor != null ? _buildDoctorInfoCardForCaretaker(doctor) : const SizedBox.shrink(),
          loading: () => const SizedBox.shrink(),
          error: (_, __) => const SizedBox.shrink(),
        ),

      // Active Plan Prompt or Main Action
      activePlanAsync.when(
        data: (plan) {
           if (plan != null) return const SizedBox.shrink();
           return Container(
             margin: const EdgeInsets.only(bottom: 24),
             child: GestureDetector(
               onTap: () => context.go('/recovery-plan'),
               child: Container(
                 width: double.infinity,
                 padding: const EdgeInsets.all(24),
                 decoration: BoxDecoration(
                   color: AppTheme.primaryColor.withOpacity(0.1),
                   borderRadius: BorderRadius.circular(24),
                   border: Border.all(color: AppTheme.primaryColor.withOpacity(0.3), style: BorderStyle.solid),
                 ),
                 child: Row(
                   children: [
                     const Icon(Icons.auto_awesome, color: AppTheme.primaryColor, size: 32),
                     const SizedBox(width: 16),
                     const Expanded(
                       child: Column(
                         crossAxisAlignment: CrossAxisAlignment.start,
                         children: [
                           Text('Unlock AI Recovery', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
                           Text('Generate a personalized strategy based on your reports.', style: TextStyle(color: Colors.white70, fontSize: 12)),
                         ],
                       ),
                     ),
                     const Icon(Icons.arrow_forward_ios_rounded, color: AppTheme.primaryColor, size: 16),
                   ],
                 ),
               ),
             ),
           );
        },
        loading: () => const SizedBox.shrink(),
        error: (_, __) => const SizedBox.shrink(),
      ),

      // Smart OCR Scanner Launchpad
      GestureDetector(
        onTap: () => context.go('/upload'),
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [AppTheme.primaryColor.withOpacity(0.8), AppTheme.primaryColor],
              begin: Alignment.topLeft, end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(24),
            boxShadow: [BoxShadow(color: AppTheme.primaryColor.withOpacity(0.3), blurRadius: 15, offset: const Offset(0, 5))]
          ),
          child: Row(
            children: [
              Container(padding: const EdgeInsets.all(12), decoration: BoxDecoration(color: AppTheme.backgroundColor.withOpacity(0.3), borderRadius: BorderRadius.circular(16)), child: const Icon(Icons.document_scanner_rounded, color: Colors.white, size: 32)),
              const SizedBox(width: 16),
              const Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text('Smart Scan', style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)), SizedBox(height: 4), Text('Extract a physical prescription', style: TextStyle(color: Colors.white70, fontSize: 14))])),
              const Icon(Icons.arrow_forward_ios_rounded, color: Colors.white54, size: 20),
            ],
          ),
        ),
      ),
      const SizedBox(height: 24),

      // Daily Survey Tile
      Container(
        width: double.infinity,
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(color: AppTheme.surfaceColor, borderRadius: BorderRadius.circular(24), border: Border.all(color: Colors.white10)),
        child: ListTile(
          onTap: () => _showHealthLoggerDialog(context, ref),
          leading: const Icon(Icons.edit_note_rounded, color: AppTheme.primaryColor),
          title: const Text('Log Daily Vitals', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
          subtitle: const Text('Tap to open Daily Survey', style: TextStyle(color: AppTheme.primaryColor)),
          trailing: const Icon(Icons.chevron_right_rounded, color: Colors.white24),
        ),
      ),
      const SizedBox(height: 40),

      // Care Circle Invitation (NEW)
      _buildCareCircleInviteModule(context, ref),
      const SizedBox(height: 40),

      Text('Today\'s Roadmap', style: theme.textTheme.titleLarge),
      const SizedBox(height: 16),

      _buildInterleavedTaskList(context, ref, medicationsAsync, planTasksAsync),
    ];
  }

  Widget _buildInterleavedTaskList(
    BuildContext context, 
    WidgetRef ref, 
    AsyncValue<List<MedicationTask>> medsAsync, 
    AsyncValue<List<Map<String, dynamic>>> tasksAsync
  ) {
    return medsAsync.when(
      data: (meds) => tasksAsync.when(
        data: (recoveryTasks) {
          if (meds.isEmpty && recoveryTasks.isEmpty) return _buildNoMedsPlaceholder();

          // Interleave and sort by time
          final List<Map<String, dynamic>> sortedList = [];

          for (final m in meds) {
            sortedList.add({
              'timeValue': m.scheduledTime.hour * 60 + m.scheduledTime.minute,
              'type': 'med',
              'data': m,
            });
          }

          for (final rt in recoveryTasks) {
            final task = rt['task'] as RecoveryTask;
            int timeValue = 1440; // Default: late night if time missing
            if (task.scheduledTime != null) {
              final parts = task.scheduledTime!.split(':');
              if (parts.length == 2) {
                timeValue = int.parse(parts[0]) * 60 + int.parse(parts[1]);
              }
            }
            sortedList.add({
              'timeValue': timeValue,
              'type': 'recovery',
              'data': rt,
            });
          }

          sortedList.sort((a, b) => (a['timeValue'] as int).compareTo(b['timeValue'] as int));

          return Column(
            children: sortedList.map((item) {
              if (item['type'] == 'med') {
                return _buildDismissibleMedCard(context, ref, item['data'] as MedicationTask);
              } else {
                return _buildRecoveryTaskDashboardCard(context, ref, item['data'] as Map<String, dynamic>);
              }
            }).toList(),
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Text('Plan error: $e'),
      ),
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Text('Med error: $e'),
    );
  }

  Widget _buildRecoveryTaskDashboardCard(BuildContext context, WidgetRef ref, Map<String, dynamic> item) {
    final task = item['task'] as RecoveryTask;
    final bool isDone = item['isCompleted'] as bool;
    final String dayXofY = item['dayXofY'] ?? 'Active';
    final user = ref.read(currentUserProfileProvider).value;

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      child: MedicationCard(
        medicationName: task.title,
        dosage: task.description,
        subtitle: dayXofY, // Show "Day X of Y"
        time: task.scheduledTime ?? '--:--',
        isTaken: isDone,
        buttonLabel: 'Mark as Done',
        successMessage: 'Done for today',
        recurringSuccessMessage: 'Great work, task completed for the day. See you again tomorrow.',
        onMarkAsTaken: () {
           if (user != null) {
             ref.read(recoveryPlanRepositoryProvider).toggleTaskCompletion(user.uid, task.id, !isDone);
           }
        },
      ),
    );
  }

  List<Widget> _buildCaretakerView(BuildContext context, WidgetRef ref, UserModel user) {
    final selectedPatientUid = ref.watch(selectedPatientProvider);
    final userAsync = ref.watch(currentUserProfileProvider);
    final userRole = userAsync.value?.role;

    return [
      // Always show Join Circle UI (Requirement)
      _buildJoinCircleInterface(context, ref, user),
      const SizedBox(height: 32),

      if (selectedPatientUid == null) ...[
        // Patient List View
        const Text('Your Medical Circle', style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold, color: Colors.white)),
        const SizedBox(height: 8),
        const Text('Monitor recovery progress and coordinate with physicians.', style: TextStyle(color: AppTheme.textSecondary, fontSize: 13)),
        const SizedBox(height: 32),

        // Caretaker Profile Completion Prompt (Safety Check)
        if (userRole == UserRole.caretaker && userAsync.value != null && (userAsync.value!.gender == null || userAsync.value!.phone == null))
          Padding(
            padding: const EdgeInsets.only(bottom: 24),
            child: _buildCaretakerProfilePrompt(context, userAsync.value!),
          ),

        if (user.linkedCircleIds.isEmpty)
          const Center(child: Text('No patients linked yet.', style: TextStyle(color: Colors.white24)))
        else
          ...user.linkedCircleIds.map((cid) {
            final pUid = cid.replaceFirst('circle_', '');
            return ref.watch(userProfileProvider(pUid)).when(
              data: (p) => p == null ? const SizedBox.shrink() : PatientStatusCard(
                patient: p,
                onTap: () => ref.read(selectedPatientProvider.notifier).state = p.uid,
              ),
              loading: () => const Padding(
                padding: EdgeInsets.all(8.0),
                child: LinearProgressIndicator(),
              ),
              error: (_, __) => const SizedBox.shrink(),
            );
          }),
      ] else ...[
        // Drill-down Detail View
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            GestureDetector(
              onTap: () => ref.read(selectedPatientProvider.notifier).state = null,
              child: const Row(
                children: [
                   Icon(Icons.arrow_back_rounded, color: AppTheme.primaryColor, size: 20),
                   SizedBox(width: 8),
                   Text('Back to Patients', style: TextStyle(color: AppTheme.primaryColor, fontWeight: FontWeight.bold)),
                ],
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(color: AppTheme.primaryColor.withOpacity(0.1), borderRadius: BorderRadius.circular(12)),
              child: const Text('PATIENT MONITOR', style: TextStyle(color: AppTheme.primaryColor, fontWeight: FontWeight.w900, fontSize: 10)),
            ),
          ],
        ),
        const SizedBox(height: 24),
        
        // Inject Patient's Doctor for the Caretaker
        ref.watch(linkedDoctorByPatientUidProvider(selectedPatientUid!)).when(
          data: (doctor) => doctor != null ? _buildDoctorInfoCardForCaretaker(doctor) : const SizedBox.shrink(),
          loading: () => const SizedBox.shrink(),
          error: (_, __) => const SizedBox.shrink(),
        ),

        const SizedBox(height: 4),
        _buildPatientDetailDashboard(context, ref, selectedPatientUid),
      ],
    ];
  }

  Widget _buildJoinCircleInterface(BuildContext context, WidgetRef ref, UserModel user) {
     return Card(
       child: Padding(
         padding: const EdgeInsets.all(20),
         child: Column(
           crossAxisAlignment: CrossAxisAlignment.start,
           children: [
              const Text('Add New Patient', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
              const SizedBox(height: 4),
              const Text('Enter code to start monitoring another loved one.', style: TextStyle(color: Colors.white60, fontSize: 12)),
              const SizedBox(height: 16),
              _buildCompactJoinInput(context, ref, user),
           ],
         ),
       ),
     );
  }

  Widget _buildCompactJoinInput(BuildContext context, WidgetRef ref, UserModel user) {
    final codeCtrl = TextEditingController();
    return Row(
      children: [
        Expanded(
          child: TextField(
            controller: codeCtrl,
            style: const TextStyle(color: Colors.white, fontSize: 14),
            decoration: InputDecoration(
              hintText: 'Code (e.g. AB1234)',
              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
            ),
          ),
        ),
        const SizedBox(width: 12),
        ElevatedButton(
          style: ElevatedButton.styleFrom(padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12)),
          onPressed: () async {
            if (codeCtrl.text.length == 6) {
               await ref.read(careCircleRepositoryProvider).joinCircle(user.uid, codeCtrl.text.toUpperCase());
               codeCtrl.clear();
            }
          },
          child: const Text('Join'),
        ),
      ],
    );
  }

  Widget _buildPatientDetailDashboard(BuildContext context, WidgetRef ref, String patientUid) {
    final patientProfileAsync = ref.watch(userProfileProvider(patientUid));
    final patientMedsAsync = ref.watch(patientMedicationsProvider(patientUid));
    final patientTasksAsync = ref.watch(patientRecoveryTasksProvider(patientUid));
    final patientLatestLogAsync = ref.watch(patientLatestLogProvider(patientUid));
    final progressAsync = ref.watch(patientRecoveryProgressProvider(patientUid));

    // AUTOMATIC SYNC: Every time the caretaker focuses a patient, pull their data
    ref.listen(selectedPatientProvider, (previous, next) {
      if (next != null) {
        ref.read(syncRepositoryProvider).pullUserFromCloud(next);
      }
    });

    return patientProfileAsync.when(
      data: (p) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Restored Large Header Card
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(color: AppTheme.surfaceColor, borderRadius: BorderRadius.circular(24)),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Text(p?.name ?? "Patient", style: const TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.bold)),
                          const SizedBox(width: 12),
                          if (p != null) 
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                              decoration: BoxDecoration(color: AppTheme.primaryColor.withOpacity(0.1), borderRadius: BorderRadius.circular(8)),
                              child: Text(p.recoveryStatus.toUpperCase(), style: const TextStyle(color: AppTheme.primaryColor, fontSize: 10, fontWeight: FontWeight.bold)),
                            ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(p?.email ?? "", style: const TextStyle(color: Colors.white54, fontSize: 14)),
                    ],
                  ),
                ),
                SizedBox(
                  width: 100, height: 100,
                  child: progressAsync.when(
                    data: (val) => ProgressRing(progress: val),
                    loading: () => const CircularProgressIndicator(strokeWidth: 2),
                    error: (_, __) => const ProgressRing(progress: 0.0),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 32),

          patientLatestLogAsync.when(
            data: (log) {
              if (log == null) return const SizedBox.shrink();
              return Container(
                padding: const EdgeInsets.all(20),
                margin: const EdgeInsets.only(bottom: 24),
                decoration: BoxDecoration(color: AppTheme.surfaceColor, borderRadius: BorderRadius.circular(24), border: Border.all(color: AppTheme.primaryColor.withOpacity(0.1))),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: [
                    _VitalsIndicator(icon: Icons.thermostat_rounded, label: 'Temp', value: '${log.temperature ?? "--"}°C', color: AppTheme.primaryColor),
                    _VitalsIndicator(icon: Icons.favorite_rounded, label: 'Pain', value: '${log.painLevel}/10', color: AppTheme.dangerColor),
                    _VitalsIndicator(icon: Icons.mood_rounded, label: 'Mood', value: '${log.moodLevel}/5', color: Colors.blue),
                  ],
                ),
              );
            },
            loading: () => const LinearProgressIndicator(),
            error: (_, __) => const SizedBox.shrink(),
          ),

          // INTERLEAVED TIMELINE FOR CARETAKER
          patientMedsAsync.when(
            data: (meds) => patientTasksAsync.when(
              data: (tasks) {
                if (meds.isEmpty && tasks.isEmpty) return const Center(child: Text('No recovery data available.', style: TextStyle(color: Colors.white24)));

                // deduplicate & sort
                final seenMeds = <String>{};
                final List<Map<String, dynamic>> timeline = [];
                for (final m in meds) {
                  final key = "${m.medicationName}_${m.scheduledTime.hour}:${m.scheduledTime.minute}";
                  if (seenMeds.add(key)) {
                    timeline.add({'type': 'med', 'time': m.scheduledTime.hour * 60 + m.scheduledTime.minute, 'data': m});
                  }
                }
                for (final t in tasks) {
                   int timeVal = 1440;
                   if (t.scheduledTime != null) {
                     final parts = t.scheduledTime!.split(':');
                     if (parts.length == 2) timeVal = int.parse(parts[0]) * 60 + int.parse(parts[1]);
                   }
                   timeline.add({'type': 'task', 'time': timeVal, 'data': t});
                }
                timeline.sort((a,b) => (a['time'] as int).compareTo(b['time'] as int));

                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Patient Roadmap (Today)', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 18)),
                    const SizedBox(height: 16),
                    ...timeline.map((item) {
                      if (item['type'] == 'med') {
                        final m = item['data'] as MedicationTask;
                        return MedicationCard(
                          medicationName: m.medicationName,
                          dosage: m.dosage,
                          time: m.scheduledTime.hour.toString().padLeft(2, '0') + ':' + m.scheduledTime.minute.toString().padLeft(2, '0'),
                          isTaken: m.isTaken,
                          onMarkAsTaken: () {}, 
                        );
                      } else {
                        final t = item['data'] as RecoveryTask;
                        return MedicationCard(
                          medicationName: t.title,
                          dosage: t.description,
                          time: t.scheduledTime ?? 'Daily',
                          isTaken: false, // In this simple view we don't have log status linked yet, will enhance in next step
                          onMarkAsTaken: () {},
                        );
                      }
                    }).toList(),
                  ],
                );
              },
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (e,_) => Text('Tasks missing: $e'),
            ),
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (e, _) => Text('Meds missing: $e', style: const TextStyle(color: Colors.red)),
          ),
        ],
      ),
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Text('Error loading patient: $e', style: const TextStyle(color: Colors.red)),
    );
  }

  Widget _buildNoLinkedPatientsPlaceholder(BuildContext context, WidgetRef ref, UserModel user) {
    final codeCtrl = TextEditingController();
    return Container(
      padding: const EdgeInsets.all(32),
      decoration: BoxDecoration(color: AppTheme.surfaceColor, borderRadius: BorderRadius.circular(24)),
      child: Column(
        children: [
          const Icon(Icons.people_outline_rounded, color: AppTheme.textSecondary, size: 64),
          const SizedBox(height: 16),
          const Text('Not monitoring any patients yet.', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          const Text('Ask your loved one for their Care Circle invite code to start monitoring their recovery.', textAlign: TextAlign.center, style: TextStyle(color: Colors.white60, fontSize: 13)),
          const SizedBox(height: 24),
          TextField(
            controller: codeCtrl,
            style: const TextStyle(color: Colors.white),
            decoration: InputDecoration(
              hintText: 'Enter Invite Code (e.g. AB1234)',
              hintStyle: const TextStyle(color: Colors.white24),
              filled: true,
              fillColor: Colors.black26,
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
            ),
          ),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: () async {
                if (codeCtrl.text.length == 6) {
                  try {
                    await ref.read(careCircleRepositoryProvider).joinCircle(user.uid, codeCtrl.text.toUpperCase());
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Joined Care Circle Successfully!')));
                    }
                  } catch (e) {
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: ${e.toString()}'), backgroundColor: AppTheme.dangerColor));
                    }
                  }
                }
              },
              child: const Text('Join Care Circle'),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCareCircleInviteModule(BuildContext context, WidgetRef ref) {
     final user = ref.read(currentUserProfileProvider).value;
     return Container(
       padding: const EdgeInsets.all(24),
       decoration: BoxDecoration(
         color: AppTheme.surfaceColor,
         borderRadius: BorderRadius.circular(24),
         border: Border.all(color: AppTheme.primaryColor.withOpacity(0.1)),
       ),
       child: Column(
         crossAxisAlignment: CrossAxisAlignment.start,
         children: [
           const Text('Care Circle', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 18)),
           const SizedBox(height: 8),
           const Text('Invite family members to monitor your recovery and get help when you miss a dose.', style: TextStyle(color: Colors.white60, fontSize: 13)),
           const SizedBox(height: 24),
           SizedBox(
             width: double.infinity,
             child: OutlinedButton.icon(
               style: OutlinedButton.styleFrom(
                 side: const BorderSide(color: AppTheme.primaryColor),
                 padding: const EdgeInsets.symmetric(vertical: 12),
               ),
               onPressed: () async {
                 final code = await ref.read(careCircleRepositoryProvider).createInviteCode(user!.uid);
                 if (context.mounted) {
                   showDialog(
                     context: context,
                     builder: (ctx) => AlertDialog(
                       backgroundColor: AppTheme.surfaceColor,
                       title: const Text('Care Circle Invite'),
                       content: Column(
                         mainAxisSize: MainAxisSize.min,
                         children: [
                           const Text('Share this code with your caretaker:', style: TextStyle(color: Colors.white70)),
                           const SizedBox(height: 24),
                           Container(
                             padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                             decoration: BoxDecoration(color: Colors.black26, borderRadius: BorderRadius.circular(12)),
                             child: Text(code, style: const TextStyle(color: AppTheme.primaryColor, fontSize: 32, fontWeight: FontWeight.bold, letterSpacing: 4)),
                           ),
                         ],
                       ),
                       actions: [
                         TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Close')),
                       ],
                     ),
                   );
                 }
               },
               icon: const Icon(Icons.person_add_rounded, color: AppTheme.primaryColor),
               label: const Text('Generate Invite Code', style: TextStyle(color: AppTheme.primaryColor)),
             ),
           ),
         ],
       ),
     );
  }

  Widget _buildNoMedsPlaceholder() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(color: AppTheme.surfaceColor, borderRadius: BorderRadius.circular(20), border: Border.all(color: Colors.white10)),
      child: const Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.health_and_safety_outlined, color: AppTheme.textSecondary, size: 48),
          SizedBox(height: 12),
          Text('No medications scheduled.\nTap the + button to build your routine.', textAlign: TextAlign.center, style: TextStyle(color: AppTheme.textSecondary)),
        ],
      ),
    );
  }

  Widget _buildDismissibleMedCard(BuildContext context, WidgetRef ref, MedicationTask t) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8.0),
      child: Dismissible(
        key: ValueKey(t.id),
        direction: DismissDirection.endToStart,
        background: Container(
          alignment: Alignment.centerRight,
          padding: const EdgeInsets.only(right: 24.0),
          decoration: BoxDecoration(color: AppTheme.dangerColor, borderRadius: BorderRadius.circular(16)),
          child: const Icon(Icons.delete_sweep_rounded, color: Colors.white, size: 32),
        ),
        confirmDismiss: (dir) => _confirmDeleteMedication(context, ref, t),
        child: MedicationCard(
          medicationName: t.medicationName,
          dosage: t.dosage,
          subtitle: 'Day ${t.scheduledTime.difference(DateTime(t.startDate.year, t.startDate.month, t.startDate.day)).inDays + 1} of ${t.durationDays}',
          time: _formatTime(t.scheduledTime),
          isTaken: t.isTaken,
          onMarkAsTaken: () => ref.read(localHealthRepositoryProvider).toggleMedicationTaken(t.id, true),
        ),
      ),
    );
  }

  Widget _buildCaretakerProfilePrompt(BuildContext context, UserModel user) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [Colors.blue.shade900.withOpacity(0.8), Colors.blue.shade800.withOpacity(0.4)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(28),
        border: Border.all(color: Colors.blue.withOpacity(0.3)),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(color: Colors.white.withOpacity(0.1), shape: BoxShape.circle),
                child: const Icon(Icons.shield_rounded, color: Colors.white, size: 28),
              ),
              const SizedBox(width: 16),
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Finalize Emergency Profile', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 18)),
                    const SizedBox(height: 4),
                    Text('Ensure doctors and patients can reach you instantly.', style: TextStyle(color: Colors.white70, fontSize: 13)),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),
          SizedBox(
            width: double.infinity,
            height: 50,
            child: ElevatedButton(
              onPressed: () => CaretakerProfileDialog.show(context, user),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.white,
                foregroundColor: Colors.blue.shade900,
                elevation: 0,
              ),
              child: const Text('Complete Caregiver Profile', style: TextStyle(fontWeight: FontWeight.bold)),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDoctorInfoCardForCaretaker(UserModel doctor) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 24),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppTheme.surfaceColor,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: AppTheme.primaryColor.withOpacity(0.2)),
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(0.15), blurRadius: 10, offset: const Offset(0, 4)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              CircleAvatar(
                radius: 20,
                backgroundColor: AppTheme.primaryColor.withOpacity(0.1),
                child: const Icon(Icons.medical_services_outlined, color: AppTheme.primaryColor, size: 20),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      doctor.medicalDegree != null ? 'Dr. ${doctor.name}, ${doctor.medicalDegree}' : 'Dr. ${doctor.name}',
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Colors.white),
                    ),
                    const Text('Primary Clinician (Emergency Contact)', style: TextStyle(color: AppTheme.textSecondary, fontSize: 11)),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          _buildCompactContactRow(Icons.phone_rounded, doctor.phone ?? 'N/A'),
          if (doctor.alternativePhone != null && doctor.alternativePhone!.isNotEmpty) ...[
            const SizedBox(height: 8),
            _buildCompactContactRow(Icons.contact_phone_outlined, '${doctor.alternativePhone} (Alt)'),
          ],
        ],
      ),
    );
  }

  Widget _buildCompactContactRow(IconData icon, String value) {
    return Row(
      children: [
        Icon(icon, size: 14, color: AppTheme.primaryColor),
        const SizedBox(width: 10),
        Text(value, style: const TextStyle(color: Colors.white70, fontSize: 13, fontWeight: FontWeight.bold)),
      ],
    );
  }

  Future<bool?> _confirmDeleteMedication(BuildContext context, WidgetRef ref, MedicationTask t) async {
    String reason = '';
    final reasonController = TextEditingController();
    return showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppTheme.surfaceColor,
        title: const Text('Delete Log', style: TextStyle(color: AppTheme.dangerColor)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('Please state why you are deleting this task.', style: TextStyle(color: Colors.white70)),
            const SizedBox(height: 16),
            TextFormField(controller: reasonController, autofocus: true, style: const TextStyle(color: Colors.white), decoration: const InputDecoration(hintText: 'e.g., Doctor advised against it', border: OutlineInputBorder())),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.of(ctx).pop(false), child: const Text('Cancel', style: TextStyle(color: Colors.white54))),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppTheme.dangerColor),
            onPressed: () {
              if (reasonController.text.trim().length > 5) {
                reason = reasonController.text.trim();
                ref.read(localHealthRepositoryProvider).softDeleteMedication(t.id, reason);
                Navigator.of(ctx).pop(true);
              }
            },
            child: const Text('Confirm Deletion'),
          ),
        ],
      ),
    );
  }
}

class _VitalsIndicator extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final Color color;

  const _VitalsIndicator({
    required this.icon,
    required this.label,
    required this.value,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Icon(icon, color: color, size: 28),
        const SizedBox(height: 8),
        Text(value, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
        Text(label, style: const TextStyle(color: AppTheme.textSecondary, fontSize: 12)),
      ],
    );
  }
}
