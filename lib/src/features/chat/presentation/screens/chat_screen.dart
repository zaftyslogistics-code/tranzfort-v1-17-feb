import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';
import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:record/record.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:uuid/uuid.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_typography.dart';
import '../../../../core/providers/auth_service_provider.dart';
import '../../../../core/models/message_model.dart';
import '../../../../shared/widgets/app_drawer.dart';
import '../../../../shared/widgets/voice_message_bubble.dart';

class ChatScreen extends ConsumerStatefulWidget {
  final String conversationId;

  const ChatScreen({super.key, required this.conversationId});

  @override
  ConsumerState<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends ConsumerState<ChatScreen> {
  final _messageController = TextEditingController();
  final _scrollController = ScrollController();
  final List<MessageModel> _messages = [];
  bool _isLoading = true;
  bool _hasText = false;
  RealtimeChannel? _channel;
  RealtimeChannel? _typingChannel;
  final _recorder = AudioRecorder();
  bool _isRecording = false;
  int _recordingSeconds = 0;
  bool _isTyping = false;
  String? _otherUserTypingName;
  Timer? _typingDebounceTimer;

  // WhatsApp UX state
  String? _otherPartyName;
  String? _otherPartyAvatar;
  bool _showScrollToBottom = false;
  int _newMessageCount = 0;

  @override
  void initState() {
    super.initState();
    _messageController.addListener(() {
      final has = _messageController.text.trim().isNotEmpty;
      if (has != _hasText) setState(() => _hasText = has);
      _handleTyping();
    });
    _scrollController.addListener(_onScroll);
    _loadConversationMeta();
    _loadMessages();
    _subscribeToMessages();
    _subscribeToTyping();
  }

  @override
  void dispose() {
    _messageController.dispose();
    _scrollController.dispose();
    _channel?.unsubscribe();
    _typingChannel?.unsubscribe();
    _recorder.dispose();
    _typingDebounceTimer?.cancel();
    super.dispose();
  }

  void _onScroll() {
    // Show scroll-to-bottom FAB when user scrolls up past 200px
    final show = _scrollController.hasClients &&
        _scrollController.offset > 200;
    if (show != _showScrollToBottom) {
      setState(() => _showScrollToBottom = show);
    }
  }

  void _scrollToBottom() {
    if (_scrollController.hasClients) {
      _scrollController.animateTo(
        0,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOut,
      );
    }
    setState(() {
      _showScrollToBottom = false;
      _newMessageCount = 0;
    });
  }

  Future<void> _loadConversationMeta() async {
    try {
      final db = ref.read(databaseServiceProvider);
      final conv = await db.getConversationById(widget.conversationId);
      if (conv == null || !mounted) return;

      final currentUserId = ref.read(authServiceProvider).currentUser?.id;
      final isSupplier = conv['supplier_id'] == currentUserId;

      // Fetch the other party's profile name
      final otherUserId = isSupplier
          ? conv['trucker_id'] as String?
          : conv['supplier_id'] as String?;

      if (otherUserId != null) {
        final profile = await db.getPublicProfile(otherUserId);
        if (profile != null && mounted) {
          setState(() {
            _otherPartyName = profile['full_name'] as String? ?? 'User';
            _otherPartyAvatar = profile['avatar_url'] as String?;
          });
        }
      }
    } catch (_) {}
  }

  void _handleTyping() {
    if (_messageController.text.trim().isNotEmpty && !_isTyping) {
      _isTyping = true;
      _sendTypingEvent(true);
    }

    _typingDebounceTimer?.cancel();
    _typingDebounceTimer = Timer(const Duration(seconds: 3), () {
      if (_isTyping) {
        _isTyping = false;
        _sendTypingEvent(false);
      }
    });
  }

  void _sendTypingEvent(bool isTyping) {
    // Reuse the subscribed typing channel to ensure broadcast reaches listeners
    _typingChannel?.sendBroadcastMessage(
      event: 'typing',
      payload: {
        'is_typing': isTyping,
        'user_id': ref.read(authServiceProvider).currentUser?.id,
      },
    );
  }

  void _subscribeToTyping() {
    final db = ref.read(databaseServiceProvider);
    _typingChannel = db.subscribeToTyping(widget.conversationId, (userId, isTyping) {
      final currentUserId = ref.read(authServiceProvider).currentUser?.id;
      if (userId != currentUserId && isTyping) {
        setState(() => _otherUserTypingName = _otherPartyName ?? 'Other user');
      } else if (userId != currentUserId && !isTyping) {
        setState(() => _otherUserTypingName = null);
      }
    });
  }

  Future<void> _loadMessages() async {
    try {
      final db = ref.read(databaseServiceProvider);
      final rawMessages = await db.getMessages(widget.conversationId);
      final messages = rawMessages.map((m) => MessageModel.fromJson(m)).toList();

      await _markConversationMessagesAsRead(messages);

      if (mounted) {
        setState(() {
          _messages.clear();
          _messages.addAll(messages);
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _subscribeToMessages() {
    final db = ref.read(databaseServiceProvider);
    _channel = db.subscribeToMessages(
      widget.conversationId,
      (newRecord) {
        final msg = MessageModel.fromJson(newRecord);
        final currentUserId = ref.read(authServiceProvider).currentUser?.id;

        if (msg.id != null && msg.senderId != currentUserId && !msg.isRead) {
          db.markAsRead(msg.id!);
        }

        // Skip if this message is already in the list (replaced from sendMessage response)
        if (_messages.any((m) => m.id != null && m.id == msg.id)) return;

        setState(() {
          _messages.add(msg);
          // Track new messages when scrolled up
          if (_showScrollToBottom && msg.senderId != currentUserId) {
            _newMessageCount++;
          }
        });
      },
    );
  }

  Future<void> _markConversationMessagesAsRead(
      [List<MessageModel>? source]) async {
    final currentUserId = ref.read(authServiceProvider).currentUser?.id;
    if (currentUserId == null) return;

    final messages = source ?? _messages;
    final hasUnread = messages
        .any((m) => m.id != null && m.senderId != currentUserId && !m.isRead);

    if (!hasUnread) return;

    // Single batch UPDATE instead of N individual calls
    final db = ref.read(databaseServiceProvider);
    await db.markAllAsRead(widget.conversationId, currentUserId);
  }

  Future<void> _sendMessage() async {
    final text = _messageController.text.trim();
    if (text.isEmpty) return;

    _messageController.clear();

    final userId = ref.read(authServiceProvider).currentUser!.id;
    final localId = const Uuid().v4();

    // Optimistic update — appears instantly
    final optimistic = MessageModel(
      localId: localId,
      conversationId: widget.conversationId,
      senderId: userId,
      messageType: 'text',
      textContent: text,
      createdAt: DateTime.now(),
      isOptimistic: true,
    );

    setState(() => _messages.add(optimistic));

    try {
      final db = ref.read(databaseServiceProvider);
      final serverRow = await db.sendMessage(
        conversationId: widget.conversationId,
        senderId: userId,
        type: 'text',
        text: text,
      );

      // Immediately replace optimistic with real server message
      if (mounted) {
        final real = MessageModel.fromJson(serverRow);
        setState(() {
          final idx = _messages.indexWhere((m) => m.localId == localId);
          if (idx != -1) {
            _messages[idx] = real;
          }
        });
      }
    } catch (e) {
      // Mark message as failed (show error icon + retry)
      if (mounted) {
        setState(() {
          final idx = _messages.indexWhere((m) => m.localId == localId);
          if (idx != -1) {
            _messages[idx] = optimistic.copyWith(
              isOptimistic: false,
              isFailed: true,
            );
          }
        });
      }
    }
  }

  Future<void> _retryMessage(MessageModel failed) async {
    final retryLocalId = const Uuid().v4();
    // Replace failed with optimistic
    setState(() {
      final idx = _messages.indexOf(failed);
      if (idx != -1) {
        _messages[idx] = failed.copyWith(
          localId: retryLocalId,
          isOptimistic: true,
          isFailed: false,
        );
      }
    });

    try {
      final db = ref.read(databaseServiceProvider);
      final serverRow = await db.sendMessage(
        conversationId: widget.conversationId,
        senderId: failed.senderId,
        type: failed.messageType,
        text: failed.textContent,
      );
      if (mounted) {
        final real = MessageModel.fromJson(serverRow);
        setState(() {
          final idx = _messages.indexWhere((m) => m.localId == retryLocalId);
          if (idx != -1) {
            _messages[idx] = real;
          }
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          final idx = _messages.indexWhere((m) => m.localId == retryLocalId);
          if (idx != -1) {
            _messages[idx] = _messages[idx].copyWith(
              isOptimistic: false,
              isFailed: true,
            );
          }
        });
      }
    }
  }

  Future<void> _startRecording() async {
    final status = await Permission.microphone.request();
    if (!status.isGranted) return;

    final dir = await getTemporaryDirectory();
    final path = '${dir.path}/voice_${DateTime.now().millisecondsSinceEpoch}.m4a';

    await _recorder.start(
      const RecordConfig(encoder: AudioEncoder.aacLc, bitRate: 64000),
      path: path,
    );

    setState(() {
      _isRecording = true;
      _recordingSeconds = 0;
    });

    // Timer to update seconds
    _tickRecording();
  }

  void _tickRecording() async {
    while (_isRecording && mounted) {
      await Future.delayed(const Duration(seconds: 1));
      if (_isRecording && mounted) {
        setState(() => _recordingSeconds++);
        if (_recordingSeconds >= 120) {
          _stopAndSendVoice();
          return;
        }
      }
    }
  }

  Future<void> _cancelRecording() async {
    await _recorder.stop();
    setState(() {
      _isRecording = false;
      _recordingSeconds = 0;
    });
  }

  Future<void> _stopAndSendVoice() async {
    final path = await _recorder.stop();
    final duration = _recordingSeconds;

    setState(() {
      _isRecording = false;
      _recordingSeconds = 0;
    });

    if (path == null || duration < 1) return;

    final userId = ref.read(authServiceProvider).currentUser!.id;
    final file = File(path);
    final msgId = const Uuid().v4();
    final storagePath = '${widget.conversationId}/$msgId.m4a';

    try {
      // Upload to Supabase Storage
      final supabase = Supabase.instance.client;
      await supabase.storage.from('voice-messages').upload(storagePath, file);
      final voiceUrl = await supabase.storage
          .from('voice-messages')
          .createSignedUrl(storagePath, 3600);

      // Send as voice message
      final db = ref.read(databaseServiceProvider);
      await db.sendMessage(
        conversationId: widget.conversationId,
        senderId: userId,
        type: 'voice',
        text: null,
        voiceUrl: voiceUrl,
        voiceDurationSeconds: duration,
      );
    } catch (_) {
      // Silently fail — voice upload errors are non-critical
    } finally {
      // Clean up temp file
      try { await file.delete(); } catch (_) {}
    }
  }

  // ─── QUICK ACTIONS ───

  void _showAttachmentSheet() {
    final role = ref.read(userRoleProvider).valueOrNull ?? 'trucker';
    final isTrucker = role == 'trucker';

    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 36,
                height: 4,
                margin: const EdgeInsets.only(bottom: 16),
                decoration: BoxDecoration(
                  color: AppColors.divider,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              Text('Quick Actions', style: AppTypography.h3Subsection),
              const SizedBox(height: 16),

              // ── Trucker-only actions ──
              if (isTrucker) ...[
                _AttachOption(
                  icon: Icons.local_shipping,
                  label: 'Send Truck Details',
                  color: AppColors.brandTeal,
                  onTap: () {
                    Navigator.pop(ctx);
                    _sendTruckCard();
                  },
                ),
                _AttachOption(
                  icon: Icons.price_change_outlined,
                  label: 'Quote My Rate',
                  color: AppColors.brandOrange,
                  onTap: () {
                    Navigator.pop(ctx);
                    _sendQuickAction('My rate for this load is ₹___. Let me know if that works.');
                  },
                ),
                _AttachOption(
                  icon: Icons.check_circle_outline,
                  label: 'Confirm Availability',
                  color: AppColors.success,
                  onTap: () {
                    Navigator.pop(ctx);
                    _sendQuickAction('I am available for this load. Please confirm booking.');
                  },
                ),
                _AttachOption(
                  icon: Icons.description_outlined,
                  label: 'Share RC',
                  color: AppColors.warning,
                  onTap: () {
                    Navigator.pop(ctx);
                    _shareRcDocument();
                  },
                ),
              ],

              // ── Supplier-only actions ──
              if (!isTrucker) ...[
                _AttachOption(
                  icon: Icons.request_page_outlined,
                  label: 'Request RC / Documents',
                  color: AppColors.info,
                  onTap: () {
                    Navigator.pop(ctx);
                    _sendQuickAction('Please share your RC book and vehicle documents.');
                  },
                ),
                _AttachOption(
                  icon: Icons.info_outline,
                  label: 'Ask Truck Details',
                  color: AppColors.warning,
                  onTap: () {
                    Navigator.pop(ctx);
                    _sendQuickAction('Can you share your truck details — body type, capacity, and tyres?');
                  },
                ),
                _AttachOption(
                  icon: Icons.price_change_outlined,
                  label: 'Share Load Rate',
                  color: AppColors.brandOrange,
                  onTap: () {
                    Navigator.pop(ctx);
                    _sendQuickAction('The rate for this load is ₹___. Are you interested?');
                  },
                ),
              ],

              // ── Common actions ──
              _AttachOption(
                icon: Icons.location_on_outlined,
                label: 'Send Location',
                color: AppColors.info,
                onTap: () {
                  Navigator.pop(ctx);
                  _sendLocation();
                },
              ),
              _AttachOption(
                icon: Icons.handshake_outlined,
                label: 'Accept Deal',
                color: AppColors.success,
                onTap: () {
                  Navigator.pop(ctx);
                  _sendQuickAction('Deal accepted! Let\'s proceed with booking.');
                },
              ),
              _AttachOption(
                icon: Icons.price_change_outlined,
                label: 'Negotiate Price',
                color: AppColors.brandTeal,
                onTap: () {
                  Navigator.pop(ctx);
                  _sendQuickAction('Can we discuss the price? What\'s your best rate?');
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _sendTruckCard() async {
    final userId = ref.read(authServiceProvider).currentUser!.id;
    final db = ref.read(databaseServiceProvider);

    try {
      final trucks = await db.getMyTrucks(userId);
      if (trucks.isEmpty) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('No trucks added yet. Add a truck first.')),
          );
        }
        return;
      }

      // If only one truck, send it directly; otherwise show picker
      if (trucks.length == 1) {
        await _sendTruckMessage(trucks.first);
      } else {
        if (!mounted) return;
        _showTruckPicker(trucks);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error loading trucks: $e')),
        );
      }
    }
  }

  void _showTruckPicker(List<Map<String, dynamic>> trucks) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Select Truck', style: AppTypography.h3Subsection),
              const SizedBox(height: 12),
              ...trucks.map((truck) => ListTile(
                leading: const Icon(Icons.local_shipping, color: AppColors.brandTeal),
                title: Text(truck['vehicle_number'] as String? ?? 'Truck'),
                subtitle: Text(
                  '${truck['body_type'] ?? '-'} • ${truck['tyres'] ?? '-'} tyres • ${truck['capacity_tonnes'] ?? '-'}T',
                ),
                onTap: () {
                  Navigator.pop(ctx);
                  _sendTruckMessage(truck);
                },
              )),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _sendTruckMessage(Map<String, dynamic> truck) async {
    final userId = ref.read(authServiceProvider).currentUser!.id;
    final db = ref.read(databaseServiceProvider);

    try {
      await db.sendMessage(
        conversationId: widget.conversationId,
        senderId: userId,
        type: 'truck_card',
        text: null,
        payload: {
          'vehicle_number': truck['vehicle_number'],
          'body_type': truck['body_type'],
          'tyres': truck['tyres'],
          'capacity_tonnes': truck['capacity_tonnes'],
        },
      );
    } catch (_) {}
  }

  Future<void> _sendQuickAction(String text) async {
    _messageController.text = text;
    _sendMessage();
  }

  Future<void> _sendLocation() async {
    try {
      // Check location permission
      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Location permission denied')),
            );
          }
          return;
        }
      }

      if (permission == LocationPermission.deniedForever) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Location permission permanently denied. Please enable in settings.')),
          );
        }
        return;
      }

      // Get current position
      final position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );

      final userId = ref.read(authServiceProvider).currentUser!.id;
      final db = ref.read(databaseServiceProvider);

      await db.sendMessage(
        conversationId: widget.conversationId,
        senderId: userId,
        type: 'location',
        text: null,
        payload: {
          'lat': position.latitude,
          'lng': position.longitude,
          'accuracy': position.accuracy,
        },
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error sending location: $e')),
        );
      }
    }
  }

  Future<void> _shareRcDocument() async {
    final userId = ref.read(authServiceProvider).currentUser!.id;
    final db = ref.read(databaseServiceProvider);

    try {
      // Get trucker's trucks
      final trucks = await db.getMyTrucks(userId);
      if (trucks.isEmpty) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('No trucks added yet. Add a truck first.')),
          );
        }
        return;
      }

      // Filter verified trucks with RC documents
      final verifiedTrucks = trucks.where((t) {
        final status = t['status'] as String?;
        final rcUrl = t['rc_photo_url'] as String?;
        return status == 'verified' && rcUrl != null && rcUrl.isNotEmpty;
      }).toList();

      if (verifiedTrucks.isEmpty) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('No verified trucks with RC documents found.')),
          );
        }
        return;
      }

      // If only one truck, share directly; otherwise show picker
      if (verifiedTrucks.length == 1) {
        await _sendRcMessage(verifiedTrucks.first);
      } else {
        if (!mounted) return;
        _showRcTruckPicker(verifiedTrucks);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error loading trucks: $e')),
        );
      }
    }
  }

  void _showRcTruckPicker(List<Map<String, dynamic>> trucks) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Select Truck to Share RC', style: AppTypography.h3Subsection),
              const SizedBox(height: 12),
              ...trucks.map((truck) => ListTile(
                leading: const Icon(Icons.description, color: AppColors.warning),
                title: Text(truck['vehicle_number'] as String? ?? 'Truck'),
                subtitle: Text(
                  '${truck['body_type'] ?? '-'} • ${truck['tyres'] ?? '-'} tyres',
                ),
                onTap: () {
                  Navigator.pop(ctx);
                  _sendRcMessage(truck);
                },
              )),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _sendRcMessage(Map<String, dynamic> truck) async {
    final rcPath = truck['rc_photo_url'] as String?;
    if (rcPath == null || rcPath.isEmpty) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('RC document not available for this truck.')),
        );
      }
      return;
    }

    final userId = ref.read(authServiceProvider).currentUser!.id;
    final db = ref.read(databaseServiceProvider);
    final storage = Supabase.instance.client.storage;

    try {
      // Generate signed URL for RC document
      final String signedUrl = await storage
          .from('truck-images')
          .createSignedUrl(rcPath, 3600); // 1 hour expiry

      // Send as document message
      await db.sendMessage(
        conversationId: widget.conversationId,
        senderId: userId,
        type: 'document',
        text: 'RC for ${truck['vehicle_number']}',
        payload: {
          'document_type': 'rc_book',
          'vehicle_number': truck['vehicle_number'],
          'body_type': truck['body_type'],
          'capacity_tonnes': truck['capacity_tonnes'],
          'file_name': 'RC_${truck['vehicle_number']}.jpg',
          'signed_url': signedUrl,
          'expires_at': DateTime.now().add(const Duration(hours: 1)).toIso8601String(),
        },
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('RC shared successfully')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error sharing RC: $e')),
        );
      }
    }
  }

  // ─── INPUT BAR WIDGET ───

  Widget _buildInputBar() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
      decoration: BoxDecoration(
        color: AppColors.cardBg,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 8,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: SafeArea(
        top: false,
        child: _isRecording ? _buildRecordingBar() : _buildNormalBar(),
      ),
    );
  }

  Widget _buildRecordingBar() {
    return Row(
      children: [
        GestureDetector(
          onTap: _cancelRecording,
          child: Container(
            width: 40,
            height: 40,
            decoration: const BoxDecoration(
              color: AppColors.errorLight,
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.close, color: AppColors.error, size: 20),
          ),
        ),
        const SizedBox(width: 12),
        const Icon(Icons.fiber_manual_record, color: AppColors.error, size: 12),
        const SizedBox(width: 6),
        Text(
          '${_recordingSeconds}s',
          style: AppTypography.bodyMedium.copyWith(
            color: AppColors.error,
            fontWeight: FontWeight.w600,
          ),
        ),
        const Spacer(),
        GestureDetector(
          onTap: _stopAndSendVoice,
          child: Container(
            width: 44,
            height: 44,
            decoration: const BoxDecoration(
              color: AppColors.brandTeal,
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.send, color: Colors.white, size: 20),
          ),
        ),
      ],
    );
  }

  Widget _buildNormalBar() {
    return Row(
      children: [
        // Attachment button
        GestureDetector(
          onTap: _showAttachmentSheet,
          child: Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: AppColors.brandTealLight,
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.add, color: AppColors.brandTeal, size: 22),
          ),
        ),
        const SizedBox(width: 8),
        // Text field
        Expanded(
          child: TextField(
            controller: _messageController,
            decoration: InputDecoration(
              hintText: 'Type a message...',
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(24),
                borderSide: BorderSide.none,
              ),
              filled: true,
              fillColor: AppColors.inputBg,
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 16,
                vertical: 10,
              ),
            ),
            maxLines: 4,
            minLines: 1,
            textInputAction: TextInputAction.send,
            onSubmitted: (_) => _sendMessage(),
          ),
        ),
        const SizedBox(width: 8),
        // Mic or Send button
        GestureDetector(
          onTap: _hasText ? _sendMessage : _startRecording,
          child: Container(
            width: 44,
            height: 44,
            decoration: const BoxDecoration(
              color: AppColors.brandTeal,
              shape: BoxShape.circle,
            ),
            child: Icon(
              _hasText ? Icons.send : Icons.mic,
              color: Colors.white,
              size: 20,
            ),
          ),
        ),
      ],
    );
  }

  // ─── DATE HEADER HELPERS ───

  String _dateLabelFor(DateTime dt) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final msgDay = DateTime(dt.year, dt.month, dt.day);
    final diff = today.difference(msgDay).inDays;
    if (diff == 0) return 'Today';
    if (diff == 1) return 'Yesterday';
    if (diff < 7) return DateFormat('EEEE').format(dt); // e.g. "Monday"
    return DateFormat('d MMM y').format(dt); // e.g. "15 Feb 2026"
  }

  bool _shouldShowDateHeader(int reversedIndex) {
    // reversedIndex is the visual index (0 = newest at bottom)
    final msgIndex = _messages.length - 1 - reversedIndex;
    if (msgIndex <= 0) return true; // first message always shows header
    final current = _messages[msgIndex];
    final previous = _messages[msgIndex - 1];
    if (current.createdAt == null || previous.createdAt == null) return false;
    final curDay = DateTime(current.createdAt!.year, current.createdAt!.month, current.createdAt!.day);
    final prevDay = DateTime(previous.createdAt!.year, previous.createdAt!.month, previous.createdAt!.day);
    return curDay != prevDay;
  }

  Widget _buildDateHeader(String label) {
    return Center(
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 12),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
        decoration: BoxDecoration(
          color: AppColors.cardBg,
          borderRadius: BorderRadius.circular(8),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.04),
              blurRadius: 2,
            ),
          ],
        ),
        child: Text(
          label,
          style: AppTypography.caption.copyWith(
            color: AppColors.textSecondary,
            fontWeight: FontWeight.w500,
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final userId = ref.read(authServiceProvider).currentUser?.id ?? '';

    return Scaffold(
      backgroundColor: AppColors.scaffoldBg,
      drawer: const AppDrawer(),
      appBar: AppBar(
        titleSpacing: 0,
        title: Row(
          children: [
            // Avatar
            CircleAvatar(
              radius: 18,
              backgroundColor: AppColors.brandTealLight,
              backgroundImage: _otherPartyAvatar != null
                  ? NetworkImage(_otherPartyAvatar!)
                  : null,
              child: _otherPartyAvatar == null
                  ? Text(
                      (_otherPartyName ?? 'U').isNotEmpty
                          ? (_otherPartyName ?? 'U')[0].toUpperCase()
                          : '?',
                      style: const TextStyle(
                        color: AppColors.brandTeal,
                        fontWeight: FontWeight.w700,
                        fontSize: 14,
                      ),
                    )
                  : null,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    _otherPartyName ?? 'Chat',
                    style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                    overflow: TextOverflow.ellipsis,
                  ),
                  if (_otherUserTypingName != null)
                    const Text(
                      'typing...',
                      style: TextStyle(
                        fontSize: 12,
                        color: AppColors.brandTeal,
                        fontWeight: FontWeight.w400,
                      ),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
      body: Stack(
        children: [
          Column(
            children: [
              // Messages
              Expanded(
                child: _isLoading
                    ? const Center(
                        child: CircularProgressIndicator(
                            color: AppColors.brandTeal),
                      )
                    : _messages.isEmpty
                        ? Center(
                            child: Text(
                              'Start the conversation!',
                              style: AppTypography.bodyMedium
                                  .copyWith(color: AppColors.textTertiary),
                            ),
                          )
                        : ListView.builder(
                            controller: _scrollController,
                            reverse: true,
                            physics: const BouncingScrollPhysics(),
                            padding: const EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 8,
                            ),
                            itemCount: _messages.length,
                            itemBuilder: (context, index) {
                              // Reversed list: newest at index 0
                              final msg = _messages[_messages.length - 1 - index];
                              final isMine = msg.senderId == userId;

                              final bubble = _MessageBubble(
                                key: ValueKey(msg.id ?? 'opt_$index'),
                                message: msg,
                                isMine: isMine,
                                onRetry: msg.isFailed
                                    ? () => _retryMessage(msg)
                                    : null,
                              );

                              // Date header (shown ABOVE the first message of each day)
                              if (_shouldShowDateHeader(index)) {
                                final label = _dateLabelFor(
                                    msg.createdAt ?? DateTime.now());
                                return Column(
                                  children: [
                                    bubble,
                                    _buildDateHeader(label),
                                  ],
                                );
                              }

                              return bubble;
                            },
                          ),
              ),

              // Input bar
              _buildInputBar(),
            ],
          ),

          // Scroll-to-bottom FAB
          if (_showScrollToBottom)
            Positioned(
              right: 16,
              bottom: 80,
              child: GestureDetector(
                onTap: _scrollToBottom,
                child: Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: AppColors.cardBg,
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.15),
                        blurRadius: 6,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      const Icon(Icons.keyboard_arrow_down,
                          color: AppColors.brandTeal, size: 24),
                      if (_newMessageCount > 0)
                        Positioned(
                          top: 2,
                          right: 2,
                          child: Container(
                            padding: const EdgeInsets.all(4),
                            decoration: const BoxDecoration(
                              color: AppColors.brandTeal,
                              shape: BoxShape.circle,
                            ),
                            child: Text(
                              '$_newMessageCount',
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 9,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _MessageBubble extends StatelessWidget {
  final MessageModel message;
  final bool isMine;
  final VoidCallback? onRetry;

  const _MessageBubble({
    super.key,
    required this.message,
    required this.isMine,
    this.onRetry,
  });

  @override
  Widget build(BuildContext context) {
    final isSystem = message.messageType == 'system';

    if (isSystem) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Center(
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: AppColors.infoLight,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(
              message.textContent ?? '',
              style: AppTypography.caption.copyWith(color: AppColors.info),
              textAlign: TextAlign.center,
            ),
          ),
        ),
      );
    }

    return Align(
      alignment: isMine ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.only(bottom: 6),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        constraints: BoxConstraints(
          maxWidth: MediaQuery.of(context).size.width * 0.75,
        ),
        decoration: BoxDecoration(
          color: isMine ? AppColors.brandTeal : AppColors.cardBg,
          borderRadius: BorderRadius.only(
            topLeft: const Radius.circular(16),
            topRight: const Radius.circular(16),
            bottomLeft: Radius.circular(isMine ? 16 : 4),
            bottomRight: Radius.circular(isMine ? 4 : 16),
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.04),
              blurRadius: 4,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            _buildContent(),
            const SizedBox(height: 4),
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  _formatTime(message.createdAt),
                  style: TextStyle(
                    fontSize: 11,
                    color: isMine
                        ? Colors.white.withValues(alpha: 0.70)
                        : AppColors.textTertiary,
                  ),
                ),
                // Message status indicators for sent messages
                if (isMine && !message.isOptimistic && !message.isFailed) ...[
                  const SizedBox(width: 4),
                  _buildStatusIcon(),
                ],
                if (message.isOptimistic) ...[
                  const SizedBox(width: 4),
                  SizedBox(
                    width: 12,
                    height: 12,
                    child: CircularProgressIndicator(
                      strokeWidth: 1.5,
                      color: isMine
                          ? Colors.white.withValues(alpha: 0.50)
                          : AppColors.textTertiary,
                    ),
                  ),
                ],
                if (message.isFailed) ...[
                  const SizedBox(width: 4),
                  GestureDetector(
                    onTap: onRetry,
                    child: const Icon(
                      Icons.error_outline,
                      size: 16,
                      color: AppColors.error,
                    ),
                  ),
                ],
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatusIcon() {
    // Single tick = delivered, Double blue tick = read (WhatsApp style)
    if (message.isRead) {
      return const Icon(
        Icons.done_all,
        size: 14,
        color: Color(0xFF53BDEB), // WhatsApp blue tick
      );
    } else {
      return Icon(
        Icons.done,
        size: 14,
        color: Colors.white.withValues(alpha: 0.60),
      );
    }
  }

  Widget _buildContent() {
    switch (message.messageType) {
      case 'truck_card':
        return _buildTruckCard();
      case 'location':
        return _buildLocation();
      case 'document':
        return _buildDocument();
      case 'voice':
        return VoiceMessageBubble(
          voiceUrl: message.voiceUrl ?? '',
          durationSeconds: message.voiceDurationSeconds ?? 0,
          isMine: isMine,
        );
      default:
        return Text(
          message.textContent ?? '',
          style: TextStyle(
            color: isMine ? Colors.white : AppColors.textPrimary,
            fontSize: 15,
          ),
        );
    }
  }

  Widget _buildTruckCard() {
    final payload = message.payload ?? {};
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: isMine
            ? Colors.white.withValues(alpha: 0.15)
            : AppColors.brandTealLight,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.local_shipping,
                  size: 16,
                  color: isMine ? Colors.white : AppColors.brandTeal),
              const SizedBox(width: 6),
              Text(
                payload['vehicle_number'] as String? ?? 'Truck',
                style: TextStyle(
                  fontWeight: FontWeight.w600,
                  color: isMine ? Colors.white : AppColors.textPrimary,
                ),
              ),
            ],
          ),
          if (payload['body_type'] != null) ...[
            const SizedBox(height: 4),
            Text(
              '${payload['body_type']} • ${payload['tyres'] ?? '-'} tyres',
              style: TextStyle(
                fontSize: 13,
                color: isMine
                    ? Colors.white.withValues(alpha: 0.80)
                    : AppColors.textSecondary,
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildLocation() {
    final payload = message.payload ?? {};
    final lat = payload['lat'];
    final lng = payload['lng'];

    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: isMine
            ? Colors.white.withValues(alpha: 0.15)
            : AppColors.infoLight,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.location_on,
              size: 18,
              color: isMine ? Colors.white : AppColors.info),
          const SizedBox(width: 6),
          Text(
            'Location shared',
            style: TextStyle(
              color: isMine ? Colors.white : AppColors.info,
              fontWeight: FontWeight.w500,
            ),
          ),
          if (lat != null && lng != null) ...[
            const SizedBox(width: 8),
            GestureDetector(
              onTap: () async {
                final uri = Uri.parse(
                  'https://www.google.com/maps/search/?api=1&query=$lat,$lng',
                );
                await launchUrl(uri, mode: LaunchMode.externalApplication);
              },
              child: Text(
                'Open',
                style: TextStyle(
                  color: isMine ? Colors.white : AppColors.info,
                  decoration: TextDecoration.underline,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildDocument() {
    final payload = message.payload ?? {};
    final signedUrl = payload['signed_url'] as String?;
    final fileName = payload['file_name'] as String? ?? 'Document';
    final vehicleNumber = payload['vehicle_number'] as String?;

    return GestureDetector(
      onTap: signedUrl != null
          ? () async {
              final uri = Uri.parse(signedUrl);
              await launchUrl(uri, mode: LaunchMode.externalApplication);
            }
          : null,
      child: Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: isMine
              ? Colors.white.withValues(alpha: 0.15)
              : AppColors.warningLight,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.description,
                size: 18,
                color: isMine ? Colors.white : AppColors.warning),
            const SizedBox(width: 6),
            Flexible(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    vehicleNumber != null ? 'RC: $vehicleNumber' : fileName,
                    style: TextStyle(
                      color: isMine ? Colors.white : AppColors.warning,
                      fontWeight: FontWeight.w500,
                      fontSize: 14,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                  if (signedUrl != null)
                    Text(
                      'Tap to view',
                      style: TextStyle(
                        color: isMine
                            ? Colors.white.withValues(alpha: 0.70)
                            : AppColors.textSecondary,
                        fontSize: 11,
                      ),
                    ),
                ],
              ),
            ),
            if (signedUrl != null) ...[
              const SizedBox(width: 8),
              Icon(
                Icons.open_in_new,
                size: 16,
                color: isMine ? Colors.white : AppColors.warning,
              ),
            ],
          ],
        ),
      ),
    );
  }

  String _formatTime(DateTime? dt) {
    if (dt == null) return '';
    final h = dt.hour.toString().padLeft(2, '0');
    final m = dt.minute.toString().padLeft(2, '0');
    return '$h:$m';
  }
}

class _AttachOption extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;

  const _AttachOption({
    required this.icon,
    required this.label,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: Container(
        width: 40,
        height: 40,
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.12),
          shape: BoxShape.circle,
        ),
        child: Icon(icon, color: color, size: 20),
      ),
      title: Text(label, style: AppTypography.bodyMedium),
      onTap: onTap,
    );
  }
}

class _TypingDots extends StatefulWidget {
  @override
  State<_TypingDots> createState() => _TypingDotsState();
}

class _TypingDotsState extends State<_TypingDots>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        return Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: List.generate(3, (index) {
            final delay = index * 0.3;
            final value = (_controller.value + delay) % 1.0;
            return Container(
              width: 4,
              height: 4,
              decoration: BoxDecoration(
                color: AppColors.textSecondary.withValues(
                  alpha: 0.3 + (value * 0.7),
                ),
                shape: BoxShape.circle,
              ),
            );
          }),
        );
      },
    );
  }
}
