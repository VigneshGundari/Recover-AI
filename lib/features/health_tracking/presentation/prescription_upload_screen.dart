import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:file_picker/file_picker.dart';
import 'package:recover_ai/core/theme/app_theme.dart';
import 'package:recover_ai/features/copilot/data/ai_service.dart';
import 'dart:convert';
import 'package:recover_ai/features/health_tracking/data/local_health_repository.dart';
import 'package:recover_ai/features/health_tracking/data/medication_task_collection.dart';
import 'package:recover_ai/features/user/data/user_repository.dart';
import 'package:recover_ai/features/copilot/data/neo4j_service.dart';
import 'package:recover_ai/features/health_tracking/data/medical_history_repository.dart';
import 'package:go_router/go_router.dart';

class PrescriptionUploadScreen extends ConsumerStatefulWidget {
  const PrescriptionUploadScreen({super.key});

  @override
  ConsumerState<PrescriptionUploadScreen> createState() => _PrescriptionUploadScreenState();
}

class _PrescriptionUploadScreenState extends ConsumerState<PrescriptionUploadScreen> {
  File? _selectedImage;
  bool _isProcessing = false;
  String? _extractedStatus;
  List<Map<String, dynamic>> _pendingDrugs = [];
  bool _isEditingMode = false;

  Future<void> _pickImage() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.image,
      allowMultiple: false,
    );

    if (result != null && result.files.single.path != null) {
      setState(() {
        _selectedImage = File(result.files.single.path!);
        _extractedStatus = "Image loaded seamlessly.";
      });
    }
  }

  Future<void> _processImage() async {
    if (_selectedImage == null) return;

    setState(() {
      _isProcessing = true;
      _extractedStatus = "Google Document AI Analyzing...";
    });

    try {
      final bytes = await _selectedImage!.readAsBytes();
      final aiService = ref.read(copilotServiceProvider);
      if (!aiService.isInitialized) await aiService.initializeWithIsarContext();
      
      final extractedJSON = await aiService.analyzePrescription(bytes);
      
      // Attempt to deserialize Native Document JSON string
      final String cleanJSON = extractedJSON.replaceAll('```json', '').replaceAll('```', '').trim();
      final List<dynamic> drugs = jsonDecode(cleanJSON);
      
      setState(() {
        _pendingDrugs = drugs.map((d) => {
          'medicationName': d['medicationName']?.toString() ?? 'Unknown',
          'dosage': "${d['dosage'] ?? ''} - ${d['instructions'] ?? ''}",
          'scheduledTime': TimeOfDay.fromDateTime(DateTime.now().add(const Duration(hours: 1))),
        }).toList();
        _extractedStatus = null; // Clear status to show list
      });

    } catch (e) {
      setState(() {
        _extractedStatus = "Extraction Engine Error: $e";
      });
    } finally {
      setState(() {
        _isProcessing = false;
      });
    }
  }

  Future<void> _confirmAndSave() async {
    final localRepo = ref.read(localHealthRepositoryProvider);
    final neo4jService = ref.read(neo4jServiceProvider);
    final aiService = ref.read(copilotServiceProvider);
    
    final userProfile = ref.read(currentUserProfileProvider).value;
    if (userProfile == null) return;

    final historyRepo = ref.read(medicalHistoryRepositoryProvider);
    String? localImagePath;
    if (_selectedImage != null) {
      final bytes = await _selectedImage!.readAsBytes();
      localImagePath = await historyRepo.saveDocumentLocally(bytes, 'scan');
    }

    for (var drug in _pendingDrugs) {
      final rawName = drug['medicationName'].toString().trim();
      if (rawName.isEmpty) continue;

      final time = drug['scheduledTime'] as TimeOfDay? ?? TimeOfDay.now();
      
      final task = MedicationTask()
        ..userId = userProfile.uid
        ..medicationName = rawName
        ..dosage = drug['dosage']
        ..scheduledTime = DateTime.now() 
        ..startDate = DateTime.now()
        ..frequency = 1
        ..durationDays = 7; 
      
      localRepo.addMedicationTasks(userProfile.uid, task, [time]);

      aiService.extractActiveIngredients(rawName).then((ingredients) {
         neo4jService.logMedicationGraph(userProfile.uid, rawName, ingredients);
      }).catchError((e) {
         debugPrint("Background Neo4j Sync Failed: $e");
      });
    }

    if (localImagePath != null) {
      final historyJson = jsonEncode(_pendingDrugs.map((d) => {
        'name': d['medicationName'],
        'dosage': d['dosage'],
        'time': (d['scheduledTime'] as TimeOfDay).format(context),
      }).toList());

      await historyRepo.saveScanHistory(
        userId: userProfile.uid,
        imagePath: localImagePath,
        extractedJson: historyJson,
      );
    }
    
    setState(() {
      _pendingDrugs.clear();
      _selectedImage = null;
    });

    if (!mounted) return;
    
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppTheme.surfaceColor,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Row(
          children: [
            Icon(Icons.check_circle_rounded, color: AppTheme.primaryColor, size: 32),
            SizedBox(width: 12),
            Text('Tasks Saved!', style: TextStyle(color: Colors.white)),
          ],
        ),
        content: const Text(
          'Successfully generated tasks and pinned them to your Dashboard.\n\nRedirecting in 5 seconds...',
          style: TextStyle(color: Colors.white70),
        ),
      ),
    );

    await Future.delayed(const Duration(seconds: 5));
    if (mounted) {
      Navigator.of(context, rootNavigator: true).pop();
      context.go('/');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Smart Intake Pipeline'),
        elevation: 0,
        backgroundColor: Colors.transparent,
      ),
      body: Center(
        child: SingleChildScrollView(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 24.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                if (_selectedImage != null)
                  ClipRRect(
                    borderRadius: BorderRadius.circular(20),
                    child: Image.file(
                      _selectedImage!, 
                      height: 400, 
                      width: double.infinity,
                      fit: BoxFit.cover,
                    ),
                  )
                else
                  GestureDetector(
                    onTap: _pickImage,
                    child: Container(
                      height: 350,
                      width: double.infinity,
                      decoration: BoxDecoration(
                        color: AppTheme.surfaceColor,
                        borderRadius: BorderRadius.circular(24),
                        border: Border.all(color: AppTheme.primaryColor.withOpacity(0.4), width: 2),
                      ),
                      child: const Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.center_focus_weak_rounded, size: 72, color: AppTheme.textSecondary),
                            SizedBox(height: 24),
                            Text(
                              'Tap to Select Prescription',
                              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                            ),
                            SizedBox(height: 8),
                            Text('Supported formats: .jpg, .png', style: TextStyle(color: Colors.white54)),
                          ],
                        ),
                      ),
                    ),
                  ),
                const SizedBox(height: 32),
                
                if (_selectedImage != null && _pendingDrugs.isEmpty)
                  ElevatedButton.icon(
                    onPressed: _isProcessing ? null : _processImage,
                    icon: _isProcessing 
                      ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: AppTheme.backgroundColor, strokeWidth: 3))
                      : const Icon(Icons.document_scanner_rounded),
                    label: Text(_isProcessing ? 'Extracting Medical Data...' : 'Extract Medications'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppTheme.primaryColor,
                      minimumSize: const Size(double.infinity, 56),
                    ),
                  ),
                  
                const SizedBox(height: 24),
                
                if (_pendingDrugs.isNotEmpty) ...[
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text('Verify Extracted Medications', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                      IconButton(
                        icon: Icon(_isEditingMode ? Icons.check_circle_rounded : Icons.edit_rounded, color: AppTheme.primaryColor),
                        onPressed: () {
                          setState(() {
                            _isEditingMode = !_isEditingMode;
                          });
                        },
                      )
                    ],
                  ),
                  const SizedBox(height: 16),
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: AppTheme.surfaceColor,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: _isEditingMode ? AppTheme.primaryColor : AppTheme.primaryColor.withOpacity(0.5), width: _isEditingMode ? 2 : 1),
                    ),
                    child: ListView.separated(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      itemCount: _pendingDrugs.length,
                      separatorBuilder: (context, index) => const Divider(color: Colors.white24, height: 32),
                      itemBuilder: (context, index) {
                        return Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            if (_isEditingMode) ...[
                              TextFormField(
                                initialValue: _pendingDrugs[index]['medicationName'],
                                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                                decoration: const InputDecoration(labelText: 'Drug Name', border: OutlineInputBorder()),
                                onChanged: (val) => _pendingDrugs[index]['medicationName'] = val,
                              ),
                              const SizedBox(height: 12),
                              TextFormField(
                                initialValue: _pendingDrugs[index]['dosage'],
                                decoration: const InputDecoration(labelText: 'Dosage / Instructions', border: OutlineInputBorder()),
                                onChanged: (val) => _pendingDrugs[index]['dosage'] = val,
                              ),
                              const SizedBox(height: 12),
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Text(
                                    "Reminder: ${(_pendingDrugs[index]['scheduledTime'] as TimeOfDay).format(context)}",
                                    style: const TextStyle(color: AppTheme.primaryColor, fontWeight: FontWeight.bold),
                                  ),
                                  TextButton.icon(
                                    onPressed: () async {
                                      final time = await showTimePicker(
                                        context: context,
                                        initialTime: _pendingDrugs[index]['scheduledTime'] as TimeOfDay,
                                      );
                                      if (time != null) {
                                        setState(() {
                                          _pendingDrugs[index]['scheduledTime'] = time;
                                        });
                                      }
                                    },
                                    icon: const Icon(Icons.access_time_rounded, color: AppTheme.primaryColor),
                                    label: const Text("Set Time", style: TextStyle(color: AppTheme.primaryColor)),
                                  ),
                                ],
                              ),
                            ] else ...[
                              Text(
                                _pendingDrugs[index]['medicationName'],
                                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: Colors.white),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                "${_pendingDrugs[index]['dosage']} at ${(_pendingDrugs[index]['scheduledTime'] as TimeOfDay).format(context)}",
                                style: const TextStyle(color: AppTheme.textSecondary),
                              ),
                            ],
                          ],
                        );
                      },
                    ),
                  ),
                  const SizedBox(height: 24),
                  ElevatedButton.icon(
                    onPressed: _confirmAndSave,
                    icon: const Icon(Icons.check_circle_rounded),
                    label: const Text('Confirm & Save Tasks', style: TextStyle(fontWeight: FontWeight.bold)),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppTheme.primaryColor,
                      foregroundColor: AppTheme.backgroundColor,
                      minimumSize: const Size(double.infinity, 56),
                    ),
                  ),
                ],
                
                if (_extractedStatus != null && _pendingDrugs.isEmpty)
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: AppTheme.surfaceColor.withOpacity(0.5),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      _extractedStatus!,
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: _extractedStatus!.contains('Error') ? AppTheme.dangerColor : AppTheme.primaryColor,
                      ),
                    ),
                  )
              ],
            ),
          ),
        ),
      ),
    );
  }
}
