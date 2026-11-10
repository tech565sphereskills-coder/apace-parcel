import 'dart:async';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../constants/app_colors.dart';
import '../services/api_client.dart';
import '../services/mock_state.dart';
import '../services/socket_service.dart';

class ChatMessage {
  final String id;
  final String text;
  final bool isFromMe;
  final DateTime timestamp;

  ChatMessage({
    required this.id,
    required this.text,
    required this.isFromMe,
    required this.timestamp,
  });
}

class RiderChatScreen extends StatefulWidget {
  final String riderName;
  final String vehicleDetails;
  final String orderId;
  final String riderPhone;

  const RiderChatScreen({
    super.key,
    required this.riderName,
    required this.vehicleDetails,
    required this.orderId,
    this.riderPhone = '+234 803 112 4490',
  });

  @override
  State<RiderChatScreen> createState() => _RiderChatScreenState();
}

class _RiderChatScreenState extends State<RiderChatScreen> {
  final _messageController = TextEditingController();
  final ScrollController _scrollController = ScrollController();

  final List<ChatMessage> _messages = [
    ChatMessage(
      id: 'm1',
      text: 'Good day boss! I have accepted your dispatch order. Currently heading towards your pickup location.',
      isFromMe: false,
      timestamp: DateTime.now().subtract(const Duration(minutes: 6)),
    ),
  ];

  final List<String> _quickChips = [
    "I'm outside by the black gate",
    "Call me when you reach the junction",
    "Leave package with estate security",
    "Traffic on Third Mainland Bridge?",
    "Please handle with care (Fragile)",
  ];

  bool _isRiderTyping = false;

  @override
  void initState() {
    super.initState();
    _initLiveChat();
  }

  Future<void> _initLiveChat() async {
    if (!AppState.instance.isAuthenticated) return;
    SocketService.instance.joinOrder(widget.orderId);
    SocketService.instance.onChatMessage((data) {
      if (!mounted) return;
      final senderId = data['senderId']?.toString();
      if (senderId == AppState.instance.userId) return;
      setState(() {
        _messages.add(
          ChatMessage(
            id: data['id']?.toString() ?? 'ws-${DateTime.now().millisecondsSinceEpoch}',
            text: data['message']?.toString() ?? '',
            isFromMe: false,
            timestamp: DateTime.tryParse(data['createdAt']?.toString() ?? '') ?? DateTime.now(),
          ),
        );
      });
      _scrollToBottom();
    });

    try {
      final res = await ApiClient.instance.dio.get('/orders/${widget.orderId}/chat');
      if (res.data is List && (res.data as List).isNotEmpty && mounted) {
        setState(() {
          _messages.clear();
          for (final item in res.data) {
            if (item is Map) {
              _messages.add(
                ChatMessage(
                  id: item['id']?.toString() ?? '',
                  text: item['message']?.toString() ?? '',
                  isFromMe: item['senderId']?.toString() == AppState.instance.userId,
                  timestamp: DateTime.tryParse(item['createdAt']?.toString() ?? '') ?? DateTime.now(),
                ),
              );
            }
          }
        });
        _scrollToBottom();
      }
    } catch (_) {}
  }

  @override
  void dispose() {
    _messageController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 250),
          curve: Curves.easeOut,
        );
      }
    });
  }

  Future<void> _sendMessage(String text) async {
    if (text.trim().isEmpty) return;
    final cleanText = text.trim();

    final userMsg = ChatMessage(
      id: 'msg-${DateTime.now().millisecondsSinceEpoch}',
      text: cleanText,
      isFromMe: true,
      timestamp: DateTime.now(),
    );

    setState(() {
      _messages.add(userMsg);
      _messageController.clear();
      _isRiderTyping = !AppState.instance.isAuthenticated;
    });

    _scrollToBottom();

    if (AppState.instance.isAuthenticated) {
      try {
        await ApiClient.instance.dio.post(
          '/orders/${widget.orderId}/chat',
          data: {'message': cleanText},
        );
        SocketService.instance.sendOrderChatMessage(widget.orderId, cleanText);
        return;
      } catch (_) {}
    }

    Timer(const Duration(milliseconds: 1400), () {
      if (!mounted) return;

      String reply = 'Alright boss, noted! On my way now.';
      if (cleanText.contains('gate') || cleanText.contains('outside')) {
        reply = 'Okay sir, I can see the landmark now. Turning into the close.';
      } else if (cleanText.contains('security')) {
        reply = 'Understood. I will hand over to the gate security and call you with OTP.';
      } else if (cleanText.contains('Traffic')) {
        reply = 'Traffic is moving slowly near Obalende, but I am beating it with the bike!';
      } else if (cleanText.contains('Fragile')) {
        reply = 'No problem sir, the box is properly padded inside my dispatch cargo trunk.';
      }

      setState(() {
        _isRiderTyping = false;
        _messages.add(
          ChatMessage(
            id: 'msg-${DateTime.now().millisecondsSinceEpoch}',
            text: reply,
            isFromMe: false,
            timestamp: DateTime.now(),
          ),
        );
      });

      _scrollToBottom();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF1F5F9),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0.5,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, color: AppColors.textDark, size: 20),
          onPressed: () => Navigator.pop(context),
        ),
        titleSpacing: 0,
        title: Row(
          children: [
            Stack(
              alignment: Alignment.bottomRight,
              children: [
                CircleAvatar(
                  radius: 20,
                  backgroundColor: AppColors.primaryOrangeLight,
                  child: const Text('BA', style: TextStyle(fontWeight: FontWeight.w800, color: AppColors.primaryOrange, fontSize: 13)),
                ),
                Container(
                  width: 10,
                  height: 10,
                  decoration: BoxDecoration(
                    color: const Color(0xFF10B981),
                    shape: BoxShape.circle,
                    border: Border.all(color: Colors.white, width: 2),
                  ),
                ),
              ],
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    widget.riderName,
                    style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: AppColors.textDark),
                  ),
                  Text(
                    '${widget.vehicleDetails} • Order #${widget.orderId}',
                    style: const TextStyle(fontSize: 11, color: AppColors.textSecondary),
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.phone_in_talk_rounded, color: AppColors.primaryOrange, size: 22),
            onPressed: () async {
              final messenger = ScaffoldMessenger.of(context);
              final clean = widget.riderPhone.replaceAll(' ', '');
              final uri = Uri(scheme: 'tel', path: clean);
              if (await canLaunchUrl(uri)) {
                await launchUrl(uri);
              } else {
                messenger.showSnackBar(
                  SnackBar(
                    content: Text('Rider ${widget.riderName}: ${widget.riderPhone}'),
                    backgroundColor: AppColors.primaryOrange,
                    behavior: SnackBarBehavior.floating,
                  ),
                );
              }
            },
          ),
          const SizedBox(width: 4),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: ListView.builder(
                controller: _scrollController,
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                itemCount: _messages.length,
                itemBuilder: (context, index) {
                  final msg = _messages[index];
                  return _buildMessageBubble(msg);
                },
              ),
            ),

            if (_isRiderTyping)
              Padding(
                padding: const EdgeInsets.only(left: 20, bottom: 8),
                child: Row(
                  children: [
                    Text(
                      '${widget.riderName} is typing...',
                      style: const TextStyle(fontSize: 11, fontStyle: FontStyle.italic, color: Color(0xFF64748B)),
                    ),
                    const SizedBox(width: 6),
                    const SizedBox(
                      width: 10,
                      height: 10,
                      child: CircularProgressIndicator(strokeWidth: 1.5, color: AppColors.primaryOrange),
                    ),
                  ],
                ),
              ),

            Container(
              height: 38,
              margin: const EdgeInsets.only(bottom: 6),
              child: ListView.separated(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                scrollDirection: Axis.horizontal,
                itemCount: _quickChips.length,
                separatorBuilder: (context, index) => const SizedBox(width: 8),
                itemBuilder: (context, index) {
                  final chip = _quickChips[index];
                  return ActionChip(
                    backgroundColor: Colors.white,
                    side: const BorderSide(color: Color(0xFFE2E8F0)),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
                    label: Text(chip, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: AppColors.textDark)),
                    onPressed: () => _sendMessage(chip),
                  );
                },
              ),
            ),

            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: const BoxDecoration(
                color: Colors.white,
                border: Border(top: BorderSide(color: Color(0xFFE2E8F0))),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _messageController,
                      textCapitalization: TextCapitalization.sentences,
                      decoration: InputDecoration(
                        hintText: 'Type a message to rider...',
                        hintStyle: const TextStyle(fontSize: 13, color: Color(0xFF94A3B8)),
                        fillColor: const Color(0xFFF8FAFC),
                        filled: true,
                        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(24), borderSide: const BorderSide(color: Color(0xFFE2E8F0))),
                        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(24), borderSide: const BorderSide(color: Color(0xFFE2E8F0))),
                        focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(24), borderSide: const BorderSide(color: AppColors.primaryOrange, width: 1.5)),
                      ),
                      onSubmitted: _sendMessage,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Container(
                    decoration: const BoxDecoration(
                      color: AppColors.primaryOrange,
                      shape: BoxShape.circle,
                    ),
                    child: IconButton(
                      icon: const Icon(Icons.send_rounded, color: Colors.white, size: 20),
                      onPressed: () => _sendMessage(_messageController.text),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMessageBubble(ChatMessage msg) {
    return Align(
      alignment: msg.isFromMe ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.76),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: msg.isFromMe ? AppColors.primaryOrange : Colors.white,
          borderRadius: BorderRadius.only(
            topLeft: const Radius.circular(16),
            topRight: const Radius.circular(16),
            bottomLeft: Radius.circular(msg.isFromMe ? 16 : 4),
            bottomRight: Radius.circular(msg.isFromMe ? 4 : 16),
          ),
          boxShadow: const [
            BoxShadow(color: Color(0x06000000), blurRadius: 4, offset: Offset(0, 2)),
          ],
        ),
        child: Column(
          crossAxisAlignment: msg.isFromMe ? CrossAxisAlignment.end : CrossAxisAlignment.start,
          children: [
            Text(
              msg.text,
              style: TextStyle(
                fontSize: 13.5,
                fontWeight: FontWeight.w500,
                color: msg.isFromMe ? Colors.white : AppColors.textDark,
                height: 1.35,
              ),
            ),
            const SizedBox(height: 4),
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  '${msg.timestamp.hour.toString().padLeft(2, '0')}:${msg.timestamp.minute.toString().padLeft(2, '0')}',
                  style: TextStyle(
                    fontSize: 10,
                    color: msg.isFromMe ? Colors.white.withValues(alpha: 0.8) : const Color(0xFF94A3B8),
                  ),
                ),
                if (msg.isFromMe) ...[
                  const SizedBox(width: 4),
                  const Icon(Icons.done_all_rounded, size: 12, color: Colors.white),
                ],
              ],
            ),
          ],
        ),
      ),
    );
  }
}
