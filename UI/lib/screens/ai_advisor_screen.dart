// lib/screens/ai_advisor_screen.dart
// EcoRouteX – AI Advisor Chat (Enhanced with suggestion chips)

import 'package:flutter/material.dart';
import '../utils/app_theme.dart';
import '../models/mobility_model.dart';
import '../services/api_service.dart';

class AiAdvisorScreen extends StatefulWidget {
  const AiAdvisorScreen({super.key});

  @override
  State<AiAdvisorScreen> createState() => _AiAdvisorScreenState();
}

class _AiAdvisorScreenState extends State<AiAdvisorScreen>
    with SingleTickerProviderStateMixin {
  final _controller = TextEditingController();
  final _scrollCtrl = ScrollController();
  late final AnimationController _typingController;
  Future<void> _responseQueue = Future<void>.value();
  int _pendingResponses = 0;
  Map<String, String>? _lastRoute;

  final List<ChatMessage> _messages = [
    ChatMessage(
      text:
          "👋 Hi! I'm EcoRouteX AI, your smart mobility advisor.\n\nAsk me anything about travel options, best routes, eco-friendly choices, or how to save money on your daily commute!\n\nOr tap a suggestion below to get started 👇",
      isUser: false,
      time: DateTime.now(),
    ),
  ];

  static const _defaultSuggestions = [
    '🎓 Best way to college?',
    '🌧️ What to do in rain?',
    '💰 Cheapest option?',
    '🌱 Most eco-friendly?',
    '🚆 Train vs Car?',
    '🚲 Walk or cycle?',
    '⚡ Fastest route?',
    '🏙️ Beat city traffic?',
  ];

  List<String> _suggestions = List<String>.from(_defaultSuggestions);

  bool get _isTyping => _pendingResponses > 0;

  @override
  void initState() {
    super.initState();
    _typingController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    )..repeat();
  }

  void _sendMessage(String text) {
    if (text.trim().isEmpty) return;
    final message = text.trim();
    setState(() {
      _messages
          .add(ChatMessage(text: message, isUser: true, time: DateTime.now()));
      _pendingResponses++;
    });
    _controller.clear();
    _scrollToBottom();

    // Serialize replies so rapid messages cannot be displayed out of order.
    _responseQueue = _responseQueue.then((_) => _respondToMessage(message));
  }

  Future<void> _respondToMessage(String message) async {
    await Future.delayed(const Duration(milliseconds: 700));
    String response;
    List<String>? followUpChips;
    try {
      final result = await ApiService.askAdvisor(
        message: message,
        lastRoute: _lastRoute,
      );
      if (result['handled'] == true) {
        response = result['response'] as String;
        followUpChips = (result['follow_up_chips'] as List<dynamic>?)
            ?.map((chip) => chip.toString())
            .toList();
        if (result['origin'] is String && result['destination'] is String) {
          _lastRoute = {
            'origin': result['origin'] as String,
            'destination': result['destination'] as String,
          };
        }
      } else {
        response = AIChatAdvisor.respond(message);
      }
    } catch (_) {
      response = AIChatAdvisor.respond(message);
    }

    if (!mounted) return;
    setState(() {
      if (_pendingResponses > 0) _pendingResponses--;
      _messages.add(
          ChatMessage(text: response, isUser: false, time: DateTime.now()));
      if (followUpChips != null && followUpChips.isNotEmpty) {
        _suggestions = followUpChips;
      }
    });
    _scrollToBottom();
  }

  void _scrollToBottom() {
    Future.delayed(const Duration(milliseconds: 120), () {
      if (!mounted) return;
      if (_scrollCtrl.hasClients) {
        _scrollCtrl.animateTo(_scrollCtrl.position.maxScrollExtent,
            duration: const Duration(milliseconds: 300), curve: Curves.easeOut);
      }
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    _scrollCtrl.dispose();
    _typingController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            _buildHeader(),
            Expanded(child: _buildMessageList()),
            if (_isTyping) _buildTypingIndicator(),
            _buildSuggestionChips(),
            _buildInputBar(),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
      decoration: BoxDecoration(
        gradient: AppTheme.cardGradient,
        border: Border(
            bottom: BorderSide(color: AppTheme.textFaint.withOpacity(0.2))),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(9),
            decoration: BoxDecoration(
                gradient: AppTheme.greenGradient,
                borderRadius: BorderRadius.circular(13),
                boxShadow: AppTheme.greenGlow),
            child: const Text('🤖', style: TextStyle(fontSize: 18)),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('EcoRouteX AI',
                    style: Theme.of(context).textTheme.titleLarge),
                Row(
                  children: [
                    Container(
                        width: 6,
                        height: 6,
                        decoration: const BoxDecoration(
                            color: AppTheme.primaryGreen,
                            shape: BoxShape.circle)),
                    const SizedBox(width: 5),
                    const Text('Smart Mobility Advisor · Online',
                        style: TextStyle(
                            color: AppTheme.primaryGreen, fontSize: 11)),
                  ],
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
            decoration: BoxDecoration(
              color: AppTheme.primaryGreen.withOpacity(0.1),
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: AppTheme.primaryGreen.withOpacity(0.3)),
            ),
            child: const Text('AI Powered',
                style: TextStyle(
                    color: AppTheme.primaryGreen,
                    fontSize: 10,
                    fontWeight: FontWeight.w600)),
          ),
        ],
      ),
    );
  }

  Widget _buildMessageList() {
    return ListView.builder(
      controller: _scrollCtrl,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      itemCount: _messages.length,
      itemBuilder: (_, i) => _buildBubble(_messages[i]),
    );
  }

  Widget _buildBubble(ChatMessage msg) {
    final isUser = msg.isUser;
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        mainAxisAlignment:
            isUser ? MainAxisAlignment.end : MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          if (!isUser) ...[
            Container(
              width: 30,
              height: 30,
              decoration: BoxDecoration(
                  gradient: AppTheme.greenGradient,
                  borderRadius: BorderRadius.circular(9)),
              child: const Center(
                  child: Text('🤖', style: TextStyle(fontSize: 13))),
            ),
            const SizedBox(width: 7),
          ],
          Flexible(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
              decoration: BoxDecoration(
                gradient:
                    isUser ? AppTheme.greenGradient : AppTheme.cardGradient,
                borderRadius: BorderRadius.only(
                  topLeft: const Radius.circular(16),
                  topRight: const Radius.circular(16),
                  bottomLeft: Radius.circular(isUser ? 16 : 4),
                  bottomRight: Radius.circular(isUser ? 4 : 16),
                ),
                border: isUser
                    ? null
                    : Border.all(color: AppTheme.textFaint.withOpacity(0.2)),
                boxShadow: isUser ? AppTheme.greenGlow : AppTheme.cardShadow,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    msg.text,
                    style: TextStyle(
                      color: isUser ? AppTheme.primaryDark : AppTheme.textWhite,
                      fontSize: 13,
                      height: 1.5,
                      fontWeight: isUser ? FontWeight.w600 : FontWeight.w400,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    _formatTime(msg.time),
                    style: TextStyle(
                        color: isUser
                            ? AppTheme.primaryDark.withOpacity(0.7)
                            : AppTheme.textFaint,
                        fontSize: 9),
                  ),
                ],
              ),
            ),
          ),
          if (isUser) ...[
            const SizedBox(width: 7),
            Container(
              width: 30,
              height: 30,
              decoration: BoxDecoration(
                color: AppTheme.cardMid,
                borderRadius: BorderRadius.circular(9),
                border:
                    Border.all(color: AppTheme.primaryGreen.withOpacity(0.3)),
              ),
              child: const Center(
                  child: Text('👤', style: TextStyle(fontSize: 13))),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildTypingIndicator() {
    return Padding(
      padding: const EdgeInsets.only(left: 52, bottom: 6),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
            decoration: BoxDecoration(
              gradient: AppTheme.cardGradient,
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(16),
                topRight: Radius.circular(16),
                bottomRight: Radius.circular(16),
                bottomLeft: Radius.circular(4),
              ),
              border: Border.all(color: AppTheme.textFaint.withOpacity(0.2)),
            ),
            child: AnimatedBuilder(
              animation: _typingController,
              builder: (context, child) => Row(
                mainAxisSize: MainAxisSize.min,
                children: List.generate(3, (i) {
                  final phase = (_typingController.value + i / 3) % 1;
                  final scale = 0.65 + (0.35 * (1 - (phase - 0.5).abs() * 2));
                  return Transform.scale(
                    scale: scale,
                    child: Container(
                      margin: const EdgeInsets.symmetric(horizontal: 2),
                      width: 6,
                      height: 6,
                      decoration: const BoxDecoration(
                          color: AppTheme.primaryGreen, shape: BoxShape.circle),
                    ),
                  );
                }),
              ),
            ),
          ),
        ],
      ),
    );
  }

  String _formatTime(DateTime time) {
    final hour = time.hour % 12 == 0 ? 12 : time.hour % 12;
    final minute = time.minute.toString().padLeft(2, '0');
    final period = time.hour >= 12 ? 'PM' : 'AM';
    return '$hour:$minute $period';
  }

  Widget _buildSuggestionChips() {
    return Container(
      height: 38,
      margin: const EdgeInsets.only(bottom: 6),
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 14),
        itemCount: _suggestions.length,
        separatorBuilder: (_, __) => const SizedBox(width: 7),
        itemBuilder: (_, i) => GestureDetector(
          onTap: () => _sendMessage(_suggestions[i]),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
            decoration: BoxDecoration(
              color: AppTheme.cardDark,
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: AppTheme.primaryGreen.withOpacity(0.3)),
            ),
            child: Text(_suggestions[i],
                style: const TextStyle(
                    color: AppTheme.primaryGreen,
                    fontSize: 11,
                    fontWeight: FontWeight.w500)),
          ),
        ),
      ),
    );
  }

  Widget _buildInputBar() {
    return Container(
      padding: const EdgeInsets.fromLTRB(14, 8, 14, 14),
      decoration: BoxDecoration(
        color: AppTheme.cardDark,
        border:
            Border(top: BorderSide(color: AppTheme.textFaint.withOpacity(0.2))),
      ),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: _controller,
              style: const TextStyle(color: AppTheme.textWhite, fontSize: 13),
              decoration: InputDecoration(
                hintText: 'Ask about your travel options...',
                hintStyle:
                    const TextStyle(color: AppTheme.textFaint, fontSize: 12),
                filled: true,
                fillColor: AppTheme.mapDark,
                border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(22),
                    borderSide: BorderSide.none),
                focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(22),
                    borderSide: const BorderSide(
                        color: AppTheme.primaryGreen, width: 1.5)),
                contentPadding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 11),
              ),
              onSubmitted: _sendMessage,
            ),
          ),
          const SizedBox(width: 9),
          GestureDetector(
            onTap: () => _sendMessage(_controller.text),
            child: Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                  gradient: AppTheme.greenGradient,
                  borderRadius: BorderRadius.circular(22),
                  boxShadow: AppTheme.greenGlow),
              child: const Icon(Icons.send_rounded,
                  color: AppTheme.primaryDark, size: 18),
            ),
          ),
        ],
      ),
    );
  }
}
