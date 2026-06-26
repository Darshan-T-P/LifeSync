import 'package:flutter/material.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;
import '../supabase/client.dart';
import '../theme/app_theme.dart';

class ChatScreen extends StatefulWidget {
  const ChatScreen({super.key});

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final _messages = <ChatMessage>[];
  final _ctrl = TextEditingController();
  final _scrollCtrl = ScrollController();
  bool _loading = false;

  @override
  void initState() {
    super.initState();
    _messages.add(ChatMessage(
      text: "Hey Darshan! I'm Dash, your AI assistant. Ask me about your tasks, spending, goals, or tell me what to create.",
      isAi: true,
    ));
  }

  @override
  void dispose() {
    _ctrl.dispose();
    _scrollCtrl.dispose();
    super.dispose();
  }

  Future<void> _send() async {
    final text = _ctrl.text.trim();
    if (text.isEmpty) return;
    _ctrl.clear();

    setState(() {
      _messages.add(ChatMessage(text: text, isAi: false));
      _loading = true;
    });
    _scrollDown();

    try {
      final userId = SupabaseService.instance.client.auth.currentUser?.id;
      final accessToken = SupabaseService.instance.client.auth.currentSession?.accessToken;
      if (userId == null || accessToken == null) {
        setState(() {
          _messages.add(ChatMessage(text: 'Not signed in. Please restart the app.', isAi: true));
          _loading = false;
        });
        return;
      }
      const functionsUrl = 'https://vhqajppzdilserxxsxgp.supabase.co/functions/v1/assistant';

      final res = await http.post(
        Uri.parse(functionsUrl),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $accessToken',
        },
        body: jsonEncode({'message': text, 'userId': userId}),
      );

      if (res.statusCode == 200) {
        final data = jsonDecode(res.body) as Map<String, dynamic>;
        final reply = data['reply'] as String? ?? '';
        final actions = data['actions'] as List<dynamic>? ?? [];

        String fullReply = reply;
        if (actions.isNotEmpty) {
          fullReply += '\n\n✅ ${actions.join('\n✅ ')}';
        }

        setState(() {
          _messages.add(ChatMessage(text: fullReply, isAi: true));
          _loading = false;
        });
      } else {
        setState(() {
          _messages.add(ChatMessage(
            text: 'Error: ${res.statusCode}. Make sure the Edge Function is deployed.',
            isAi: true,
          ));
          _loading = false;
        });
      }
    } catch (e) {
      setState(() {
        _messages.add(ChatMessage(
          text: 'Connection error: $e',
          isAi: true,
        ));
        _loading = false;
      });
    }
    _scrollDown();
  }

  void _scrollDown() {
    Future.delayed(const Duration(milliseconds: 100), () {
      if (_scrollCtrl.hasClients) {
        _scrollCtrl.animateTo(_scrollCtrl.position.maxScrollExtent,
            duration: const Duration(milliseconds: 200), curve: Curves.easeOut);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.neutral,
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            // Header
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
              child: Row(
                children: [
                  Container(
                    width: 32, height: 32,
                    decoration: BoxDecoration(
                      color: AppTheme.highlight.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Icon(Icons.auto_awesome, size: 16, color: AppTheme.highlight),
                  ),
                  const SizedBox(width: 10),
                  const Text('AI Assistant', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600)),
                ],
              ),
            ),

            // Message list
            Expanded(
              child: ListView.builder(
                controller: _scrollCtrl,
                padding: const EdgeInsets.symmetric(horizontal: 16),
                itemCount: _messages.length,
                itemBuilder: (_, i) {
                  final msg = _messages[i];
                  return _MessageBubble(message: msg);
                },
              ),
            ),

            if (_loading)
              const Padding(
                padding: EdgeInsets.only(bottom: 4),
                child: SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2)),
              ),

            // Input bar
            Container(
              padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
              decoration: BoxDecoration(
                color: Colors.white,
                border: Border(top: BorderSide(color: Colors.grey[100]!)),
              ),
              child: SafeArea(
                top: false,
                child: Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _ctrl,
                        textInputAction: TextInputAction.send,
                        onSubmitted: (_) => _send(),
                        decoration: InputDecoration(
                          hintText: 'Ask Dash...',
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(24),
                            borderSide: BorderSide(color: Colors.grey[200]!),
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(24),
                            borderSide: BorderSide(color: Colors.grey[200]!),
                          ),
                          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                          isDense: true,
                          filled: true,
                          fillColor: Colors.grey[50],
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    GestureDetector(
                      onTap: _send,
                      child: Container(
                        width: 40, height: 40,
                        decoration: BoxDecoration(
                          color: AppTheme.primary,
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: const Icon(Icons.arrow_upward, color: Colors.white, size: 18),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class ChatMessage {
  final String text;
  final bool isAi;
  ChatMessage({required this.text, required this.isAi});
}

class _MessageBubble extends StatelessWidget {
  final ChatMessage message;
  const _MessageBubble({required this.message});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: message.isAi ? MainAxisAlignment.start : MainAxisAlignment.end,
        children: [
          if (message.isAi) ...[
            Container(
              width: 28, height: 28,
              decoration: BoxDecoration(
                color: AppTheme.highlight.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(Icons.auto_awesome, size: 14, color: AppTheme.highlight),
            ),
            const SizedBox(width: 8),
            Flexible(
              child: Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.grey[100]!),
                ),
                child: Text(message.text, style: const TextStyle(fontSize: 13, height: 1.4)),
              ),
            ),
          ] else ...[
            Flexible(
              child: Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppTheme.primary,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(message.text,
                  style: const TextStyle(fontSize: 13, color: Colors.white, height: 1.4)),
              ),
            ),
            const SizedBox(width: 8),
          ],
        ],
      ),
    );
  }
}
