import 'package:flutter/material.dart';
import '../api/chatbot_api.dart';

const _chatBlue = Color(0xFF2563EB);

class ChatOverlayShell extends StatefulWidget {
  const ChatOverlayShell({super.key, required this.child});

  final Widget child;

  @override
  State<ChatOverlayShell> createState() => _ChatOverlayShellState();
}

class _ChatOverlayShellState extends State<ChatOverlayShell> with SingleTickerProviderStateMixin {
  bool _chatOpen = false;
  bool _chatLoading = false;
  final List<_ChatMessage> _chatMessages = [];
  final TextEditingController _chatInputController = TextEditingController();
  final ScrollController _chatScrollController = ScrollController();
  late final AnimationController _chatController;
  late final Animation<double> _chatCurve;

  @override
  void initState() {
    super.initState();
    _chatController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 260),
      reverseDuration: const Duration(milliseconds: 180),
    );
    _chatCurve = CurvedAnimation(
      parent: _chatController,
      curve: Curves.easeOutCubic,
      reverseCurve: Curves.easeInCubic,
    );
    _chatMessages.add(
      _ChatMessage(
        text: 'Hi! Ask me about tours, rentals, or other things.',
        isUser: false,
        timestamp: DateTime.now(),
      ),
    );
  }

  @override
  void dispose() {
    _chatController.dispose();
    _chatInputController.dispose();
    _chatScrollController.dispose();
    super.dispose();
  }

  void _toggleChat() {
    setState(() => _chatOpen = !_chatOpen);
    if (_chatOpen) {
      _chatController.forward();
      _scrollChatToEnd(jump: true);
    } else {
      _chatController.reverse();
    }
  }

  void _scrollChatToEnd({bool jump = false}) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_chatScrollController.hasClients) return;
      final target = _chatScrollController.position.maxScrollExtent + 120;
      if (jump) {
        _chatScrollController.jumpTo(target);
      } else {
        _chatScrollController.animateTo(
          target,
          duration: const Duration(milliseconds: 220),
          curve: Curves.easeOut,
        );
      }
    });
  }

  Future<void> _sendChatMessage([String? text]) async {
    final question = (text ?? _chatInputController.text).trim();
    if (question.isEmpty || _chatLoading) return;

    setState(() {
      _chatMessages.add(_ChatMessage(
        text: question,
        isUser: true,
        timestamp: DateTime.now(),
      ));
      _chatLoading = true;
    });
    _chatInputController.clear();
    _scrollChatToEnd();

    try {
      final response = await ChatbotApi.ask(question);
      final answer = response.answer.trim().isEmpty ? 'I could not find an answer for that yet.' : response.answer;
      if (!mounted) return;
      setState(() {
        _chatMessages.add(_ChatMessage(
          text: answer,
          isUser: false,
          timestamp: DateTime.now(),
        ));
        _chatLoading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _chatMessages.add(_ChatMessage(
          text: 'Sorry, I am having trouble reaching the chatbot right now.',
          isUser: false,
          timestamp: DateTime.now(),
        ));
        _chatLoading = false;
      });
    }

    _scrollChatToEnd();
  }

  Widget _buildChatOverlay() {
    final size = MediaQuery.of(context).size;
    final panelWidth = size.width < 520 ? size.width - 32 : 360.0;
    final panelHeight = size.height < 720 ? size.height * 0.55 : 480.0;
    final panelBottom = 24.0;
    final panelRight = 24.0 + 56.0 + 12.0;

    return Align(
      alignment: Alignment.bottomRight,
      child: Padding(
        padding: EdgeInsets.only(right: panelRight, bottom: panelBottom),
        child: AnimatedBuilder(
          animation: _chatCurve,
          builder: (context, child) {
            final v = _chatCurve.value;
            return IgnorePointer(
              ignoring: v < 0.02,
              child: Opacity(
                opacity: v,
                child: Transform.translate(
                  offset: Offset(0, 18 * (1 - v)),
                  child: Transform.scale(
                    scale: 0.96 + 0.04 * v,
                    child: child,
                  ),
                ),
              ),
            );
          },
          child: ConstrainedBox(
            constraints: BoxConstraints(
              maxWidth: panelWidth,
              maxHeight: panelHeight,
            ),
            child: Material(
              elevation: 16,
              borderRadius: BorderRadius.circular(16),
              color: Colors.white,
              child: Column(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                    decoration: const BoxDecoration(
                      color: _chatBlue,
                      borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
                    ),
                    child: Row(
                      children: [
                        const CircleAvatar(
                          radius: 16,
                          backgroundColor: Colors.white,
                          child: Icon(Icons.smart_toy, color: _chatBlue, size: 18),
                        ),
                        const SizedBox(width: 10),
                        const Expanded(
                          child: Text(
                            'Your Travelista Buddy',
                            style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600),
                          ),
                        ),
                        if (_chatLoading)
                          const SizedBox(
                            width: 14,
                            height: 14,
                            child: CircularProgressIndicator(strokeWidth: 2, valueColor: AlwaysStoppedAnimation<Color>(Colors.white)),
                          ),
                        IconButton(
                          onPressed: _toggleChat,
                          icon: const Icon(Icons.close, color: Colors.white),
                          splashRadius: 18,
                        ),
                      ],
                    ),
                  ),
                  Expanded(
                    child: Container(
                      color: const Color(0xFFF8FAFC),
                      child: ListView.builder(
                        controller: _chatScrollController,
                        padding: const EdgeInsets.all(12),
                        itemCount: _chatMessages.length + (_chatLoading ? 1 : 0),
                        itemBuilder: (context, index) {
                          if (_chatLoading && index == _chatMessages.length) {
                            return _buildChatBubble(
                              text: 'Typing...',
                              isUser: false,
                              isTyping: true,
                            );
                          }
                          final msg = _chatMessages[index];
                          return _buildChatBubble(text: msg.text, isUser: msg.isUser);
                        },
                      ),
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
                    decoration: const BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.vertical(bottom: Radius.circular(16)),
                    ),
                    child: Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: _chatInputController,
                            onSubmitted: _sendChatMessage,
                            decoration: InputDecoration(
                              hintText: 'Ask a question...',
                              isDense: true,
                              contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        ElevatedButton(
                          onPressed: _chatLoading ? null : _sendChatMessage,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: _chatBlue,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          ),
                          child: const Icon(Icons.send, size: 18),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildChatBubble({
    required String text,
    required bool isUser,
    bool isTyping = false,
  }) {
    final bg = isUser ? const Color(0xFFDBEAFE) : Colors.white;
    final textColor = isUser ? const Color(0xFF1E3A5F) : const Color(0xFF111827);
    return Align(
      alignment: isUser ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 6),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        constraints: const BoxConstraints(maxWidth: 260),
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: isUser ? const Color(0xFFBFDBFE) : const Color(0xFFE5E7EB)),
        ),
        child: Text(
          text,
          style: TextStyle(color: textColor, fontSize: 13, fontStyle: isTyping ? FontStyle.italic : FontStyle.normal),
        ),
      ),
    );
  }

  Widget _buildChatFab() {
    return Align(
      alignment: Alignment.bottomRight,
      child: SafeArea(
        minimum: const EdgeInsets.all(24),
        child: FloatingActionButton(
          heroTag: 'chatFab',
          onPressed: _toggleChat,
          backgroundColor: _chatBlue,
          child: Icon(_chatOpen ? Icons.close : Icons.chat_bubble_outline, color: Colors.white),
          tooltip: _chatOpen ? 'Close chat' : 'Chat with us',
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        widget.child,
        _buildChatOverlay(),
        _buildChatFab(),
      ],
    );
  }
}

class _ChatMessage {
  _ChatMessage({
    required this.text,
    required this.isUser,
    required this.timestamp,
  });

  final String text;
  final bool isUser;
  final DateTime timestamp;
}
