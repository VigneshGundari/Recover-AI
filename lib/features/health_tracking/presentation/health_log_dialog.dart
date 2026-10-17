import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../data/daily_health_log_collection.dart';
import '../data/local_health_repository.dart';
import '../../user/data/user_repository.dart';
import '../../copilot/data/ai_service.dart';

class HealthLogDialog extends ConsumerStatefulWidget {
  const HealthLogDialog({super.key});

  static Future<void> show(BuildContext context) {
    return showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const HealthLogDialog(),
    );
  }

  @override
  ConsumerState<HealthLogDialog> createState() => _HealthLogDialogState();
}

class _HealthLogDialogState extends ConsumerState<HealthLogDialog> {
  int _painLevel = 1;
  int _moodLevel = 3; // Neutral
  double _temperature = 36.6;
  final TextEditingController _notesController = TextEditingController();
  final Set<String> _selectedSymptoms = {};

  final List<String> _commonSymptoms = [
    'Headache', 'Fatigue', 'Nausea', 'Cough', 'Fever', 
    'Dizziness', 'Body Ache', 'Sore Throat', 'Shortness of Breath'
  ];

  final List<IconData> _moodIcons = [
    Icons.sentiment_very_dissatisfied,
    Icons.sentiment_dissatisfied,
    Icons.sentiment_neutral,
    Icons.sentiment_satisfied,
    Icons.sentiment_very_satisfied,
  ];

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      backgroundColor: theme.colorScheme.surface.withOpacity(0.95),
      child: Container(
        padding: const EdgeInsets.all(24),
        constraints: const BoxConstraints(maxWidth: 500),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text('How are you feeling?', 
                    style: theme.textTheme.headlineSmall?.copyWith(color: Colors.white, fontWeight: FontWeight.bold)),
                  IconButton(
                    icon: const Icon(Icons.close, color: Colors.white70),
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ],
              ),
              const SizedBox(height: 24),

              // Mood Selector
              Text('Overall Mood', style: theme.textTheme.titleMedium?.copyWith(color: Colors.white)),
              const SizedBox(height: 12),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: List.generate(5, (index) {
                  final isSelected = _moodLevel == (index + 1);
                  return GestureDetector(
                    onTap: () => setState(() => _moodLevel = index + 1),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: isSelected ? theme.colorScheme.primaryContainer : Colors.transparent,
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: isSelected ? theme.colorScheme.primary : Colors.grey.withOpacity(0.3),
                        ),
                      ),
                      child: Icon(
                        _moodIcons[index],
                        color: isSelected ? Colors.white : Colors.white38,
                        size: 32,
                      ),
                    ),
                  );
                }),
              ),
              const SizedBox(height: 32),

              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text('Pain Level', style: theme.textTheme.titleMedium?.copyWith(color: Colors.white)),
                  Text('$_painLevel / 10', style: theme.textTheme.titleMedium?.copyWith(
                    color: _painLevel > 7 ? Colors.red : _painLevel > 4 ? Colors.orange : Colors.green,
                  )),
                ],
              ),
              Slider(
                value: _painLevel.toDouble(),
                min: 1,
                max: 10,
                divisions: 9,
                activeColor: Color.lerp(Colors.green, Colors.red, _painLevel / 10),
                onChanged: (val) => setState(() => _painLevel = val.toInt()),
              ),
              const SizedBox(height: 32),

              // Temperature Input
              Text('Temperature (°C)', style: theme.textTheme.titleMedium?.copyWith(color: Colors.white)),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: Slider(
                      value: _temperature,
                      min: 35.0,
                      max: 42.0,
                      divisions: 70,
                      onChanged: (val) => setState(() => _temperature = double.parse(val.toStringAsFixed(1))),
                    ),
                  ),
                  Container(
                    width: 80,
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    decoration: BoxDecoration(
                      border: Border.all(color: theme.colorScheme.primary),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text('$_temperature', textAlign: TextAlign.center, 
                      style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold, color: Colors.white)),
                  ),
                ],
              ),
              const SizedBox(height: 32),

              // Symptoms Chips
              Text('Common Symptoms', style: theme.textTheme.titleMedium?.copyWith(color: Colors.white)),
              const SizedBox(height: 12),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: _commonSymptoms.map((symptom) {
                  final isSelected = _selectedSymptoms.contains(symptom);
                  return FilterChip(
                    label: Text(symptom),
                    selected: isSelected,
                    onSelected: (selected) {
                      setState(() {
                        if (selected) _selectedSymptoms.add(symptom);
                        else _selectedSymptoms.remove(symptom);
                      });
                    },
                  );
                }).toList(),
              ),
              const SizedBox(height: 32),

              // Notes
              Text('Detailed Notes', style: theme.textTheme.titleMedium?.copyWith(color: Colors.white)),
              const SizedBox(height: 12),
              TextField(
                controller: _notesController,
                maxLines: 3,
                style: const TextStyle(color: Colors.white),
                decoration: InputDecoration(
                  hintText: 'Describe how you feel...',
                  hintStyle: const TextStyle(color: Colors.white38),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(color: Colors.white10),
                  ),
                ),
              ),
              const SizedBox(height: 32),

              // Submit Button
              SizedBox(
                width: double.infinity,
                height: 54,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  ),
                  onPressed: _saveLog,
                  child: const Text('Save Daily Log', style: TextStyle(fontSize: 18)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _saveLog() async {
    final repository = ref.read(localHealthRepositoryProvider);
    final user = ref.read(currentUserProfileProvider).value;
    final copilot = ref.read(copilotServiceProvider);
    
    if (user == null) return;

    // Show loading
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('AI is analyzing your check-in...'), duration: Duration(seconds: 1)),
      );
    }

    double sentiment = 0.0;
    if (_notesController.text.isNotEmpty) {
      sentiment = await copilot.analyzeSentiment(_notesController.text);
    }

    final log = HealthLog()
      ..userId = user.uid
      ..moodLevel = _moodLevel
      ..painLevel = _painLevel
      ..temperature = _temperature
      ..sentimentScore = sentiment
      ..symptoms = _selectedSymptoms.toList()
      ..aiJournalEntry = _notesController.text
      ..timestamp = DateTime.now();

    await repository.addHealthLog(user.uid, log);
    
    if (mounted) {
      ScaffoldMessenger.of(context).clearSnackBars();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Daily log saved. Feel better soon!')),
      );
      Navigator.of(context).pop();
    }
  }
}
