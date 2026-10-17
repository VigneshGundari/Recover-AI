import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:recover_ai/core/theme/app_theme.dart';
import 'package:recover_ai/features/copilot/data/ai_service.dart';
import 'package:google_generative_ai/google_generative_ai.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:recover_ai/core/services/voice_service.dart';

class CopilotChatScreen extends ConsumerStatefulWidget {
  const CopilotChatScreen({super.key});

  @override
  ConsumerState<CopilotChatScreen> createState() => _CopilotChatScreenState();
}

class _CopilotChatScreenState extends ConsumerState<CopilotChatScreen> {
  final TextEditingController _msgCtrl = TextEditingController();
  final ScrollController _scrollCtrl = ScrollController();
  bool _isLoading = true;
  bool _isTyping = false;

  @override
  void initState() {
    super.initState();
    _initializeBrain();
    _initializeVoice();
  }

  Future<void> _initializeVoice() async {
    final voiceService = ref.read(voiceServiceProvider);
    await voiceService.initialize();
  }

  Future<void> _initializeBrain() async {
    final aiService = ref.read(copilotServiceProvider);
    if (!aiService.isInitialized) {
      await aiService.initializeWithIsarContext();
    }
    if (mounted) setState(() { _isLoading = false; });
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollCtrl.hasClients) {
        _scrollCtrl.animateTo(
          _scrollCtrl.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  Future<void> _toggleListening() async {
    final voiceService = ref.read(voiceServiceProvider);
    final aiService = ref.read(copilotServiceProvider);
    
    if (await voiceService.isRecording()) {
      final path = await voiceService.stopRecording();
      if (path != null) {
        setState(() { _isTyping = true; });
        try {
          final response = await aiService.processVoiceInput(path);
          // Synthesis for response
          await voiceService.speak(response);
          // Manually refresh state for history
          setState(() { _isTyping = false; });
        } catch (e) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Voice processing failed: $e')));
          }
          setState(() { _isTyping = false; });
        }
      }
      setState(() {});
      return;
    }

    final hasPerm = await voiceService.checkPermissions();
    if (!hasPerm) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Microphone permission required.')));
      }
      return;
    }

    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Recording...'), duration: Duration(milliseconds: 1000)));

    await voiceService.startRecording();
    if (mounted) setState(() {});
  }

  Future<void> _sendMessage() async {
    final text = _msgCtrl.text.trim();
    if (text.isEmpty) return;

    final aiService = ref.read(copilotServiceProvider);
    
    _msgCtrl.clear();
    setState(() { _isTyping = true; });
    _scrollToBottom();

    try {
      final response = await aiService.chatSession!.sendMessage(Content.text(text));
      // Voice synthesis for the response
      if (response.text != null && response.text!.isNotEmpty) {
        ref.read(voiceServiceProvider).speak(response.text!);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
      }
    } finally {
      if (mounted) setState(() { _isTyping = false; });
      _scrollToBottom();
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(
        backgroundColor: AppTheme.backgroundColor,
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              CircularProgressIndicator(color: AppTheme.primaryColor),
              SizedBox(height: 16),
              Text('Analyzing your offline logs...', style: TextStyle(color: AppTheme.textSecondary)),
            ],
          ),
        ),
      );
    }

    final aiService = ref.watch(copilotServiceProvider);
    final history = aiService.chatSession!.history.toList();

    return Scaffold(
      backgroundColor: AppTheme.backgroundColor,
      appBar: AppBar(
        title: const Text('AI Health Guide', style: TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: AppTheme.surfaceColor,
        elevation: 0,
        centerTitle: true,
      ),
      body: Column(
        children: [
          Expanded(
            child: history.isEmpty 
              ? _buildWelcomeMessage()
              : ListView.builder(
                  controller: _scrollCtrl,
                  padding: const EdgeInsets.all(16),
                  itemCount: history.length,
                  itemBuilder: (context, index) {
                    final message = history[index];
                    final isUser = message.role == 'user';
                    final part = message.parts.isNotEmpty ? message.parts.first : null;
                    final content = part is TextPart ? part.text : '';

                    return Align(
                      alignment: isUser ? Alignment.centerRight : Alignment.centerLeft,
                      child: Container(
                        margin: const EdgeInsets.symmetric(vertical: 8),
                        padding: const EdgeInsets.all(16),
                        constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.75),
                        decoration: BoxDecoration(
                          color: isUser ? AppTheme.primaryColor.withOpacity(0.9) : AppTheme.surfaceColor,
                          borderRadius: BorderRadius.only(
                            topLeft: const Radius.circular(20),
                            topRight: const Radius.circular(20),
                            bottomLeft: Radius.circular(isUser ? 20 : 0),
                            bottomRight: Radius.circular(isUser ? 0 : 20),
                          ),
                        ),
                        child: MarkdownBody(
                          data: content,
                          styleSheet: MarkdownStyleSheet(
                            p: TextStyle(color: isUser ? AppTheme.backgroundColor : Colors.white, fontSize: 16),
                            strong: TextStyle(color: isUser ? AppTheme.backgroundColor : AppTheme.primaryColor, fontWeight: FontWeight.bold),
                          ),
                        ),
                      ),
                    );
                  },
                ),
          ),
          if (_isTyping)
            const Padding(
              padding: EdgeInsets.all(16.0),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Text('Health Guide is thinking...', style: TextStyle(color: AppTheme.textSecondary, fontStyle: FontStyle.italic)),
              ),
            ),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: const BoxDecoration(
              color: AppTheme.surfaceColor,
              border: Border(top: BorderSide(color: Colors.white10)),
            ),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _msgCtrl,
                    decoration: InputDecoration(
                      hintText: 'Ask your health guide anything...',
                      hintStyle: const TextStyle(color: Colors.white24),
                      filled: true,
                      fillColor: AppTheme.backgroundColor,
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(24), borderSide: BorderSide.none),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
                    ),
                    onSubmitted: (_) => _sendMessage(),
                  ),
                ),
                const SizedBox(width: 12),
                ValueListenableBuilder<TextEditingValue>(
                  valueListenable: _msgCtrl,
                  builder: (context, value, child) {
                    final isEmpty = value.text.trim().isEmpty;
                    final voiceService = ref.watch(voiceServiceProvider);
                    
                    return FutureBuilder<bool>(
                      future: voiceService.isRecording(),
                      builder: (context, snapshot) {
                        final isRecording = snapshot.data ?? false;
                        
                        return CircleAvatar(
                          radius: 24,
                          backgroundColor: isRecording ? Colors.red : AppTheme.primaryColor,
                          child: IconButton(
                            icon: Icon(
                              isEmpty ? (isRecording ? Icons.stop_rounded : Icons.mic_rounded) : Icons.send_rounded, 
                              color: AppTheme.backgroundColor,
                            ),
                            onPressed: isEmpty ? _toggleListening : _sendMessage,
                          ),
                        );
                      },
                    );
                  },
                ),
              ],
            ),
          )
        ],
      ),
    );
  }

  Widget _buildWelcomeMessage() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: AppTheme.primaryColor.withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.auto_awesome_rounded, color: AppTheme.primaryColor, size: 40),
            ),
            const SizedBox(height: 24),
            const Text(
              'AI Health Guide',
              style: TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            const Text(
              'Hey there, this is your AI Health Companion. If you have any questions, you can ask me freely.',
              textAlign: TextAlign.center,
              style: TextStyle(color: AppTheme.textSecondary, fontSize: 16, height: 1.5),
            ),
          ],
        ),
      ),
    );
  }
}
