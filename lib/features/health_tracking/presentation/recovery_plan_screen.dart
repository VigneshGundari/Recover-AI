import 'dart:typed_data';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:file_picker/file_picker.dart';
import 'dart:io';
import '../../../core/theme/app_theme.dart';
import '../data/recovery_plan_repository.dart';
import '../data/recovery_plan_collection.dart';
import '../data/medical_history_repository.dart';
import '../../copilot/data/ai_service.dart';
import '../../user/data/user_repository.dart';

class RecoveryPlanScreen extends ConsumerStatefulWidget {
  const RecoveryPlanScreen({super.key});

  @override
  ConsumerState<RecoveryPlanScreen> createState() => _RecoveryPlanScreenState();
}

class _RecoveryPlanScreenState extends ConsumerState<RecoveryPlanScreen> {
  bool _isAnalyzing = false;
  Map<String, dynamic>? _proposedPlan;
  Uint8List? _reportBytes; 
  final TextEditingController _durationController = TextEditingController();

  Future<void> _pickAndAnalyzeReport() async {
    final result = await FilePicker.platform.pickFiles(type: FileType.image);
    if (result == null || result.files.single.path == null) return;

    setState(() => _isAnalyzing = true);

    try {
      _reportBytes = await File(result.files.single.path!).readAsBytes();
      final aiService = ref.read(copilotServiceProvider);
      if (!aiService.isInitialized) await aiService.initializeWithIsarContext();

      final jsonResponse = await aiService.generateRecoveryPlan(_reportBytes!);
      final cleanJson = jsonResponse.replaceAll('```json', '').replaceAll('```', '').trim();
      
      setState(() {
        _proposedPlan = jsonDecode(cleanJson);
        _durationController.text = _proposedPlan?['durationDays']?.toString() ?? '14';
      });
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Plan generation failed: $e'), backgroundColor: AppTheme.dangerColor),
      );
    } finally {
      setState(() => _isAnalyzing = false);
    }
  }

  Future<void> _activatePlan() async {
    if (_proposedPlan == null) return;
    
    final user = ref.read(currentUserProfileProvider).value;
    if (user == null) return;

    final planRepo = ref.read(recoveryPlanRepositoryProvider);
    final historyRepo = ref.read(medicalHistoryRepositoryProvider);
    
    String? localPath;
    if (_reportBytes != null) {
      localPath = await historyRepo.saveDocumentLocally(_reportBytes!, 'report');
    }

    // Override suggested duration if user edited it
    _proposedPlan!['durationDays'] = int.tryParse(_durationController.text) ?? 14;

    try {
      await planRepo.savePlan(
        user.uid, 
        _proposedPlan!, 
        List<Map<String, dynamic>>.from(_proposedPlan!['tasks']),
        reportPath: localPath,
      );

      if (mounted) {
        setState(() {
          _proposedPlan = null;
          _reportBytes = null;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Recovery Plan Activated Successfully!'), backgroundColor: AppTheme.primaryColor),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to activate plan: $e'), backgroundColor: AppTheme.dangerColor),
        );
      }
    }
  }

  void _showReportPreview(String path) {
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
              const Text(
                'Source Analysis Document', 
                style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
    );
  }

  void _showEditProposedTaskDialog(int index) {
    final taskData = _proposedPlan!['tasks'][index];
    final title = taskData['title'] as String;
    String? editedTime = taskData['scheduledTime'];
    
    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          backgroundColor: AppTheme.surfaceColor,
          title: Text('Edit Target Time', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: const TextStyle(color: AppTheme.textSecondary, fontSize: 13)),
              const SizedBox(height: 20),
              const Text('Scheduled Time', style: TextStyle(color: AppTheme.textSecondary, fontSize: 12)),
              const SizedBox(height: 8),
              ListTile(
                dense: true,
                tileColor: Colors.black26,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                title: Text(editedTime ?? 'Anytime', style: const TextStyle(color: AppTheme.primaryColor, fontWeight: FontWeight.bold)),
                trailing: const Icon(Icons.access_time_rounded, color: AppTheme.primaryColor, size: 20),
                onTap: () async {
                  final time = await showTimePicker(
                    context: context, 
                    initialTime: TimeOfDay.now(),
                  );
                  if (time != null) {
                    setDialogState(() => editedTime = '${time.hour.toString().padLeft(2, '0')}:${time.minute.toString().padLeft(2, '0')}');
                  }
                },
              ),
            ],
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: AppTheme.primaryColor),
              onPressed: () {
                setState(() {
                  _proposedPlan!['tasks'][index]['scheduledTime'] = editedTime;
                });
                Navigator.pop(ctx);
              },
              child: const Text('Confirm', style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold)),
            ),
          ],
        ),
      ),
    );
  }

  void _showEditTaskDialog(RecoveryTask task) {
    String? editedTime = task.scheduledTime;
    final durationCtrl = TextEditingController(text: task.durationDays.toString());
    List<int> selectedDays = List.from(task.daysOfWeek);
    final List<String> weekDays = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          backgroundColor: AppTheme.surfaceColor,
          title: Text('Edit ${task.title}', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Schedule Time', style: TextStyle(color: AppTheme.textSecondary, fontSize: 12)),
                const SizedBox(height: 8),
                ListTile(
                  dense: true,
                  tileColor: Colors.black26,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  title: Text(editedTime ?? 'Anytime', style: const TextStyle(color: AppTheme.primaryColor, fontWeight: FontWeight.bold)),
                  trailing: const Icon(Icons.access_time_rounded, color: AppTheme.primaryColor, size: 20),
                  onTap: () async {
                    final time = await showTimePicker(
                      context: context, 
                      initialTime: editedTime != null 
                        ? TimeOfDay(hour: int.parse(editedTime!.split(':')[0]), minute: int.parse(editedTime!.split(':')[1]))
                        : TimeOfDay.now()
                    );
                    if (time != null) {
                      setDialogState(() => editedTime = '${time.hour.toString().padLeft(2, '0')}:${time.minute.toString().padLeft(2, '0')}');
                    }
                  },
                ),
                const SizedBox(height: 20),
                const Text('Total Duration (Days)', style: TextStyle(color: AppTheme.textSecondary, fontSize: 12)),
                const SizedBox(height: 8),
                TextField(
                  controller: durationCtrl,
                  keyboardType: TextInputType.number,
                  style: const TextStyle(color: Colors.white),
                  decoration: InputDecoration(
                    filled: true,
                    fillColor: Colors.black26,
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                  ),
                ),
                const SizedBox(height: 20),
                const Text('Days of Week', style: TextStyle(color: AppTheme.textSecondary, fontSize: 12)),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 4,
                  children: List.generate(7, (index) {
                    final dayInt = index + 1;
                    final isSelected = selectedDays.contains(dayInt);
                    return FilterChip(
                      label: Text(weekDays[index], style: TextStyle(fontSize: 10, color: isSelected ? Colors.black : Colors.white)),
                      selected: isSelected,
                      selectedColor: AppTheme.primaryColor,
                      backgroundColor: Colors.black26,
                      onSelected: (val) {
                        setDialogState(() {
                          if (val) selectedDays.add(dayInt);
                          else if (selectedDays.length > 1) selectedDays.remove(dayInt);
                        });
                      },
                    );
                  }),
                ),
                const SizedBox(height: 12),
                const Divider(color: Colors.white10),
                const SizedBox(height: 12),
                TextButton.icon(
                  onPressed: () {
                    // Postpone logic: shift startDate to tomorrow
                    task.startDate = DateTime.now().add(const Duration(days: 1));
                    ref.read(recoveryPlanRepositoryProvider).updateTask(task);
                    Navigator.pop(ctx);
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Task postponed to tomorrow'))
                    );
                  },
                  icon: const Icon(Icons.next_plan_rounded, color: Colors.orangeAccent),
                  label: const Text('Postpone to Tomorrow', style: TextStyle(color: Colors.orangeAccent)),
                )
              ],
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: AppTheme.primaryColor),
              onPressed: () {
                task.scheduledTime = editedTime;
                task.durationDays = int.tryParse(durationCtrl.text) ?? task.durationDays;
                task.daysOfWeek = selectedDays;
                ref.read(recoveryPlanRepositoryProvider).updateTask(task);
                Navigator.pop(ctx);
              },
              child: const Text('Save Changes', style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold)),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final activePlanAsync = ref.watch(activeRecoveryPlanProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Column(
          children: [
            Text('Recovery Plan'),
            Text('AI-Generated Strategy', style: TextStyle(fontSize: 12, color: AppTheme.primaryColor)),
          ],
        ),
      ),
      body: activePlanAsync.when(
        data: (plan) {
          if (_proposedPlan != null) return _buildReviewUI();
          if (plan == null) return _buildEmptyUI();
          return _buildActivePlanUI(plan);
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Error: $e')),
      ),
    );
  }

  Widget _buildEmptyUI() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        children: [
          const SizedBox(height: 40),
          _buildReportUploadPrompt(),
        ],
      ),
    );
  }

  Widget _buildReviewUI() {
    final tasks = List<Map<String, dynamic>>.from(_proposedPlan!['tasks']);

    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: AppTheme.primaryColor.withOpacity(0.1),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: AppTheme.primaryColor.withOpacity(0.3)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('AI Proposed Strategy', style: TextStyle(color: AppTheme.primaryColor, fontWeight: FontWeight.bold)),
                const SizedBox(height: 12),
                Text(_proposedPlan!['title'], style: const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold)),
                const SizedBox(height: 8),
                Text(_proposedPlan!['description'], style: const TextStyle(color: Colors.white70, fontSize: 14)),
                const SizedBox(height: 20),
                Row(
                  children: [
                    const Text('Duration (Days): ', style: TextStyle(color: Colors.white)),
                    const SizedBox(width: 12),
                    SizedBox(
                      width: 60,
                      child: TextField(
                        controller: _durationController,
                        keyboardType: TextInputType.number,
                        style: const TextStyle(color: AppTheme.primaryColor, fontWeight: FontWeight.bold),
                        decoration: const InputDecoration(isDense: true, contentPadding: EdgeInsets.symmetric(vertical: 8)),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 32),
          const Text('Suggested Daily Tasks', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 18)),
          const SizedBox(height: 16),
          ...tasks.asMap().entries.map((entry) {
            final index = entry.key;
            final task = entry.value;
            return Container(
              margin: const EdgeInsets.only(bottom: 12),
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(color: AppTheme.surfaceColor, borderRadius: BorderRadius.circular(16)),
              child: Row(
                children: [
                  Icon(Icons.auto_awesome, size: 16, color: AppTheme.primaryColor.withOpacity(0.5)),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(task['title'], style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                        Text(task['description'], style: const TextStyle(color: AppTheme.textSecondary, fontSize: 12)),
                      ],
                    ),
                  ),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(task['scheduledTime'] ?? '--:--', style: const TextStyle(color: AppTheme.primaryColor, fontSize: 12)),
                      IconButton(
                        onPressed: () => _showEditProposedTaskDialog(index),
                        icon: const Icon(Icons.edit_calendar_rounded, color: AppTheme.primaryColor, size: 18),
                        constraints: const BoxConstraints(),
                        padding: EdgeInsets.zero,
                        tooltip: 'Fix Time',
                      ),
                    ],
                  ),
                ],
              ),
            );
          }),
          const SizedBox(height: 40),
          ElevatedButton(
            onPressed: _activatePlan,
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.primaryColor,
              minimumSize: const Size(double.infinity, 56),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            ),
            child: const Text('Confirm & Activate Plan', style: TextStyle(color: AppTheme.backgroundColor, fontWeight: FontWeight.bold)),
          ),
          TextButton(
            onPressed: () => setState(() => _proposedPlan = null),
            child: const Center(child: Text('Discard and Start Over', style: TextStyle(color: AppTheme.dangerColor))),
          ),
        ],
      ),
    );
  }

  Widget _buildActivePlanUI(RecoveryPlan plan) {
    final todaysTasksAsync = ref.watch(todaysRecoveryTasksProvider);

    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildActiveHeaderCard(plan),
          const SizedBox(height: 32),
          const Text('Today\'s Roadmap', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 18)),
          const SizedBox(height: 16),
          todaysTasksAsync.when(
            data: (tasks) => Column(children: tasks.map((t) => _buildPlanCard(t)).toList()),
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (e, _) => Text('Error: $e'),
          ),
          const SizedBox(height: 32),
          _buildFullPlanOverview(plan),
        ],
      ),
    );
  }

  Widget _buildActiveHeaderCard(RecoveryPlan plan) {
    final now = DateTime.now();
    final remaining = plan.endDate.difference(now).inDays + 1;

    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [AppTheme.secondaryColor.withOpacity(0.8), AppTheme.secondaryColor],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(24),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(plan.title, style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
                const SizedBox(height: 8),
                Text(
                  '$remaining days remaining in your journey.',
                  style: const TextStyle(color: Colors.white70, fontSize: 13),
                ),
                if (plan.reportPath != null) ...[
                  const SizedBox(height: 12),
                  GestureDetector(
                    onTap: () => _showReportPreview(plan.reportPath!),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.2),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.remove_red_eye, color: Colors.white, size: 14),
                          SizedBox(width: 8),
                          Text('View Original Report', style: TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold)),
                        ],
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
          const Icon(Icons.rocket_launch_rounded, color: Colors.white30, size: 48),
        ],
      ),
    );
  }

  Widget _buildPlanCard(Map<String, dynamic> item) {
    final task = item['task'] as RecoveryTask;
    final bool isDone = item['isCompleted'] as bool;
    final String dayXofY = item['dayXofY'] ?? '';
    final user = ref.read(currentUserProfileProvider).value;

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.surfaceColor,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: isDone ? AppTheme.primaryColor.withOpacity(0.3) : Colors.white10),
      ),
      child: Row(
        children: [
          Checkbox(
            value: isDone,
            activeColor: AppTheme.primaryColor,
            onChanged: (val) {
              if (user != null) {
                ref.read(recoveryPlanRepositoryProvider).toggleTaskCompletion(user.uid, task.id, val ?? false);
              }
            },
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        task.title, 
                        style: TextStyle(
                          color: Colors.white, 
                          fontWeight: FontWeight.bold, 
                          decoration: isDone ? TextDecoration.lineThrough : null
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(color: Colors.white10, borderRadius: BorderRadius.circular(4)),
                      child: Text(
                        dayXofY.isNotEmpty ? dayXofY : task.type, 
                        style: const TextStyle(color: AppTheme.textSecondary, fontSize: 10),
                      ),
                    ),
                  ],
                ),
                Text(task.description, style: const TextStyle(color: AppTheme.textSecondary, fontSize: 12)),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              if (task.scheduledTime != null)
                Text(task.scheduledTime!, style: const TextStyle(color: AppTheme.primaryColor, fontSize: 12, fontWeight: FontWeight.bold)),
              const SizedBox(height: 4),
              IconButton(
                onPressed: () => _showEditTaskDialog(task),
                icon: const Icon(Icons.edit_note_rounded, color: AppTheme.primaryColor, size: 20),
                constraints: const BoxConstraints(),
                padding: EdgeInsets.zero,
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildFullPlanOverview(RecoveryPlan plan) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(color: Colors.white.withOpacity(0.02), borderRadius: BorderRadius.circular(20), border: Border.all(color: Colors.white10)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('Overall Strategy', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
              IconButton(
                onPressed: () {
                   ref.read(recoveryPlanRepositoryProvider).deletePlan(plan.id);
                }, 
                icon: const Icon(Icons.delete_outline, color: AppTheme.dangerColor, size: 20)
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(plan.description, style: const TextStyle(color: AppTheme.textSecondary, fontSize: 12)),
        ],
      ),
    );
  }

  Widget _buildReportUploadPrompt() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: AppTheme.primaryColor.withOpacity(0.05),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: AppTheme.primaryColor.withOpacity(0.1), style: BorderStyle.solid),
      ),
      child: Column(
        children: [
          _isAnalyzing 
            ? const CircularProgressIndicator(color: AppTheme.primaryColor)
            : const Icon(Icons.cloud_upload_outlined, color: AppTheme.primaryColor, size: 48),
          const SizedBox(height: 16),
          Text(
            _isAnalyzing ? 'RECOVER AI Analyzing...' : 'Need a more specific plan?',
            style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16),
          ),
          const SizedBox(height: 8),
          const Text(
            'Upload your latest scan or medical report to let RECOVER AI personalize your daily tasks and mobility strategy.', 
            textAlign: TextAlign.center, 
            style: TextStyle(color: AppTheme.textSecondary, fontSize: 13),
          ),
          const SizedBox(height: 24),
          ElevatedButton.icon(
            onPressed: _isAnalyzing ? null : _pickAndAnalyzeReport, 
            icon: const Icon(Icons.auto_awesome),
            label: const Text('Generate AI Plan'),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.primaryColor,
              foregroundColor: AppTheme.backgroundColor,
              minimumSize: const Size(200, 50),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
          ),
        ],
      ),
    );
  }
}
