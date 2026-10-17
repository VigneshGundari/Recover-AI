import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:record/record.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;

final voiceServiceProvider = Provider<VoiceService>((ref) => VoiceService());

class VoiceService {
  final AudioRecorder _recorder = AudioRecorder();
  final FlutterTts _tts = FlutterTts();
  
  bool _isTtsInitialized = false;

  Future<void> initialize() async {
    if (!_isTtsInitialized) {
      await _tts.setLanguage("en-US");
      
      // Quick fix to find a female voice
      try {
        final voices = await _tts.getVoices;
        for (var voice in voices) {
          final name = voice["name"].toString().toLowerCase();
          if (name.contains("female") || name.contains("zira") || name.contains("aria")) {
            await _tts.setVoice({"name": voice["name"], "locale": voice["locale"]});
            break;
          }
        }
      } catch (e) {
        debugPrint('Voice selection error: $e');
      }

      await _tts.setPitch(1.0);
      await _tts.setSpeechRate(0.5); // Calm, professional clinical rate
      _isTtsInitialized = true;
    }
  }

  Future<bool> checkPermissions() async {
    final status = await Permission.microphone.status;
    if (status.isGranted) return true;
    
    final result = await Permission.microphone.request();
    return result.isGranted;
  }

  Future<void> startRecording() async {
    if (await _recorder.hasPermission()) {
      final appDir = await getTemporaryDirectory();
      final path = p.join(appDir.path, 'speech.m4a');
      
      const config = RecordConfig(
        encoder: AudioEncoder.aacLc,
        bitRate: 128000,
        sampleRate: 44100,
      );

      await _recorder.start(config, path: path);
    }
  }

  Future<String?> stopRecording() async {
    return await _recorder.stop();
  }

  Future<void> speak(String text) async {
    if (!_isTtsInitialized) await initialize();
    await _tts.speak(text);
  }

  Future<void> stopSpeaking() async {
    await _tts.stop();
  }

  Future<bool> isRecording() async {
    return await _recorder.isRecording();
  }

  void dispose() {
    _recorder.dispose();
  }
}
