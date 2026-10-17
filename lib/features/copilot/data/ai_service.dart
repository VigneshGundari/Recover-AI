import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_generative_ai/google_generative_ai.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:isar/isar.dart';
import 'package:recover_ai/features/health_tracking/data/local_health_repository.dart';
import 'package:recover_ai/features/health_tracking/data/daily_health_log_collection.dart';

final copilotServiceProvider = Provider<CopilotService>((ref) {
  final isar = ref.watch(isarProvider);
  return CopilotService(isar: isar);
});

class CopilotService {
  final Isar _isar;
  GenerativeModel? _model;
  GenerativeModel? _normModel; 
  ChatSession? chatSession;
  bool _isInitInProgress = false;
  bool isInitialized = false;

  CopilotService({required Isar isar}) : _isar = isar;

  Future<void> _ensureInitialized() async {
    if (isInitialized) return;
    if (_isInitInProgress) {
      while (_isInitInProgress) {
        await Future.delayed(const Duration(milliseconds: 100));
      }
      return;
    }
    _isInitInProgress = true;
    try {
      await initializeWithIsarContext();
    } finally {
      _isInitInProgress = false;
    }
  }

  /// Safely injects the Offline Isar Database natively into the AI's core Brain.
  Future<void> initializeWithIsarContext() async {
    // 1. Fetch the last 7 offline health logs
    final logs = await _isar.healthLogs.where().sortByTimestampDesc().limit(7).findAll();
    
    // 2. Synthesize the logs into unstructured text for the AI
    String dynamicContext = '';
    if (logs.isEmpty) {
      dynamicContext = "No history logged yet. Kindly encourage them to use the Dashboard Timeline Check-in button so you have data to analyze!";
    } else {
      for (var log in logs) {
        dynamicContext += "Date logged: ${log.timestamp}\n";
        dynamicContext += "Pain Score: ${log.painLevel}/10\n";
        dynamicContext += "Mood Score: ${log.moodLevel}/10\n";
        dynamicContext += "User Journal: ${log.aiJournalEntry}\n\n";
      }
    }

    // 3. Assemble the intelligence Model
    final apiKey = dotenv.env['GEMINI_API_KEY'];
    if (apiKey == null || apiKey.isEmpty) {
      throw Exception('Gemini API Key missing in .env file!');
    }

    _model = GenerativeModel(
      model: 'gemini-2.5-flash',
      apiKey: apiKey,
      systemInstruction: Content.system('''
You are the official Recover AI Health Copilot.
Personality: You are a friendly, casual, highly empathetic coach and health assistant. You speak directly to the user as a supportive friend. Do not be overly clinical unless stating facts. Use emojis occasionally. Keep responses beautifully concise. Do not write monolithic essays.

Context: I will securely feed you the user's latest Health Logs consisting of their daily Pain (1-10), Mood (1-10), and their personal journal entry. 
Your Core Directive: Explicitly explicitly reference the user's exact logs below to formulate a hyper-personalized response. If their pain is high, show deep empathy. If their mood is up, be hyper-enthusiastic. 

---
User's Recent Logs (Last 7 Days):
$dynamicContext
'''),
    );

    _normModel = GenerativeModel(
      model: 'gemini-2.5-flash',
      apiKey: apiKey,
    );

    // Start a clean, context-injected chat session
    chatSession = _model!.startChat();
    isInitialized = true;
  }

  // Session 3 Multi-Modal Extraction Engine
  Future<String> analyzePrescription(List<int> imageBytes) async {
    await _ensureInitialized();
    const systemPrompt = '''
You are a highly experienced clinical pharmacist reading a patient's physical medical prescription.
Extract the medication details and return ONLY a strict JSON Array with the exact medications listed.
Do NOT use markdown. Do NOT use backticks. ONLY RETURN PURE JSON.
Format MUST exactly strictly match:
[
  {
    "medicationName": "Amoxicillin",
    "dosage": "500 mg",
    "instructions": "Take twice daily after meals for 7 days"
  }
]
If you cannot read anything, return an empty array [].
''';
    
    final promptPart = TextPart(systemPrompt);
    final imagePart = DataPart('image/jpeg', Uint8List.fromList(imageBytes));

    try {
      final response = await _model!.generateContent([
        Content.multi([promptPart, imagePart])
      ]);
      return response.text ?? '[]';
    } catch (e) {
      throw Exception('Gemini extraction failed: $e');
    }
  }

  // Session 4 Knowledge Graph Normalization Engine
  Future<List<String>> extractActiveIngredients(String commonDrugName) async {
    await _ensureInitialized();
    if (!isInitialized) return [commonDrugName];
    
    final prompt = '''
You are a strict pharmacology expert mapping medications for a Medical Knowledge Graph.
Extract the core active pharmacological ingredients from the commercial drug name provided.
RETURN ONLY A STRICT JSON ARRAY OF STRINGS representing the generic chemical names.
Do NOT use markdown. Do NOT explain. 
Example Input: Tylenol Cold & Flu
Example Output: ["Acetaminophen", "Dextromethorphan", "Guaifenesin", "Phenylephrine"]

Input: $commonDrugName
''';

    try {
      final response = await _normModel!.generateContent([Content.text(prompt)]);
      final raw = response.text ?? '[]';
      debugPrint('[Gemini Graph Raw Parse]: $raw');
      
      final clean = raw.replaceAll('```json', '').replaceAll('```', '').trim();
      final List<dynamic> decoded = jsonDecode(clean);
      return decoded.map((e) => e.toString()).toList();
    } catch (e) {
      debugPrint('[Graph Normalization] Extraction fallback triggered for $commonDrugName: $e');
      return [commonDrugName]; // Fallback to raw nomenclature natively
    }
  }

  /// AI-Driven Rehabilitation Strategy Engine
  Future<String> generateRecoveryPlan(Uint8List imageBytes) async {
    await _ensureInitialized();
    const systemPrompt = '''
You are a world-class recovery specialist and physical therapist. 
Analyze the provided medical report/scan and design a comprehensive, multi-layered Recovery Plan.
Suggest a suitable duration for the recovery (e.g., 7 days, 14 days, 30 days).
Return ONLY a strict JSON object with the exact structure below.
Do NOT use markdown. Do NOT use backticks. ONLY RETURN PURE JSON.

Format MUST strictly match:
{
  "title": "Comprehensive Recovery Plan",
  "description": "Short overview based on the reports",
  "durationDays": 14,
  "tasks": [
    {
      "title": "Light Walking",
      "description": "Slow walks inside the home for 10-15 mins",
      "type": "Exercise",
      "scheduledTime": "08:00"
    },
    {
      "title": "Sunlight Exposure",
      "description": "Sit near a window or outdoors for 15 min",
      "type": "Environmental",
      "scheduledTime": "10:00"
    }
  ]
}
''';

    final promptPart = TextPart(systemPrompt);
    final imagePart = DataPart('image/jpeg', imageBytes);

    try {
      final response = await _model!.generateContent([
        Content.multi([promptPart, imagePart])
      ]);
      return response.text ?? '{}';
    } catch (e) {
      throw Exception('Gemini strategy generation failed: $e');
    }
  }

  /// Analyzes the sentiment of a journal entry. returns -1.0 to 1.0.
  Future<double> analyzeSentiment(String journalEntry) async {
    if (journalEntry.trim().isEmpty) return 0.0;
    await _ensureInitialized();
    
    final prompt = '''
You are a sentiment analyzer for a recovery tracking app. 
Analyze the following journal entry for its emotional tone and health outlook.
Return ONLY a single numerical value between -1.0 and 1.0.
-1.0 means extremely negative, discouraged, or in severe pain.
0.0 means neutral or clinical.
1.0 means extremely positive, encouraged, and recovering well.

Entry: "$journalEntry"

Your Response (ONLY THE NUMBER):
''';

    try {
      final response = await _normModel?.generateContent([Content.text(prompt)]);
      final raw = response?.text?.trim() ?? '0.0';
      return double.tryParse(raw) ?? 0.0;
    } catch (e) {
      debugPrint('[Sentiment Analysis] Failed: $e');
      return 0.0;
    }
  }

  /// Processes vocal input by sending the recorded audio natively to Gemini.
  Future<String> processVoiceInput(String filePath) async {
    await _ensureInitialized();
    final file = File(filePath);
    if (!await file.exists()) throw Exception('Audio file not found at $filePath');
    
    final bytes = await file.readAsBytes();
    
    // We send a multi-modal prompt to Gemini
    final promptPart = TextPart('The user has sent a voice message. Please listen to it and respond as the sympathetic Recover AI Health Guide.');
    final audioPart = DataPart('audio/mp4', Uint8List.fromList(bytes));

    try {
      final response = await _model!.generateContent([
        Content.multi([promptPart, audioPart])
      ]);
      return response.text ?? 'I heard the audio, but I could not formulate a response.';
    } catch (e) {
      debugPrint('[Voice AI Processing] Error: $e');
      throw Exception('Gemini failed to process your voice: $e');
    }
  }
}
