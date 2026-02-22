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
import '../../../../shared/widgets/map_message_card.dart';
import '../../../../shared/widgets/voice_message_bubble.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:tranzfort/l10n/app_localizations.dart';

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
  // TECH-3: Pagination
  static const _pageSize = 50;
  int _messageOffset = 0;
  bool _hasMoreMessages = true;
  bool _isLoadingMore = false;

  // WhatsApp UX state
  String? _otherPartyName;
  String? _otherPartyAvatar;
  bool _showScrollToBottom = false;
  int _newMessageCount = 0;
  Map<String, dynamic>? _loadInfo; // CHAT-B: linked load context

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
    _startConnectivityWatch();
  }

  @override
  void dispose() {
    _messageController.dispose();
    _scrollController.dispose();
    _channel?.unsubscribe();
    _typingChannel?.unsubscribe();
    _recorder.dispose();
    _typingDebounceTimer?.cancel();
    _connectivitySub?.cancel();
    super.dispose();
  }

  void _onScroll() {
    // Show scroll-to-bottom FAB when user scrolls up past 200px
    final show = _scrollController.hasClients &&
        _scrollController.offset > 200;
    if (show != _showScrollToBottom) {
      setState(() => _showScrollToBottom = show);
    }
    // TECH-3: Load more messages when near top
    if (_scrollController.hasClients &&
        _scrollController.position.pixels >=
            _scrollController.position.maxScrollExtent - 100) {
      _loadMoreMessages();
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

      // CHAT-B: Fetch linked load for context banner
      final loadId = conv['load_id'] as String?;
      if (loadId != null) {
        final load = await db.getLoadById(loadId);
        if (load != null && mounted) {
          setState(() => _loadInfo = load);
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
    _typingDebounceTimer = Timer(const Duration(seconds: 5), () {
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
      final rawMessages = await db.getMessages(
        widget.conversationId,
        limit: _pageSize,
        offset: 0,
      );
      final messages = rawMessages.map((m) => MessageModel.fromJson(m)).toList();

      await _markConversationMessagesAsRead(messages);

      if (mounted) {
        setState(() {
          _messages.clear();
          _messages.addAll(messages);
          _messageOffset = messages.length;
          _hasMoreMessages = messages.length >= _pageSize;
          _isLoading = false;
        });
        
        // V4-017: Auto-send map_card if load is linked and not yet sent
        _checkAndAutoSendMapCard();
      }
    } catch (e) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  // V4-017: Auto-send map_card if load is linked and not yet sent
  Future<void> _checkAndAutoSendMapCard() async {
    final userId = ref.read(authServiceProvider).currentUser?.id;
    if (userId == null || _loadInfo == null) return;
    
    // Only supplier should auto-send the map card
    if (_loadInfo!['supplier_id'] != userId) return;

    // Check if map_card is already in the messages
    final hasMapCard = _messages.any((m) => m.messageType == 'map_card');
    if (hasMapCard) return;

    // Send it
    final db = ref.read(databaseServiceProvider);
    try {
      await db.sendMessage(
        conversationId: widget.conversationId,
        senderId: userId,
        type: 'map_card',
        text: null,
        payload: {
          'load_id': _loadInfo!['id'],
          'origin_city': _loadInfo!['origin_city'],
          'dest_city': _loadInfo!['dest_city'],
          'origin_lat': _loadInfo!['origin_lat'],
          'origin_lng': _loadInfo!['origin_lng'],
          'dest_lat': _loadInfo!['dest_lat'],
          'dest_lng': _loadInfo!['dest_lng'],
          'distance_km': _loadInfo!['distance_km'],
          'duration_min': _loadInfo!['duration_min'],
          'diesel_cost': _loadInfo!['diesel_cost'],
          'toll_cost': _loadInfo!['toll_cost'],
          'total_cost': _loadInfo!['total_cost'],
          'material': _loadInfo!['material'],
          'weight_tonnes': _loadInfo!['weight_tonnes'],
        },
      );
    } catch (_) {}
  }

  // TECH-3: Load older messages when scrolling to top
  Future<void> _loadMoreMessages() async {
    if (_isLoadingMore || !_hasMoreMessages) return;
    _isLoadingMore = true;

    try {
      final db = ref.read(databaseServiceProvider);
      final rawMessages = await db.getMessages(
        widget.conversationId,
        limit: _pageSize,
        offset: _messageOffset,
      );
      final older = rawMessages.map((m) => MessageModel.fromJson(m)).toList();

      if (mounted) {
        setState(() {
          _messages.insertAll(0, older);
          _messageOffset += older.length;
          _hasMoreMessages = older.length >= _pageSize;
        });
      }
    } catch (_) {}
    _isLoadingMore = false;
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

  // CHAT-H: Offline queue — pending messages to retry when online
  final List<MessageModel> _offlineQueue = [];
  StreamSubscription<List<ConnectivityResult>>? _connectivitySub;

  void _startConnectivityWatch() {
    _connectivitySub = Connectivity().onConnectivityChanged.listen((results) {
      final isOnline = results.any((r) => r != ConnectivityResult.none);
      if (isOnline && _offlineQueue.isNotEmpty) {
        _flushOfflineQueue();
      }
    });
  }

  Future<void> _flushOfflineQueue() async {
    final queue = List<MessageModel>.from(_offlineQueue);
    _offlineQueue.clear();
    for (final msg in queue) {
      if (msg.textContent != null) {
        _messageController.text = msg.textContent!;
        await _sendMessage();
      }
    }
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

    // CHAT-H: Check connectivity before sending
    final connectivity = await Connectivity().checkConnectivity();
    final isOffline = connectivity.every((r) => r == ConnectivityResult.none);
    if (isOffline) {
      _offlineQueue.add(optimistic);
      if (mounted) {
        setState(() {
          final idx = _messages.indexWhere((m) => m.localId == localId);
          if (idx != -1) {
            _messages[idx] = optimistic.copyWith(isOptimistic: true);
          }
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(AppLocalizations.of(context)?.offlineQueue ??
                'Messages will be sent when you\'re back online'),
            duration: const Duration(seconds: 2),
          ),
        );
      }
      return;
    }

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
    final localId = const Uuid().v4();
    final storagePath = '${widget.conversationId}/$localId.m4a';

    // CHAT-F: Optimistic voice message
    final optimistic = MessageModel(
      localId: localId,
      conversationId: widget.conversationId,
      senderId: userId,
      messageType: 'voice',
      voiceDurationSeconds: duration,
      createdAt: DateTime.now(),
      isOptimistic: true,
    );
    setState(() => _messages.insert(0, optimistic));

    try {
      final supabase = Supabase.instance.client;
      await supabase.storage.from('voice-messages').upload(storagePath, file);
      // CHAT-G: Use 24h signed URL instead of 1h
      final voiceUrl = await supabase.storage
          .from('voice-messages')
          .createSignedUrl(storagePath, 86400);

      final db = ref.read(databaseServiceProvider);
      final sent = await db.sendMessage(
        conversationId: widget.conversationId,
        senderId: userId,
        type: 'voice',
        text: null,
        voiceUrl: voiceUrl,
        voiceDurationSeconds: duration,
      );

      // Replace optimistic with server message
      if (mounted) {
        setState(() {
          final idx = _messages.indexWhere((m) => m.localId == localId);
          if (idx != -1) {
            _messages[idx] = MessageModel.fromJson(sent).copyWith(localId: localId);
          }
        });
      }
    } catch (_) {
      // Mark as failed for retry
      if (mounted) {
        setState(() {
          final idx = _messages.indexWhere((m) => m.localId == localId);
          if (idx != -1) {
            _messages[idx] = _messages[idx].copyWith(isFailed: true, isOptimistic: false);
          }
        });
      }
    } finally {
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
              Builder(builder: (_) {
                final l10n = AppLocalizations.of(context)!;
                return Text(l10n.chatQuickActions, style: AppTypography.h3Subsection);
              }),
              const SizedBox(height: 16),

              // ── Simplified quick actions (Phase 2E) ──
              // Booking is now done via load detail screen, not chat.
              // Chat is for questions only: text + voice + location.

              _AttachOption(
                icon: Icons.location_on_outlined,
                label: AppLocalizations.of(context)!.chatSendLocation,
                color: AppColors.info,
                onTap: () {
                  Navigator.pop(ctx);
                  _sendLocation();
                },
              ),
              if (isTrucker)
                _AttachOption(
                  icon: Icons.price_change_outlined,
                  label: AppLocalizations.of(context)!.chatQuoteRate,
                  color: AppColors.brandOrange,
                  onTap: () {
                    Navigator.pop(ctx);
                    _sendQuickAction(AppLocalizations.of(context)!.chatQuoteRateMsg);
                  },
                ),
              if (isTrucker)
                _AttachOption(
                  icon: Icons.check_circle_outline,
                  label: AppLocalizations.of(context)!.chatConfirmAvailability,
                  color: AppColors.success,
                  onTap: () {
                    Navigator.pop(ctx);
                    _sendQuickAction(AppLocalizations.of(context)!.chatConfirmAvailabilityMsg);
                  },
                ),
              if (!isTrucker)
                _AttachOption(
                  icon: Icons.info_outline,
                  label: AppLocalizations.of(context)!.chatAskTruckDetails,
                  color: AppColors.warning,
                  onTap: () {
                    Navigator.pop(ctx);
                    _sendQuickAction(AppLocalizations.of(context)!.chatAskTruckDetailsMsg);
                  },
                ),
              _AttachOption(
                icon: Icons.price_change_outlined,
                label: AppLocalizations.of(context)!.chatNegotiatePrice,
                color: AppColors.brandTeal,
                onTap: () {
                  Navigator.pop(ctx);
                  _sendQuickAction(AppLocalizations.of(context)!.chatNegotiatePriceMsg);
                },
              ),
            ],
          ),
        ),
      ),
    );
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
              // CHAT-B: Load context banner
              if (_loadInfo != null)
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                  decoration: BoxDecoration(
                    color: AppColors.brandTealLight,
                    border: Border(
                      bottom: BorderSide(
                        color: AppColors.brandTeal.withValues(alpha: 0.20),
                      ),
                    ),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.inventory_2,
                          size: 16, color: AppColors.brandTeal),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          '${_loadInfo!['origin_city']} → ${_loadInfo!['dest_city']}  •  '
                          '${_loadInfo!['material'] ?? '-'}  •  '
                          '₹${_loadInfo!['price'] ?? '-'}/ton',
                          style: AppTypography.caption.copyWith(
                            color: AppColors.brandTeal,
                            fontWeight: FontWeight.w500,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ),
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
                                viewerRole: ref.read(userRoleProvider).valueOrNull ?? 'trucker',
                                onRetry: msg.isFailed ? () => _retryMessage(msg) : null,
                                onAcceptDeal: null,
                                onRejectDeal: null,
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
  final void Function(Map<String, dynamic>)? onAcceptDeal;
  final void Function(Map<String, dynamic>)? onRejectDeal;
  final String viewerRole;

  const _MessageBubble({
    super.key,
    required this.message,
    required this.isMine,
    this.onRetry,
    this.onAcceptDeal,
    this.onRejectDeal,
    required this.viewerRole,
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
            _buildContent(context),
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

  Widget _buildContent(BuildContext context) {
    switch (message.messageType) {
      case 'truck_card':
        return _buildTruckCard(context);
      case 'load_card':
        return _buildLoadCard();
      case 'deal_proposal':
        return _buildDealProposal(context);
      case 'location':
        return _buildLocation();
      case 'map_card':
        return MapMessageCard(
          payload: message.payload ?? {},
          isMine: isMine,
          viewerRole: viewerRole,
        );
      case 'document':
        return _buildDocument();
      case 'voice':
        return VoiceMessageBubble(
          voiceUrl: message.voiceUrl ?? '',
          durationSeconds: message.voiceDurationSeconds ?? 0,
          isMine: isMine,
          isUploading: message.isOptimistic,
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

  Widget _buildTruckCard(BuildContext context) {
    final payload = message.payload ?? {};
    return GestureDetector(
      onTap: () => _showTruckDetails(context, payload),
      child: Container(
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
                Expanded(
                  child: Text(
                    payload['vehicle_number'] as String? ?? 'Truck',
                    style: TextStyle(
                      fontWeight: FontWeight.w600,
                      color: isMine ? Colors.white : AppColors.textPrimary,
                    ),
                  ),
                ),
                Icon(Icons.open_in_new, size: 12,
                    color: isMine
                        ? Colors.white.withValues(alpha: 0.60)
                        : AppColors.textTertiary),
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
      ),
    );
  }

  void _showTruckDetails(BuildContext context, Map<String, dynamic> p) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Icon(Icons.local_shipping,
                      color: AppColors.brandTeal, size: 24),
                  const SizedBox(width: 10),
                  Text(
                    p['vehicle_number'] as String? ?? 'Truck',
                    style: AppTypography.h3Subsection,
                  ),
                ],
              ),
              const SizedBox(height: 16),
              if (p['body_type'] != null)
                _detailRow('Body Type', p['body_type'].toString()),
              if (p['tyres'] != null)
                _detailRow('Tyres', '${p['tyres']} wheeler'),
              if (p['capacity_tonnes'] != null)
                _detailRow('Capacity', '${p['capacity_tonnes']} tonnes'),
              if (p['length_ft'] != null)
                _detailRow('Length', '${p['length_ft']} ft'),
              if (p['owner_name'] != null)
                _detailRow('Owner', p['owner_name'].toString()),
              const SizedBox(height: 8),
            ],
          ),
        ),
      ),
    );
  }

  Widget _detailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          SizedBox(
            width: 100,
            child: Text(label,
                style: AppTypography.caption
                    .copyWith(color: AppColors.textSecondary)),
          ),
          Expanded(
            child: Text(value, style: AppTypography.bodyMedium),
          ),
        ],
      ),
    );
  }

  Widget _buildLoadCard() {
    final p = message.payload ?? {};
    final textColor = isMine ? Colors.white : AppColors.textPrimary;
    final subtextColor = isMine
        ? Colors.white.withValues(alpha: 0.80)
        : AppColors.textSecondary;

    return Container(
      width: 240,
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: isMine
            ? Colors.white.withValues(alpha: 0.15)
            : AppColors.brandTealLight,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: isMine
              ? Colors.white.withValues(alpha: 0.25)
              : AppColors.brandTeal.withValues(alpha: 0.30),
          width: 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Row(
            children: [
              Icon(Icons.inventory_2,
                  size: 16, color: isMine ? Colors.white : AppColors.brandTeal),
              const SizedBox(width: 6),
              Text('Load Details',
                  style: TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 13,
                    color: textColor,
                  )),
            ],
          ),
          const SizedBox(height: 6),
          // Route
          Text(
            '${p['origin_city'] ?? '?'} → ${p['dest_city'] ?? '?'}',
            style: TextStyle(
              fontWeight: FontWeight.w600,
              fontSize: 14,
              color: textColor,
            ),
          ),
          const SizedBox(height: 4),
          // Material + Weight
          Text(
            '${p['material'] ?? '-'} • ${p['weight_tonnes'] ?? '-'} tonnes',
            style: TextStyle(fontSize: 13, color: subtextColor),
          ),
          const SizedBox(height: 2),
          // Price
          Row(
            children: [
              Text(
                '₹${p['price'] ?? '-'}/ton',
                style: TextStyle(
                  fontWeight: FontWeight.w700,
                  fontSize: 14,
                  color: textColor,
                ),
              ),
              if (p['price_type'] != null) ...[
                const SizedBox(width: 6),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                  decoration: BoxDecoration(
                    color: isMine
                        ? Colors.white.withValues(alpha: 0.20)
                        : AppColors.scaffoldBg,
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    (p['price_type'] as String).toUpperCase(),
                    style: TextStyle(fontSize: 10, color: subtextColor),
                  ),
                ),
              ],
            ],
          ),
          // Truck type + pickup
          if (p['required_truck_type'] != null || p['pickup_date'] != null) ...[
            const SizedBox(height: 4),
            Text(
              [
                if (p['required_truck_type'] != null)
                  '🚛 ${p['required_truck_type']}',
                if (p['pickup_date'] != null) '📅 ${p['pickup_date']}',
              ].join(' • '),
              style: TextStyle(fontSize: 12, color: subtextColor),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildDealProposal(BuildContext context) {
    final p = message.payload ?? {};
    final isPending = p['status'] == 'pending';
    final showActions = !isMine && isPending;

    return Container(
      width: 250,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: isMine
            ? Colors.white.withValues(alpha: 0.15)
            : AppColors.successLight,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: AppColors.success.withValues(alpha: 0.40),
          width: 1.5,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.handshake, size: 18,
                  color: isMine ? Colors.white : AppColors.success),
              const SizedBox(width: 6),
              Text('Deal Proposal',
                  style: TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 14,
                    color: isMine ? Colors.white : AppColors.success,
                  )),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            '${p['origin_city'] ?? '?'} → ${p['dest_city'] ?? '?'}',
            style: TextStyle(
              fontWeight: FontWeight.w600,
              fontSize: 13,
              color: isMine ? Colors.white : AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            '${p['material'] ?? '-'} • ${p['weight_tonnes'] ?? '-'} tonnes',
            style: TextStyle(
              fontSize: 12,
              color: isMine
                  ? Colors.white.withValues(alpha: 0.80)
                  : AppColors.textSecondary,
            ),
          ),
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: isMine
                  ? Colors.white.withValues(alpha: 0.10)
                  : Colors.white,
              borderRadius: BorderRadius.circular(6),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Price',
                        style: TextStyle(fontSize: 10,
                            color: isMine
                            ? Colors.white.withValues(alpha: 0.60)
                            : AppColors.textTertiary)),
                    Text('₹${p['proposed_price'] ?? '-'}/ton',
                        style: TextStyle(
                          fontWeight: FontWeight.w700,
                          fontSize: 15,
                          color: isMine ? Colors.white : AppColors.textPrimary,
                        )),
                  ],
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text('Advance',
                        style: TextStyle(fontSize: 10,
                            color: isMine
                            ? Colors.white.withValues(alpha: 0.60)
                            : AppColors.textTertiary)),
                    Text('${p['advance_percentage'] ?? '-'}%',
                        style: TextStyle(
                          fontWeight: FontWeight.w700,
                          fontSize: 15,
                          color: isMine ? Colors.white : AppColors.textPrimary,
                        )),
                  ],
                ),
              ],
            ),
          ),
          if (showActions) ...[
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => onRejectDeal?.call(p),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppColors.error,
                      side: const BorderSide(color: AppColors.error),
                      padding: const EdgeInsets.symmetric(vertical: 6),
                      minimumSize: const Size(0, 32),
                    ),
                    child: const Text('Reject', style: TextStyle(fontSize: 12)),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: FilledButton(
                    onPressed: () => onAcceptDeal?.call(p),
                    style: FilledButton.styleFrom(
                      backgroundColor: AppColors.success,
                      padding: const EdgeInsets.symmetric(vertical: 6),
                      minimumSize: const Size(0, 32),
                    ),
                    child: const Text('Accept', style: TextStyle(fontSize: 12)),
                  ),
                ),
              ],
            ),
          ],
          if (!isPending) ...[
            const SizedBox(height: 6),
            Center(
              child: Text(
                p['status'] == 'accepted' ? '✅ Deal Accepted' : '❌ Declined',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: p['status'] == 'accepted'
                      ? AppColors.success
                      : AppColors.error,
                ),
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
